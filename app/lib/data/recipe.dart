import 'package:ofr/ofr.dart';

enum RecipeSource { seed, imported, camera }

class Recipe {
  const Recipe({required this.id, required this.ofr, this.verified = false, this.imageUrls = const [], this.source = RecipeSource.seed, this.createdAt});
  final String id;
  final OfrRecipe ofr;
  final bool verified;
  final List<String> imageUrls;
  final RecipeSource source;
  final DateTime? createdAt;

  String get name => ofr.name ?? 'Untitled';
  String get hash => ofr.hash ?? OfrHasher.compute(ofr);
  bool get isMono => ofr.isMono;

  Recipe copyWith({OfrRecipe? ofr, bool? verified, List<String>? imageUrls, RecipeSource? source}) => Recipe(
      id: id, ofr: ofr ?? this.ofr, verified: verified ?? this.verified, imageUrls: imageUrls ?? this.imageUrls, source: source ?? this.source, createdAt: createdAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'verified': verified,
        'image_urls': imageUrls,
        'source': source.name,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
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
    );
  }
}
