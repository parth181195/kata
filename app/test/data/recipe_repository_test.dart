import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/local_db.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/data/recipe_repository.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

const _imp = OfrRecipe(
    name: 'Imp', filmSimulation: 'Velvia', dRangePriority: 'Off', grainRoughness: 'Off', whiteBalance: 'Auto', whiteBalanceRed: 0, whiteBalanceBlue: 0, sharpness: 0, highIsoNr: 0, clarity: 0);

void main() {
  late KataDb db;
  late FakeRecipeApi api;
  late RecipeRepository repo;
  setUp(() async {
    db = KataDb.memory();
    api = FakeRecipeApi.fromSeed(seedJson);
    api.pageSize = 2; // force paging
    repo = RecipeRepository(db: db, api: api);
    await repo.load();
    await repo.sync();
  });
  tearDown(() => db.close());

  test('load → sync pages through the API and caches', () async {
    expect(api.calls, greaterThanOrEqualTo(2));
    expect(repo.all.map((r) => r.id), ['a', 'b', 'c']);
    expect(repo.byId('a')!.hash, 'ac98f45967554208ac8fd9b485c3b6598beb99f9fd17b941843fff4c0c3ec176');
    expect(repo.lastSyncedAt, isNotNull);
    expect(repo.offline, isFalse);
    expect((await db.select(db.cachedRecipes).get()).length, 3);
  });

  test('second sync removes ids the API no longer returns', () async {
    api.recipes.removeWhere((r) => r.id == 'b');
    await repo.sync();
    expect(repo.all.map((r) => r.id), ['a', 'c']);
    expect((await db.select(db.cachedRecipes).get()).map((r) => r.id), ['a', 'c']);
  });

  test('network failure → offline, cached data still served (fresh repo on same db)', () async {
    api.failNetwork = true;
    final repo2 = RecipeRepository(db: db, api: api);
    await repo2.load();
    await repo2.sync();
    expect(repo2.offline, isTrue);
    expect(repo2.all.length, 3);
    expect(repo2.lastSyncedAt, isNotNull);
  });

  test('API 5xx → offline (server) but cached data served', () async {
    api.failStatus = 502;
    await repo.sync();
    expect(repo.offline, isTrue);
    expect(repo.offlineIsNetwork, isFalse);
    expect(repo.all.length, 3);
    api.failStatus = null;
    await repo.sync();
    expect(repo.offline, isFalse);
  });

  test('filters and sorts', () {
    expect(repo.where(const LibraryFilter(query: 'koda')).map((r) => r.id), ['a']);
    expect(repo.where(const LibraryFilter(mono: true)).map((r) => r.id), ['b']);
    expect(repo.where(const LibraryFilter(verifiedOnly: true)).map((r) => r.id), ['a', 'c']);
    expect(repo.where(const LibraryFilter(sensor: 'X-Trans V')).map((r) => r.id), ['b']);
    expect(repo.where(const LibraryFilter(sort: LibrarySort.az)).first.id, 'a');
    expect(repo.where(const LibraryFilter(filmSim: 'Velvia')).map((r) => r.id), ['c']);
  });

  test('favourites + imported persist across repositories on the same db', () async {
    await repo.toggleFavourite('a');
    final added = await repo.addImported(_imp);
    final repo2 = RecipeRepository(db: db, api: api);
    await repo2.load();
    expect(repo2.favourites, {'a'});
    expect(repo2.mine.map((r) => r.id), [added.id]);
    expect(repo2.byId(added.id)!.source, RecipeSource.imported);
    expect(repo2.all.length, 4);
    await repo2.remove(added.id);
    expect(repo2.mine, isEmpty);
    final repo3 = RecipeRepository(db: db, api: api);
    await repo3.load();
    expect(repo3.mine, isEmpty);
  });

  test('Recipe.fromApi maps the DTO', () {
    final r = Recipe.fromApi({
      'id': 'x1',
      'ofr': {'v': 1, 'name': 'Api One', 'film_simulation': 'Velvia', 'd_range_priority': 'Off', 'grain_roughness': 'Off', 'white_balance': 'Auto', 'white_balance_red': 0, 'white_balance_blue': 0, 'sharpness': 0, 'high_iso_nr': 0, 'clarity': 0},
      'hash': 'h',
      'reviewed': true,
      'imageUrls': ['https://cdn/x.jpg'],
      'favouritesCount': 7,
      'createdAt': '2026-08-01T00:00:00.000Z',
    });
    expect(r.verified, isTrue);
    expect(r.imageUrls, ['https://cdn/x.jpg']);
    expect(r.favouritesCount, 7);
    expect(r.hash, 'h');
    expect(r.createdAt!.year, 2026);
  });
}
