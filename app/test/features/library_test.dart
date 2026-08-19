import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('library lists seed recipes, search filters, B&W chip filters', (t) async {
    await pumpKata(t);
    expect(find.text('KODACHROME 64'), findsOneWidget);
    expect(find.text('MONO PUSH'), findsOneWidget);
    expect(find.text('SLIDE FILM'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'koda');
    await t.pumpAndSettle();
    expect(find.text('KODACHROME 64'), findsOneWidget);
    expect(find.text('MONO PUSH'), findsNothing);

    await t.enterText(find.byType(TextField), '');
    await t.tap(find.text('B&W'));
    await t.pumpAndSettle();
    expect(find.text('MONO PUSH'), findsOneWidget);
    expect(find.text('KODACHROME 64'), findsNothing);
  });

  testWidgets('tapping a card opens detail with spec grid and write button', (t) async {
    await pumpKata(t);
    await t.tap(find.text('KODACHROME 64'));
    await t.pumpAndSettle();
    expect(find.text('CLASSIC CHROME'), findsWidgets);
    expect(find.text('Q-MENU ORDER'), findsOneWidget);
    expect(find.text('WRITE TO CAMERA'), findsOneWidget);
    expect(find.text('NO CAMERA'), findsOneWidget);
    expect(find.text('HIGH ISO NR'), findsOneWidget);
  });
}
