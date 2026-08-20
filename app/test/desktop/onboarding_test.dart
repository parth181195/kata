import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:kata/core/auth/auth_repository.dart';
import 'package:kata/core/net/api_client.dart';
import 'package:kata/core/net/token_store.dart';
import 'package:kata/data/local_db.dart';
import 'package:kata/data/recipe_repository.dart';
import 'package:kata/desktop/desktop_onboarding.dart';
import 'package:kata_ui/kata_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('desktop asks the two questions as two pages and saves the answers', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    t.view.physicalSize = const Size(1440, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    final db = KataDb.memory();
    addTearDown(db.close);
    final repo = RecipeRepository(db: db, api: FakeRecipeApi([]));
    await repo.load();
    var done = false;
    final tokens = MemoryTokenStore();
    await tokens.write(TokenKeys.access, 'A1');
    await tokens.write(TokenKeys.refresh, 'R1');
    await tokens.write(TokenKeys.user, jsonEncode(userWith(const {})));
    final adapter = authAdapter(const {});
    final c = ProviderContainer(overrides: [
      recipeRepositoryProvider.overrideWith((_) => repo),
      tokenStoreProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWith((ref) => ApiClient(tokens: tokens, base: 'https://t', adapter: adapter, onSessionLost: () {})),
    ]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: KataTheme.dark(), home: DesktopOnboarding(onDone: () => done = true)),
    ));
    await t.pumpAndSettle();

    // it must stand on its own as a route: no Material ancestor means yellow-underlined text
    expect(find.descendant(of: find.byType(DesktopOnboarding), matching: find.byType(Scaffold)), findsOneWidget);
    expect(find.text('WHICH BODIES DO YOU SHOOT?'), findsOneWidget);
    expect(find.text('STEP 1 OF 2'), findsOneWidget);
    expect(find.textContaining('WHAT ARE YOU AFTER'), findsNothing, reason: 'each question gets its own page');

    await t.enterText(find.byType(TextField).first, 'X-S20');
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(KataListRow, 'X-S20'));
    await t.pumpAndSettle();
    expect(find.textContaining('LIBRARY WILL OPEN ON X-TRANS V'), findsOneWidget, reason: 'it says what it will do');

    // a second body: plenty of people own two, and both sensors should come through
    await t.enterText(find.byType(TextField).first, 'X-T4');
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(KataListRow, 'X-T4'));
    await t.pumpAndSettle();
    expect(find.textContaining('X-TRANS IV · X-TRANS V'), findsOneWidget, reason: 'both generations are named');
    expect(find.text('CONTINUE · 2'), findsOneWidget);

    await t.tap(find.text('CONTINUE · 2'));
    await t.pumpAndSettle();
    expect(find.text('WHAT ARE YOU AFTER?'), findsOneWidget);
    expect(find.text('STEP 2 OF 2'), findsOneWidget);
    expect(find.textContaining('KATAS'), findsWidgets, reason: 'each look shows how many it would give you');
    await t.tap(find.text('BLACK & WHITE'));
    await t.pumpAndSettle();

    await t.tap(find.text('START'));
    await t.pumpAndSettle();
    expect(done, isTrue);
    final prefs = c.read(sessionProvider).valueOrNull!.user.preferences;
    expect(prefs.bodies, ['X-S20', 'X-T4']);
    expect(prefs.sensors, ['X-Trans IV', 'X-Trans V']);
    expect(prefs.onboarded, isTrue);
    expect(prefs.filmSimFamilies, ['mono']);
  });
}
