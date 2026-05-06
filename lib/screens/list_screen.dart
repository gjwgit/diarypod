/// ListScreen — searchable, filterable list of diary entries.
///
// Time-stamp: <2026-04-26>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:diarypod/models/diary_entry.dart';
import 'package:diarypod/pages/entry_edit.dart';
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
    _search.dispose();
    super.dispose();
  }

  Future<void> _addEntry(BuildContext context, AppProvider provider) async {
    final entry = await showDialog<DiaryEntry>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EntryEdit(
        entry: _query.trim().isNotEmpty
            ? AppProvider.newEntry().copyWith(title: _query.trim())
            : null,
      ),
    );
    if (entry != null && context.mounted) {
      provider.addEntry(entry);
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
  }

  void _showFilterSheet(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _FilterSheet(
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
        // ── Search bar ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search entries…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isEmpty
                        ? null
                        : MarkdownTooltip(
                            message:
                                '**Clear search**\n\nRemove the search text and show all entries.',
                            child: IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                          ),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) {
                      _addEntry(context, provider);
                    }
                  },
                ),
              ),
              const Gap(8),
              const MarkdownTooltip(
                message:
                    '**Search tips**\n\n'
                    '- Plain text searches title, notes, location and tags\n'
                    '- Use `tag:health` to filter by a specific tag\n'
                    '- Future events are shown with a blue badge\n'
                    '- Use the filter button to narrow by type or tag',
                child: Icon(Icons.help_outline, size: 18),
              ),
              MarkdownTooltip(
                message: '**Add entry**\n\nCreate a new diary entry.',
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () => _addEntry(context, provider),
                ),
              ),
              MarkdownTooltip(
                message: '**Filter**\n\nFilter by past/future or by tags.',
                child: IconButton(
                  icon: Badge(
                    isLabelVisible: _hasFilter,
                    child: const Icon(Icons.filter_list),
                  ),
                  onPressed: () => _showFilterSheet(context, provider),
                ),
              ),
            ],
          ),
        ),

        // ── Active filter chips ──────────────────────────────────────
        if (_hasFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 6,
              children: [
                if (_timeFilter != DiaryTimeFilter.all)
                  FilterChip(
                    label: Text(switch (_timeFilter) {
                      DiaryTimeFilter.past => 'Past',
                      DiaryTimeFilter.today => 'Today',
                      DiaryTimeFilter.pastAndToday => 'Past & Today',
                      DiaryTimeFilter.upcoming => 'Upcoming',
                      DiaryTimeFilter.all => '',
                    }),
                    selected: true,
                    onSelected: (_) {
                      setState(() => _timeFilter = DiaryTimeFilter.all);
                      _savePrefs();
                    },
                  ),
                for (final t in _tagFilter)
                  FilterChip(
                    label: Text(t),
                    selected: true,
                    onSelected: (_) {
                      setState(
                        () => _tagFilter = _tagFilter
                            .where((x) => x != t)
                            .toList(),
                      );
                      _savePrefs();
                    },
                  ),
              ],
            ),
          ),

        // ── List ─────────────────────────────────────────────────────
        if (provider.loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (entries.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const Gap(16),
                  Text(
                    _query.isNotEmpty || _hasFilter
                        ? 'No entries match your search.'
                        : 'No diary entries yet.\nTap + to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: entries.length,
              itemBuilder: (_, i) => EntryTile(
                entry: entries[i],
                onTap: () => _editEntry(context, provider, entries[i]),
                onDelete: () => _deleteEntry(context, provider, entries[i]),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final DiaryTimeFilter timeFilter;
  final List<String> tagFilter;
  final List<String> allTags;
  final void Function(DiaryTimeFilter tf, List<String> tags) onApply;

  const _FilterSheet({
    required this.timeFilter,
    required this.tagFilter,
    required this.allTags,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late DiaryTimeFilter _filter;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _filter = widget.timeFilter;
    _tags = List<String>.from(widget.tagFilter);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter', style: Theme.of(context).textTheme.titleLarge),
          const Gap(16),
          Text('Show', style: Theme.of(context).textTheme.labelLarge),
          const Gap(8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _filter == DiaryTimeFilter.all,
                onSelected: (_) =>
                    setState(() => _filter = DiaryTimeFilter.all),
              ),
              ChoiceChip(
                label: const Text('Past'),
                selected: _filter == DiaryTimeFilter.past,
                onSelected: (_) =>
                    setState(() => _filter = DiaryTimeFilter.past),
              ),
              ChoiceChip(
                label: const Text('Today'),
                selected: _filter == DiaryTimeFilter.today,
                onSelected: (_) =>
                    setState(() => _filter = DiaryTimeFilter.today),
              ),
              ChoiceChip(
                label: const Text('Past & Today'),
                selected: _filter == DiaryTimeFilter.pastAndToday,
                onSelected: (_) =>
                    setState(() => _filter = DiaryTimeFilter.pastAndToday),
              ),
              ChoiceChip(
                label: const Text('Upcoming'),
                selected: _filter == DiaryTimeFilter.upcoming,
                onSelected: (_) =>
                    setState(() => _filter = DiaryTimeFilter.upcoming),
              ),
            ],
          ),
          if (widget.allTags.isNotEmpty) ...[
            const Gap(16),
            Text('Tags', style: Theme.of(context).textTheme.labelLarge),
            const Gap(8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.allTags.map((t) {
                return FilterChip(
                  label: Text(t),
                  selected: _tags.contains(t),
                  onSelected: (sel) => setState(() {
                    sel ? _tags.add(t) : _tags.remove(t);
                  }),
                );
              }).toList(),
            ),
          ],
          const Gap(24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _filter = DiaryTimeFilter.all;
                    _tags = [];
                  });
                  widget.onApply(DiaryTimeFilter.all, []);
                },
                child: const Text('Clear'),
              ),
              const Gap(8),
              FilledButton(
                onPressed: () => widget.onApply(_filter, _tags),
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
