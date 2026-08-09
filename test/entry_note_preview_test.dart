// Widget test for EntryNotePreview's compact Markdown styling.
//
// Runs without a live Pod: rendering and layout only.

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:diarypod/widgets/entry_note_preview.dart';

void main() {
  testWidgets('bullets are tightly spaced in the preview', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: EntryNotePreview(
              note: '## Agenda\n\n- First bullet\n- Second bullet',
              height: 300,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = tester.getRect(find.text('First bullet'));
    final second = tester.getRect(find.text('Second bullet'));
    // The package default is 8px between blocks, which reads as a wide gap
    // at this text size; the preview tightens it.
    expect(second.top - first.bottom, lessThan(6));
  });
}
