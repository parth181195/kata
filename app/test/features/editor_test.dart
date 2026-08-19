import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/recipe_repository.dart';

import '../helpers.dart';

void main() {
  testWidgets('new kata → name → save draft → appears in Mine as DRAFT → edit → publish → IN REVIEW; fake API has it', (t) async {
    final api = FakeRecipeApi.fromSeed(seedJson);
    final c = await pumpKata(t, initialLocation: '/mine', api: api);
    await t.tap(find.byKey(const ValueKey('nav-2')));
    await t.pumpAndSettle();
    // My recipes segment → empty → "New kata"
    await t.tap(find.text('MY RECIPES'));
    await t.pumpAndSettle();
    expect(find.text('NO RECIPES OF YOURS YET'), findsOneWidget);
    await t.tap(find.text('New kata'));
    await t.pumpAndSettle();
    expect(find.text('NEW KATA'), findsOneWidget);
    // publish disabled without sensors/name? (button enabled; tapping asks for a name)
    await t.enterText(find.widgetWithText(TextField, 'e.g. Kodachrome 64').first, 'Test Kata');
    await t.pump();
    // pick a sensor (chips are at the top)
    await t.tap(find.text('X-TRANS V'));
    await t.pump();
    // first stepper is WB shift R (below the fold): +2
    await t.ensureVisible(find.text('+').first);
    await t.pumpAndSettle();
    await t.tap(find.text('+').first);
    await t.pump();
    await t.tap(find.text('+').first);
    await t.pump();
    expect(find.text('+2'), findsWidgets);
    // save as draft
    await t.tap(find.text('Save draft'));
    await t.pumpAndSettle();
    expect(find.text('DRAFT'), findsOneWidget);
    expect(find.text('TEST KATA'), findsOneWidget);
    final repo = c.read(recipeRepositoryProvider);
    expect(repo.drafts.length, 1);
    expect(repo.drafts.first.ofr.whiteBalanceRed, 2);
    // edit → publish (let the "Saved to Mine" toast clear — it sits over the footer buttons)
    await t.pump(const Duration(seconds: 4));
    await t.pumpAndSettle();
    await t.tap(find.text('Edit · Publish'));
    await t.pumpAndSettle();
    expect(find.text('EDIT KATA'), findsOneWidget);
    await t.tap(find.text('PUBLISH'));
    await t.pumpAndSettle();
    expect(find.text('PUBLISH “TEST KATA”?'), findsOneWidget);
    await t.tap(find.text('PUBLISH').last); // dialog confirm
    await t.pumpAndSettle();
    expect(api.published.length, 1);
    expect(api.published.first.name, 'Test Kata');
    expect(repo.drafts, isEmpty);
    expect(find.text('IN REVIEW'), findsOneWidget);
    expect(find.text('DRAFT'), findsNothing);
  });

  testWidgets('publishing settings that already exist offers to open the existing kata', (t) async {
    final api = FakeRecipeApi.fromSeed(seedJson);
    await pumpKata(t, initialLocation: '/new?from=a', api: api); // duplicate of Kodachrome 64 (id a)
    await t.pumpAndSettle();
    expect(find.text('NEW KATA'), findsOneWidget);
    // name is prefilled "(copy)"; sensors copied → publish → conflict
    await t.tap(find.text('PUBLISH'));
    await t.pumpAndSettle();
    await t.tap(find.text('PUBLISH').last);
    await t.pumpAndSettle();
    expect(find.text('ALREADY IN THE LIBRARY'), findsOneWidget);
    await t.tap(find.text('OPEN'));
    await t.pumpAndSettle();
    expect(find.text('KODACHROME 64'), findsWidgets);
  });

  testWidgets('detail ⋮ → Report sends a reason to the API', (t) async {
    final api = FakeRecipeApi.fromSeed(seedJson);
    await pumpKata(t, initialLocation: '/recipe/a', api: api);
    await t.tap(find.byIcon(Icons.more_vert).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Report'));
    await t.pumpAndSettle();
    await t.tap(find.text('Duplicate of another kata'));
    await t.pumpAndSettle();
    expect(api.reports, [('a', 'Duplicate of another kata')]);
    expect(find.text('Thanks — sent to the curators'), findsOneWidget);
  });
}
