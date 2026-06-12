/// EntryEdit — full-screen page for creating and editing diary entries.
///
// Time-stamp: <Friday 2026-05-15 16:10:34 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:emacs_text_field/emacs_text_field.dart'
    show attachPrimarySelection;
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:diarypod/constants/tooltips.dart';
import 'package:diarypod/models/diary_entry.dart';
import 'package:diarypod/pages/edit_fields/entry_notes_field.dart';
import 'package:diarypod/pages/edit_fields/entry_title_date_fields.dart';
import 'package:diarypod/services/app_provider.dart';
import 'package:diarypod/widgets/reference_panel.dart';
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
  final _bodyScrollCtrl = ScrollController();
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
    _bodyScrollCtrl.dispose();
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

  /// True when the user has modified any field from the original entry
  /// (or, for a new entry, entered anything at all).
  bool get _hasChanges {
    final e = widget.entry;
    if (e == null) {
      // New entry: dirty if any field has content.
      return _title.text.trim().isNotEmpty ||
          _note.text.trim().isNotEmpty ||
          _location.text.trim().isNotEmpty ||
          _tags.isNotEmpty;
    }
    // Existing entry: compare each editable field to the original.
    final tagsChanged =
        _tags.length != e.tags.length ||
        !List.generate(
          _tags.length,
          (i) => _tags[i] == e.tags[i],
        ).every((x) => x);
    return _title.text.trim() != e.title ||
        _note.text != e.note ||
        _location.text.trim() != (e.location ?? '') ||
        _eventDate != e.eventDate ||
        tagsChanged;
  }

  /// Pop the editor, but if there are unsaved changes first ask the user
  /// whether to save, discard, or keep editing. Returns nothing — it
  /// handles the navigation itself.
  Future<void> _confirmDiscard() async {
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text(
          'You have unsaved changes. Would you like to save them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('keep'),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'save':
        // Only save if the title is valid; otherwise stay in the editor.
        if (_title.text.trim().isNotEmpty) {
          _save();
        }
      case 'discard':
        Navigator.of(context).pop();
      default:
        // 'keep' or dismissed — stay in the editor.
        break;
    }
  }

  /// Insert [text] into the note field at the current cursor position,
  /// replacing any active selection, then place the cursor after the
  /// inserted text. Falls back to appending if there's no valid selection.
  void _insertAtCursor(String text) {
    // If currently in preview, switch to edit mode so the insertion is
    // visible and the cursor lands in the editable field.
    if (_showPreview) {
      setState(() => _showPreview = false);
    }
    final value = _note.value;
    final sel = value.selection;
    final base = value.text;
    if (sel.isValid) {
      final start = sel.start;
      final end = sel.end;
      final newText = base.replaceRange(start, end, text);
      _note.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + text.length),
      );
    } else {
      final newText = base.isEmpty ? text : '$base\n$text';
      _note.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
    _notesFocus.requestFocus();
    setState(() {});
  }

  /// Open the reference panel to browse/copy other entries while editing.
  void _openReference() {
    final provider = context.read<AppProvider>();
    // Offer all entries except the one currently being edited.
    final others = provider.entries
        .where((e) => e.id != widget.entry?.id)
        .toList();
    showReferencePanel(
      context: context,
      entries: others,
      onInsert: _insertAtCursor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
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
      child: PopScope(
        // Intercept the back button / X so we can warn about unsaved
        // changes. canPop is false when there are changes; the
        // onPopInvoked handler then runs our confirmation flow.
        canPop: !_hasChanges,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _confirmDiscard();
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(_isNew ? 'New Entry' : 'Edit Entry'),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu_book_outlined),
                tooltip: 'Reference another note',
                onPressed: _openReference,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton(
                  onPressed: _confirmDiscard,
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
          body: SingleChildScrollView(
            controller: _bodyScrollCtrl,
            child: Column(
              children: [
                // ── Title + Date ────────────────────────────────────────────
                EntryTitleDateFields(
                  title: _title,
                  titleFocus: _titleFocus,
                  tagFocus: _tagFocus,
                  dateFocus: _dateFocus,
                  eventDate: _eventDate,
                  onChanged: () => setState(() {}),
                  onPickDate: _pickDate,
                ),

                // ── Tags ─────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      editSectionLabel(
                        context,
                        'Tags',
                        tooltip: entryTagsTooltip,
                      ),
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

                // ── Notes ────────────────────────────────────────────────────
                EntryNotesField(
                  note: _note,
                  notesFocus: _notesFocus,
                  toggleFocus: _toggleFocus,
                  tagFocus: _tagFocus,
                  bodyScrollCtrl: _bodyScrollCtrl,
                  showPreview: _showPreview,
                  onToggle: () => setState(() => _showPreview = !_showPreview),
                  onShowEditor: () => setState(() => _showPreview = false),
                  onShowPreview: () => setState(() => _showPreview = true),
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
        ),
      ),
    );
  }
}
