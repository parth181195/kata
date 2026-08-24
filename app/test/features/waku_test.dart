import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/features/waku/waku_screen.dart';
import 'package:kata_ui/kata_ui.dart';

/// A tiny in-memory PNG so the screen has a real decodable photo under test.
/// (toImage/toByteData need real async — hence runAsync at the call sites.)
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

  testWidgets('the chin text is edited in place and dragged along the chin', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFFAA5522))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    // curated gallery: just the instant print and the bring-your-own slot
    expect(find.text('POLAROID'), findsOneWidget);
    expect(find.text('CUSTOM'), findsOneWidget);

    // tap the invitation → inline editor on the frame itself
    await t.tap(find.text('ADD A LINE'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('slot-editor')), 'golden hour');
    // while editing, the chrome stays and the grip still moves the slot
    expect(find.byKey(const ValueKey('slot-grip')), findsOneWidget);
    await t.drag(find.byKey(const ValueKey('slot-grip')), const Offset(25, 0));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('slot-editor')), findsOneWidget); // drag didn't kill the editor
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(find.text('GOLDEN HOUR'), findsOneWidget);

    // the slot is draggable: a pan moves it via its Transform
    Offset translationOf() {
      final tr = t.widgetList<Transform>(find.ancestor(of: find.text('GOLDEN HOUR'), matching: find.byType(Transform))).first;
      final v = tr.transform.getTranslation();
      return Offset(v.x, v.y);
    }

    final before = translationOf();
    await t.drag(find.text('GOLDEN HOUR'), const Offset(40, 0));
    await t.pumpAndSettle();
    expect(translationOf().dx, greaterThan(before.dx));
  });

  testWidgets('grain is the frame\'s own — no user controls for it anywhere', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF667788))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    // curated frames bake their surface grain in; nothing to toggle
    expect(find.text('GRAIN'), findsNothing);
    expect(find.text('WEAK'), findsNothing);
    expect(find.text('STRONG'), findsNothing);
  });

  testWidgets('selection: filled text needs two taps to edit; photo select shows placement controls', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF884422))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    // empty slot: first tap goes straight to the editor
    await t.tap(find.text('ADD A LINE'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('slot-editor')), 'monsoon');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    // tap the mat to deselect (the slot stays selected right after editing)
    await t.tapAt(t.getTopLeft(find.byType(InteractiveViewer)) + const Offset(4, -12));
    await t.pumpAndSettle();
    // filled slot: first tap selects (context panel appears, no editor)
    await t.tap(find.text('MONSOON'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('slot-editor')), findsNothing);
    expect(find.text('Clear line'), findsOneWidget);
    // second tap edits
    await t.tap(find.text('MONSOON'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('slot-editor')), findsOneWidget);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    // select the photo: placement-only controls, no look controls
    await t.tap(find.byType(InteractiveViewer));
    await t.pumpAndSettle();
    expect(find.text('STRAIGHTEN'), findsOneWidget);
    expect(find.text('FLIP'), findsOneWidget);
    expect(find.text('RESET'), findsOneWidget);
    expect(find.text('Exposure'), findsNothing); // the look stayed in the camera
  });

  testWidgets('a custom frame image offers frame-on-top, which hides the surround slider', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF2255AA))))!;
    final frame = (await t.runAsync(() => _png(const Color(0xFF111111))))!;
    await _pump(t, WakuScreen(initialPhoto: photo, initialFrame: frame));
    expect(find.text('Frame on top'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget); // surround mode insets the photo
    await t.tap(find.text('Frame on top'));
    await t.pumpAndSettle();
    expect(find.byType(Slider), findsNothing); // overlay mode: photo fills, no surround
  });
}
