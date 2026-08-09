/// EntryTile — a single diary entry in the list view.
///
// Time-stamp: <Friday 2026-05-08 05:38:53 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:diarypod/models/diary_entry.dart';
import 'package:diarypod/widgets/entry_note_preview.dart';

class EntryTile extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onPdf;

  const EntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
    required this.onPdf,
  });

  /// The title, optional location and tag chips — the block that sits either
  /// above the note preview (narrow) or to its left (wide).

  Widget _titleBlock(ColorScheme cs, bool isFuture) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titleAndLocation(cs, isFuture),
        if (entry.tags.isNotEmpty) ...[const Gap(4), _tagChips()],
      ],
    );
  }

  /// Title plus optional location — the part that shares its line with the
  /// action buttons on a narrow screen.

  Widget _titleAndLocation(ColorScheme cs, bool isFuture) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (isFuture) ...[
              Icon(Icons.event_outlined, size: 14, color: cs.primary),
              const Gap(4),
            ],
            Expanded(
              child: Text(
                entry.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
        ),
        if (entry.location != null) ...[
          const Gap(2),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 12, color: cs.onSurfaceVariant),
              const Gap(3),
              Text(
                entry.location!,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _tagChips() {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: entry.tags.map((t) {
        return Chip(
          label: Text(t),
          labelStyle: const TextStyle(fontSize: 10),
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  /// Duplicate / PDF / Delete — to the right of the whole tile when wide, and
  /// beside the title (so tags and the note can run under them) when narrow.

  List<Widget> _actions(ColorScheme cs) {
    return [
      // ── Duplicate ────────────────────────────────────────────
      MarkdownTooltip(
        message:
            '**Duplicate**\n\nCopy this entry with the date/time '
            'set to now and open it for editing.',
        child: IconButton(
          icon: const Icon(Icons.copy_outlined, size: 18),
          onPressed: onDuplicate,
        ),
      ),

      // ── PDF ──────────────────────────────────────────────────
      MarkdownTooltip(
        message:
            '**PDF**\n\nPreview this entry as a PDF and optionally '
            'save it to a file.',
        child: IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          onPressed: onPdf,
        ),
      ),

      // ── Delete ──────────────────────────────────────────────
      MarkdownTooltip(
        message:
            '**Delete**\n\nPermanently remove this entry. '
            'This cannot be undone.',
        child: IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          color: cs.error,
          onPressed: onDelete,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final timeFmt = DateFormat('HH:mm');
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final eventDay = DateUtils.dateOnly(entry.eventDate);
    final isFuture = entry.isFuture;
    final isToday = !isFuture && eventDay == today;
    final isPast = !isFuture && !isToday;

    // Same breakpoint as the reference panel's side-sheet/bottom-sheet
    // choice, so "wide" means one thing across the app. 20260731 gjw

    final isWide = MediaQuery.of(context).size.width >= 700;

    // The side-by-side layout only pays off when there is a note to put in
    // the middle column; otherwise use the stacked layout, which keeps the
    // buttons on the title's line. 20260809 gjw

    final sideBySide = isWide && entry.hasNote;

    return Card(
      color: isFuture
          ? cs.primaryContainer.withValues(alpha: 0.35)
          : isToday
          ? Colors.blue.withValues(alpha: 0.15)
          : isPast
          ? const Color(0xFF4CAF50).withValues(alpha: 0.30)
          : cs.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Date badge ─────────────────────────────────────────
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isFuture
                      ? cs.primary
                      : isToday
                      ? Colors.blue.shade700
                      : isPast
                      ? const Color(0xFF2E7D32)
                      : cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('EEE').format(entry.eventDate),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isFuture
                            ? cs.onPrimary.withValues(alpha: 0.9)
                            : isToday
                            ? Colors.white.withValues(alpha: 0.9)
                            : isPast
                            ? Colors.white
                            : cs.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      entry.eventDate.day.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isFuture
                            ? cs.onPrimary
                            : isToday
                            ? Colors.white
                            : isPast
                            ? Colors.white
                            : cs.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(entry.eventDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: isFuture
                            ? cs.onPrimary.withValues(alpha: 0.8)
                            : isToday
                            ? Colors.white.withValues(alpha: 0.85)
                            : isPast
                            ? Colors.white.withValues(alpha: 0.85)
                            : cs.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      timeFmt.format(entry.eventDate),
                      style: TextStyle(
                        fontSize: 10,
                        color: isFuture
                            ? cs.onPrimary.withValues(alpha: 0.7)
                            : isToday
                            ? Colors.white.withValues(alpha: 0.75)
                            : isPast
                            ? Colors.white.withValues(alpha: 0.75)
                            : cs.onSecondaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),

              // ── Content ─────────────────────────────────────────────
              //
              // Wide screens have plenty of unused width beside the title
              // block, so the note preview sits in that middle space; narrow
              // screens keep it stacked below. 20260731 gjw
              Expanded(
                child: sideBySide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _titleBlock(cs, isFuture)),
                          const Gap(12),

                          // Slightly taller than the stacked preview: the
                          // column is narrower, so fewer words per line.
                          Expanded(
                            flex: 3,
                            child: EntryNotePreview(
                              note: entry.note,
                              height: 72,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Only the title shares its line with the buttons;
                          // the tags and the note preview then run the full
                          // width of the tile, using the space under the
                          // buttons instead of wrapping early. 20260809 gjw
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _titleAndLocation(cs, isFuture)),
                              const Gap(4),
                              ..._actions(cs),
                            ],
                          ),
                          if (entry.tags.isNotEmpty) ...[
                            const Gap(4),
                            _tagChips(),
                          ],
                          if (entry.hasNote) ...[
                            const Gap(4),
                            EntryNotePreview(note: entry.note, height: 60),
                          ],
                        ],
                      ),
              ),
              if (sideBySide) ...[const Gap(4), ..._actions(cs)],
            ],
          ),
        ),
      ),
    );
  }
}
