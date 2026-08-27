import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/data/recipe_specs.dart';
import 'package:kata/features/share/card_templates.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

const _colour = OfrRecipe(
    name: 'Beach Chrome', sensors: ['X-Trans V'], filmSimulation: 'Classic Chrome', dynamicRange: 'DR200',
    dRangePriority: 'Off', grainRoughness: 'Weak', grainSize: 'Small', whiteBalance: 'Daylight',
    whiteBalanceRed: 1, whiteBalanceBlue: -2, highlight: 0, shadow: -1, color: 2, sharpness: 0,
    highIsoNr: -2, clarity: 3);

void main() {
  testWidgets('the recipe card shows every setting it has, not the first twelve', (t) async {
    // A colour recipe has 13 spec rows; the grid used to take(12), which dropped
    // Clarity off the bottom of every card silently.
    final items = RecipeSpecs.items(_colour.copyWith(), rulers: false);
    expect(items.length, greaterThan(12), reason: 'the fixture must exercise the overflow');

    t.view.physicalSize = const Size(kCardWidth, kCardWidth / (4 / 5));
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(MaterialApp(
      theme: KataTheme.light(),
      home: Material(
        child: ShareCard(ShareSpec(
          recipe: Recipe(id: 'r1', ofr: _colour),
          template: ShareTemplate.card,
          ratio: ShareRatio.r4x5,
          credit: 'Kata',
        )),
      ),
    ));
    await t.pumpAndSettle();

    for (final it in items) {
      expect(find.text(it.label.toUpperCase()), findsOneWidget, reason: '${it.label} is missing from the card');
    }
  });

  test('a name that survives no ASCII still names a file, and two of them differ', () {
    final a = Recipe(id: 'aaaaaa11', ofr: _colour.copyWith(name: '夏の海辺 — 富士フイルム'));
    final b = Recipe(id: 'bbbbbb22', ofr: _colour.copyWith(name: '...'));
    final an = shareFileName(a, ShareTemplate.card);
    final bn = shareFileName(b, ShareTemplate.card);

    expect(an, isNot(startsWith('-')), reason: 'a filename should not start with a separator');
    expect(an, isNot(contains('--')));
    expect(an, endsWith('-s1.png'));
    expect(an, isNot(bn), reason: 'two unnameable recipes would overwrite each other in Downloads');
  });

  test('an ordinary name is still the obvious filename', () {
    expect(shareFileName(Recipe(id: 'x', ofr: _colour), ShareTemplate.card), 'beach-chrome-s1.png');
  });
}
