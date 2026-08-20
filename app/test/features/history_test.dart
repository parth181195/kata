import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/local_db.dart';
import 'package:kata/data/recipe_repository.dart';
import 'package:kata/features/history/version_history_sheet.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

const _base = OfrRecipe(
    name: 'Beach Chrome', sensors: ['X-Trans V'], filmSimulation: 'Classic Chrome', dynamicRange: 'DR200',
    dRangePriority: 'Off', grainRoughness: 'Weak', whiteBalance: 'Daylight', whiteBalanceRed: 1, whiteBalanceBlue: -2,
    highlight: 0, shadow: 0, color: 0, sharpness: 0, highIsoNr: -2, clarity: 0);

void main() {
  testWidgets('history lists earlier versions with what differs, and rolls back', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    t.view.physicalSize = const Size(900, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    final api = FakeRecipeApi([]);
    final db = KataDb.memory();
    addTearDown(db.close);
    final repo = RecipeRepository(db: db, api: api);
    await repo.load();

    // publish, then edit twice → two snapshots on the server
    final v1 = await repo.publish(_base);
    await repo.updatePublished(v1.id, _base.copyWith(clarity: 3));
    final current = await repo.updatePublished(v1.id, _base.copyWith(clarity: 3, shadow: 2));
    expect(api.history[v1.id]!.length, 2);

    final c = ProviderContainer(overrides: [recipeRepositoryProvider.overrideWith((_) => repo)]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: KataTheme.dark(),
        home: Scaffold(
          body: Builder(builder: (ctx) => TextButton(onPressed: () => showVersionHistoryDialog(ctx, current), child: const Text('open'))),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    expect(find.text('VERSION HISTORY'), findsOneWidget);
    expect(find.text('V1'), findsOneWidget);
    expect(find.text('V2'), findsOneWidget);
    // v1 predates both edits (shadow + clarity), v2 only the shadow one
    expect(find.textContaining('DIFFERS IN'), findsNWidgets(2));
    expect(find.textContaining('CLARITY'), findsWidgets);
    expect(find.textContaining('SHADOW'), findsWidgets);

    // rows are newest first, so the last Roll back is v1
    await t.tap(find.text('Roll back').last);
    await t.pumpAndSettle();
    expect(find.text('ROLL BACK TO V1?'), findsOneWidget);
    await t.tap(find.text('ROLL BACK')); // confirm
    await t.pumpAndSettle();

    // rolled back to v1's settings, and the pre-rollback state was itself snapshotted
    expect(repo.published.single.ofr.clarity, 0);
    expect(repo.published.single.ofr.shadow, 0);
    expect(api.history[v1.id]!.length, 3, reason: 'rolling back keeps the version we rolled away from');
  });

  testWidgets('a kata with no edits says so instead of showing an empty list', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final api = FakeRecipeApi([]);
    final db = KataDb.memory();
    addTearDown(db.close);
    final repo = RecipeRepository(db: db, api: api);
    await repo.load();
    final r = await repo.publish(_base);
    final c = ProviderContainer(overrides: [recipeRepositoryProvider.overrideWith((_) => repo)]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: KataTheme.dark(),
        home: Scaffold(body: Builder(builder: (ctx) => TextButton(onPressed: () => showVersionHistoryDialog(ctx, r), child: const Text('open')))),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.textContaining('never been edited'), findsOneWidget);
    expect(find.text('Roll back'), findsNothing);
  });
}
