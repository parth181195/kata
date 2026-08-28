import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/features/share/photo_meta.dart';
import 'package:kata/features/share/share_screen.dart';

import '../helpers.dart';

void main() {
  test('matchKata: the photo\'s film simulation picks the kata; nothing when it has none or no kata uses it', () {
    final all = FakeRecipeApi.fromSeed(seedJson).recipes;
    expect(matchKata(all, const PhotoMeta(filmMode: 'Velvia'))?.name, 'Slide Film');
    expect(matchKata(all, const PhotoMeta(filmMode: 'velvia'))?.name, 'Slide Film');
    expect(matchKata(all, const PhotoMeta(filmMode: 'Classic Chrome'))?.name, 'Kodachrome 64');
    expect(matchKata(all, const PhotoMeta()), isNull);
    expect(matchKata(all, const PhotoMeta(filmMode: 'Nostalgic Neg. Plus Ultra')), isNull);
    expect(matchKata(<Recipe>[], const PhotoMeta(filmMode: 'Velvia')), isNull);
  });

  testWidgets('the picker pins the guess, searches, and pops the tap', (t) async {
    final all = FakeRecipeApi.fromSeed(seedJson).recipes;
    final guess = all.firstWhere((r) => r.name == 'Slide Film');
    Recipe? picked;
    await t.pumpWidget(MaterialApp(
      theme: KataTheme.light(),
      home: Builder(builder: (c) => TextButton(onPressed: () async => picked = await pickKata(c, all: all, mine: const [], guess: guess, filmMode: 'Velvia'), child: const Text('go'))),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.text('SHOT ON SLIDE FILM?'), findsOneWidget);
    expect(find.text('USE SLIDE FILM'), findsOneWidget);
    // no sheet handle on a page of its own; search narrows the rest
    expect(find.byType(KataSheet), findsNothing);
    await t.enterText(find.byType(TextField), 'mono');
    await t.pumpAndSettle();
    expect(find.text('Mono Push'), findsOneWidget);
    expect(find.text('Kodachrome 64'), findsNothing);
    await t.tap(find.text('Mono Push'));
    await t.pumpAndSettle();
    expect(picked?.name, 'Mono Push');
  });
}
