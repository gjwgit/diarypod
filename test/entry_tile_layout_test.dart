// Widget tests for EntryTile's wide vs narrow content layout.
//
// Runs without a live Pod: rendering and layout only.

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:diarypod/models/diary_entry.dart';
import 'package:diarypod/widgets/entry_note_preview.dart';
import 'package:diarypod/widgets/entry_tile.dart';

DiaryEntry entry({String note = '## Agenda\n\n- Test out the coding'}) {
  final when = DateTime(2026, 7, 31, 11);
  return DiaryEntry(
    id: 'e1',
    eventDate: when,
    title: 'Tony 1:1',
    note: note,
    tags: const ['anu'],
    createdAt: when,
    modifiedAt: when,
  );
}

Future<void> pumpTile(
  WidgetTester tester, {
  required double width,
  DiaryEntry? withEntry,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EntryTile(
          entry: withEntry ?? entry(),
          onTap: () {},
          onDelete: () {},
          onDuplicate: () {},
          onPdf: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('wide screen puts the note beside the title', (tester) async {
    await pumpTile(tester, width: 1000);
    final title = tester.getTopLeft(find.text('Tony 1:1'));
    final preview = tester.getTopLeft(find.byType(EntryNotePreview));
    // Beside, not below: further right and no lower than the title.
    expect(preview.dx, greaterThan(title.dx));
    expect(preview.dy, lessThanOrEqualTo(title.dy));
  });

  testWidgets('narrow screen keeps the note below the title', (tester) async {
    await pumpTile(tester, width: 500);
    final title = tester.getTopLeft(find.text('Tony 1:1'));
    final preview = tester.getTopLeft(find.byType(EntryNotePreview));
    expect(preview.dy, greaterThan(title.dy));
    expect(preview.dx, closeTo(title.dx, 1));
  });

  testWidgets('no preview is built for an entry without a note', (
    tester,
  ) async {
    await pumpTile(tester, width: 1000, withEntry: entry(note: ''));
    expect(find.byType(EntryNotePreview), findsNothing);
    expect(find.text('Tony 1:1'), findsOneWidget);
  });
}
