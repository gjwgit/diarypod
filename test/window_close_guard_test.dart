// Widget tests for UnsavedChangesGuard as wired up by EntryEdit — the
// window-close confirmation path (save / discard / keep editing).
//
// Runs without a live Pod: only rendering / state behaviour.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:solidui/solidui.dart';

import 'package:diarypod/pages/entry_edit.dart';
import 'package:diarypod/services/app_provider.dart';

Widget wrap(Widget child) => ChangeNotifierProvider(
  create: (_) => AppProvider(),
  child: MaterialApp(home: child),
);

void main() {
  testWidgets('resolveAll succeeds with no prompt when nothing changed', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const EntryEdit()));
    await tester.pumpAndSettle();
    expect(await SolidWindowCloseGuard.resolveAll(), isTrue);
    expect(find.text('Unsaved changes'), findsNothing);
  });

  testWidgets('resolveAll prompts and resolves true on Discard', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const EntryEdit()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'New title');
    await tester.pump();

    final future = SolidWindowCloseGuard.resolveAll();
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(await future, isTrue);
  });

  testWidgets('resolveAll prompts and resolves false on Keep editing', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const EntryEdit()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'New title');
    await tester.pump();

    final future = SolidWindowCloseGuard.resolveAll();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(await future, isFalse);
    // The editor is still open with the unsaved title intact.
    expect(find.text('New title'), findsOneWidget);
  });

  // Regression: onSave used to be a void callback, so the Pod write was
  // fire-and-forget. resolveAll() returned immediately, the window was
  // destroyed mid-write, and the new entry was lost despite tapping Save.
  testWidgets('window-close Save waits for the Pod write to finish', (
    tester,
  ) async {
    final podWrite = Completer<void>();
    var written = false;

    await tester.pumpWidget(
      wrap(
        EntryEdit(
          onSave: (entry) async {
            await podWrite.future;
            written = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'New title');
    await tester.pump();

    var resolved = false;
    final future = SolidWindowCloseGuard.resolveAll()
      ..then((_) => resolved = true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The Pod write is still in flight, so the guard must NOT have resolved
    // — otherwise the caller would destroy the window and lose the entry.
    expect(resolved, isFalse);
    expect(written, isFalse);

    podWrite.complete();
    await tester.pumpAndSettle();

    expect(await future, isTrue);
    expect(written, isTrue);
  });

  testWidgets('editor unregisters its resolver on dispose', (tester) async {
    await tester.pumpWidget(wrap(const EntryEdit()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pumpAndSettle();
    // No editor left registered, so nothing to resolve.
    expect(await SolidWindowCloseGuard.resolveAll(), isTrue);
  });
}
