/// EntryNotesField — the Notes input (with edit/preview toggle) for the
/// entry editor.
///
/// Extracted from entry_edit.dart to keep that file under the project
/// line-count limit. Preview state is owned by the parent and passed in.
///
// Time-stamp: <2026-06-12>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:emacs_text_field/emacs_text_field.dart'
    show EmacsTextField, writePrimarySelection;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:gap/gap.dart';

import 'package:diarypod/constants/tooltips.dart';
import 'package:diarypod/widgets/tag_autocomplete.dart';

/// The Notes editor with an Edit/Preview toggle. [showPreview] and
/// [onToggle] let the parent own the toggle state; the keyboard handlers
/// move focus between the toggle button, the notes field and the tags.
class EntryNotesField extends StatelessWidget {
  const EntryNotesField({
    super.key,
    required this.note,
    required this.notesFocus,
    required this.toggleFocus,
    required this.tagFocus,
    required this.bodyScrollCtrl,
    required this.showPreview,
    required this.onToggle,
    required this.onShowEditor,
    required this.onShowPreview,
  });

  final TextEditingController note;
  final FocusNode notesFocus;
  final FocusNode toggleFocus;
  final FocusNode tagFocus;
  final ScrollController bodyScrollCtrl;
  final bool showPreview;
  final VoidCallback onToggle;
  final VoidCallback onShowEditor;
  final VoidCallback onShowPreview;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              editSectionLabel(context, 'Notes', tooltip: entryNotesTooltip),
              const Spacer(),
              Focus(
                onKeyEvent: (_, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  if (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.space) {
                    // "Edit" shown (preview mode) → switch to edit and move
                    // focus to Notes. "Preview" shown (edit mode) → toggle to
                    // preview and stay on the button.
                    if (showPreview) {
                      onShowEditor();
                      notesFocus.requestFocus();
                    } else {
                      onShowPreview();
                      toggleFocus.requestFocus();
                    }
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.tab &&
                      !HardwareKeyboard.instance.isShiftPressed) {
                    if (!showPreview) {
                      notesFocus.requestFocus();
                    } else {
                      tagFocus.requestFocus();
                    }
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextButton.icon(
                  focusNode: toggleFocus,
                  onPressed: onToggle,
                  icon: Icon(
                    showPreview ? Icons.edit_outlined : Icons.preview_outlined,
                    size: 16,
                  ),
                  label: Text(showPreview ? 'Edit' : 'Preview'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          showPreview
              ? Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outline),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: note.text.trim().isEmpty
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
                            if (text.isNotEmpty) writePrimarySelection(text);
                          },
                          child: MarkdownBody(
                            data: note.text,
                            shrinkWrap: true,
                            styleSheet: MarkdownStyleSheet.fromTheme(
                              Theme.of(context),
                            ),
                          ),
                        ),
                )
              : EmacsTextField(
                  controller: note,
                  focusNode: notesFocus,
                  outerScrollController: bodyScrollCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Details, thoughts, markdown…',
                    alignLabelWithHint: true,
                  ),
                ),
        ],
      ),
    );
  }
}
