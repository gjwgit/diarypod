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
  const EntryEdit({super.key, this.entry, this.initialPreview, this.onSave});

  final DiaryEntry? entry;

  /// When null (default) the mode is inferred: existing entries open in
  /// preview, new entries open in edit.  Pass [false] to force edit mode
  /// even for a pre-populated entry (e.g. created from the search bar).
  final bool? initialPreview;

  /// Called with the saved entry after the user taps Save.  The editor stays
  /// open; the caller is responsible for updating the provider and Pod.
  final void Function(DiaryEntry)? onSave;

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

  // Snapshot of the last-saved state — used to compute _hasChanges.
  late String _savedTitle;
  late String _savedNote;
  late String _savedLocation;
  late DateTime _savedEventDate;
  late List<String> _savedTags;

  // Focus nodes for keyboard tab traversal.
  // _dateFocus is excluded from the Tab order (skipTraversal); it can still
  // receive focus programmatically (e.g. mouse click / tap).
  final _titleFocus = FocusNode();
  final _dateFocus = FocusNode(skipTraversal: true);
  final _toggleFocus = FocusNode();
  final _notesFocus = FocusNode();
  final _bodyScrollCtrl = ScrollController();
  final _tagFocus = FocusNode();

  late final String _entryId;

  @override
  void initState() {
    super.initState();
    _entryId = widget.entry?.id ?? const Uuid().v4();
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
    _snapshotSavedState();

    // Rebuild on any text edit so the Save button's enabled state tracks
    // _hasChanges live. Date and tag changes call setState in their own
    // handlers, so they re-evaluate _hasChanges too.
    for (final c in [_title, _note, _location]) {
      c.addListener(_onChanged);
    }
  }

  /// Snapshot the current field values as the last-saved baseline.
  void _snapshotSavedState() {
    _savedTitle = _title.text.trim();
    _savedNote = _note.text;
    _savedLocation = _location.text.trim();
    _savedEventDate = _eventDate;
    _savedTags = List<String>.from(_tags);
  }

  /// Rebuild when a tracked text field changes so the Save button's enabled
  /// state reflects [_hasChanges].
  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _removePrimaryTitle();
    _removePrimaryLocation();
    for (final c in [_title, _note, _location]) {
      c.removeListener(_onChanged);
    }
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
      id: _entryId,
      eventDate: _eventDate,
      title: title,
      note: _note.text,
      tags: _tags,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      createdAt: widget.entry?.createdAt ?? now,
      modifiedAt: now,
    );
    widget.onSave?.call(entry);
    // Snapshot saved state so _hasChanges becomes false and Save deactivates.
    setState(_snapshotSavedState);
  }

  /// True when the user has modified any field since the last save.
  bool get _hasChanges {
    final tagsChanged =
        _tags.length != _savedTags.length ||
        !List.generate(
          _tags.length,
          (i) => _tags[i] == _savedTags[i],
        ).every((x) => x);
    return _title.text.trim() != _savedTitle ||
        _note.text != _savedNote ||
        _location.text.trim() != _savedLocation ||
        _eventDate != _savedEventDate ||
        tagsChanged;
  }

  /// Pop the editor, but if there are unsaved changes first ask the user
  /// whether to save, discard, or keep editing.
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
        if (_title.text.trim().isNotEmpty) _save();
      case 'discard':
        Navigator.of(context).pop();
      default:
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
    final canSave = _title.text.trim().isNotEmpty && _hasChanges;

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
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: _confirmDiscard,
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
