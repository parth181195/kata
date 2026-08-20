import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/local_db.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/data/recipe_repository.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

OfrRecipe _ofr(String name, {int clarity = 0}) => OfrRecipe(
      name: name,
      sensors: const ['X-Trans V'],
      filmSimulation: 'Classic Chrome',
      dynamicRange: 'DR200',
      dRangePriority: 'Off',
      grainRoughness: 'Weak',
      whiteBalance: 'Daylight',
      whiteBalanceRed: 1,
      whiteBalanceBlue: -2,
      highlight: 0,
      shadow: 0,
      color: 0,
      sharpness: 0,
      highIsoNr: -2,
      clarity: clarity,
    );

void main() {
  test('a hidden recipe never reaches the browse feed or Saved, even when cached and favourited', () async {
    final visible = Recipe(id: 'ok-1', ofr: _ofr('Beach Chrome'));
    // the server should not send this at all any more; the client must not trust that
    final hidden = Recipe(id: 'hid-1', ofr: _ofr('Pulled From The Shelf', clarity: 2), hidden: true);
    final api = FakeRecipeApi([visible, hidden]);
    final db = KataDb.memory();
    addTearDown(db.close);
    final repo = RecipeRepository(db: db, api: api);
    await repo.load();
    await repo.sync();

    // browse feed
    final feed = repo.where(const LibraryFilter());
    expect(feed.map((r) => r.id), ['ok-1']);

    // …and it stays out even when someone had already favourited it
    await repo.toggleFavourite('hid-1');
    expect(repo.favourites.contains('hid-1'), isTrue, reason: 'the favourite itself is untouched');
    final saved = repo.all.where((r) => repo.favourites.contains(r.id) && !r.hidden).toList();
    expect(saved, isEmpty, reason: 'Saved reads the raw cache, so it filters hidden itself');

    // searching for it by name finds nothing either
    expect(repo.where(const LibraryFilter(query: 'shelf')), isEmpty);

    // but it is still resolvable by id: the detail route and slot identification need that
    expect(repo.byId('hid-1')?.name, 'Pulled From The Shelf');
  });

  test('my own kata that a curator hid is still mine, and says so', () async {
    final api = FakeRecipeApi([]);
    final db = KataDb.memory();
    addTearDown(db.close);
    final repo = RecipeRepository(db: db, api: api);
    await repo.load();
    final published = await repo.publish(_ofr('My Kata'));
    expect(repo.published.single.hidden, isFalse);

    // a curator hides it; the next sync of /me/recipes brings it back with hidden: true
    api.published[0] = api.published.first.copyWith(hidden: true);
    await repo.sync(); // pulls /me/recipes too
    expect(repo.published.single.id, published.id);
    expect(repo.published.single.hidden, isTrue, reason: 'Mine keeps it — the UI labels it HIDDEN');
    // and it is not in the public feed
    expect(repo.where(const LibraryFilter()).map((r) => r.id), isNot(contains(published.id)));
  });
}
