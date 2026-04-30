/// Tag input widget with autocomplete for DiaryPod.
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

/// A labelled section header with an optional [MarkdownTooltip] info icon.
/// Matches the todopod editSectionLabel style.
Widget editSectionLabel(BuildContext context, String text, {String? tooltip}) {
  final label = Text(
    text,
    style: TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
      fontSize: 13,
      letterSpacing: 0.5,
    ),
  );
  if (tooltip == null) return label;

  return Row(
    children: [
      label,
      const Gap(4),
      MarkdownTooltip(
        message: tooltip,
        child: Icon(
          Icons.info_outline,
          size: 13,
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    ],
  );
}

/// Displays the current [tags] as chips and an autocomplete text field
/// for adding new ones.
class TagField extends StatefulWidget {
  final List<String> tags;
  final List<String> suggestions;
  final ValueChanged<List<String>> onChanged;

  const TagField({
    super.key,
    required this.tags,
    required this.suggestions,
    required this.onChanged,
  });

  @override
  State<TagField> createState() => _TagFieldState();
}

class _TagFieldState extends State<TagField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  void _addTag(String tag) {
    final t = tag.trim().toLowerCase();
    if (t.isEmpty) return;
    if (widget.tags.contains(t)) {
      _ctrl.clear();
      return;
    }
    widget.onChanged(List<String>.from(widget.tags)..add(t));
    _ctrl.clear();
  }

  void _removeTag(String tag) {
    widget.onChanged(widget.tags.where((t) => t != tag).toList());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing tags as chips.
        if (widget.tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: widget.tags.map((t) {
              return InputChip(
                label: Text(t),
                onDeleted: () => _removeTag(t),
                deleteIconColor: cs.onSurfaceVariant,
              );
            }).toList(),
          ),
        if (widget.tags.isNotEmpty) const Gap(6),
        // Autocomplete input.
        RawAutocomplete<String>(
          textEditingController: _ctrl,
          focusNode: _focus,
          optionsBuilder: (value) {
            final q = value.text.toLowerCase();
            return widget.suggestions.where(
              (s) =>
                  (q.isEmpty || s.toLowerCase().contains(q)) &&
                  !widget.tags.contains(s),
            );
          },
          onSelected: _addTag,
          fieldViewBuilder: (ctx, ctrl, focusNode, onSubmitted) {
            return MarkdownTooltip(
              message:
                  '**Tags**\n\nType a tag and press Enter or tap + to add. '
                  'Tap × on a chip to remove it.',
              child: TextField(
                controller: ctrl,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Add tag…',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  suffixIcon: MarkdownTooltip(
                    message: '**Add tag**\n\nAdd the typed text as a tag.',
                    child: IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () => _addTag(_ctrl.text),
                    ),
                  ),
                ),
                onSubmitted: _addTag,
              ),
            );
          },
          optionsViewBuilder: (ctx, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: options.map((opt) {
                      return ListTile(
                        dense: true,
                        title: Text(opt),
                        onTap: () => onSelected(opt),
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
