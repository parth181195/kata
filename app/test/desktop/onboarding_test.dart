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
  testWidgets('desktop asks both questions on one card and saves the answers', (t) async {
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
      child: MaterialApp(theme: KataTheme.dark(), home: Scaffold(body: DesktopOnboarding(onDone: () => done = true))),
    ));
    await t.pumpAndSettle();

    expect(find.text('SET KATA UP'), findsOneWidget);
    expect(find.textContaining('WHICH BODY'), findsOneWidget);
    expect(find.textContaining('WHAT ARE YOU AFTER'), findsOneWidget, reason: 'one card, not paged steps');

    await t.enterText(find.byType(TextField).first, 'X-S20');
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(KataListRow, 'X-S20'));
    await t.pumpAndSettle();
    expect(find.textContaining('open on X-Trans V'), findsOneWidget, reason: 'it says what it will do');

    await t.tap(find.text('START'));
    await t.pumpAndSettle();
    expect(done, isTrue);
    final prefs = c.read(sessionProvider).valueOrNull!.user.preferences;
    expect(prefs.body, 'X-S20');
    expect(prefs.sensor, 'X-Trans V');
    expect(prefs.onboarded, isTrue);
  });
}
