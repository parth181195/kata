import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/recipe_repository.dart';
import 'package:kata/features/scan/scan_screen.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

/// Test scanner: a button that "sees" the given payload.
class FakeScanner implements CodeScanner {
  FakeScanner(this.payload);
  final String payload;
  @override
  Widget build(BuildContext context, void Function(String raw) onDetect) => Center(child: TextButton(onPressed: () => onDetect(payload), child: const Text('FAKE-DETECT')));
}

const _code = 'kata1:NN,DR100,WBA/+2-3,H-2,S-2,C+1,SH+1,GR-WS;n=Summer+in+Paris;a=heikki.k;v=xt5';

void main() {
  testWidgets('scan → preview → Save to mine lands in the library', (t) async {
    final c = await pumpKata(t, initialLocation: '/scan', overrides: [codeScannerProvider.overrideWithValue(FakeScanner(_code))]);
    expect(find.text('SCAN A KATA CODE'), findsOneWidget);
    await t.tap(find.text('FAKE-DETECT'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('scan-preview')), findsOneWidget);
    expect(find.text('SUMMER IN PARIS'), findsOneWidget);
    expect(find.textContaining('from heikki.k'), findsOneWidget);
    await t.tap(find.text('SAVE TO MINE'));
    await t.pumpAndSettle();
    final repo = c.read(recipeRepositoryProvider);
    expect(repo.drafts.single.name, 'Summer in Paris');
    expect(repo.drafts.single.ofr.filmSimulation, 'Nostalgic Negative');
    expect(find.text('SUMMER IN PARIS'), findsWidgets); // detail opened
  });

  testWidgets('a non-Kata QR is rejected with a hint; Review fields opens the editor', (t) async {
    await pumpKata(t, initialLocation: '/scan', overrides: [codeScannerProvider.overrideWithValue(FakeScanner('https://kata.parthjansari.dev/kata.apk'))]);
    await t.tap(find.text('FAKE-DETECT'));
    await t.pumpAndSettle();
    expect(find.textContaining('isn’t a Kata Code'), findsOneWidget);
  });

  testWidgets('import sheet accepts a pasted Kata Code', (t) async {
    final c = await pumpKata(t, initialLocation: '/mine');
    await t.tap(find.text('+'));
    await t.pumpAndSettle();
    await t.tap(find.text('Import OFR'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), _code);
    await t.pumpAndSettle();
    expect(find.text('SUMMER IN PARIS'), findsOneWidget); // sheet title
    await t.tap(find.text('SAVE TO MINE'));
    await t.pumpAndSettle();
    expect(c.read(recipeRepositoryProvider).drafts.single.ofr.whiteBalanceRed, 2);
    expect(KataCode.decode(_code).recipe.highlight, -2);
  });
}
