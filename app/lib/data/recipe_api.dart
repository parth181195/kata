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
