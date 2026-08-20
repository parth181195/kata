import 'ofr_enums.dart';
import 'ofr_recipe.dart';

/// Film simulations grouped the way photographers actually ask for them ("something classic",
/// "black and white"), so a picker can offer a handful of choices instead of nineteen sims.
///
/// Deliberately built only from things a recipe carries — there are no genre or mood tags in
/// OFR, and inventing them here would produce filters that match nothing.
class FilmFamily {
  const FilmFamily({required this.id, required this.label, required this.blurb, required this.filmSims});

  final String id;
  final String label;

  /// One line a person can choose from without knowing Fujifilm's naming.
  final String blurb;
  final List<String> filmSims;

  bool matches(OfrRecipe r) => filmSims.contains(r.filmSimulation);

  static const all = <FilmFamily>[
    FilmFamily(
      id: 'classic',
      label: 'Classic',
      blurb: 'Muted, documentary colour — Classic Chrome and friends',
      filmSims: ['Classic Chrome', 'Classic Negative', 'Nostalgic Negative', 'Reala Ace'],
    ),
    FilmFamily(
      id: 'vivid',
      label: 'Vivid',
      blurb: 'Saturated and punchy — slide film',
      filmSims: ['Velvia', 'Astia', 'Provia'],
    ),
    FilmFamily(
      id: 'cinematic',
      label: 'Cinematic',
      blurb: 'Flat, filmic, graded — Eterna',
      filmSims: ['Eterna', 'Eterna Bleach Bypass'],
    ),
    FilmFamily(
      id: 'portrait',
      label: 'Portrait',
      blurb: 'Kind to skin — Pro Neg and Astia',
      filmSims: ['Pro Neg. Std', 'Pro Neg. Hi', 'Astia'],
    ),
    FilmFamily(
      id: 'mono',
      label: 'Black & white',
      blurb: 'Acros, Monochrome and Sepia',
      // kept identical to OfrEnums.monoFilmSims so this and the B&W filter never disagree
      filmSims: [...OfrEnums.monoFilmSims],
    ),
  ];

  static FilmFamily? byId(String id) => all.where((f) => f.id == id).firstOrNull;

  /// Every sim in the given families, for turning a preference into a filter.
  static Set<String> simsFor(Iterable<String> ids) => {
        for (final id in ids)
          if (byId(id) case final f?) ...f.filmSims,
      };
}
