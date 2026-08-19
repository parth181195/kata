import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ofr/ofr.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recipe.dart';

enum LibrarySort { newest, popular, az }

class LibraryFilter {
  const LibraryFilter({this.query = '', this.sensor, this.filmSim, this.mono, this.verifiedOnly = false, this.sort = LibrarySort.newest});
  final String query;
  final String? sensor;
  final String? filmSim;
  final bool? mono;
  final bool verifiedOnly;
  final LibrarySort sort;
  LibraryFilter copyWith({
    String? query,
    String? sensor,
    bool clearSensor = false,
    String? filmSim,
    bool clearFilmSim = false,
    bool? mono,
    bool clearMono = false,
    bool? verifiedOnly,
    LibrarySort? sort,
  }) =>
      LibraryFilter(
        query: query ?? this.query,
        sensor: clearSensor ? null : (sensor ?? this.sensor),
        filmSim: clearFilmSim ? null : (filmSim ?? this.filmSim),
        mono: clearMono ? null : (mono ?? this.mono),
        verifiedOnly: verifiedOnly ?? this.verifiedOnly,
        sort: sort ?? this.sort,
      );
  bool get isEmpty => query.isEmpty && sensor == null && filmSim == null && mono == null && !verifiedOnly;
}

/// Seed recipes from assets + user data (favourites, imported/camera recipes) in SharedPreferences.
class LocalLibrary {
  LocalLibrary(this._prefs, {AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  final SharedPreferences _prefs;
  final AssetBundle _bundle;
  static const seedAsset = 'assets/recipes/seed.json';
  static const _kFav = 'kata.favourites';
  static const _kMine = 'kata.mine';

  final List<Recipe> _seed = [];
  final List<Recipe> _mine = [];
  final Set<String> _fav = {};

  Future<void> load() async {
    _seed.clear();
    final raw = jsonDecode(await _bundle.loadString(seedAsset)) as Map<String, dynamic>;
    for (final j in (raw['recipes'] as List)) {
      _seed.add(Recipe.fromJson(j as Map<String, dynamic>));
    }
    _mine
      ..clear()
      ..addAll((_prefs.getStringList(_kMine) ?? []).map((s) => Recipe.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    _fav
      ..clear()
      ..addAll(_prefs.getStringList(_kFav) ?? []);
  }

  List<Recipe> get all => [..._mine, ..._seed];
  List<Recipe> get mine => List.unmodifiable(_mine);
  Set<String> get favourites => Set.unmodifiable(_fav);
  Recipe? byId(String id) => all.where((r) => r.id == id).firstOrNull;
  Recipe? byHash(String hash) => all.where((r) => r.hash == hash).firstOrNull;

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
        out.sort((a, b) => (b.verified ? 1 : 0) - (a.verified ? 1 : 0));
      case LibrarySort.newest:
        out.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    }
    return out;
  }

  Future<void> toggleFavourite(String id) async {
    if (!_fav.remove(id)) _fav.add(id);
    await _prefs.setStringList(_kFav, _fav.toList());
  }

  Future<Recipe> addImported(OfrRecipe ofr, {RecipeSource source = RecipeSource.imported}) async {
    final withHash = ofr.hash == null ? ofr.copyWith(hash: OfrHasher.compute(ofr)) : ofr;
    final r = Recipe(id: '${source.name}-${DateTime.now().microsecondsSinceEpoch}', ofr: withHash, source: source, createdAt: DateTime.now());
    _mine.insert(0, r);
    await _persistMine();
    return r;
  }

  Future<void> remove(String id) async {
    _mine.removeWhere((r) => r.id == id);
    _fav.remove(id);
    await _persistMine();
    await _prefs.setStringList(_kFav, _fav.toList());
  }

  Future<void> _persistMine() => _prefs.setStringList(_kMine, _mine.map((r) => jsonEncode(r.toJson())).toList());
}

// ---------------------------------------------------------------- providers

final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('override in main'));

class LocalLibraryNotifier extends ChangeNotifier {
  LocalLibraryNotifier(this.lib);
  final LocalLibrary lib;
  bool loaded = false;
  Future<void> load() async {
    await lib.load();
    loaded = true;
    notifyListeners();
  }

  Future<void> toggleFavourite(String id) async {
    await lib.toggleFavourite(id);
    notifyListeners();
  }

  Future<Recipe> addImported(OfrRecipe ofr, {RecipeSource source = RecipeSource.imported}) async {
    final r = await lib.addImported(ofr, source: source);
    notifyListeners();
    return r;
  }

  Future<void> remove(String id) async {
    await lib.remove(id);
    notifyListeners();
  }
}

final localLibraryProvider = ChangeNotifierProvider<LocalLibraryNotifier>((ref) {
  final n = LocalLibraryNotifier(LocalLibrary(ref.watch(prefsProvider)));
  n.load();
  return n;
});

final libraryFilterProvider = StateProvider<LibraryFilter>((_) => const LibraryFilter());

final filteredRecipesProvider = Provider<List<Recipe>>((ref) {
  final lib = ref.watch(localLibraryProvider);
  final f = ref.watch(libraryFilterProvider);
  return lib.loaded ? lib.lib.where(f) : const [];
});
