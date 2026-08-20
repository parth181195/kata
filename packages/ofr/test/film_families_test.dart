import 'package:test/test.dart';
import 'package:ofr/ofr.dart';

void main() {
  test('every family names real film simulations', () {
    for (final e in FilmFamily.all) {
      expect(e.filmSims, isNotEmpty, reason: '${e.id} would match nothing');
      for (final sim in e.filmSims) {
        expect(OfrEnums.filmSims, contains(sim), reason: '${e.id} lists "$sim", which is not a film simulation');
      }
    }
  });

  test('the mono family is exactly what the recipe model calls monochrome', () {
    final mono = FilmFamily.byId('mono')!.filmSims.toSet();
    expect(mono, OfrEnums.monoFilmSims, reason: 'otherwise "B&W" and the B&W chip disagree');
  });

  test('families cover the colour sims worth grouping, and ids are unique', () {
    final ids = FilmFamily.all.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
    // a recipe that is not mono should land in at least one colour family
    final grouped = {for (final f in FilmFamily.all) ...f.filmSims};
    for (final sim in ['Classic Chrome', 'Velvia', 'Eterna', 'Pro Neg. Std', 'Classic Negative']) {
      expect(grouped, contains(sim));
    }
  });

  test('matches() answers whether a recipe belongs to a family', () {
    const acros = OfrRecipe(filmSimulation: 'Acros Red', dRangePriority: 'Off', grainRoughness: 'Off', whiteBalance: 'Auto', whiteBalanceRed: 0, whiteBalanceBlue: 0, sharpness: 0, highIsoNr: 0, clarity: 0);
    expect(FilmFamily.byId('mono')!.matches(acros), isTrue);
    expect(FilmFamily.byId('vivid')!.matches(acros), isFalse);
  });
}
