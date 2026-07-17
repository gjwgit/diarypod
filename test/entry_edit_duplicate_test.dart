// Widget tests for the Duplicate action on the EntryEdit page.
//
// Runs without a live Pod: only rendering / enabled-state behaviour.

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:diarypod/models/diary_entry.dart';
import 'package:diarypod/pages/entry_edit.dart';
import 'package:diarypod/services/app_provider.dart';

Widget wrap(Widget child) => ChangeNotifierProvider(
  create: (_) => AppProvider(),
  child: MaterialApp(home: child),
);

DiaryEntry entry() {
  final now = DateTime(2026, 7, 17, 9);
  return DiaryEntry(
    id: 'e1',
    eventDate: now,
    title: 'Coffee with Alex',
    createdAt: now,
    modifiedAt: now,
  );
}

void main() {
  testWidgets('duplicate icon shown for an existing entry', (tester) async {
    await tester.pumpWidget(wrap(EntryEdit(entry: entry())));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
  });

  testWidgets('duplicate icon hidden for a new entry', (tester) async {
    await tester.pumpWidget(wrap(const EntryEdit()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.copy_outlined), findsNothing);
  });

  testWidgets('tapping duplicate opens a pre-filled editor', (tester) async {
    await tester.pumpWidget(wrap(EntryEdit(entry: entry())));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pumpAndSettle();
    // A second EntryEdit is pushed with the copied title.
    expect(find.byType(EntryEdit), findsOneWidget);
    expect(find.text('Coffee with Alex'), findsWidgets);
  });
}
