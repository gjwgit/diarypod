/// EntryEdit — full-screen page for creating and editing diary entries.
///
// Time-stamp: <Wednesday 2026-05-06 15:13:05 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:emacs_text_field/emacs_text_field.dart'
    show EmacsTextField, attachPrimarySelection, writePrimarySelection;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:diarypod/constants/tooltips.dart';
import 'package:diarypod/models/diary_entry.dart';
import 'package:diarypod/services/app_provider.dart';
import 'package:diarypod/widgets/tag_autocomplete.dart';

class EntryEdit extends StatefulWidget {
  const EntryEdit({super.key, this.entry, this.initialPreview});

  final DiaryEntry? entry;

  /// When null (default) the mode is inferred: existing entries open in
  /// preview, new entries open in edit.  Pass [false] to force edit mode
  /// even for a pre-populated entry (e.g. created from the search bar).
  final bool? initialPreview;

  @override
  State<EntryEdit> createState() => _EntryEditState();
}

class _EntryEditState extends State<EntryEdit> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _location;
  late final VoidCallback _removePrimaryTitle;
  late final VoidCallback _removePrimaryLocation;
  late DateTime _eventDate;
  late List<String> _tags;
  bool get _isNew => widget.entry == null;
  late bool _showPreview;
  String? _chordPrefix;

  // Focus nodes for keyboard tab traversal.
  // _dateFocus is excluded from the Tab order (skipTraversal); it can still
  // receive focus programmatically (e.g. mouse click / tap).
  final _titleFocus = FocusNode();
  final _dateFocus = FocusNode(skipTraversal: true);
  final _toggleFocus = FocusNode();
  final _notesFocus = FocusNode();
  final _tagFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Existing entries open in preview; new entries open in edit mode.
    _showPreview = widget.initialPreview ?? !_isNew;
    final e = widget.entry;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    // _note is handled by EmacsTextField's own primary selection support.
    _removePrimaryTitle = attachPrimarySelection(_title);
    _removePrimaryLocation = attachPrimarySelection(_location);
    _eventDate = e?.eventDate ?? DateTime.now();
    _tags = List<String>.from(e?.tags ?? []);
  }

  @override
  void dispose() {
    _removePrimaryTitle();
    _removePrimaryLocation();
    _title.dispose();
    _note.dispose();
    _location.dispose();
    _titleFocus.dispose();
    _dateFocus.dispose();
    _toggleFocus.dispose();
    _notesFocus.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eventDate),
    );
    if (!mounted) return;
    setState(() {
      _eventDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        time?.hour ?? _eventDate.hour,
        time?.minute ?? _eventDate.minute,
      );
    });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final now = DateTime.now();
    final entry = DiaryEntry(
      id: widget.entry?.id ?? const Uuid().v4(),
      eventDate: _eventDate,
      title: title,
      note: _note.text,
      tags: _tags,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      createdAt: widget.entry?.createdAt ?? now,
      modifiedAt: now,
    );
    Navigator.of(context).pop(entry);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final provider = context.read<AppProvider>();
    final fmt = DateFormat('EEE d MMM yyyy  HH:mm');
    final canSave = _title.text.trim().isNotEmpty;

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        final key = event.logicalKey;
        if (_chordPrefix != null) {
          final prefix = _chordPrefix!;
          _chordPrefix = null;
          if (prefix == 'C-x' && isCtrl && key == LogicalKeyboardKey.keyS) {
            if (_title.text.trim().isNotEmpty) _save();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }
        if (isCtrl && key == LogicalKeyboardKey.keyX) {
          setState(() => _chordPrefix = 'C-x');
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'New Entry' : 'Edit Entry'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: canSave ? _save : null,
                child: Text(_isNew ? 'Add' : 'Save'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // ── Title + Date ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title — autofocus, Tab skips Date and moves to Tags.
                  editSectionLabel(
                    context,
                    'Title',
                    tooltip: entryTitleTooltip,
                  ),
                  const Gap(8),
                  Focus(
                    onKeyEvent: (_, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      if (event.logicalKey == LogicalKeyboardKey.tab &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        _tagFocus.requestFocus();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _title,
                      focusNode: _titleFocus,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _tagFocus.requestFocus(),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: 'What happened?',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const Gap(16),
                  // Date — focusable via mouse/tap; excluded from Tab order
                  // (skipTraversal: true on _dateFocus). Enter/Space opens picker.
                  editSectionLabel(
                    context,
                    'Date & Time',
                    tooltip: entryDateTooltip,
                  ),
                  const Gap(8),
                  Row(
                    children: [
                      Expanded(
                        child: Focus(
                          focusNode: _dateFocus,
                          onKeyEvent: (_, event) {
                            if (event is KeyDownEvent) {
                              if (event.logicalKey ==
                                      LogicalKeyboardKey.enter ||
                                  event.logicalKey ==
                                      LogicalKeyboardKey.space) {
                                _pickDate();
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(4),
                            child: Builder(
                              builder: (ctx) {
                                final hasFocus = Focus.of(ctx).hasFocus;
                                return InputDecorator(
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          ctx,
                                        ).colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                    filled: hasFocus,
                                    fillColor: Theme.of(ctx)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: 0.15),
                                  ),
                                  child: Text(fmt.format(_eventDate)),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Tags ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  editSectionLabel(context, 'Tags', tooltip: entryTagsTooltip),
                  const Gap(8),
                  TagField(
                    tags: _tags,
                    focusNode: _tagFocus,
                    suggestions: provider.allTags,
                    onChanged: (updated) => setState(() => _tags = updated),
                  ),
                ],
              ),
            ),

            // ── Notes (expanded) ────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        editSectionLabel(
                          context,
                          'Notes',
                          tooltip: entryNotesTooltip,
                        ),
                        const Spacer(),
                        Focus(
                          onKeyEvent: (_, event) {
                            if (event is! KeyDownEvent) {
                              return KeyEventResult.ignored;
                            }
                            if (event.logicalKey == LogicalKeyboardKey.enter ||
                                event.logicalKey == LogicalKeyboardKey.space) {
                              // "Edit" shown (preview mode) → switch to edit
                              // and move focus to Notes.
                              // "Preview" shown (edit mode) → toggle to preview
                              // and stay on the button.
                              if (_showPreview) {
                                setState(() => _showPreview = false);
                                _notesFocus.requestFocus();
                              } else {
                                setState(() => _showPreview = true);
                                _toggleFocus.requestFocus();
                              }
                              return KeyEventResult.handled;
                            }
                            if (event.logicalKey == LogicalKeyboardKey.tab &&
                                !HardwareKeyboard.instance.isShiftPressed) {
                              if (!_showPreview) {
                                _notesFocus.requestFocus();
                              } else {
                                _tagFocus.requestFocus();
                              }
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextButton.icon(
                            focusNode: _toggleFocus,
                            onPressed: () =>
                                setState(() => _showPreview = !_showPreview),
                            icon: Icon(
                              _showPreview
                                  ? Icons.edit_outlined
                                  : Icons.preview_outlined,
                              size: 16,
                            ),
                            label: Text(_showPreview ? 'Edit' : 'Preview'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(8),
                    Expanded(
                      child: _showPreview
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: cs.outline),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: _note.text.trim().isEmpty
                                  ? Text(
                                      'Nothing to preview.',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  : SelectionArea(
                                      onSelectionChanged: (value) {
                                        final text = value?.plainText ?? '';
                                        if (text.isNotEmpty) {
                                          writePrimarySelection(text);
                                        }
                                      },
                                      child: SingleChildScrollView(
                                        child: MarkdownBody(
                                          data: _note.text,
                                          shrinkWrap: true,
                                          styleSheet:
                                              MarkdownStyleSheet.fromTheme(
                                                Theme.of(context),
                                              ),
                                        ),
                                      ),
                                    ),
                            )
                          : EmacsTextField(
                              controller: _note,
                              focusNode: _notesFocus,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Details, thoughts, markdown…',
                                alignLabelWithHint: true,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Location ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  editSectionLabel(
                    context,
                    'Location',
                    tooltip: entryLocationTooltip,
                  ),
                  const Gap(8),
                  TextField(
                    controller: _location,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      hintText: 'Where did this happen?',
                      prefixIcon: Icon(Icons.place_outlined, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
