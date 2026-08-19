import 'package:ofr/ofr.dart';

enum RecipeSource { seed, imported, camera }

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

class Recipe {
  const Recipe({
    required this.id,
    required this.ofr,
    this.verified = false,
    this.imageUrls = const [],
    this.source = RecipeSource.seed,
    this.createdAt,
    this.favouritesCount = 0,
  });
  final String id;
  final OfrRecipe ofr;
  final bool verified;
  final List<String> imageUrls;
  final RecipeSource source;
  final DateTime? createdAt;
  final int favouritesCount;

  String get name => ofr.name ?? 'Untitled';
  String get hash => ofr.hash ?? OfrHasher.compute(ofr);
  bool get isMono => ofr.isMono;

  Recipe copyWith({OfrRecipe? ofr, bool? verified, List<String>? imageUrls, RecipeSource? source, int? favouritesCount}) => Recipe(
    id: id,
    ofr: ofr ?? this.ofr,
    verified: verified ?? this.verified,
    imageUrls: imageUrls ?? this.imageUrls,
    source: source ?? this.source,
    createdAt: createdAt,
    favouritesCount: favouritesCount ?? this.favouritesCount,
  );

  Map<String, dynamic> toJson() => {
        'id': id,
        'verified': verified,
        'image_urls': imageUrls,
        'source': source.name,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (favouritesCount != 0) 'favourites_count': favouritesCount,
        'ofr': ofr.toJson(),
      };

  factory Recipe.fromJson(Map<String, dynamic> j) {
    var ofr = OfrRecipe.fromJson(j['ofr'] as Map<String, dynamic>);
    if (ofr.hash == null) ofr = ofr.copyWith(hash: OfrHasher.compute(ofr));
    return Recipe(
      id: j['id'] as String,
      ofr: ofr,
      verified: j['verified'] as bool? ?? false,
      imageUrls: (j['image_urls'] as List?)?.cast<String>() ?? const [],
      source: RecipeSource.values.firstWhere((s) => s.name == j['source'], orElse: () => RecipeSource.seed),
      createdAt: j['created_at'] == null ? null : DateTime.tryParse(j['created_at'] as String),
      favouritesCount: (j['favourites_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// From the Kata API `RecipeDto` (camelCase envelope around the OFR json).
  factory Recipe.fromApi(Map<String, dynamic> j) {
    var ofr = OfrRecipe.fromJson(j['ofr'] as Map<String, dynamic>);
    final hash = j['hash'] as String?;
    if (ofr.hash == null) ofr = ofr.copyWith(hash: hash ?? OfrHasher.compute(ofr));
    return Recipe(
      id: j['id'] as String,
      ofr: ofr,
      verified: j['reviewed'] as bool? ?? false,
      imageUrls: (j['imageUrls'] as List?)?.cast<String>() ?? const [],
      source: RecipeSource.seed,
      createdAt: j['createdAt'] == null ? null : DateTime.tryParse(j['createdAt'] as String),
      favouritesCount: (j['favouritesCount'] as num?)?.toInt() ?? 0,
    );
  }
}
