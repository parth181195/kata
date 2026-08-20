import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:kata/core/auth/auth_repository.dart';
import 'package:kata/core/net/api_client.dart';
import 'package:kata/core/net/token_store.dart';
import 'package:kata/data/local_db.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/data/recipe_repository.dart';
import 'package:kata/desktop/desktop_editor.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

const _ofr = OfrRecipe(
    name: 'Beach Chrome', sensors: ['X-Trans V'], filmSimulation: 'Classic Chrome', dynamicRange: 'DR200',
    dRangePriority: 'Off', grainRoughness: 'Weak', whiteBalance: 'Daylight', whiteBalanceRed: 1, whiteBalanceBlue: -2,
    highlight: 0, shadow: 0, color: 0, sharpness: 0, highIsoNr: -2, clarity: 0);

Future<(ProviderContainer, FakeRecipeApi, RecipeRepository)> _pump(WidgetTester t, {String? id, String? from, bool signedIn = true}) async {
  t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  t.view.physicalSize = const Size(1440, 1500); // tall enough that the whole field set renders
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final api = FakeRecipeApi([Recipe(id: 'lib-1', ofr: _ofr.copyWith(hash: OfrHasher.compute(_ofr)))]);
  final db = KataDb.memory();
  addTearDown(db.close);
  final repo = RecipeRepository(db: db, api: api);
  await repo.load();
  await repo.sync();
  final tokens = MemoryTokenStore();
  if (signedIn) {
    await tokens.write(TokenKeys.access, 'A1');
    await tokens.write(TokenKeys.refresh, 'R1');
    await tokens.write(TokenKeys.user, jsonEncode(testUser));
  }
  final adapter = authAdapter();
  final c = ProviderContainer(overrides: [
    recipeRepositoryProvider.overrideWith((_) => repo),
    tokenStoreProvider.overrideWithValue(tokens),
    apiClientProvider.overrideWith((ref) => ApiClient(tokens: tokens, base: 'https://t', adapter: adapter, onSessionLost: () {})),
    googleIdTokenProvider.overrideWithValue(FakeGoogle()),
  ]);
  addTearDown(c.dispose);
  await c.read(sessionProvider.future);
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(theme: KataTheme.dark(), home: Scaffold(body: DesktopEditor(id: id, from: from))),
  ));
  await t.pumpAndSettle();
  return (c, api, repo);
}

void main() {
  testWidgets('new kata: fields render, live Kata Code updates, save draft lands in Mine', (t) async {
    final (_, _, repo) = await _pump(t);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('Film simulation'), findsOneWidget);
    expect(find.textContaining('BYTES · LIVE'), findsOneWidget);
    expect(find.text('CLARITY'), findsOneWidget); // steppers uppercase their labels
    expect(find.text('HIGH ISO NR'), findsOneWidget);
    expect(find.text('COMPATIBILITY'), findsOneWidget);

    await t.enterText(find.widgetWithText(TextField, 'e.g. Kodachrome 64'), 'Gym Light');
    await t.pumpAndSettle();
    expect(find.text('GYM LIGHT'), findsOneWidget, reason: 'header follows the name');

    await t.tap(find.text('Save draft'));
    await t.pumpAndSettle();
    expect(repo.mine.length, 1);
    expect(repo.mine.first.name, 'Gym Light');
  });

  testWidgets('duplicate & edit seeds from an existing kata without touching the original', (t) async {
    final (_, _, repo) = await _pump(t, from: 'lib-1');
    expect(find.textContaining('BEACH CHROME (COPY)'), findsOneWidget);
    await t.tap(find.text('Save draft'));
    await t.pumpAndSettle();
    expect(repo.mine.single.ofr.filmSimulation, 'Classic Chrome');
    expect(repo.byId('lib-1')!.name, 'Beach Chrome', reason: 'source recipe untouched');
  });

  testWidgets('publish is blocked until signed in', (t) async {
    await _pump(t, signedIn: false);
    expect(find.text('SIGN IN TO PUBLISH'), findsOneWidget);
    final btn = t.widget<KataPillButton>(find.widgetWithText(KataPillButton, 'PUBLISH'));
    expect(btn.onPressed, isNull);
  });
}
