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

/// The worst content a real user plausibly produces — see share_qr_test.dart.
const _worst = OfrRecipe(
    name: '夏の海辺の富士フイルムレシピ', sensors: ['X-Trans V', 'X-Trans IV'],
    sourceAttribution: '富士フイルム写真家協会', sourceUrl: 'https://example.jp/recipes/natsu-no-umibe',
    filmSimulation: 'Classic Negative', dynamicRange: 'DR400', dRangePriority: 'Strong',
    grainRoughness: 'Strong', grainSize: 'Large', colorChromeEffect: 'Strong', colorChromeFxBlue: 'Strong',
    whiteBalance: 'Kelvin', wbKelvin: 7500, whiteBalanceRed: 9, whiteBalanceBlue: -9,
    highlight: 4, shadow: 4, color: 4, sharpness: 4, highIsoNr: 4, clarity: 5,
    monochromaticColorWarmCool: 9, monochromaticColorMagentaGreen: -9);

void main() {
  // A card is a fixed box; a Column that outgrows it overflows, which in a
  // release build is a silent clip — the code or the credit simply isn't there.
  // The story template did this on every square card for a plain recipe.
  testWidgets('no template overflows its card, at any ratio, with the worst content', (t) async {
    for (final (label, ofr) in [('worst', _worst), ('plain', _colour)]) {
      for (final template in ShareTemplate.values) {
        for (final ratio in ShareRatio.values) {
          final overflow = <String>[];
          final prev = FlutterError.onError;
          FlutterError.onError = (d) => overflow.add(d.exceptionAsString().split('\n').first);
          final h = kCardWidth / ratio.aspect;
          t.view.physicalSize = Size(kCardWidth, h);
          t.view.devicePixelRatio = 1;
          await t.pumpWidget(MaterialApp(
            theme: KataTheme.light(),
            home: Material(
              child: SizedBox(
                width: kCardWidth,
                height: h,
                child: ShareCard(ShareSpec(
                  recipe: Recipe(id: 'o1', ofr: ofr),
                  template: template,
                  ratio: ratio,
                  credit: ofr.sourceAttribution ?? 'Kata',
                )),
              ),
            ),
          ));
          await t.pump();
          FlutterError.onError = prev;
          expect(overflow, isEmpty, reason: '$label on ${template.code} at ${ratio.label}: ${overflow.join('; ')}');
        }
      }
    }
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  });

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
