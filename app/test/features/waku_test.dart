import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/grain.dart';
import 'package:kata/core/compose/layers.dart';
import 'package:kata/core/compose/roll.dart';
import 'package:kata/core/compose/treatment.dart';
import 'package:kata/core/compose/voice.dart';
import 'package:kata/features/waku/frames/frame.dart';
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

/// The panel's field for the selected slot.
final _field = find.descendant(of: find.byKey(const ValueKey('slot-text')), matching: find.byType(TextField));

/// [text] as it appears on the print — the panel's field holds the same string,
/// so a bare find.text would match twice.
Finder _onPrint(String text) => find.descendant(of: find.byType(ComposeCanvasView), matching: find.text(text));

/// An object that grants every optional handle, so the panel controls that a
/// rigid object like the stamp never offers still have something to act on.
class _LooseObject extends WakuObject {
  const _LooseObject();

  @override
  String get id => 'loose';

  @override
  String get label => 'Loose';

  @override
  Allowances get allowances => const Allowances(
        voices: {VoiceId.bureau},
        inkFamily: 'postmark',
        treatment: TreatmentBounds(),
        grounds: [Color(0xFF222222)],
      );

  @override
  List<ComposeLayer> build(ObjectContext ctx) => [
        const ComposeSurface(ColoredBox(color: Color(0xFFF4EFE3))),
        ComposePhotoWindow(rect: Rect.fromLTWH(0, 0, ctx.size.width, ctx.size.height * 0.7)),
        ComposeTextSlot(
          id: 'line',
          region: Rect.fromLTWH(ctx.size.width * 0.1, ctx.size.height * 0.75, ctx.size.width * 0.8, ctx.size.height * 0.12),
          style: ctx.roll.voice.textStyle(ctx.size.width * 0.05, ctx.roll.ink),
          draggable: true,
          scalable: true,
          rotatable: true,
          maxChars: 56,
          maxLines: 2,
          inkChoices: const [Color(0xFF3A362E), Color(0xFF3D4E6B), Color(0xFFB3402B)],
        ),
      ];
}

void main() {
  testWidgets('without a photo: the empty state invites choosing one', (t) async {
    await _pump(t, const WakuScreen());
    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.text('Pick a photo first — it lands on something already composed.'), findsOneWidget);
  });

  testWidgets('a photo lands on a finished object, not a gallery', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF667788))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    // no "pick a frame" step: something is already composed
    expect(find.byType(ComposeCanvasView), findsWidgets);
    expect(find.text('SHUFFLE'), findsOneWidget);
    // and there is no gallery of thumbnails to choose from first
    expect(find.byKey(const ValueKey('waku-frames')), findsNothing);
  });

  testWidgets('shuffle changes the output; a pinned axis holds', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF667788))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));

    Roll rollOf() => t.state<WakuScreenState>(find.byType(WakuScreen)).roll;
    final before = rollOf().seed;
    await t.tap(find.text('SHUFFLE'));
    await t.pumpAndSettle();
    expect(rollOf().seed, isNot(before));

    // pin the voice, then shuffle: the voice must not move
    final voiceBefore = rollOf().voiceId;
    await t.tap(find.byKey(const ValueKey('pin-voice')));
    await t.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await t.tap(find.text('SHUFFLE'));
      await t.pumpAndSettle();
    }
    expect(rollOf().voiceId, voiceBefore);
  });

  testWidgets('grain is the frame\'s own — no user controls for it anywhere', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF667788))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    // objects bake their surface grain in; nothing to toggle
    expect(find.text('GRAIN'), findsNothing);
    expect(find.text('WEAK'), findsNothing);
    expect(find.text('STRONG'), findsNothing);

    // and it isn't carried while the canvas is live: a full-sheet overlay blend
    // on every drag frame is what made placing a photo feel heavy
    expect(find.byType(GrainOverlay), findsNothing);
    expect(find.text('The paper grain goes on when you save.'), findsOneWidget);

    // ...but it must be there for the frame that gets rasterised, or saving
    // would quietly hand back a sheet with no tooth at all
    final desktop = Platform.isLinux || Platform.isMacOS || Platform.isWindows;
    // KataPillButton renders its label in caps when display is on
    final save = find.text(desktop ? 'SAVE PNG' : 'SHARE');
    await t.ensureVisible(save);
    await t.pumpAndSettle();
    await t.tap(save);
    await t.pump();
    // two passes: the ground's tooth, and the same tooth through the ink
    expect(find.byType(GrainOverlay), findsNWidgets(2));
  });

  testWidgets('the canvas paints grain when it is asked to — that is the export frame', (t) async {
    Widget canvas({required bool grain}) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 400,
                child: ComposeCanvasView(
                  canvasSize: const Size(300, 400),
                  grain: grain,
                  layers: const [
                    ComposeSurface(ColoredBox(color: Color(0xFFFBFAF6))),
                    ComposeGrainSheet(GrainSpec(strength: GrainStrength.weak)),
                  ],
                  photo: const SizedBox.shrink(),
                  textOf: (_) => '',
                  dragOf: (_) => Offset.zero,
                  onTapText: (_) {},
                  onDragText: (_, _) {},
                ),
              ),
            ),
          ),
        );

    await t.pumpWidget(canvas(grain: false));
    expect(find.byType(GrainOverlay), findsNothing);

    await t.pumpWidget(canvas(grain: true));
    expect(find.byType(GrainOverlay), findsOneWidget);
  });

  testWidgets('selecting a slot opens the panel field; the print is never typed on', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF884422))))!;
    await _pump(t, WakuScreen(initialPhoto: photo, initialObject: const _LooseObject()));
    // nothing selected: no field
    expect(_field, findsNothing);
    // one tap on the slot selects it and the panel takes over
    await t.tap(find.text('ADD A LINE'));
    await t.pumpAndSettle();
    expect(_field, findsOneWidget);
    expect(find.text('CLEAR LINE'), findsOneWidget);
    await t.enterText(_field, 'monsoon');
    await t.pumpAndSettle();
    // it lands on the print as you type — no editor sitting on the sheet
    expect(_onPrint('MONSOON'), findsOneWidget);
    expect(find.byKey(const ValueKey('slot-editor')), findsNothing);

    // select the photo: placement-only controls, no look controls
    await t.tap(find.byType(InteractiveViewer));
    await t.pumpAndSettle();
    expect(_field, findsNothing);
    expect(find.text('STRAIGHTEN'), findsOneWidget);
    expect(find.text('FLIP'), findsOneWidget);
    expect(find.text('RESET'), findsOneWidget);
    expect(find.text('Exposure'), findsNothing); // the look stayed in the camera
  });

  testWidgets('text capacity is the slot\'s: input clamps at maxChars', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF446688))))!;
    await _pump(t, WakuScreen(initialPhoto: photo, initialObject: const _LooseObject()));
    await t.tap(find.text('ADD A LINE'));
    await t.pumpAndSettle();
    await t.enterText(_field, 'x' * 200);
    final field = t.widget<TextField>(_field);
    expect(field.controller!.text.length, 56);
    expect(field.maxLines, 2);
  });

  testWidgets('a rigid object grants no handles: the stamp cannot be restyled', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF665544))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    // the stamp's country line is still yours to write
    await t.tap(find.text('KATA'));
    await t.pumpAndSettle();
    await t.enterText(_field, 'bombay');
    await t.pumpAndSettle();
    expect(_onPrint('BOMBAY'), findsOneWidget);
    // ...but nothing about how it is set is the user's to move
    expect(find.byKey(const ValueKey('slot-size')), findsNothing);
    expect(find.byKey(const ValueKey('slot-tilt')), findsNothing);
    expect(find.byKey(const ValueKey('slot-grip')), findsNothing);
  });

  testWidgets('size and tilt are panel controls, not handles on the print', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF775533))))!;
    await _pump(t, WakuScreen(initialPhoto: photo, initialObject: const _LooseObject()));
    // type a line into the panel; the slot stays selected
    await t.tap(find.text('ADD A LINE'));
    await t.pumpAndSettle();
    await t.enterText(_field, 'chai break');
    await t.pumpAndSettle();

    // nothing to grab on the sheet itself beyond the grip that places the line
    expect(find.byKey(const ValueKey('slot-scale')), findsNothing);
    expect(find.byKey(const ValueKey('slot-rotate')), findsNothing);

    double fontSize() => t.widget<Text>(_onPrint('CHAI BREAK')).style!.fontSize!;
    final before = fontSize();
    final size = find.byKey(const ValueKey('slot-size'));
    await t.ensureVisible(size);
    await t.pumpAndSettle();
    await t.drag(size, const Offset(60, 0)); // slide it right: bigger type
    await t.pumpAndSettle();
    expect(fontSize(), greaterThan(before));

    // the tilt slider reads out in degrees and snaps level near the middle
    final tilt = find.byKey(const ValueKey('slot-tilt'));
    await t.ensureVisible(tilt);
    await t.pumpAndSettle();
    await t.drag(tilt, const Offset(30, 0));
    await t.pumpAndSettle();
    expect(find.textContaining('°'), findsOneWidget);

    // ink: pick the red pen
    await t.tap(find.byKey(const ValueKey('ink-ffb3402b')));
    await t.pumpAndSettle();
    expect(t.widget<Text>(_onPrint('CHAI BREAK')).style!.color, const Color(0xFFB3402B));
    expect(find.text('RESET STYLE'), findsOneWidget);
  });

  testWidgets('a draggable slot moves with a pan', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFFAA5522))))!;
    await _pump(t, WakuScreen(initialPhoto: photo, initialObject: const _LooseObject()));
    await t.tap(find.text('ADD A LINE'));
    await t.pumpAndSettle();
    await t.enterText(_field, 'golden hour');
    await t.pumpAndSettle();
    expect(_onPrint('GOLDEN HOUR'), findsOneWidget);
    // a selected draggable slot carries its grip
    expect(find.byKey(const ValueKey('slot-grip')), findsOneWidget);
    await t.drag(find.byKey(const ValueKey('slot-grip')), const Offset(25, 0));
    await t.pumpAndSettle();

    Offset translationOf() {
      // the slot renders rotate-inside-translate; sum every ancestor Transform
      var dx = 0.0, dy = 0.0;
      for (final tr in t.widgetList<Transform>(find.ancestor(of: _onPrint('GOLDEN HOUR'), matching: find.byType(Transform)))) {
        final v = tr.transform.getTranslation();
        dx += v.x;
        dy += v.y;
      }
      return Offset(dx, dy);
    }

    final before = translationOf();
    await t.drag(_onPrint('GOLDEN HOUR'), const Offset(40, 0));
    await t.pumpAndSettle();
    expect(translationOf().dx, greaterThan(before.dx));
  });

  testWidgets('stickers: added within allowance, selectable, removable', // kit shelved until the drawings match real references
      skip: true, (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF335544))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    // allowance shows on the chips; add both tapes, then the chip is spent
    await t.tap(find.text('TAPE 0/2'));
    await t.pumpAndSettle();
    await t.tap(find.text('TAPE 1/2'));
    await t.pumpAndSettle();
    expect(find.text('TAPE 2/2'), findsOneWidget);
    // the newest tape arrives selected: rotate handle + Remove offered
    expect(find.byKey(const ValueKey('sticker-rotate')), findsOneWidget);
    expect(find.text('REMOVE'), findsOneWidget);
    await t.tap(find.text('REMOVE'));
    await t.pumpAndSettle();
    expect(find.text('TAPE 1/2'), findsOneWidget);
  });

}
