import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/net/api_client.dart';
import 'local_db.dart';
import 'recipe.dart';

class RecipePage {
  const RecipePage({required this.items, this.nextCursor});
  final List<Recipe> items;
  final String? nextCursor;
}

abstract class RecipeApi {
  Future<RecipePage> list({String? cursor, int limit = 50});
  Future<Recipe> get(String id);
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
}

final recipeApiProvider = Provider<RecipeApi>((ref) => HttpRecipeApi(ref.watch(apiClientProvider)));

final kataDbProvider = Provider<KataDb>((ref) {
  final db = KataDb.open();
  ref.onDispose(db.close);
  return db;
});
