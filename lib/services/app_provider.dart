/// AppProvider — central state for DairyPod.
///
// Time-stamp: <2026-04-26>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:diarypod/models/diary_entry.dart';
import 'package:diarypod/services/pod_service.dart';

/// Time-range filter for the diary list.
enum DiaryTimeFilter { all, past, today, pastAndToday, upcoming }

class AppProvider extends ChangeNotifier {
  AppProvider();

  // ── State ───────────────────────────────────────────────────────────────────

  List<DiaryEntry> _entries = [];
  bool _loading = false;
  bool _testMode = false;
  bool _hasLoaded = false;

  List<DiaryEntry> get entries => List.unmodifiable(_entries);
  bool get loading => _loading;

  /// All known tags across all entries, sorted.
  List<String> get allTags {
    final tags = <String>{};
    for (final e in _entries) {
      tags.addAll(e.tags);
    }
    return tags.toList()..sort();
  }

  /// Entries sorted newest-event-first, optionally filtered.
  /// Parse `tag:xxx` tokens from [query], returning the extracted tag names
  /// and the remaining text query.
  static ({List<String> tags, String text}) _parseQuery(String query) {
    final tagRe = RegExp(r'tag:(\S+)', caseSensitive: false);
    final tags = tagRe
        .allMatches(query)
        .map((m) => m.group(1)!.toLowerCase())
        .toList();
    final text = query.replaceAll(tagRe, '').trim();
    return (tags: tags, text: text);
  }

  List<DiaryEntry> filtered({
    String query = '',
    List<String> tags = const [],
    DiaryTimeFilter timeFilter = DiaryTimeFilter.all,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    var result = _entries.toList();
    switch (timeFilter) {
      case DiaryTimeFilter.past:
        result = result.where((e) => e.eventDate.isBefore(today)).toList();
      case DiaryTimeFilter.today:
        result = result
            .where(
              (e) =>
                  !e.eventDate.isBefore(today) &&
                  e.eventDate.isBefore(tomorrow),
            )
            .toList();
      case DiaryTimeFilter.upcoming:
        result = result.where((e) => !e.eventDate.isBefore(tomorrow)).toList();
      case DiaryTimeFilter.pastAndToday:
        result = result.where((e) => e.eventDate.isBefore(tomorrow)).toList();
      case DiaryTimeFilter.all:
        break;
    }
    // Combine explicit tag filter with any tag:xxx tokens from the query.
    final parsed = _parseQuery(query);
    final allTagFilters = [...tags, ...parsed.tags];
    if (allTagFilters.isNotEmpty) {
      result = result
          .where((e) => allTagFilters.every((t) => e.tags.contains(t)))
          .toList();
    }
    if (parsed.text.isNotEmpty) {
      final q = parsed.text.toLowerCase();
      result = result
          .where(
            (e) =>
                e.title.toLowerCase().contains(q) ||
                e.note.toLowerCase().contains(q) ||
                (e.location?.toLowerCase().contains(q) ?? false) ||
                e.tags.any((t) => t.toLowerCase().contains(q)),
          )
          .toList();
    }
    result.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return result;
  }

  /// All entries that fall on [day] (same calendar date).
  List<DiaryEntry> entriesForDay(DateTime day) => _entries
      .where(
        (e) =>
            e.eventDate.year == day.year &&
            e.eventDate.month == day.month &&
            e.eventDate.day == day.day,
      )
      .toList();

  // ── Load / Save ─────────────────────────────────────────────────────────────

  Future<void> loadFromPod() async {
    if (_testMode || _hasLoaded) return;
    _hasLoaded = true;
    _loading = true;
    notifyListeners();
    try {
      _entries = await PodService.load();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> saveToPod() async {
    if (_testMode) return;
    await PodService.save(_entries);
  }

  /// For unit tests — bypasses Pod I/O.
  void loadTestData(List<DiaryEntry> entries) {
    _testMode = true;
    _entries = List<DiaryEntry>.from(entries);
    notifyListeners();
  }

  // ── CRUD ────────────────────────────────────────────────────────────────────

  void addEntry(DiaryEntry entry) {
    _entries.add(entry);
    _entries.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    notifyListeners();
  }

  void updateEntry(DiaryEntry updated) {
    final idx = _entries.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;
    _entries[idx] = updated;
    _entries.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    notifyListeners();
  }

  void deleteEntry(String id) {
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Import a list of entries, skipping any whose id already exists.
  int importEntries(List<DiaryEntry> incoming) {
    final existing = _entries.map((e) => e.id).toSet();
    final fresh = incoming.where((e) => !existing.contains(e.id)).toList();
    _entries.addAll(fresh);
    _entries.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    notifyListeners();
    return fresh.length;
  }

  /// Create a new empty entry with a fresh UUID and current timestamps.
  static DiaryEntry newEntry({DateTime? eventDate}) {
    final now = DateTime.now();
    return DiaryEntry(
      id: const Uuid().v4(),
      eventDate: eventDate ?? now,
      title: '',
      createdAt: now,
      modifiedAt: now,
    );
  }
}
