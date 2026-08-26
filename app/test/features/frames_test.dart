import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/ink.dart';
import 'package:kata/core/compose/layers.dart';
import 'package:kata/core/compose/roll.dart';
import 'package:kata/features/share/kata_code_qr.dart';
import 'package:kata/features/waku/frames/frame.dart';
import 'package:kata/features/waku/waku_exif.dart';
import 'package:kata/features/waku/waku_grain_measure.dart';

const _palette = [Color(0xFF8A2B1C), Color(0xFF3C4A5A), Color(0xFFE8DFC9), Color(0xFF6B7F52), Color(0xFFD8C9A8)];
const _meta = PhotoMeta(model: 'X-S20', iso: 400, filmMode: 'CLASSIC CHROME');
const _ratios = [(600.0, 750.0), (600.0, 600.0), (600.0, 1067.0), (600.0, 900.0)];

void main() {
  test('the registry is not empty', () {
    expect(kObjects, isNotEmpty);
  });

  test('object ids are unique and resolvable', () {
    expect(kObjects.map((o) => o.id).toSet().length, kObjects.length);
    for (final o in kObjects) {
      expect(objectById(o.id), same(o));
    }
  });

  test('the stamp is registered', () {
    expect(kObjects.any((o) => o.id == 'stamp'), isTrue);
  });

  test('every object keeps its slots on the sheet, at every ratio and seed', () {
    for (final obj in kObjects) {
      for (final (w, h) in _ratios) {
        final size = Size(w, h);
        final sheet = Rect.fromLTWH(0, 0, w, h);
        for (var seed = 0; seed < 25; seed++) {
          final roll = Roll.draw(seed: seed, allowances: obj.allowances, palette: _palette, filmSim: _meta.filmMode, iso: _meta.iso);
          final layers = obj.build(ObjectContext(size: size, meta: _meta, grain: PhotoGrain.none, palette: _palette, roll: roll));

          expect(layers, isNotEmpty, reason: '${obj.id} built nothing');
          expect(layers.whereType<ComposePhotoWindow>().length, 1, reason: '${obj.id} must have exactly one photo window');

          for (final l in layers) {
            if (l is ComposeTextSlot) {
              expect(l.region.width, greaterThan(0), reason: '${obj.id} slot ${l.id} has no width at ${w}x$h');
              expect(l.region.height, greaterThan(0), reason: '${obj.id} slot ${l.id} has no height at ${w}x$h');
              expect(sheet.overlaps(l.region), isTrue,
                  reason: '${obj.id} put slot ${l.id} off the sheet at ${w}x$h seed $seed');
            }
            if (l is ComposePhotoWindow) {
              expect(l.rect.width, greaterThan(0), reason: '${obj.id} photo has no width at ${w}x$h');
              expect(l.rect.height, greaterThan(0), reason: '${obj.id} photo has no height at ${w}x$h');
              expect(sheet.overlaps(l.rect), isTrue, reason: '${obj.id} put the photo off the sheet at ${w}x$h');
            }
          }
        }
      }
    }
  });

  test('the negative strip is registered and carries the recipe on its edge', () {
    final obj = kObjects.firstWhere((o) => o.id == 'negative');
    final layers = obj.build(ObjectContext(
      size: const Size(600, 750),
      meta: _meta,
      grain: PhotoGrain.none,
      palette: _palette,
      roll: Roll.draw(seed: 3, allowances: obj.allowances, palette: _palette),
      kataName: 'KODACHROME 64',
    ));
    final edge = layers.whereType<ComposeTextSlot>().firstWhere((s) => s.id == 'stock');
    expect(edge.prefill, contains('KODACHROME 64'));
  });

  test('a 35mm frame is 3:2 at every sheet ratio — that is what makes it 35mm', () {
    final obj = kObjects.firstWhere((o) => o.id == 'negative');
    for (final (w, h) in _ratios) {
      final roll = Roll.draw(seed: 5, allowances: obj.allowances, palette: _palette);
      final layers = obj.build(ObjectContext(size: Size(w, h), meta: _meta, grain: PhotoGrain.none, palette: _palette, roll: roll));
      final win = layers.whereType<ComposePhotoWindow>().first.rect;
      expect(win.width / win.height, closeTo(1.5, 0.02), reason: 'the frame is not 3:2 at ${w}x$h');
    }
  });

  test('the edge print is the roll\'s ink, or the colour axis does nothing here', () {
    final obj = kObjects.firstWhere((o) => o.id == 'negative');
    final inks = <Color>{};
    for (var seed = 0; seed < 20; seed++) {
      final roll = Roll.draw(seed: seed, allowances: obj.allowances, palette: _palette);
      final layers = obj.build(ObjectContext(size: const Size(600, 750), meta: _meta, grain: PhotoGrain.none, palette: _palette, roll: roll));
      final edge = layers.whereType<ComposeTextSlot>().firstWhere((s) => s.id == 'stock');
      expect(edge.style.color, roll.ink, reason: 'seed $seed printed the edge in something the roll did not choose');
      inks.add(roll.ink);
    }
    expect(inks.length, greaterThan(1));
  });

  test('every object prints ink you can read on the surface it prints on', () {
    for (final obj in kObjects) {
      for (var seed = 0; seed < 60; seed++) {
        final roll = Roll.draw(seed: seed, allowances: obj.allowances, palette: _palette, filmSim: _meta.filmMode, iso: _meta.iso);
        expect(contrastRatio(roll.ink, obj.allowances.inkOn), greaterThanOrEqualTo(3.0),
            reason: '${obj.id} at seed $seed is unreadable on its own surface');
      }
    }
  });

  // A CustomPainter that draws past the size it was given paints over whatever
  // was drawn before it. On one canvas the screen hides that; put two canvases
  // in one layer — an object drawer, a row of thumbnails — and an object erases
  // its neighbour. The negative strip did exactly this, and it took a bisect to
  // find, because every layer rect involved was correct.
  //
  // The invariant, stated without guessing what an object may draw on itself:
  // an object rendered beside another must come out pixel-for-pixel identical
  // to the same object rendered alone.
  testWidgets('no object paints outside its own sheet', (t) async {
    const cell = Size(300, 375);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    Widget canvas(WakuObject obj, int seed) => SizedBox(
          width: cell.width,
          height: cell.height,
          child: ComposeCanvasView(
            canvasSize: cell,
            grain: false,
            layers: obj.build(ObjectContext(
              size: cell,
              meta: _meta,
              grain: PhotoGrain.none,
              palette: _palette,
              roll: Roll.draw(seed: seed, allowances: obj.allowances, palette: _palette),
            )),
            photo: const ColoredBox(color: Color(0xFFFF00FF)),
            textOf: (_) => '',
            dragOf: (_) => Offset.zero,
            hideInvitations: true,
            onTapText: (_) {},
            onDragText: (_, _) {},
          ),
        );

    Future<ByteData> shoot(WidgetTester t, GlobalKey key, Widget child, Size view) async {
      t.view.physicalSize = view;
      await t.pumpWidget(MaterialApp(home: Material(child: RepaintBoundary(key: key, child: child))));
      await t.pumpAndSettle();
      late ByteData out;
      await t.runAsync(() async {
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage();
        out = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        img.dispose();
      });
      return out;
    }

    for (final obj in kObjects) {
      final alone = await shoot(t, GlobalKey(), canvas(obj, 1), cell);
      final paired = await shoot(t, GlobalKey(),
          Row(children: [canvas(obj, 1), canvas(obj, 2)]), Size(cell.width * 2, cell.height));

      var differing = 0;
      for (var y = 0; y < cell.height.round(); y++) {
        for (var x = 0; x < cell.width.round(); x++) {
          final a = (y * cell.width.round() + x) * 4;
          final b = (y * cell.width.round() * 2 + x) * 4;
          if (alone.getUint32(a) != paired.getUint32(b)) differing++;
        }
      }
      expect(differing, 0,
          reason: '${obj.id} changed by $differing pixels when another object was placed beside it — '
              'something it draws is escaping its own sheet');
    }
  });

  testWidgets('an attached recipe rides every object exactly once, and never when absent', (t) async {
    const cell = Size(600, 750);
    t.view.physicalSize = cell;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    Future<int> codesOn(WakuObject obj, {String? code}) async {
      await t.pumpWidget(MaterialApp(
        home: Material(
          child: SizedBox(
            width: cell.width,
            height: cell.height,
            child: ComposeCanvasView(
              canvasSize: cell,
              grain: false,
              layers: obj.build(ObjectContext(
                size: cell,
                meta: _meta,
                grain: PhotoGrain.none,
                palette: _palette,
                roll: Roll.draw(seed: 4, allowances: obj.allowances, palette: _palette),
                kataName: code == null ? null : 'KODACHROME 64',
                kataCode: code,
              )),
              photo: const ColoredBox(color: Color(0xFF667788)),
              textOf: (_) => '',
              dragOf: (_) => Offset.zero,
              hideInvitations: true,
              onTapText: (_) {},
              onDragText: (_, _) {},
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
      return find.byType(KataCodeQr).evaluate().length;
    }

    for (final obj in kObjects) {
      expect(await codesOn(obj, code: 'kata1:AAAA'), 1,
          reason: '${obj.id} should carry the attached code exactly once');
      expect(await codesOn(obj), 0, reason: '${obj.id} drew a code with no recipe attached');
    }
  });

  test('slot ids are unique within an object — a duplicate would share text', () {
    for (final obj in kObjects) {
      final roll = Roll.draw(seed: 1, allowances: obj.allowances, palette: _palette);
      final layers = obj.build(ObjectContext(size: const Size(600, 750), meta: _meta, grain: PhotoGrain.none, palette: _palette, roll: roll));
      final ids = layers.whereType<ComposeTextSlot>().map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length, reason: '${obj.id} has a duplicate slot id');
    }
  });
}
