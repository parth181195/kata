import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/grain.dart';
import 'package:kata/core/compose/layers.dart';
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
      // the slot renders rotate-inside-translate; sum every ancestor Transform
      var dx = 0.0, dy = 0.0;
      for (final tr in t.widgetList<Transform>(find.ancestor(of: find.text('GOLDEN HOUR'), matching: find.byType(Transform)))) {
        final v = tr.transform.getTranslation();
        dx += v.x;
        dy += v.y;
      }
      return Offset(dx, dy);
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
                  editingId: null,
                  onTapText: (_) {},
                  onDragText: (_, _) {},
                  editorBuilder: (_, _, _) => const SizedBox.shrink(),
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
    expect(find.text('CLEAR LINE'), findsOneWidget);
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

  testWidgets('text capacity is the slot\'s: input clamps at maxChars', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF446688))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    await t.tap(find.text('ADD A LINE'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('slot-editor')), 'x' * 200);
    final field = t.widget<TextField>(find.byKey(const ValueKey('slot-editor')));
    expect(field.controller!.text.length, 56); // polaroid chin capacity
    expect(field.maxLines, 2);
  });

  testWidgets('size and tilt are panel controls, not handles on the print', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF775533))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    // type a line, close the editor, slot stays selected
    await t.tap(find.text('ADD A LINE'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('slot-editor')), 'chai break');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();

    // nothing to grab on the sheet itself beyond the grip that places the line
    expect(find.byKey(const ValueKey('slot-scale')), findsNothing);
    expect(find.byKey(const ValueKey('slot-rotate')), findsNothing);

    double fontSize() => t.widget<Text>(find.text('CHAI BREAK')).style!.fontSize!;
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
    expect(t.widget<Text>(find.text('CHAI BREAK')).style!.color, const Color(0xFFB3402B));
    expect(find.text('RESET STYLE'), findsOneWidget);
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

  testWidgets('poster frame: fixed credit grid, huge title, nothing draggable', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF554433))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    await t.tap(find.text('POSTER'));
    await t.pumpAndSettle();
    // credit headers are furniture; slots show invitations (no EXIF in test PNG)
    for (final head in ['CAMERA', 'LENS', 'FILM', 'EXPOSURE', 'DATE']) {
      expect(find.text(head), findsWidgets);
    }
    expect(find.text('UNTITLED'), findsWidgets);
    // the one-sheet's own furniture: a tagline over the title, a billing block
    // under the photograph
    expect(find.text('A QUIET WEEK'), findsWidgets);
    expect(find.text('YOUR NAME'), findsWidgets);
    expect(find.text('PHOTOGRAPHED WITH KATA 型'), findsWidgets); // the thumbnail draws it too
    // the grid is the design: dragging the title does not move it
    await t.tap(find.text('UNTITLED').first); // empty slot → editor opens
    await t.pumpAndSettle();
    await t.testTextInput.receiveAction(TextInputAction.done); // close, keep empty
    await t.pumpAndSettle();
    final before = t.getTopLeft(find.text('UNTITLED').first);
    await t.drag(find.text('UNTITLED').first, const Offset(60, 30));
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.text('UNTITLED').first), before);
  });

  testWidgets('a title that sizes itself to the sheet keeps that size while it is typed', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF335544))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    await t.tap(find.text('POSTER'));
    await t.pumpAndSettle();
    await t.tap(find.text('UNTITLED').first);
    await t.pumpAndSettle();

    final editor = find.byKey(const ValueKey('slot-editor'));
    double editorSize() => t.widget<TextField>(editor).style!.fontSize!;
    final short = editorSize();
    // a long title has to shrink; the editor must shrink with it, or you type
    // at one size and the print shows another
    await t.enterText(editor, 'A VERY LONG TITLE INDEED');
    await t.pumpAndSettle();
    final long = editorSize();
    expect(long, lessThan(short));

    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    // and the label picks up exactly where the editor left off
    expect(t.widget<Text>(find.text('A VERY LONG TITLE INDEED')).style!.fontSize, closeTo(long, 0.01));
  });

  testWidgets('words frame: the dictionary grid with its fixed furniture', (t) async {
    final photo = (await t.runAsync(() => _png(const Color(0xFF445566))))!;
    await _pump(t, WakuScreen(initialPhoto: photo));
    await t.tap(find.text('WORDS'));
    await t.pumpAndSettle();
    expect(find.text('Untitled.'), findsWidgets); // lowercase word, case kept
    expect(find.text('[noun]'), findsWidgets);
    expect(find.text('ka\nta.'), findsWidgets); // the boxed mark
    expect(find.text('001'), findsWidgets);
    // title edits keep case
    await t.tap(find.text('Untitled.').first);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('slot-editor')), 'Monsoon.');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(find.text('Monsoon.'), findsWidgets);
    expect(find.text('MONSOON.'), findsNothing);
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
