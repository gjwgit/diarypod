/// duplicateEntry — shared duplicate action for diary entries.
///
// Time-stamp: <Friday 2026-07-17 12:00:00 +1000 Graham Williams>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:uuid/uuid.dart';

import 'package:diarypod/models/diary_entry.dart';
import 'package:diarypod/pages/entry_edit.dart';
import 'package:diarypod/services/app_provider.dart';

/// Duplicate [entry]: copy it with a fresh id and the date/time set to now,
/// then open the copy for editing on top of the current page.
///
/// Shared by the list view, the calendar view, and the EntryEdit page so the
/// behaviour stays identical everywhere. Saving routes through [EntryEdit]'s
/// onSave callback: the first Save adds the copy, later Saves in the same
/// editor session update it, and each Save is pushed to the Pod.

Future<void> duplicateEntry(
  BuildContext context,
  AppProvider provider,
  DiaryEntry entry,
) async {
  final now = DateTime.now();
  final duplicate = entry.copyWith(
    id: const Uuid().v4(),
    eventDate: now,
    createdAt: now,
    modifiedAt: now,
  );
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => EntryEdit(
        entry: duplicate,
        onSave: (updated) async {
          if (provider.entries.any((e) => e.id == updated.id)) {
            provider.updateEntry(updated);
          } else {
            provider.addEntry(updated);
          }
          // Left to propagate: EntryEdit must see a failure so it does not
          // mark itself saved.
          await provider.saveToPod();
        },
      ),
    ),
  );
}
