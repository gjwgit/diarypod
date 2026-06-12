/// EntryTitleDateFields — the Title and Date/Time inputs for the entry editor.
///
/// Extracted from entry_edit.dart to keep that file focused and under the
/// project line-count limit.
///
// Time-stamp: <2026-06-12>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import 'package:diarypod/constants/tooltips.dart';
import 'package:diarypod/widgets/tag_autocomplete.dart';

/// Title (autofocus, Tab → tags) and Date/Time (tap or Enter/Space to pick).
class EntryTitleDateFields extends StatelessWidget {
  const EntryTitleDateFields({
    super.key,
    required this.title,
    required this.titleFocus,
    required this.tagFocus,
    required this.dateFocus,
    required this.eventDate,
    required this.onChanged,
    required this.onPickDate,
  });

  final TextEditingController title;
  final FocusNode titleFocus;
  final FocusNode tagFocus;
  final FocusNode dateFocus;
  final DateTime eventDate;
  final VoidCallback onChanged;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE d MMM yyyy  HH:mm');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title — autofocus, Tab skips Date and moves to Tags.
          editSectionLabel(context, 'Title', tooltip: entryTitleTooltip),
          const Gap(8),
          Focus(
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.tab &&
                  !HardwareKeyboard.instance.isShiftPressed) {
                tagFocus.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: title,
              focusNode: titleFocus,
              autofocus: true,
              textInputAction: TextInputAction.next,
              onChanged: (_) => onChanged(),
              onSubmitted: (_) => tagFocus.requestFocus(),
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
          // (skipTraversal: true on dateFocus). Enter/Space opens picker.
          editSectionLabel(context, 'Date & Time', tooltip: entryDateTooltip),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: Focus(
                  focusNode: dateFocus,
                  onKeyEvent: (_, event) {
                    if (event is KeyDownEvent) {
                      if (event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.space) {
                        onPickDate();
                        return KeyEventResult.handled;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: InkWell(
                    onTap: onPickDate,
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
                                color: Theme.of(ctx).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            filled: hasFocus,
                            fillColor: Theme.of(ctx)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.15),
                          ),
                          child: Text(fmt.format(eventDate)),
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
    );
  }
}
