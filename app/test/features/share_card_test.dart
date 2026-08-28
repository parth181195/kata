import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/data/recipe_specs.dart';
import 'package:kata/features/share/card_templates.dart';
import 'package:kata/features/share/kata_code_qr.dart';
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

/// An image that never resolves — enough to prove the card built an Image.
class _NeverImage extends ImageProvider<_NeverImage> {
  const _NeverImage();
  @override
  Future<_NeverImage> obtainKey(ImageConfiguration configuration) => Future.value(this);
  @override
  ImageStreamCompleter loadImage(_NeverImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}

void main() {
  // A card is a fixed box; a Column that outgrows it overflows, which in a
  // release build is a silent clip — the code or the credit simply isn't there.
  // The story template did this on every square card for a plain recipe.
  testWidgets('no template overflows its card, at any ratio, with the worst content', (t) async {
    for (final (label, ofr) in [('worst', _worst), ('plain', _colour)]) {
      for (final (template, page) in [for (final t in ShareTemplate.values) for (final pg in SharePage.values) (t, pg)]) {
        for (final ratio in ShareRatio.values) {
          final overflow = <String>[];
          final prev = FlutterError.onError;
          FlutterError.onError = (d) => overflow.add(d.exceptionAsString().split('\n').first);
          final h = kCardWidth / ratio.aspect;
          // page 1 sizes itself, so its view is simply tall; page 2 is the card's ratio
          t.view.physicalSize = Size(kCardWidth, page == SharePage.photo ? 1600 : h);
          t.view.devicePixelRatio = 1;
          await t.pumpWidget(MaterialApp(
            theme: KataTheme.light(),
            home: Material(
              child: SizedBox(
                width: kCardWidth,
                height: page == SharePage.photo ? null : h,
                child: ShareCard(ShareSpec(
                  recipe: Recipe(id: 'o1', ofr: ofr),
                  template: template,
                  page: page,
                  ratio: ratio,
                  credit: ofr.sourceAttribution ?? 'Kata',
                )),
              ),
            ),
          ));
          await t.pump();
          FlutterError.onError = prev;
          expect(overflow, isEmpty, reason: '$label on ${template.code} ${page.name} at ${ratio.label}: ${overflow.join('; ')}');
        }
      }
    }
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  });

  // On a 390px square a frame above the name can never have meaningful height
  // — it got 18px, a sliver bought with the last word of the name. The code's
  // row is 128px tall with air beside it, so that is where the pictures go:
  // two of them, and the name stays whole.
  testWidgets('the pair: page 1 carries the picture at every ratio, page 2 never does', (t) async {
    final long = Recipe(
      id: 'l1',
      ofr: _colour.copyWith(name: 'Kodak T-Max 100 Hard Tone'),
      imageUrls: const ['gated://a', 'gated://b', 'gated://c'],
    );
    Future<void> pump(ShareTemplate template, SharePage page, ShareRatio ratio) async {
      final h = kCardWidth / ratio.aspect;
      t.view.physicalSize = Size(kCardWidth, page == SharePage.photo ? 1600 : h);
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(MaterialApp(
        theme: KataTheme.light(),
        home: Material(
          child: SizedBox(
            width: kCardWidth,
            height: page == SharePage.photo ? null : h,
            child: ShareCard(ShareSpec(
              recipe: long,
              template: template,
              page: page,
              ratio: ratio,
              credit: 'Kata',
              imageFor: (_) => const _NeverImage(),
            )),
          ),
        ),
      ));
      await t.pump();
    }

    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final nameText = find.text('KODAK T-MAX 100 HARD TONE');

    for (final template in ShareTemplate.values) {
      for (final ratio in ShareRatio.values) {
        await pump(template, SharePage.photo, ratio);
        expect(find.byType(Image), findsOneWidget, reason: '${template.code} page 1 at ${ratio.label} is one photograph');
        final r = t.getRect(find.byType(Image));
        expect(r.height, greaterThan(80), reason: '${template.code} at ${ratio.label}: a picture, not a sliver: ${r.height}px');
        expect(r.width, greaterThan(80));
        expect(r.width, greaterThan(kCardWidth - 50), reason: '${template.code}: the frame runs edge to edge');
        expect(nameText, findsOneWidget, reason: 'the name travels with the picture');

        await pump(template, SharePage.recipe, ratio);
        expect(find.byType(Image), findsNothing, reason: '${template.code} page 2 at ${ratio.label} has no picture');
        expect(find.byType(KataCodeQr), findsOneWidget, reason: 'and carries the code');
      }
    }
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

  test('a file is named by five digits of the recipe and the day; the pair sits as -1 and -2', () {
    final day = DateTime(2026, 8, 28);
    final a = Recipe(id: 'aaaaaa11', ofr: _colour.copyWith(name: '夏の海辺 — 富士フイルム'));
    final b = Recipe(id: 'bbbbbb22', ofr: _colour.copyWith(name: '...'));
    final an = shareFileName(a, SharePage.photo, now: day);
    final bn = shareFileName(b, SharePage.photo, now: day);
    expect(an, matches(RegExp(r'^kata-\d{5}-20260828-1\.png$')));
    expect(shareFileName(a, SharePage.recipe, now: day), endsWith('-20260828-2.png'));
    expect(an, isNot(bn), reason: 'two recipes saved the same day would overwrite each other in Downloads');
    // a numeric id keeps its own digits; a long one keeps its last five
    expect(recipeCode5('42'), '00042');
    expect(recipeCode5('1234567'), '34567');
    expect(recipeCode5('srv-1'), recipeCode5('srv-1'), reason: 'stable');
    expect(recipeCode5('srv-1'), isNot(recipeCode5('srv-2')));
  });

  testWidgets('the outline draws over the card without moving anything; square corners drop the radius', (t) async {
    Future<void> pump({required bool outline, required bool round}) => t.pumpWidget(MaterialApp(
          theme: KataTheme.light(),
          home: Material(
            child: ShareCard(ShareSpec(
              recipe: Recipe(id: 'r1', ofr: _colour),
              template: ShareTemplate.card,
              page: SharePage.photo,
              ratio: ShareRatio.r4x5,
              inverted: true,
              outline: outline,
              roundCorners: round,
              credit: 'Kata',
            )),
          ),
        ));
    t.view.physicalSize = const Size(kCardWidth, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pump(outline: false, round: true);
    final frame = find.byType(ClipRRect).at(1); // the photograph's frame (the first clip is the card's own edge)
    final before = t.getRect(frame);
    expect(t.widget<ClipRRect>(frame).borderRadius, BorderRadius.circular(kFrameRadius));
    await pump(outline: true, round: false);
    expect(t.getRect(frame), before, reason: 'the outline is drawn over the content, not around it');
    expect(t.widget<ClipRRect>(frame).borderRadius, BorderRadius.zero);
    expect(t.widget<ClipRRect>(find.byType(ClipRRect).first).borderRadius, BorderRadius.zero, reason: 'square corners square the card too');
    final card = t.widget<Container>(find.byWidgetPredicate((w) => w is Container && w.foregroundDecoration != null));
    expect((card.foregroundDecoration! as BoxDecoration).border, isNotNull);
  });

  testWidgets('the photograph is placed by the spec, and never pulled off its frame', (t) async {
    // a 2:1 photo of solid colour, as bytes (real async: the rasteriser
    // doesn't run inside the test's fake clock)
    late final Uint8List bytes;
    await t.runAsync(() async {
      final rec = ui.PictureRecorder();
      ui.Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 200, 100), Paint()..color = const Color(0xFF3366CC));
      final img = await rec.endRecording().toImage(200, 100);
      bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    });
    Future<void> pump(Offset off, double zoom) => t.pumpWidget(MaterialApp(
          theme: KataTheme.light(),
          home: Material(
            child: SizedBox(
              width: kCardWidth,
              child: ShareCard(ShareSpec(
                recipe: Recipe(id: 'r1', ofr: _colour),
                template: ShareTemplate.card,
                page: SharePage.photo,
                ratio: ShareRatio.r4x5,
                credit: 'Kata',
                photos: [bytes],
                photoSize: const Size(200, 100),
                photoOffset: off,
                photoZoom: zoom,
              )),
            ),
          ),
        ));
    t.view.physicalSize = const Size(kCardWidth, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    Offset shift() => t.widgetList<Transform>(find.byType(Transform)).first.transform.getTranslation().let((v) => Offset(v.x, v.y));
    await pump(Offset.zero, 1);
    expect(shift(), Offset.zero);
    // a wide photo cover-fits a taller frame with spare width only: it can
    // slide sideways, never up or down at zoom 1
    await pump(const Offset(30, 30), 1);
    expect(shift().dx, 30);
    expect(shift().dy, 0, reason: 'no vertical slack at zoom 1');
    // and however far it is dragged, the frame stays covered
    await pump(const Offset(9999, 9999), 2);
    final frame = t.getRect(find.byType(ClipRRect).at(1));
    final s = shift();
    expect(s.dx, lessThan(9999));
    expect(s.dy, lessThan(frame.height), reason: 'clamped to the zoomed overflow');
    expect(s.dy, greaterThan(0), reason: 'zoom 2 leaves vertical slack');
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
