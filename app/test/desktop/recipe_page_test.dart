import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/local_db.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/data/recipe_repository.dart';
import 'package:kata/desktop/desktop_recipe_page.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

const _ofr = OfrRecipe(
    name: 'Beach Chrome', sensors: ['X-Trans V'], filmSimulation: 'Classic Chrome', dynamicRange: 'DR200',
    dRangePriority: 'Off', grainRoughness: 'Weak', whiteBalance: 'Daylight', whiteBalanceRed: 1, whiteBalanceBlue: -2,
    highlight: 0, shadow: 0, color: 0, sharpness: 0, highIsoNr: -2, clarity: 0);

Future<ProviderContainer> _open(WidgetTester t, Recipe r) async {
  t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  t.view.physicalSize = const Size(1600, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final db = KataDb.memory();
  addTearDown(db.close);
  final repo = RecipeRepository(db: db, api: FakeRecipeApi([r]));
  await repo.load();
  await repo.sync();
  final c = ProviderContainer(overrides: [recipeRepositoryProvider.overrideWith((_) => repo)]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      theme: KataTheme.dark(),
      home: Scaffold(body: Builder(builder: (ctx) => TextButton(onPressed: () => showRecipeFullScreen(ctx, r), child: const Text('open')))),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('photos are a carousel: one frame at a time, with dots and a counter', (t) async {
    await _open(t, Recipe(id: 'r1', ofr: _ofr, imageUrls: const ['https://x/1.jpg', 'https://x/2.jpg', 'https://x/3.jpg']));

    expect(find.text('BEACH CHROME'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget, reason: 'a slider, not a scrolling contact sheet');
    expect(find.text('1 / 3'), findsOneWidget);

    // the right arrow advances
    await t.tap(find.byIcon(Icons.arrow_forward));
    await t.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    // and the keyboard does too
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);

    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('a single photo gets no arrows or dots, and none means none', (t) async {
    await _open(t, Recipe(id: 'r2', ofr: _ofr, imageUrls: const ['https://x/1.jpg']));
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsNothing, reason: 'nowhere to go');
    expect(find.text('1 / 1'), findsNothing);
  });

  testWidgets('no photos says so instead of showing an empty frame', (t) async {
    await _open(t, Recipe(id: 'r3', ofr: _ofr));
    expect(find.text('NO SAMPLE FRAMES YET'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('the credit itself is the link to the original write-up', (t) async {
    const withSource = OfrRecipe(
        name: 'Kodachrome 64', sensors: ['X-Trans V'], filmSimulation: 'Classic Chrome', dynamicRange: 'DR400',
        dRangePriority: 'Off', grainRoughness: 'Weak', whiteBalance: 'Daylight', whiteBalanceRed: 2, whiteBalanceBlue: -5,
        sharpness: 0, highIsoNr: -4, clarity: 0,
        sourceAttribution: 'Fuji X Weekly', sourceUrl: 'https://fujixweekly.com/kodachrome-64');
    await _open(t, Recipe(id: 'r4', ofr: withSource));
    expect(find.text('CREDITS '), findsOneWidget);
    expect(find.text('Fuji X Weekly'), findsOneWidget, reason: 'the name carries the link');
    expect(find.text(' ↗'), findsOneWidget, reason: 'and says it leaves the app');
    final credit = t.widget<Text>(find.text('Fuji X Weekly'));
    expect(credit.style?.decoration, TextDecoration.underline);
  });

  testWidgets('a kata without one still credits somebody, without a dead link', (t) async {
    await _open(t, Recipe(id: 'r5', ofr: _ofr));
    expect(find.text('CREDITS '), findsOneWidget);
    expect(find.text(' ↗'), findsNothing);
    final credit = t.widget<Text>(find.text('The community'));
    expect(credit.style?.decoration, isNull);
  });
}
