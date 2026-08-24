import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/features/waku/waku_frames.dart';
import 'package:kata/features/waku/waku_screen.dart';
import 'package:kata_ui/kata_ui.dart';

/// A tiny in-memory PNG so the screen has a real decodable photo under test.
Future<Uint8List> _png(Color c, {int size = 8}) async {
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), Paint()..color = c);
  final img = await rec.endRecording().toImage(size, size);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return bytes!.buffer.asUint8List();
}

Future<void> _pump(WidgetTester t, Widget child) async {
  t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  t.view.physicalSize = const Size(1280, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(theme: KataTheme.dark(), home: child));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('without a photo: the empty state invites choosing one', (t) async {
    await _pump(t, const WakuScreen());
    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.text('Pick a photo first — the frames preview with it.'), findsOneWidget);
  });

  testWidgets('with a photo: every frame preset previews as a thumbnail; switching frames re-renders', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFFAA5522))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    for (final f in WakuFrame.values) {
      // the strip scrolls; later thumbnails are built once brought into view
      await t.scrollUntilVisible(find.text(f.label.toUpperCase()), 60, scrollable: find.descendant(of: find.byKey(const ValueKey('waku-frames')), matching: find.byType(Scrollable)));
      expect(find.text(f.label.toUpperCase()), findsOneWidget);
    }
    for (final r in WakuRatio.values) {
      expect(find.text(r.label), findsOneWidget);
    }
    await t.scrollUntilVisible(find.text('FILM'), -60, scrollable: find.descendant(of: find.byKey(const ValueKey('waku-frames')), matching: find.byType(Scrollable)));
    await t.tap(find.text('FILM'));
    await t.pumpAndSettle();
    await t.tap(find.text('1:1'));
    await t.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('a custom frame image offers frame-on-top, which hides the mat slider', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF2255AA))))!;
    final frame = (await t.runAsync(() => _png(const Color(0xFF111111))))!;
    await _pump(t, WakuScreen(initialPhoto: photo, initialFrame: frame));
    expect(find.text('Frame on top'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget); // surround mode still insets the photo
    await t.tap(find.text('Frame on top'));
    await t.pumpAndSettle();
    expect(find.byType(Slider), findsNothing); // overlay mode: photo fills, no mat
  });
}
