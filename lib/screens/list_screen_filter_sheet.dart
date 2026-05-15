/// ListScreen filter bottom sheet.
///
// Time-stamp: <2026-05-15>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:gap/gap.dart';

import 'package:diarypod/services/app_provider.dart';

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class FilterSheet extends StatefulWidget {
  final DiaryTimeFilter timeFilter;
  final List<String> tagFilter;
  final List<String> allTags;
  final void Function(DiaryTimeFilter tf, List<String> tags) onApply;

  const FilterSheet({
    super.key,
    required this.timeFilter,
    required this.tagFilter,
    required this.allTags,
    required this.onApply,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
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
              children: widget.allTags
                  .map(
                    (t) => FilterChip(
                      label: Text(t),
                      selected: _tags.contains(t),
                      onSelected: (sel) => setState(() {
                        sel ? _tags.add(t) : _tags.remove(t);
                      }),
                    ),
                  )
                  .toList(),
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
