/// CalendarScreen — monthly calendar view of diary entries.
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
import 'package:solidui/solidui.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:diarypod/models/diary_entry.dart';
import 'package:diarypod/pages/entry_duplicate.dart';
import 'package:diarypod/pages/entry_edit.dart';
import 'package:diarypod/screens/diary_io.dart';
import 'package:diarypod/services/app_provider.dart';
import 'package:diarypod/widgets/entry_tile.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  Future<void> _addEntry(
    BuildContext context,
    AppProvider provider, [
    DateTime? day,
  ]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EntryEdit(
        entry: AppProvider.newEntry(
          eventDate: day ?? _selectedDay ?? DateTime.now(),
        ),
        onSave: (entry) async {
          if (provider.entries.any((e) => e.id == entry.id)) {
            provider.updateEntry(entry);
          } else {
            provider.addEntry(entry);
          }
          // Left to propagate: EntryEdit must see a failure so it does not
          // mark itself saved.
          await provider.saveToPod();
        },
      ),
    );
  }

  Future<void> _editEntry(
    BuildContext context,
    AppProvider provider,
    DiaryEntry entry,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => EntryEdit(
          entry: entry,
          onSave: (updated) async {
            provider.updateEntry(updated);
            // Left to propagate: EntryEdit must see a failure so it does not
            // mark itself saved.
            await provider.saveToPod();
          },
        ),
      ),
    );
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
        // Errors need acknowledging, so report rather than flash a SnackBar.
        SolidWriteFailures.report('Failed deleting the entry.\n\n$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final cs = Theme.of(context).colorScheme;
    final selected = _selectedDay;
    final dayEntries = selected != null
        ? provider.entriesForDay(selected)
        : <DiaryEntry>[];

    return Column(
      children: [
        // ── Calendar ───────────────────────────────────────────────────
        TableCalendar<DiaryEntry>(
          firstDay: DateTime(2010),
          lastDay: DateTime(2035),
          focusedDay: _focusedDay,
          selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
          eventLoader: provider.entriesForDay,
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: cs.secondary,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          onDaySelected: (selected, focused) {
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            });
          },
          onPageChanged: (focused) {
            _focusedDay = focused;
          },
        ),
        const Divider(),

        // ── Day entries list ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected != null ? _formatDay(selected) : 'Select a day',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              MarkdownTooltip(
                message: '**Today**\n\nJump back to today\'s date.',
                child: IconButton(
                  icon: const Icon(Icons.today_outlined, size: 20),
                  onPressed: () {
                    final today = DateTime.now();
                    setState(() {
                      _selectedDay = today;
                      _focusedDay = today;
                    });
                  },
                ),
              ),
              MarkdownTooltip(
                message:
                    '**Add entry**\n\nCreate a new entry on the selected day.',
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () => _addEntry(context, provider, selected),
                ),
              ),
            ],
          ),
        ),

        if (provider.loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (dayEntries.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 48,
                    color: cs.outlineVariant,
                  ),
                  const Gap(12),
                  Text(
                    'No entries on this day.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: dayEntries.length,
              itemBuilder: (_, i) => EntryTile(
                entry: dayEntries[i],
                onTap: () => _editEntry(context, provider, dayEntries[i]),
                onDelete: () => _deleteEntry(context, provider, dayEntries[i]),
                onDuplicate: () =>
                    duplicateEntry(context, provider, dayEntries[i]),
                onPdf: () => DiaryIO.entryPdf(context, dayEntries[i]),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDay(DateTime d) {
    final months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${days[d.weekday]}  ${d.day} ${months[d.month]} ${d.year}';
  }
}
