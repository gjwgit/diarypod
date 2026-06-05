/// ReferencePanel — view another diary entry while editing the current one.
///
/// Lets the user browse and search their other entries without leaving the
/// editor. The selected entry is shown with selectable text (so it can be
/// copied) and an "Insert at cursor" action that injects its note into the
/// entry being edited at the current cursor position.
///
// Time-stamp: <2026-06-04>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import 'package:diarypod/models/diary_entry.dart';

/// Show the reference panel. On wide screens it appears as a right-hand
/// side sheet; on narrow screens as a draggable bottom sheet.
///
/// [entries] is the list to browse (typically all entries except the one
/// being edited). [onInsert] is called with the chosen text to insert at
/// the editor's cursor.
Future<void> showReferencePanel({
  required BuildContext context,
  required List<DiaryEntry> entries,
  required void Function(String text) onInsert,
}) {
  final isWide = MediaQuery.of(context).size.width >= 700;

  if (isWide) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Reference',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 420,
          height: double.infinity,
          child: Material(
            elevation: 8,
            child: _ReferencePanelBody(entries: entries, onInsert: onInsert),
          ),
        ),
      ),
      transitionBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => _ReferencePanelBody(
        entries: entries,
        onInsert: onInsert,
        scrollController: scrollController,
      ),
    ),
  );
}

class _ReferencePanelBody extends StatefulWidget {
  final List<DiaryEntry> entries;
  final void Function(String text) onInsert;
  final ScrollController? scrollController;

  const _ReferencePanelBody({
    required this.entries,
    required this.onInsert,
    this.scrollController,
  });

  @override
  State<_ReferencePanelBody> createState() => _ReferencePanelBodyState();
}

class _ReferencePanelBodyState extends State<_ReferencePanelBody> {
  final _search = TextEditingController();
  DiaryEntry? _selected;
  bool _showMarkdown = true;

  // The currently highlighted text within the displayed reference note.
  // When non-empty, "Insert at cursor" inserts just this rather than the
  // whole note.
  String _highlighted = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<DiaryEntry> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.entries;
    return widget.entries.where((e) {
      return e.title.toLowerCase().contains(q) ||
          e.note.toLowerCase().contains(q) ||
          (e.location ?? '').toLowerCase().contains(q) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // When an entry is selected, show its detail; otherwise the list.
    return Column(
      children: [
        // Header.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              if (_selected != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to list',
                  onPressed: () => setState(() {
                    _selected = null;
                    _highlighted = '';
                  }),
                ),
              Expanded(
                child: Text(
                  _selected?.title ?? 'Reference a note',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _selected == null ? _buildList(cs) : _buildDetail(cs)),
      ],
    );
  }

  Widget _buildList(ColorScheme cs) {
    final items = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search notes…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    'No matching notes',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  controller: widget.scrollController,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = items[i];
                    return ListTile(
                      title: Text(
                        e.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        DateFormat('d MMM yyyy').format(e.eventDate),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () => setState(() {
                        _selected = e;
                        _highlighted = '';
                      }),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDetail(ColorScheme cs) {
    final e = _selected!;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE d MMM yyyy  HH:mm').format(e.eventDate),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                if (e.location != null && e.location!.isNotEmpty) ...[
                  const Gap(2),
                  Text(
                    e.location!,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
                const Gap(12),
                // Selectable so the user can copy any part. When markdown
                // view is on, render formatted; otherwise show raw text
                // (easier to copy exact source including markdown syntax).
                // The active selection is captured so "Insert at cursor"
                // can insert just the highlighted portion.
                if (_showMarkdown)
                  SelectionArea(
                    onSelectionChanged: (value) {
                      setState(() => _highlighted = value?.plainText ?? '');
                    },
                    child: MarkdownBody(data: e.note),
                  )
                else
                  SelectableText(
                    e.note,
                    style: const TextStyle(fontSize: 13),
                    onSelectionChanged: (selection, cause) {
                      setState(
                        () => _highlighted = selection.textInside(e.note),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // Action row: toggle raw/markdown and insert into the editor.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              TextButton.icon(
                icon: Icon(
                  _showMarkdown ? Icons.code : Icons.preview_outlined,
                  size: 18,
                ),
                label: Text(_showMarkdown ? 'Raw' : 'Formatted'),
                onPressed: () => setState(() {
                  _showMarkdown = !_showMarkdown;
                  // Selection doesn't carry across the view swap.
                  _highlighted = '';
                }),
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.input, size: 18),
                // Insert the highlighted portion if the user has selected
                // text; otherwise insert the whole note.
                label: Text(
                  _highlighted.trim().isEmpty
                      ? 'Insert all'
                      : 'Insert selection',
                ),
                onPressed: () {
                  final text = _highlighted.trim().isEmpty
                      ? e.note
                      : _highlighted;
                  widget.onInsert(text);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
