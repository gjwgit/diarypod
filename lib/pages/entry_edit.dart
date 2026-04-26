/// EntryEdit — dialog for creating and editing diary entries.
///
// Time-stamp: <2026-04-26>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:markdown_tooltip/markdown_tooltip.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:diarypod/models/diary_entry.dart';
import 'package:diarypod/services/app_provider.dart';
import 'package:diarypod/widgets/tag_autocomplete.dart';

class EntryEdit extends StatefulWidget {
  final DiaryEntry? entry;

  const EntryEdit({super.key, this.entry});

  @override
  State<EntryEdit> createState() => _EntryEditState();
}

class _EntryEditState extends State<EntryEdit> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _location;
  late DateTime _eventDate;
  late List<String> _tags;
  bool get _isNew => widget.entry == null;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _eventDate = e?.eventDate ?? DateTime.now();
    _tags = List<String>.from(e?.tags ?? []);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _location.dispose();
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
    if (picked == null) return;
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

    return AlertDialog(
      title: Text(_isNew ? 'New Entry' : 'Edit Entry'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Event date/time ──────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: MarkdownTooltip(
                      message:
                          '**Event Date**\n\nThe date and time of this event. '
                          'Future dates mark the entry as scheduled.',
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Event date & time',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          child: Text(fmt.format(_eventDate)),
                        ),
                      ),
                    ),
                  ),
                  const Gap(8),
                  MarkdownTooltip(
                    message: '**Pick Date**\n\nChoose the event date and time.',
                    child: IconButton(
                      icon: const Icon(Icons.calendar_today_outlined),
                      onPressed: _pickDate,
                    ),
                  ),
                ],
              ),
              const Gap(12),

              // ── Title ────────────────────────────────────────────────
              MarkdownTooltip(
                message: '**Title**\n\nA short headline for this diary entry.',
                child: TextField(
                  controller: _title,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const Gap(12),

              // ── Notes ─────────────────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Notes',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const Spacer(),
                  TextButton.icon(
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
                ],
              ),
              const Gap(4),
              if (_showPreview) ...[
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 120),
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
                      : MarkdownBody(
                          data: _note.text,
                          shrinkWrap: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ),
                        ),
                ),
              ] else ...[
                MarkdownTooltip(
                  message:
                      '**Notes**\n\nMarkdown is supported. Use **bold**, '
                      '*italic*, `code`, lists, and headings.',
                  child: TextField(
                    controller: _note,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Markdown)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    minLines: 5,
                    maxLines: 12,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ],
              const Gap(12),

              // ── Tags ─────────────────────────────────────────────────
              Text(
                'Tags',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const Gap(4),
              TagField(
                tags: _tags,
                suggestions: provider.allTags,
                onChanged: (updated) => setState(() => _tags = updated),
              ),
              const Gap(12),

              // ── Location ─────────────────────────────────────────────
              MarkdownTooltip(
                message:
                    '**Location**\n\nOptional venue or place for this event.',
                child: TextField(
                  controller: _location,
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.place_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _title.text.trim().isEmpty ? null : _save,
          child: Text(_isNew ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
