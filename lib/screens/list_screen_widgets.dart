/// ListScreen helper widgets — search bar, filter chips, empty state.
///
// Time-stamp: <2026-05-15>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:gap/gap.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:diarypod/services/app_provider.dart';

// ── Search bar ────────────────────────────────────────────────────────────────

class ListSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final bool hasFilter;
  final VoidCallback onAdd;
  final VoidCallback onFilter;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  const ListSearchBar({
    super.key,
    required this.controller,
    required this.query,
    required this.hasFilter,
    required this.onAdd,
    required this.onFilter,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Search entries…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (query.isNotEmpty)
                      MarkdownTooltip(
                        message:
                            '**Clear search**\n\nRemove the search text and show all entries.',
                        child: IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => onChanged(''),
                        ),
                      ),
                    MarkdownTooltip(
                      message: '**Add entry**\n\nCreate a new diary entry.',
                      child: IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: onAdd,
                      ),
                    ),
                  ],
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              onChanged: onChanged,
              onSubmitted: onSubmitted,
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
            message: '**Filter**\n\nFilter by past/future or by tags.',
            child: IconButton(
              icon: Badge(
                isLabelVisible: hasFilter,
                child: const Icon(Icons.filter_list),
              ),
              onPressed: onFilter,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Active filter chips ───────────────────────────────────────────────────────

class ActiveFilterChips extends StatelessWidget {
  final DiaryTimeFilter timeFilter;
  final List<String> tagFilter;
  final VoidCallback onClearTime;
  final ValueChanged<String> onRemoveTag;

  const ActiveFilterChips({
    super.key,
    required this.timeFilter,
    required this.tagFilter,
    required this.onClearTime,
    required this.onRemoveTag,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilter = timeFilter != DiaryTimeFilter.all || tagFilter.isNotEmpty;
    if (!hasFilter) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 6,
        children: [
          if (timeFilter != DiaryTimeFilter.all)
            FilterChip(
              label: Text(switch (timeFilter) {
                DiaryTimeFilter.past => 'Past',
                DiaryTimeFilter.today => 'Today',
                DiaryTimeFilter.pastAndToday => 'Past & Today',
                DiaryTimeFilter.upcoming => 'Upcoming',
                DiaryTimeFilter.all => '',
              }),
              selected: true,
              onSelected: (_) => onClearTime(),
            ),
          for (final t in tagFilter)
            FilterChip(
              label: Text(t),
              selected: true,
              onSelected: (_) => onRemoveTag(t),
            ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class EntryListEmpty extends StatelessWidget {
  final bool hasSearch;

  const EntryListEmpty({super.key, required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Expanded(
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
              hasSearch
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
    );
  }
}
