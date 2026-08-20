import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/local_db.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/data/recipe_repository.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

const _imp = OfrRecipe(
    name: 'Imp', filmSimulation: 'Velvia', dRangePriority: 'Off', grainRoughness: 'Off', whiteBalance: 'Auto', whiteBalanceRed: 0, whiteBalanceBlue: 0, sharpness: 0, highIsoNr: 0, clarity: 0);

void main() {
  _stage2();
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
    expect(repo.where(const LibraryFilter(sensors: {'X-Trans V'})).map((r) => r.id), ['b']);
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

void _stage2() {
  late KataDb db;
  late FakeRecipeApi api;
  late RecipeRepository repo;
  setUp(() async {
    db = KataDb.memory();
    api = FakeRecipeApi.fromSeed(seedJson);
    repo = RecipeRepository(db: db, api: api);
    await repo.load();
    await repo.sync();
  });
  tearDown(() => db.close());

  test('favourite on a library recipe is mirrored to the server; offline toggles queue and push on next sync', () async {
    await repo.toggleFavourite('a');
    expect(api.serverFavourites, {'a'});
    expect(repo.pendingFavouriteOps, 0);
    api.failNetwork = true;
    await repo.toggleFavourite('b');
    expect(repo.favourites, {'a', 'b'});
    expect(repo.pendingFavouriteOps, 1);
    // persists across a reload
    final repo2 = RecipeRepository(db: db, api: api);
    await repo2.load();
    await Future<void>.delayed(Duration.zero); // let load()'s background (failing) sync finish
    expect(repo2.pendingFavouriteOps, 1);
    api.failNetwork = false;
    await repo2.sync();
    expect(api.serverFavourites, {'a', 'b'});
    expect(repo2.pendingFavouriteOps, 0);
    // server-side change (another device) is adopted on sync
    api.serverFavourites.remove('a');
    await repo2.sync();
    expect(repo2.favourites, {'b'});
  });

  test('draft favourites stay local (no server op)', () async {
    final d = await repo.addImported(_imp);
    await repo.toggleFavourite(d.id);
    expect(api.serverFavourites, isEmpty);
    expect(repo.favourites, {d.id});
    await repo.sync();
    expect(repo.favourites, {d.id}); // survives the server reconcile
  });

  test('publish a draft → server recipe in mine, draft removed; conflict surfaces; update + unpublish', () async {
    final d = await repo.addImported(_imp);
    expect(repo.mine.map((r) => r.id), [d.id]);
    final pub = await repo.publish(d.ofr, draftId: d.id);
    expect(pub.source, RecipeSource.published);
    expect(repo.drafts, isEmpty);
    expect(repo.mine.map((r) => r.id), [pub.id]);
    expect(repo.byId(pub.id)!.verified, isFalse);
    expect(api.published.length, 1);
    // persisted
    final repo2 = RecipeRepository(db: db, api: api);
    await repo2.load();
    expect(repo2.published.map((r) => r.id), [pub.id]);
    // duplicate settings → conflict with the existing id
    expect(() => repo2.publish(_imp), throwsA(isA<RecipeConflict>().having((c) => c.existingId, 'existingId', pub.id)));
    // edit → still mine, unverified; all() shows it once
    await repo2.sync();
    final upd = await repo2.updatePublished(pub.id, _imp.copyWith(name: 'Imp v2'));
    expect(upd.name, 'Imp v2');
    expect(repo2.all.where((r) => r.id == pub.id).length, 1);
    expect(repo2.all.firstWhere((r) => r.id == pub.id).name, 'Imp v2');
    await repo2.unpublish(pub.id);
    expect(repo2.mine, isEmpty);
    expect(repo2.byId(pub.id), isNull);
    expect(api.published, isEmpty);
  });

  test('report goes to the API', () async {
    await repo.report('a', 'wrong attribution');
    expect(api.reports, [('a', 'wrong attribution')]);
  });
}
