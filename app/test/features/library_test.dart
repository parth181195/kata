import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata_ui/kata_ui.dart';

import 'package:kata/data/recipe_repository.dart';

import '../helpers.dart';

void main() {
  _offlineTests();
  testWidgets('library lists seed recipes, search filters, B&W chip filters', (t) async {
    await pumpKata(t);
    expect(find.text('KODACHROME 64'), findsOneWidget);
    expect(find.text('MONO PUSH'), findsOneWidget);
    expect(find.text('SLIDE FILM'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'koda');
    await t.pumpAndSettle();
    expect(find.text('KODACHROME 64'), findsOneWidget);
    expect(find.text('MONO PUSH'), findsNothing);

    await t.enterText(find.byType(TextField), '');
    await t.tap(find.text('B&W'));
    await t.pumpAndSettle();
    expect(find.text('MONO PUSH'), findsOneWidget);
    expect(find.text('KODACHROME 64'), findsNothing);
  });

  testWidgets('tapping a card opens detail with spec grid and write button', (t) async {
    await pumpKata(t);
    await t.tap(find.text('KODACHROME 64'));
    await t.pumpAndSettle();
    expect(find.text('CLASSIC CHROME'), findsWidgets);
    expect(find.text('Q-MENU ORDER'), findsOneWidget);
    expect(find.text('WRITE TO CAMERA'), findsOneWidget);
    expect(find.text('NO CAMERA'), findsOneWidget);
    expect(find.text('HIGH ISO NR'), findsOneWidget);
  });
}

void _offlineTests() {
  testWidgets('offline → banner with RETRY; retry syncs once the network is back', (t) async {
    final api = FakeRecipeApi.fromSeed(seedJson)..failNetwork = true;
    final c = await pumpKata(t, api: api);
    expect(find.text('Offline — showing cached library'), findsOneWidget);
    expect(find.text('NOTHING CACHED YET'), findsOneWidget); // empty cache + offline → dedicated empty state
    api.failNetwork = false;
    await t.tap(find.text('RETRY'));
    await t.pumpAndSettle();
    expect(find.text('Offline — showing cached library'), findsNothing);
    expect(c.read(recipeRepositoryProvider).all.length, 3);
    expect(find.text('KODACHROME 64'), findsOneWidget);
  });

  testWidgets('first sync with an empty cache shows the syncing skeletons, then the list', (t) async {
    final api = FakeRecipeApi.fromSeed(seedJson)..delay = const Duration(seconds: 2);
    await pumpKata(t, api: api, awaitSync: false);
    expect(find.text('SYNCING LIBRARY'), findsOneWidget);
    expect(find.byType(KataSkeletonCard), findsNWidgets(3));
    await t.pump(const Duration(seconds: 3));
    await t.pumpAndSettle();
    expect(find.text('SYNCING LIBRARY'), findsNothing);
    expect(find.text('KODACHROME 64'), findsOneWidget);
  });

  testWidgets('pull to refresh calls sync', (t) async {
    final api = FakeRecipeApi.fromSeed(seedJson);
    await pumpKata(t, api: api);
    final before = api.calls;
    await t.fling(find.text('KODACHROME 64'), const Offset(0, 400), 1000);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(api.calls, greaterThan(before));
  });
}
