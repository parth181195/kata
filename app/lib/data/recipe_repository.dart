import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofr/ofr.dart';

import '../core/net/api_client.dart';
import 'local_db.dart';
import 'recipe.dart';
import 'recipe_api.dart';

export 'recipe_api.dart' show RecipeConflict, RecipeInvalid;

/// Library = API recipes cached in drift + device-local "mine" recipes + favourites.
class RecipeRepository extends ChangeNotifier {
  RecipeRepository({required KataDb db, required RecipeApi api}) : _db = db, _api = api;
  final KataDb _db;
  final RecipeApi _api;
  static const _kLastSync = 'lastSyncedAt';
  static const _kPublished = 'myPublished';

  bool loaded = false;
  bool syncing = false;
  /// True when the last sync couldn't reach the API: no network, or the API is down (5xx).
  bool offline = false;
  /// True when [offline] is because the device has no connectivity (vs. the server failing).
  bool offlineIsNetwork = false;
  String? syncError;
  DateTime? lastSyncedAt;

  final List<Recipe> _cached = [];
  final List<Recipe> _mine = []; // device-local drafts (imported / camera)
  final List<Recipe> _published = []; // my recipes on the server (from /me/recipes)
  final Set<String> _fav = {};
  final Map<String, bool> _pendingFav = {}; // recipeId → add? (offline toggles awaiting push)

  /// Everything: drafts first, then my published (deduped against the library), then the library.
  List<Recipe> get all {
    final pubIds = _published.map((r) => r.id).toSet();
    return [..._mine, ..._published, ..._cached.where((r) => !pubIds.contains(r.id))];
  }

  List<Recipe> get cached => List.unmodifiable(_cached);
  /// Drafts + my published recipes (what the Mine tab shows).
  List<Recipe> get mine => [..._mine, ..._published];
  List<Recipe> get drafts => List.unmodifiable(_mine);
  List<Recipe> get published => List.unmodifiable(_published);
  Set<String> get favourites => Set.unmodifiable(_fav);
  int get pendingFavouriteOps => _pendingFav.length;
  Recipe? byId(String id) => all.where((r) => r.id == id).firstOrNull;
  Recipe? byHash(String hash) => all.where((r) => r.hash == hash).firstOrNull;

  /// Reads the local db into memory, then kicks off a background [sync].
  Future<void> load() async {
    final cached = await _db.select(_db.cachedRecipes).get();
    _cached
      ..clear()
      ..addAll(cached.map((r) => Recipe.fromJson(jsonDecode(r.body) as Map<String, dynamic>)));
    final mine = await (_db.select(_db.mineRecipes)..orderBy([(m) => OrderingTerm.desc(m.createdAt)])).get();
    _mine
      ..clear()
      ..addAll(mine.map((r) => Recipe.fromJson(jsonDecode(r.body) as Map<String, dynamic>)));
    _fav
      ..clear()
      ..addAll((await _db.select(_db.favourites).get()).map((f) => f.recipeId));
    _pendingFav
      ..clear()
      ..addEntries((await _db.select(_db.pendingFavOps).get()).map((o) => MapEntry(o.recipeId, o.add)));
    final pub = await _db.getMeta(_kPublished);
    _published
      ..clear()
      ..addAll(pub == null ? const <Recipe>[] : (jsonDecode(pub) as List).map((j) => Recipe.fromJson(j as Map<String, dynamic>)));
    final ls = await _db.getMeta(_kLastSync);
    lastSyncedAt = ls == null ? null : DateTime.tryParse(ls);
    loaded = true;
    notifyListeners();
    unawaited(sync());
  }

  Future<void>? _inflight;

  /// Pages through the API, upserts the cache, drops recipes the API no longer returns.
  /// Concurrent calls share the in-flight sync.
  Future<void> sync() => _inflight ??= _sync().whenComplete(() => _inflight = null);

  Future<void> _sync() async {
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      final seen = <String>{};
      final fresh = <Recipe>[];
      String? cursor;
      do {
        final page = await _api.list(cursor: cursor);
        fresh.addAll(page.items);
        seen.addAll(page.items.map((r) => r.id));
        cursor = page.nextCursor;
      } while (cursor != null);
      final now = DateTime.now();
      await _db.transaction(() async {
        await _db.batch((b) {
          b.insertAllOnConflictUpdate(_db.cachedRecipes, [
            for (final r in fresh)
              CachedRecipesCompanion.insert(id: r.id, body: jsonEncode(r.toJson()), createdAt: r.createdAt ?? now, updatedAt: now),
          ]);
        });
        await (_db.delete(_db.cachedRecipes)..where((c) => c.id.isNotIn(seen.toList()))).go();
        await _db.setMeta(_kLastSync, now.toIso8601String());
      });
      _cached
        ..clear()
        ..addAll(fresh);
      lastSyncedAt = now;
      offline = false;
      offlineIsNetwork = false;
      notifyListeners();
      await _syncMine();
    } on ApiException catch (e) {
      offlineIsNetwork = e.isNetwork;
      offline = e.isNetwork || (e.status ?? 0) >= 500;
      syncError = e.message;
    } catch (e) {
      syncError = e.toString();
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// Push queued favourite toggles, adopt the server's favourite set, refresh my published recipes.
  /// Failures here don't flip [offline] (the library itself synced) but are reported via [syncError].
  Future<void> _syncMine() async {
    try {
      for (final e in _pendingFav.entries.toList()) {
        await _api.setFavourite(e.key, e.value);
        _pendingFav.remove(e.key);
        await (_db.delete(_db.pendingFavOps)..where((o) => o.recipeId.equals(e.key))).go();
      }
      final server = await _api.favourites();
      // server wins for ids we have no pending op on; local drafts (non-server ids) keep their favourite
      final localOnly = _fav.where((id) => byId(id)?.isDraft ?? false).toSet();
      _fav
        ..clear()
        ..addAll(server)
        ..addAll(localOnly);
      await _db.transaction(() async {
        await _db.delete(_db.favourites).go();
        await _db.batch((b) => b.insertAll(_db.favourites, [for (final id in _fav) FavouritesCompanion.insert(recipeId: id)]));
      });
      final mine = <Recipe>[];
      String? cursor;
      do {
        final page = await _api.mine(cursor: cursor);
        mine.addAll(page.items);
        cursor = page.nextCursor;
      } while (cursor != null);
      _published
        ..clear()
        ..addAll(mine);
      await _db.setMeta(_kPublished, jsonEncode(mine.map((r) => r.toJson()).toList()));
    } on ApiException catch (e) {
      syncError = e.message;
    } finally {
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- publishing

  /// Publish a local draft (or any recipe's settings) to the community library. Removes the draft on success.
  /// Throws [RecipeConflict] / [RecipeInvalid] / [ApiException].
  Future<Recipe> publish(OfrRecipe ofr, {String? draftId}) async {
    final r = await _api.publish(ofr);
    if (draftId != null) {
      _mine.removeWhere((x) => x.id == draftId);
      await (_db.delete(_db.mineRecipes)..where((m) => m.id.equals(draftId))).go();
      if (_fav.remove(draftId)) {
        await (_db.delete(_db.favourites)..where((f) => f.recipeId.equals(draftId))).go();
      }
    }
    _published.insert(0, r);
    await _db.setMeta(_kPublished, jsonEncode(_published.map((x) => x.toJson()).toList()));
    notifyListeners();
    return r;
  }

  /// Edit one of my published recipes (goes back to the review queue server-side).
  Future<Recipe> updatePublished(String id, OfrRecipe ofr) async {
    final r = await _api.update(id, ofr);
    final i = _published.indexWhere((x) => x.id == id);
    if (i >= 0) {
      _published[i] = r;
    } else {
      _published.insert(0, r);
    }
    final ci = _cached.indexWhere((x) => x.id == id);
    if (ci >= 0) _cached[ci] = r.copyWith(source: RecipeSource.seed);
    await _db.setMeta(_kPublished, jsonEncode(_published.map((x) => x.toJson()).toList()));
    notifyListeners();
    return r;
  }

  Future<void> unpublish(String id) async {
    await _api.delete(id);
    _published.removeWhere((x) => x.id == id);
    _cached.removeWhere((x) => x.id == id);
    await (_db.delete(_db.cachedRecipes)..where((c) => c.id.equals(id))).go();
    await _db.setMeta(_kPublished, jsonEncode(_published.map((x) => x.toJson()).toList()));
    notifyListeners();
  }

  /// Save an edited draft in place (local only).
  Future<Recipe> updateDraft(String id, OfrRecipe ofr) async {
    final i = _mine.indexWhere((x) => x.id == id);
    if (i < 0) throw StateError('draft $id not found');
    final withHash = ofr.copyWith(hash: OfrHasher.compute(ofr));
    final r = _mine[i].copyWith(ofr: withHash);
    _mine[i] = r;
    await (_db.update(_db.mineRecipes)..where((m) => m.id.equals(id))).write(MineRecipesCompanion(body: Value(jsonEncode(r.toJson()))));
    notifyListeners();
    return r;
  }

  Future<void> report(String id, String reason) => _api.report(id, reason);

  /// Fire-and-forget: failures are irrelevant to the user.
  Future<void> reportCamera({required String model, required String firmware, required int pid, required int slots, required int props}) async {
    try {
      await _api.reportCamera({'model': model, 'firmware': firmware, 'pid': pid, 'slots': slots, 'props': props});
    } catch (_) {}
  }

  List<Recipe> where(LibraryFilter f) {
    final q = f.query.trim().toLowerCase();
    final out = all.where((r) {
      if (f.verifiedOnly && !r.verified) return false;
      if (f.mono != null && r.isMono != f.mono) return false;
      if (f.filmSim != null && r.ofr.filmSimulation != f.filmSim) return false;
      if (f.sensor != null && !r.ofr.sensors.contains(f.sensor)) return false;
      if (q.isNotEmpty) {
        final hay = '${r.name} ${r.ofr.filmSimulation} ${r.ofr.sourceAttribution ?? ''}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    switch (f.sort) {
      case LibrarySort.az:
        out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case LibrarySort.popular:
        out.sort((a, b) {
          final c = b.favouritesCount.compareTo(a.favouritesCount);
          return c != 0 ? c : (b.verified ? 1 : 0) - (a.verified ? 1 : 0);
        });
      case LibrarySort.newest:
        out.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    }
    return out;
  }

  Future<void> toggleFavourite(String id) async {
    final on = !_fav.remove(id);
    if (on) {
      _fav.add(id);
      await _db.into(_db.favourites).insertOnConflictUpdate(FavouritesCompanion.insert(recipeId: id));
    } else {
      await (_db.delete(_db.favourites)..where((f) => f.recipeId.equals(id))).go();
    }
    notifyListeners();
    // drafts live only on this device; everything else is mirrored to the server (queued if offline)
    if (byId(id)?.isDraft ?? false) return;
    _pendingFav[id] = on;
    await _db.into(_db.pendingFavOps).insertOnConflictUpdate(PendingFavOpsCompanion.insert(recipeId: id, add: on));
    try {
      await _api.setFavourite(id, on);
      _pendingFav.remove(id);
      await (_db.delete(_db.pendingFavOps)..where((o) => o.recipeId.equals(id))).go();
    } on ApiException {
      // stays queued; pushed by the next sync
    }
  }

  Future<Recipe> addImported(OfrRecipe ofr, {RecipeSource source = RecipeSource.imported}) async {
    final withHash = ofr.hash == null ? ofr.copyWith(hash: OfrHasher.compute(ofr)) : ofr;
    final now = DateTime.now();
    final r = Recipe(id: '${source.name}-${now.microsecondsSinceEpoch}', ofr: withHash, source: source, createdAt: now);
    _mine.insert(0, r);
    await _db.into(_db.mineRecipes).insert(MineRecipesCompanion.insert(id: r.id, body: jsonEncode(r.toJson()), source: source.name, createdAt: now));
    notifyListeners();
    return r;
  }

  Future<void> remove(String id) async {
    _mine.removeWhere((r) => r.id == id);
    _fav.remove(id);
    await (_db.delete(_db.mineRecipes)..where((m) => m.id.equals(id))).go();
    await (_db.delete(_db.favourites)..where((f) => f.recipeId.equals(id))).go();
    notifyListeners();
  }
}

// ---------------------------------------------------------------- providers

final recipeRepositoryProvider = ChangeNotifierProvider<RecipeRepository>((ref) {
  final repo = RecipeRepository(db: ref.watch(kataDbProvider), api: ref.watch(recipeApiProvider));
  repo.load();
  return repo;
});

final libraryFilterProvider = StateProvider<LibraryFilter>((_) => const LibraryFilter());

final filteredRecipesProvider = Provider<List<Recipe>>((ref) {
  final repo = ref.watch(recipeRepositoryProvider);
  final f = ref.watch(libraryFilterProvider);
  return repo.loaded ? repo.where(f) : const [];
});
