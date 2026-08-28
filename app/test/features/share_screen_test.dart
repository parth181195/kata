import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/features/share/share_composer_sheet.dart';

import '../helpers.dart';

void main() {
  testWidgets('share tab: pick a kata, get its code card; the card\'s photo is swappable', (t) async {
    await pumpKata(t, initialLocation: '/share');
    expect(find.text('SHARE'), findsWidgets);
    // the seeded library lists, and a kata opens the composer
    await t.tap(find.text('Kodachrome 64').first);
    await t.pumpAndSettle();
    expect(find.byType(ShareComposerSheet), findsOneWidget);
    // the photo row: sample frame by default, with the two ways to swap it
    await t.ensureVisible(find.text('SAMPLE FRAME').last);
    await t.pumpAndSettle();
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
  });

  testWidgets('share tab: search narrows by name and film simulation', (t) async {
    await pumpKata(t, initialLocation: '/share');
    await t.enterText(find.byType(TextField).first, 'mono');
    await t.pumpAndSettle();
    expect(find.text('Mono Push'), findsOneWidget);
    expect(find.text('Kodachrome 64'), findsNothing);
  });
}
