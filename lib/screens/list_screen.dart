/// ListScreen — searchable, filterable list of diary entries.
///
// Time-stamp: <2026-05-15>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:emacs_text_field/emacs_text_field.dart'
    show attachPrimarySelection;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:diarypod/models/diary_entry.dart';
import 'package:diarypod/pages/entry_edit.dart';
import 'package:diarypod/screens/diary_io.dart';
import 'package:diarypod/screens/list_screen_filter_sheet.dart';
import 'package:diarypod/screens/list_screen_widgets.dart';
import 'package:diarypod/services/app_provider.dart';
import 'package:diarypod/widgets/entry_tile.dart';

class ListScreen extends StatefulWidget {
  const ListScreen({
    super.key,
    this.initialFilter = DiaryTimeFilter.pastAndToday,
  });

  final DiaryTimeFilter initialFilter;

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final _search = TextEditingController();
  late final VoidCallback _removePrimarySearch;
  String _query = '';
  late DiaryTimeFilter _timeFilter;
  List<String> _tagFilter = [];

  static const _kTimeFilter = 'diary_time_filter';
  static const _kTagFilter = 'diary_tag_filter';

  @override
  void initState() {
    super.initState();
    _timeFilter = widget.initialFilter;
    _loadPrefs();
    _removePrimarySearch = attachPrimarySelection(_search);
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final tf = prefs.getString(_kTimeFilter + widget.initialFilter.name);
    final tags = prefs.getStringList(_kTagFilter + widget.initialFilter.name);
    if (!mounted) return;
    setState(() {
      _timeFilter = DiaryTimeFilter.values.firstWhere(
        (e) => e.name == tf,
        orElse: () => widget.initialFilter,
      );
      _tagFilter = tags ?? [];
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final suffix = widget.initialFilter.name;
    await prefs.setString(_kTimeFilter + suffix, _timeFilter.name);
    await prefs.setStringList(_kTagFilter + suffix, _tagFilter);
  }

  @override
  void dispose() {
    _removePrimarySearch();
    _search.dispose();
    super.dispose();
  }

  // ── Pod persistence ───────────────────────────────────────────────────────

  Future<void> _saveToPod(BuildContext context, AppProvider provider) async {
    try {
      await provider.saveToPod();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  // ── Entry actions ─────────────────────────────────────────────────────────

  Future<void> _addEntry(BuildContext context, AppProvider provider) async {
    final entry = await showDialog<DiaryEntry>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EntryEdit(
        entry: _query.trim().isNotEmpty
            ? AppProvider.newEntry().copyWith(title: _query.trim())
            : null,
        initialPreview: false,
      ),
    );
    if (entry != null && context.mounted) {
      provider.addEntry(entry);
      if (_query.isNotEmpty) {
        _search.clear();
        setState(() => _query = '');
      }
      await _saveToPod(context, provider);
    }
  }

  Future<void> _editEntry(
    BuildContext context,
    AppProvider provider,
    DiaryEntry entry,
  ) async {
    final updated = await Navigator.of(context).push<DiaryEntry>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EntryEdit(entry: entry),
      ),
    );
    if (updated != null && context.mounted) {
      provider.updateEntry(updated);
      await _saveToPod(context, provider);
    }
  }

  Future<void> _duplicateEntry(
    BuildContext context,
    AppProvider provider,
    DiaryEntry entry,
  ) async {
    final now = DateTime.now();
    final duplicate = entry.copyWith(
      id: const Uuid().v4(),
      eventDate: now,
      createdAt: now,
      modifiedAt: now,
    );
    final updated = await Navigator.of(context).push<DiaryEntry>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EntryEdit(entry: duplicate),
      ),
    );
    if (updated != null && context.mounted) {
      provider.addEntry(updated);
      await _saveToPod(context, provider);
    }
  }

  Future<void> _deleteEntry(
    BuildContext context,
    AppProvider provider,
    DiaryEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text('"${entry.title}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      provider.deleteEntry(entry.id);
      await _saveToPod(context, provider);
    }
  }

  void _showFilterSheet(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (_) => FilterSheet(
        timeFilter: _timeFilter,
        tagFilter: _tagFilter,
        allTags: provider.allTags,
        onApply: (tf, tags) {
          setState(() {
            _timeFilter = tf;
            _tagFilter = tags;
          });
          _savePrefs();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  bool get _hasFilter =>
      _timeFilter != DiaryTimeFilter.all || _tagFilter.isNotEmpty;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final entries = provider.filtered(
      query: _query,
      tags: _tagFilter,
      timeFilter: _timeFilter,
    );

    return Column(
      children: [
        ListSearchBar(
          controller: _search,
          query: _query,
          hasFilter: _hasFilter,
          onAdd: () => _addEntry(context, provider),
          onFilter: () => _showFilterSheet(context, provider),
          onChanged: (v) {
            _search.value = _search.value.copyWith(text: v);
            setState(() => _query = v);
          },
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) _addEntry(context, provider);
          },
        ),
        ActiveFilterChips(
          timeFilter: _timeFilter,
          tagFilter: _tagFilter,
          onClearTime: () {
            setState(() => _timeFilter = DiaryTimeFilter.all);
            _savePrefs();
          },
          onRemoveTag: (t) {
            setState(
              () => _tagFilter = _tagFilter.where((x) => x != t).toList(),
            );
            _savePrefs();
          },
        ),
        if (provider.loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (entries.isEmpty)
          EntryListEmpty(hasSearch: _query.isNotEmpty || _hasFilter)
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: entries.length,
              itemBuilder: (_, i) => EntryTile(
                entry: entries[i],
                onTap: () => _editEntry(context, provider, entries[i]),
                onDelete: () => _deleteEntry(context, provider, entries[i]),
                onDuplicate: () =>
                    _duplicateEntry(context, provider, entries[i]),
                onPdf: () => DiaryIO.entryPdf(context, entries[i]),
              ),
            ),
          ),
      ],
    );
  }
}
