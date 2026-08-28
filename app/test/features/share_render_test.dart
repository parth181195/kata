import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/export.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/features/share/card_renderer.dart';
import 'package:kata/features/share/card_templates.dart';
import 'package:ofr/ofr.dart';

const _ofr = OfrRecipe(
    name: 'Beach Chrome', sensors: ['X-Trans V'], filmSimulation: 'Classic Chrome', dRangePriority: 'Off',
    grainRoughness: 'Weak', whiteBalance: 'Daylight', whiteBalanceRed: 1, whiteBalanceBlue: -2,
    sharpness: 0, highIsoNr: -2, clarity: 0);

/// An image provider whose decode we control: the card's photo arrives when the
/// test says so, the way a network image arrives when the network says so.
class _SlowImage extends ImageProvider<_SlowImage> {
  _SlowImage(this.gate);
  final Completer<ui.Image> gate;

  @override
  Future<_SlowImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_SlowImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(gate.future.then((i) => ImageInfo(image: i)));
}

Future<ui.Image> _solid(Color c) async {
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 64, 64), Paint()..color = c);
  return rec.endRecording().toImage(64, 64);
}


/// rasterizePng awaits endOfFrame, and inside runAsync nobody schedules a frame
/// unless the test does. This runs [export] while pumping, the way the app's
/// own frame loop would.
Future<T> _whilePumping<T>(WidgetTester t, Future<T> export, {Duration atMost = const Duration(seconds: 5)}) async {
  final sw = Stopwatch()..start();
  T? out;
  var done = false;
  unawaited(export.then((v) {
    out = v;
    done = true;
  }));
  while (!done) {
    if (sw.elapsed > atMost) throw TimeoutException('export did not finish', atMost);
    await t.pump(const Duration(milliseconds: 16));
    await Future<void>.delayed(const Duration(milliseconds: 4));
  }
  return out as T;
}

void main() {
  testWidgets('the card is not captured before its photo has arrived', (t) async {
    final gate = Completer<ui.Image>();
    final key = GlobalKey();
    const w = 200.0, h = 250.0;
    t.view.physicalSize = const Size(w, h);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: w, height: h, child: Image(image: _SlowImage(gate), fit: BoxFit.cover)),
        ),
      ),
    ));
    await t.pump();

    await t.runAsync(() async {
      // start the export while the photo is still "downloading"
      final export = rasterizePng(key, pixelRatio: 1, settle: true);
      // it must be waiting on the image, not racing ahead of it: pump frames
      // for a while and check it has NOT finished
      var done = false;
      unawaited(export.then((_) => done = true));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 16));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(done, isFalse, reason: 'the export captured before the photo decoded');

      gate.complete(await _solid(const Color(0xFFFF00FF)));
      final png = await _whilePumping(t, export);
      expect(png.length, greaterThan(100));
    });
  });

  testWidgets('a photo that never arrives does not hang the export', (t) async {
    final gate = Completer<ui.Image>(); // never completed: an offline device
    final key = GlobalKey();
    t.view.physicalSize = const Size(200, 250);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: 200, height: 250, child: Image(image: _SlowImage(gate), fit: BoxFit.cover)),
        ),
      ),
    ));
    await t.pump();
    await t.runAsync(() async {
      final png = await _whilePumping(
        t,
        rasterizePng(key, pixelRatio: 1, settle: true, imageWait: const Duration(milliseconds: 200)),
      );
      expect(png.length, greaterThan(100), reason: 'an offline export should still produce a card');
    });
  });

  testWidgets('the card renderer waits for the card\'s own image', (t) async {
    // the real card, with a recipe whose image URL points at our gated provider
    final gate = Completer<ui.Image>();
    final key = GlobalKey();
    t.view.physicalSize = const Size(kCardWidth, kCardWidth / (4 / 5));
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final spec = ShareSpec(
      recipe: Recipe(id: 'r1', ofr: _ofr, imageUrls: const ['gated://one']),
      template: ShareTemplate.card,
      page: SharePage.photo, // the photograph is on page 1
      ratio: ShareRatio.r4x5,
      credit: 'Kata',
    );
    await t.pumpWidget(MaterialApp(
      home: Center(
        child: OffscreenCardHost(
          boundaryKey: key,
          spec: spec,
          scale: 1,
          imageFor: (_) => _SlowImage(gate),
        ),
      ),
    ));
    await t.pump();
    await t.runAsync(() async {
      final export = CardRenderer(key).toPng(pixelRatio: 1);
      var done = false;
      unawaited(export.then((_) => done = true));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 16));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(done, isFalse, reason: 'the card was captured with its sample frame still loading');
      gate.complete(await _solid(const Color(0xFFFF00FF)));
      await _whilePumping(t, export);
    });
  });
}
