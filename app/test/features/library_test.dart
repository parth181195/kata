import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata_ui/kata_ui.dart';

import 'package:kata/data/recipe_repository.dart';
import 'package:kata/features/library/recipe_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  _offlineTests();
  _layoutTests();
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

  testWidgets('a rejected sync with an empty cache says so, not "no katas match"', (t) async {
    final api = FakeRecipeApi.fromSeed(seedJson)..failStatus = 400;
    final c = await pumpKata(t, api: api);
    expect(find.text('COULDN’T LOAD THE LIBRARY'), findsOneWidget);
    expect(find.text('NO KATAS MATCH'), findsNothing);
    api.failStatus = null;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
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

void _layoutTests() {
  testWidgets('layout switcher: all-hero feed default, grid persists', (t) async {
    await pumpKata(t);
    // 6a: hero feed is the default; every card is the hero variant (VERIFIED overlay on photo)
    expect(find.byKey(const ValueKey('library-list')), findsOneWidget);
    expect(find.text('VERIFIED'), findsWidgets);
    await t.tap(find.byKey(const ValueKey('layout-grid')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-grid')), findsOneWidget);
    expect(find.byType(RecipeGridTile), findsWidgets);
    // persisted
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('kata.libraryLayout'), 'grid');
    await t.tap(find.byKey(const ValueKey('layout-hero')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-list')), findsOneWidget);
  });

  testWidgets('detail: tapping the hero opens the image viewer when photos exist', (t) async {
    final api = FakeRecipeApi.fromSeed(seedJson);
    api.recipes[0] = api.recipes[0].copyWith(imageUrls: ['https://cdn.test/a.jpg', 'https://cdn.test/b.jpg']);
    await pumpKata(t, initialLocation: '/recipe/a', api: api);
    await t.tapAt(const Offset(200, 150)); // hero area
    await t.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('viewer-0')), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    await t.pumpAndSettle();
    expect(find.text('1 / 2'), findsNothing);
  });
}
