// A contact sheet of one object, several seeds, rendered one at a time.
//
// Run: cd app && fvm flutter test tool/contact_sheet.dart --dart-define=obj=negative
//
// Not under test/, so `flutter test` doesn't pick it up. Each seed is pumped
// into its own widget tree and rasterised on its own: nine canvases sharing one
// layer is not what the app ever does, and it renders differently when they do.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/grain.dart';
import 'package:kata/core/compose/layers.dart';
import 'package:kata/core/compose/roll.dart';
import 'package:kata/features/waku/frames/frame.dart';
import 'package:kata/features/waku/waku_exif.dart';
import 'package:kata/features/waku/waku_grain_measure.dart';
import 'package:kata/features/waku/waku_palette.dart';

const _objId = String.fromEnvironment('obj', defaultValue: 'stamp');
const _photoPath = String.fromEnvironment('photo', defaultValue: '/home/parth/WebstormProjects/fuji/web/landing/img/hero-1.jpg');
const _outDir = String.fromEnvironment('out', defaultValue: '/home/parth/.claude/jobs/787ed077/tmp/sheet');
const _ratio = String.fromEnvironment('ratio', defaultValue: '4x5');
const _seeds = int.fromEnvironment('seeds', defaultValue: 6);
/// Show the empty slots' invitations, so a card whose maker and title are the
/// user's to write can still be judged as a finished object.
const _invite = bool.fromEnvironment('invite');

const _ratios = {'1x1': Size(760, 760), '4x5': Size(760, 950), '3x2': Size(950, 633), '9x16': Size(600, 1067)};

void main() {
  testWidgets('contact sheet', (t) async {
    final size = _ratios[_ratio]!;
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    final bytes = File(_photoPath).readAsBytesSync();
    late PhotoMeta meta;
    late List<Color> palette;
    late PhotoGrain grain;
    await t.runAsync(() async {
      meta = await readPhotoMeta(bytes);
      palette = await extractPalette(bytes) ?? const <Color>[];
      grain = await measurePhotoGrain(bytes);
    });
    if (meta.isEmpty) meta = const PhotoMeta(model: 'X-S20', iso: 400, filmMode: 'CLASSIC CHROME');

    final obj = kObjects.firstWhere((o) => o.id == _objId);
    Directory(_outDir).createSync(recursive: true);

    for (var seed = 1; seed <= _seeds; seed++) {
      final roll = Roll.draw(seed: seed, allowances: obj.allowances, palette: palette, filmSim: meta.filmMode, iso: meta.iso);
      final key = GlobalKey();
      await t.runAsync(() async {
        await t.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          // a Material ancestor, or every Text renders with Flutter's
          // missing-Material yellow underline and the sheet lies to you
          home: Material(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
              width: size.width,
              height: size.height,
              child: ComposeCanvasView(
                canvasSize: size,
                grain: true,
                layers: obj.build(ObjectContext(size: size, meta: meta, grain: grain, palette: palette, roll: roll)),
                photo: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                textOf: (_) => '',
                dragOf: (_) => Offset.zero,
                hideInvitations: !_invite,
                onTapText: (_) {},
                onDragText: (_, _) {},
                ),
              ),
            ),
          ),
        ));
        // the photo decode and the grain template are both async
        await GrainOverlay.ready();
        for (var i = 0; i < 10; i++) {
          await t.pump(const Duration(milliseconds: 50));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage();
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$_outDir/${_objId}_${_ratio}_$seed.png').writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
    }
    // ignore: avoid_print
    print('wrote $_seeds sheets to $_outDir');
  });
}
