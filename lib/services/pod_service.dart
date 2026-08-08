/// PodService — encrypted TTL read/write for DairyPod.
///
// Time-stamp: <Thursday 2026-04-30 09:31:07 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:diarypod/constants/app.dart';
import 'package:diarypod/models/diary_entry.dart';

class PodService {
  PodService._();

  static const _predicate =
      'https://schema.org/'
      'diary';

  /// Load diary entries from the Pod.
  ///
  /// Returns an empty list when the file does not yet exist.
  static Future<List<DiaryEntry>> load() async {
    try {
      final content = await readPod(diaryFilePathSuffix);
      if (content.isEmpty) return [];
      return _parse(content);
    } catch (e) {
      debugPrint('[PodService.load] $e');
      return [];
    }
  }

  /// Save diary entries to the Pod as encrypted TTL.
  static Future<void> save(List<DiaryEntry> entries) async {
    try {
      final ttl = _serialise(entries);
      await SolidPendingWrites.track(
        writePod(diaryFilePathSuffix, ttl, overwrite: true),
      );
    } catch (e) {
      debugPrint('[PodService.save] $e');
      rethrow;
    }
  }

  // ── TTL helpers ─────────────────────────────────────────────────────────────

  static String _serialise(List<DiaryEntry> entries) {
    final buf = StringBuffer();
    buf.writeln('@prefix schema: <https://schema.org/> .');
    buf.writeln('@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .');
    buf.writeln();
    for (final e in entries) {
      final json = jsonEncode(e.toJson());
      final escaped = json.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
      buf.writeln('<#${e.id}> $_predicate "$escaped" .');
    }
    return buf.toString();
  }

  static List<DiaryEntry> _parse(String ttl) {
    final entries = <DiaryEntry>[];
    final re = RegExp(r'<#[^>]+> [^ ]+ "(.+)" \.$', multiLine: true);
    for (final m in re.allMatches(ttl)) {
      try {
        final raw = m.group(1)!.replaceAll('\\"', '"').replaceAll('\\\\', '\\');
        final map = jsonDecode(raw) as Map<String, dynamic>;
        entries.add(DiaryEntry.fromJson(map));
      } catch (e) {
        debugPrint('[PodService._parse] skipping entry: $e');
      }
    }
    entries.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return entries;
  }
}
