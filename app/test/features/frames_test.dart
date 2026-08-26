import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/ink.dart';
import 'package:kata/core/compose/layers.dart';
import 'package:kata/core/compose/roll.dart';
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

  test('every object prints ink you can read on the surface it prints on', () {
    for (final obj in kObjects) {
      for (var seed = 0; seed < 60; seed++) {
        final roll = Roll.draw(seed: seed, allowances: obj.allowances, palette: _palette, filmSim: _meta.filmMode, iso: _meta.iso);
        expect(contrastRatio(roll.ink, obj.allowances.inkOn), greaterThanOrEqualTo(3.0),
            reason: '${obj.id} at seed $seed is unreadable on its own surface');
      }
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
