import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/data/recipe_repository.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

OfrRecipe _ofr({required String name, String sim = 'Classic Chrome', String dr = 'DR200', String grain = 'Weak', String wb = 'Daylight'}) => OfrRecipe(
      name: name,
      sensors: const ['X-Trans V'],
      filmSimulation: sim,
      dynamicRange: dr,
      dRangePriority: 'Off',
      grainRoughness: grain,
      whiteBalance: wb,
      whiteBalanceRed: 0,
      whiteBalanceBlue: 0,
      sharpness: 0,
      highIsoNr: 0,
      clarity: 0,
    );

void main() {
  testWidgets('the sheet filters on the axes the chip row has no room for', (t) async {
    final api = FakeRecipeApi([
      Recipe(id: 'a', ofr: _ofr(name: 'Sunny'), imageUrls: const ['https://x/1.jpg']),
      Recipe(id: 'b', ofr: _ofr(name: 'Grainy', dr: 'DR400', grain: 'Strong')),
      Recipe(id: 'c', ofr: _ofr(name: 'Tungsten', wb: 'Incandescent')),
    ]);
    final c = await pumpKata(t, api: api);

    // chips render uppercase, and the row scrolls: bring the last chip into view first
    await t.drag(find.text('VERIFIED'), const Offset(-500, 0));
    await t.pumpAndSettle();
    await t.tap(find.text('FILTERS'));
    await t.pumpAndSettle();
    expect(find.text('Clear all'), findsNothing, reason: 'nothing to clear on a fresh filter');
    expect(find.textContaining('3 katas match'), findsOneWidget, reason: 'a live count, before you commit');

    await t.tap(find.text('DR400'));
    await t.pumpAndSettle();
    expect(c.read(libraryFilterProvider).dynamicRange, 'DR400');
    expect(find.textContaining('1 kata match'), findsOneWidget);

    // tapping the same value again clears it
    await t.tap(find.text('DR400'));
    await t.pumpAndSettle();
    expect(c.read(libraryFilterProvider).dynamicRange, isNull);

    // "with sample photos" is the one axis that reads the recipe rather than the OFR
    await t.tap(find.text('WITH SAMPLE PHOTOS'));
    await t.pumpAndSettle();
    expect(c.read(recipeRepositoryProvider).where(c.read(libraryFilterProvider)).map((r) => r.id), ['a']);

    await t.tap(find.text('Clear all'));
    await t.pumpAndSettle();
    expect(c.read(libraryFilterProvider).isEmpty, isTrue);

    await t.tap(find.textContaining('SHOW 3 KATAS'));
    await t.pumpAndSettle();
    expect(find.text('Clear all'), findsNothing, reason: 'the sheet closes when you accept it');
  });

  testWidgets('the chip counts how many advanced axes are set', (t) async {
    final c = await pumpKata(t);
    c.read(libraryFilterProvider.notifier).update((f) => f.copyWith(dynamicRange: 'DR400', grain: 'Strong'));
    await t.pumpAndSettle();
    await t.drag(find.text('VERIFIED'), const Offset(-500, 0));
    await t.pumpAndSettle();
    expect(find.text('FILTERS · 2'), findsOneWidget);
  });
}
