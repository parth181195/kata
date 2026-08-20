import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofr/ofr.dart';

import '../core/net/api_client.dart';
import 'local_db.dart';
import 'recipe.dart';

class RecipePage {
  const RecipePage({required this.items, this.nextCursor});
  final List<Recipe> items;
  final String? nextCursor;
}

/// Publishing a recipe whose settings already exist in the library.
class RecipeConflict implements Exception {
  RecipeConflict(this.existingId);
  final String existingId;
  @override
  String toString() => 'RecipeConflict($existingId)';
}

/// Server-side OFR validation failed.
class RecipeInvalid implements Exception {
  RecipeInvalid(this.issues);
  final List<String> issues;
  @override
  String toString() => 'RecipeInvalid(${issues.join('; ')})';
}

/// One snapshot of a recipe as it was at that version.
class RecipeVersion {
  const RecipeVersion({required this.version, required this.name, required this.ofr, required this.createdAt});
  final int version;
  final String name;
  final OfrRecipe ofr;
  final DateTime createdAt;

  static RecipeVersion fromJson(Map<String, dynamic> j) => RecipeVersion(
        version: (j['version'] as num).toInt(),
        name: j['name'] as String? ?? 'Untitled',
        ofr: OfrRecipe.fromJson(j['ofr'] as Map<String, dynamic>),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class RecipeHistory {
  const RecipeHistory({required this.current, required this.items});
  final int current;
  final List<RecipeVersion> items;
}

abstract class RecipeApi {
  Future<RecipePage> list({String? cursor, int limit = 50});
  Future<Recipe> get(String id);
  // ---- Stage 2
  Future<RecipePage> mine({String? cursor});
  Future<Set<String>> favourites();
  Future<void> setFavourite(String id, bool on);
  Future<Recipe> publish(OfrRecipe ofr);
  Future<Recipe> update(String id, OfrRecipe ofr);
  Future<void> delete(String id);
  Future<void> report(String id, String reason);

  /// Every kept snapshot of one of my recipes (server keeps the last 10), newest first.
  Future<RecipeHistory> versions(String id);

  /// Roll back to [version] — the server writes it as a *new* version, so nothing is lost.
  Future<Recipe> revert(String id, int version);
  /// Remember which body this account connects (model/firmware/slots) — powers the "seen in the wild" matrix.
  Future<void> reportCamera(Map<String, dynamic> body);
}

class HttpRecipeApi implements RecipeApi {
  HttpRecipeApi(this._api);
  final ApiClient _api;

  @override
  Future<RecipePage> list({String? cursor, int limit = 50}) async {
    final j = await _api.getJson('/recipes', query: {'limit': limit, 'cursor': ?cursor});
    return RecipePage(
      items: [for (final r in (j['items'] as List)) Recipe.fromApi(r as Map<String, dynamic>)],
      nextCursor: j['nextCursor'] as String?,
    );
  }

  @override
  Future<Recipe> get(String id) async => Recipe.fromApi(await _api.getJson('/recipes/$id'));

  @override
  Future<RecipePage> mine({String? cursor}) async {
    final j = await _api.getJson('/me/recipes', query: {'limit': 50, 'cursor': ?cursor});
    return RecipePage(
      items: [for (final r in (j['items'] as List)) Recipe.fromApi(r as Map<String, dynamic>, source: RecipeSource.published)],
      nextCursor: j['nextCursor'] as String?,
    );
  }

  @override
  Future<Set<String>> favourites() async => ((await _api.getJson('/me/favourites'))['ids'] as List).cast<String>().toSet();

  @override
  Future<void> setFavourite(String id, bool on) => on ? _api.put('/me/favourites/$id') : _api.delete('/me/favourites/$id');

  @override
  Future<Recipe> publish(OfrRecipe ofr) async {
    try {
      return Recipe.fromApi(await _api.postJson('/recipes', {'ofr': ofr.toJson()}), source: RecipeSource.published);
    } on ApiException catch (e) {
      throw _mapWriteError(e);
    }
  }

  @override
  Future<Recipe> update(String id, OfrRecipe ofr) async {
    try {
      return Recipe.fromApi(await _api.patchJson('/recipes/$id', {'ofr': ofr.toJson()}), source: RecipeSource.published);
    } on ApiException catch (e) {
      throw _mapWriteError(e);
    }
  }

  @override
  Future<void> delete(String id) => _api.delete('/recipes/$id');

  @override
  Future<void> report(String id, String reason) => _api.postJson('/recipes/$id/report', {'reason': reason});

  @override
  Future<RecipeHistory> versions(String id) async {
    final j = await _api.getJson('/recipes/$id/versions');
    return RecipeHistory(
      current: (j['current'] as num).toInt(),
      items: [for (final v in j['items'] as List) RecipeVersion.fromJson(v as Map<String, dynamic>)],
    );
  }

  @override
  Future<Recipe> revert(String id, int version) async =>
      Recipe.fromApi(await _api.postJson('/recipes/$id/revert', {'version': version}));

  @override
  Future<void> reportCamera(Map<String, dynamic> body) => _api.put('/me/cameras', body: body);

  static Object _mapWriteError(ApiException e) {
    final b = e.body;
    if (e.status == 409 && b is Map && b['id'] is String) return RecipeConflict(b['id'] as String);
    if (e.status == 400 && b is Map && b['issues'] is List) {
      return RecipeInvalid([for (final i in b['issues'] as List) if (i is Map) '${i['field']}: ${i['message']}']);
    }
    return e;
  }
}

final recipeApiProvider = Provider<RecipeApi>((ref) => HttpRecipeApi(ref.watch(apiClientProvider)));

final kataDbProvider = Provider<KataDb>((ref) {
  final db = KataDb.open();
  ref.onDispose(db.close);
  return db;
});
