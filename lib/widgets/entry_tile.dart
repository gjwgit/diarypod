/// EntryTile — a single diary entry in the list view.
///
// Time-stamp: <Friday 2026-05-08 05:38:53 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:diarypod/models/diary_entry.dart';

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final timeFmt = DateFormat('HH:mm');
    final isFuture = entry.isFuture;
    final isPast = !isFuture && entry.eventDate.isBefore(DateTime.now());

    return Card(
      color: isFuture
          ? cs.primaryContainer.withValues(alpha: 0.35)
          : isPast
          ? const Color(0xFF4CAF50).withValues(alpha: 0.10)
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
                      : isPast
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.25)
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
                            : isPast
                            ? const Color(0xFF2E7D32)
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
                            : isPast
                            ? const Color(0xFF2E7D32)
                            : cs.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(entry.eventDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: isFuture
                            ? cs.onPrimary.withValues(alpha: 0.8)
                            : isPast
                            ? const Color(0xFF2E7D32).withValues(alpha: 0.85)
                            : cs.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      timeFmt.format(entry.eventDate),
                      style: TextStyle(
                        fontSize: 10,
                        color: isFuture
                            ? cs.onPrimary.withValues(alpha: 0.7)
                            : isPast
                            ? const Color(0xFF2E7D32).withValues(alpha: 0.75)
                            : cs.onSecondaryContainer.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(12),

              // ── Content ─────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isFuture) ...[
                          Icon(
                            Icons.event_outlined,
                            size: 14,
                            color: cs.primary,
                          ),
                          const Gap(4),
                        ],
                        Expanded(
                          child: Text(
                            entry.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (entry.location != null) ...[
                      const Gap(2),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                          const Gap(3),
                          Text(
                            entry.location!,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (entry.tags.isNotEmpty) ...[
                      const Gap(4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: entry.tags.map((t) {
                          return Chip(
                            label: Text(t),
                            labelStyle: const TextStyle(fontSize: 10),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                    if (entry.hasNote) ...[
                      const Gap(4),
                      SizedBox(
                        height: 60,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            maxHeight: double.infinity,
                            child: MarkdownBody(
                              data: entry.note,
                              shrinkWrap: true,
                              styleSheet: MarkdownStyleSheet(
                                p: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                                h1: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurfaceVariant,
                                ),
                                h2: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurfaceVariant,
                                ),
                                h3: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurfaceVariant,
                                ),
                                code: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant,
                                  backgroundColor: cs.surfaceContainerHighest,
                                ),
                                blockquote: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Gap(4),

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
            ],
          ),
        ),
      ),
    );
  }
}
