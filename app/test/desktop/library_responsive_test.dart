import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/local_db.dart';
import 'package:kata/data/recipe_repository.dart';
import 'package:kata/desktop/desktop_library.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

const _a = OfrRecipe(
    name: 'Beach Chrome', sensors: ['X-Trans V'], filmSimulation: 'Classic Chrome', dynamicRange: 'DR200',
    dRangePriority: 'Off', grainRoughness: 'Weak', whiteBalance: 'Daylight', whiteBalanceRed: 1, whiteBalanceBlue: -2,
    highlight: 0, shadow: 0, color: 0, sharpness: 0, highIsoNr: -2, clarity: 0);

Future<void> _pump(WidgetTester t, {required Size size}) async {
  t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final db = KataDb.memory();
  addTearDown(db.close);
  final repo = RecipeRepository(db: db, api: FakeRecipeApi([]));
  await repo.load();
  await repo.addImported(_a);

  final c = ProviderContainer(overrides: [recipeRepositoryProvider.overrideWith((_) => repo)]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(theme: KataTheme.dark(), home: const Scaffold(body: DesktopLibrary())),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('wide window keeps the detail pane beside the grid', (t) async {
    await _pump(t, size: const Size(1400, 900));
    expect(find.text('BEACH CHROME'), findsWidgets); // card + pane
    expect(find.text('Open recipe page'), findsOneWidget); // pane action
  });

  testWidgets('small window drops the pane; a tap opens the full recipe view', (t) async {
    await _pump(t, size: const Size(900, 620));
    expect(find.text('Open recipe page'), findsNothing); // no side pane
    await t.tap(find.text('BEACH CHROME'));
    // the card also listens for double-tap, so a single tap only fires after
    // the disambiguation window — pumpAndSettle alone never advances that timer
    await t.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    await t.pumpAndSettle();
    expect(find.text('Q-MENU ORDER'), findsOneWidget); // full-screen recipe page
  });
}
