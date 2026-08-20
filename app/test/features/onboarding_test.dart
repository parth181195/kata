import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/auth/auth_repository.dart';
import 'package:kata/data/recipe_repository.dart';

import '../helpers.dart';

void main() {
  testWidgets('a first sign-in asks the two questions and opens the library on that sensor', (t) async {
    final c = await pumpKata(t, signedIn: true, preferences: const {}); // brand-new account
    expect(find.text('WHICH BODIES DO YOU SHOOT?'), findsOneWidget, reason: 'onboarding comes before the library');

    await t.enterText(find.byType(TextField).first, 'X-S20');
    await t.pumpAndSettle();
    // the search field holds the same text, so target the row itself
    await t.tap(find.widgetWithText(KataListRow, 'X-S20'));
    await t.pumpAndSettle();
    await t.tap(find.text('CONTINUE · 1'));
    await t.pumpAndSettle();

    expect(find.text('WHAT ARE YOU AFTER?'), findsOneWidget);
    expect(find.textContaining('katas'), findsWidgets, reason: 'each look shows a real count');
    await t.tap(find.text('Black & white'));
    await t.pumpAndSettle();
    await t.tap(find.text('CONTINUE'));
    await t.pumpAndSettle();

    expect(find.text("YOU'RE SET"), findsOneWidget);
    expect(find.textContaining('X-Trans V'), findsWidgets);
    await t.tap(find.text('BROWSE THE LIBRARY'));
    await t.pumpAndSettle();

    // the library is open, filtered, and the user is not asked again
    expect(find.text('Search recipes, film sims, authors'), findsOneWidget);
    expect(c.read(libraryFilterProvider).sensors, {'X-Trans V'});
    final prefs = c.read(sessionProvider).valueOrNull!.user.preferences;
    expect(prefs.bodies, ['X-S20']);
    expect(prefs.filmSimFamilies, ['mono']);
    expect(prefs.onboarded, isTrue);
  });

  testWidgets('skipping leaves the library unfiltered and is remembered', (t) async {
    final c = await pumpKata(t, signedIn: true, preferences: const {});
    await t.tap(find.text('Skip'));
    await t.pumpAndSettle();
    expect(find.text('Search recipes, film sims, authors'), findsOneWidget);
    expect(c.read(libraryFilterProvider).sensors, isEmpty);
    expect(c.read(sessionProvider).valueOrNull!.user.preferences.onboarded, isTrue);
  });

  testWidgets('someone who already answered goes straight to the library', (t) async {
    final c = await pumpKata(t, signedIn: true, preferences: {'sensors': ['X-Trans IV'], 'bodies': ['X-T4'], 'onboardedAt': '2026-08-20T10:00:00.000Z'});
    expect(find.text('WHICH BODIES DO YOU SHOOT?'), findsNothing);
    expect(find.text('Search recipes, film sims, authors'), findsOneWidget);
    expect(c.read(libraryFilterProvider).sensors, {'X-Trans IV'});
    // and the seeded filter is visible, so an unexpectedly small library is explainable
    expect(find.text('X-TRANS IV'), findsWidgets);
  });
}
