// Every share card, rendered headlessly, so they can be looked at.
//
// Run:
//   cd app && fvm flutter test tool/share_sheet.dart \
//     --dart-define=fixture=maximal --dart-define=ratio=4x5 --dart-define=inverted=true
//
// A card is broken by its content far more often than by its options, so the
// fixtures are the point: a name nobody can fit, an attribution from a blog, a
// recipe with every optional field set, a recipe with almost none.
//
// Lives outside test/ so `flutter test` doesn't run it. Renders each card in its
// own widget tree — nine canvases in one layer is not what the app does, and it
// does not render the same when they are (see tool/contact_sheet.dart).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/features/share/card_templates.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

const _fixture = String.fromEnvironment('fixture', defaultValue: 'typical');
const _ratioKey = String.fromEnvironment('ratio', defaultValue: '4x5');
const _inverted = bool.fromEnvironment('inverted');
const _embed = bool.fromEnvironment('embed', defaultValue: true);
const _outDir = String.fromEnvironment('out', defaultValue: '/home/parth/.claude/jobs/787ed077/tmp/share');

const _ratios = {'4x5': ShareRatio.r4x5, '1x1': ShareRatio.r1x1, '9x16': ShareRatio.r9x16};

/// The base every fixture varies from — a plausible everyday recipe.
const _base = OfrRecipe(
  name: 'Beach Chrome',
  sensors: ['X-Trans V'],
  filmSimulation: 'Classic Chrome',
  dynamicRange: 'DR200',
  dRangePriority: 'Off',
  grainRoughness: 'Weak',
  grainSize: 'Small',
  whiteBalance: 'Daylight',
  whiteBalanceRed: 1,
  whiteBalanceBlue: -2,
  highlight: 0,
  shadow: -1,
  color: 2,
  sharpness: 0,
  highIsoNr: -2,
  clarity: 0,
);

/// Every optional field set: the overflow case for the settings grids.
const _maximal = OfrRecipe(
  name: 'Everything, All Of It, Turned All The Way Up',
  sensors: ['X-Trans V', 'X-Trans IV', 'GFX'],
  sourceAttribution: 'Fuji X Weekly — Ritchie Roesch',
  sourceUrl: 'https://fujixweekly.com/some/very/long/path/to/a/recipe',
  filmSimulation: 'Classic Negative',
  dynamicRange: 'DR400',
  dRangePriority: 'Strong',
  grainRoughness: 'Strong',
  grainSize: 'Large',
  colorChromeEffect: 'Strong',
  colorChromeFxBlue: 'Strong',
  whiteBalance: 'Kelvin',
  wbKelvin: 7500,
  whiteBalanceRed: 9,
  whiteBalanceBlue: -9,
  highlight: 4,
  shadow: 4,
  color: 4,
  sharpness: 4,
  highIsoNr: 4,
  clarity: 5,
  monochromaticColorWarmCool: 9,
  monochromaticColorMagentaGreen: -9,
);

/// The least a recipe can be and still be one.
const _minimal = OfrRecipe(
  filmSimulation: 'Provia',
  dRangePriority: 'Off',
  grainRoughness: 'Off',
  whiteBalance: 'Auto',
  whiteBalanceRed: 0,
  whiteBalanceBlue: 0,
  sharpness: 0,
  highIsoNr: 0,
  clarity: 0,
);

OfrRecipe _named(String name) => OfrRecipe(
      name: name,
      sensors: _base.sensors,
      filmSimulation: _base.filmSimulation,
      dynamicRange: _base.dynamicRange,
      dRangePriority: _base.dRangePriority,
      grainRoughness: _base.grainRoughness,
      whiteBalance: _base.whiteBalance,
      whiteBalanceRed: _base.whiteBalanceRed,
      whiteBalanceBlue: _base.whiteBalanceBlue,
      highlight: _base.highlight,
      shadow: _base.shadow,
      color: _base.color,
      sharpness: _base.sharpness,
      highIsoNr: _base.highIsoNr,
      clarity: _base.clarity,
    );

final _fixtures = <String, (Recipe, String)>{
  'typical': (Recipe(id: 'f1', ofr: _base), 'Kata'),
  'maximal': (Recipe(id: 'f2', ofr: _maximal), 'Fuji X Weekly — Ritchie Roesch'),
  'minimal': (Recipe(id: 'f3', ofr: _minimal), 'Kata'),
  'longname': (
    Recipe(id: 'f4', ofr: _named('A Recipe With An Extremely Long Name That Nobody Would Ever Fit')),
    'Kata'
  ),
  'cjk': (Recipe(id: 'f5', ofr: _named('夏の海辺 — 富士フイルム')), '夏の写真家'),
  'emoji': (Recipe(id: 'f6', ofr: _named('🌊 beach vibes 🌴')), 'Kata'),
  'longcredit': (
    Recipe(id: 'f7', ofr: _base),
    'A Very Long Attribution Line From Somebody Else’s Blog Indeed'
  ),
};

/// `flutter test` renders every declared font family as the box font unless you
/// load it yourself. Without this the sheet shows solid rectangles and tells you
/// nothing about the type — which is exactly the sort of harness lie that costs
/// an afternoon.
Future<void> _loadFonts() async {
  const dir = '/home/parth/WebstormProjects/fuji/packages/kata_ui/fonts';
  // KataType names them package-scoped ('packages/kata_ui/Inter'), which is the
  // family the engine actually looks up — loading them as bare 'Inter' loads a
  // font nothing asks for.
  for (final (family, file) in [
    ('packages/kata_ui/Inter', 'Inter.ttf'),
    ('packages/kata_ui/JetBrains Mono', 'JetBrainsMono.ttf'),
    ('packages/kata_ui/Doto', 'Doto.ttf'),
  ]) {
    final bytes = File('$dir/$file').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  }
}

void main() {
  testWidgets('share sheet', (t) async {
    await t.runAsync(_loadFonts);
    final ratio = _ratios[_ratioKey]!;
    final (recipe, credit) = _fixtures[_fixture]!;
    final h = kCardWidth / ratio.aspect;

    t.view.physicalSize = Size(kCardWidth, h);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    Directory(_outDir).createSync(recursive: true);

    for (final template in ShareTemplate.values) {
      final spec = ShareSpec(
        recipe: recipe,
        template: template,
        ratio: ratio,
        inverted: _inverted,
        embedCode: _embed,
        credit: credit,
      );
      final key = GlobalKey();
      await t.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: KataTheme.light(),
        home: Material(child: RepaintBoundary(key: key, child: ShareCard(spec))),
      ));
      await t.pumpAndSettle();
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        final flags = [if (_inverted) 'inv', if (!_embed) 'nocode'];
        final name = '${[_fixture, template.code, _ratioKey, ...flags].join('_')}.png';
        File('$_outDir/$name').writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
      // ignore: avoid_print
      print('${template.code} ${spec.payload.length} bytes payload');
    }
    // ignore: avoid_print
    print('wrote ${ShareTemplate.values.length} cards to $_outDir');
  });
}
