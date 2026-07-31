/// EntryNotePreview — clipped Markdown preview of an entry's note.
///
// Time-stamp: <Friday 2026-07-31 09:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Top-aligned Markdown rendering of [note], clipped to [height] so that
/// every tile in the list keeps the same height regardless of note length.
///
/// [height] varies by layout: the tile gives the preview a little more room
/// when it sits beside the title block on a wide screen than when it sits
/// below it on a narrow one.

class EntryNotePreview extends StatelessWidget {
  final String note;
  final double height;

  const EntryNotePreview({super.key, required this.note, required this.height});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: height,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          maxHeight: double.infinity,
          child: MarkdownBody(
            data: note,
            shrinkWrap: true,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
