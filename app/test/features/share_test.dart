import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:kata/features/library/image_viewer.dart';
import 'package:flutter/services.dart';
import 'package:kata/features/share/card_renderer.dart';
import 'package:kata/features/share/card_templates.dart';
import 'package:kata/features/share/share_composer_sheet.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

void main() {
  _viewerNavigation();

  testWidgets('detail ⋮ → Share card: composer with preview, template switch, payload peek, copy', (t) async {
    await pumpKata(t, initialLocation: '/recipe/a');
    await t.tap(find.byIcon(Icons.more_vert).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Share card…'));
    await t.pumpAndSettle();
    expect(find.byType(ShareComposerSheet), findsOneWidget);
    expect(find.text('S1 · RECIPE CARD'), findsOneWidget);
    await t.ensureVisible(find.text('S4 CODE'));
    await t.pumpAndSettle();
    await t.tap(find.text('S4 CODE'));
    await t.pumpAndSettle();
    expect(find.text('S4 · KATA CODE'), findsOneWidget);
    expect(find.text('HOW TO USE'), findsOneWidget);
    await t.ensureVisible(find.text('{ }'));
    await t.pumpAndSettle();
    await t.tap(find.text('{ }'));
    await t.pumpAndSettle();
    final payload = t.widget<Text>(find.byKey(const ValueKey('payload'))).data!;
    expect(payload, startsWith('kata1:CC,DR400'));
    expect(KataCode.decode(payload).recipe.name, 'Kodachrome 64');
    // invert toggles palette without breaking layout
    await t.ensureVisible(find.text('Invert card'));
    await t.pumpAndSettle();
    await t.tap(find.text('Invert card'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('S1 card renders to a PNG', (t) async {
    await t.runAsync(() async {
      final key = GlobalKey();
      final r = FakeRecipeApi.fromSeed(seedJson).recipes.first;
      await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: OffscreenCardHost(boundaryKey: key, spec: ShareSpec(recipe: r, template: ShareTemplate.card, ratio: ShareRatio.r4x5, credit: 'Fuji X Weekly'), scale: 0.5)))));
      await t.pump();
      final png = await CardRenderer(key).toPng(pixelRatio: 2, settle: false);
      expect(png.length, greaterThan(8 * 1024));
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });
  });
}

/// The zoom viewer: a mouse can't swipe, so arrows and the keyboard have to work.
void _viewerNavigation() {
  testWidgets('the photo viewer moves with arrows and the keyboard, not just swipes', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await t.pumpWidget(MaterialApp(
      theme: KataTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () => showImageViewer(c, urls: const ['https://x/1.jpg', 'https://x/2.jpg', 'https://x/3.jpg'], credit: 'Fuji X Weekly'),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget, reason: 'a mouse needs a target to click');

    await t.tap(find.byIcon(Icons.arrow_forward));
    await t.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);

    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    // escape closes it
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.text('2 / 3'), findsNothing);
  });
}
