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

/// Library = API recipes cached in drift + device-local "mine" recipes + favourites.
class RecipeRepository extends ChangeNotifier {
  RecipeRepository({required KataDb db, required RecipeApi api}) : _db = db, _api = api;
  final KataDb _db;
  final RecipeApi _api;
  static const _kLastSync = 'lastSyncedAt';

  bool loaded = false;
  bool syncing = false;
  bool offline = false;
  String? syncError;
  DateTime? lastSyncedAt;

  final List<Recipe> _cached = [];
  final List<Recipe> _mine = [];
  final Set<String> _fav = {};

  List<Recipe> get all => [..._mine, ..._cached];
  List<Recipe> get cached => List.unmodifiable(_cached);
  List<Recipe> get mine => List.unmodifiable(_mine);
  Set<String> get favourites => Set.unmodifiable(_fav);
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
    } on ApiException catch (e) {
      offline = e.isNetwork;
      syncError = e.message;
    } catch (e) {
      syncError = e.toString();
    } finally {
      syncing = false;
      notifyListeners();
    }
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
    if (_fav.remove(id)) {
      await (_db.delete(_db.favourites)..where((f) => f.recipeId.equals(id))).go();
    } else {
      _fav.add(id);
      await _db.into(_db.favourites).insertOnConflictUpdate(FavouritesCompanion.insert(recipeId: id));
    }
    notifyListeners();
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
