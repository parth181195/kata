import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/features/share/photo_meta.dart';
import 'package:kata/features/share/share_screen.dart';

import '../helpers.dart';

void main() {
  test('matchKata: the photo\'s film simulation picks the kata; nothing when it has none or no kata uses it', () {
    final all = FakeRecipeApi.fromSeed(seedJson).recipes;
    expect(matchKata(all, const PhotoMeta(filmMode: 'Velvia'))?.name, 'Slide Film');
    expect(matchKata(all, const PhotoMeta(filmMode: 'velvia'))?.name, 'Slide Film');
    expect(matchKata(all, const PhotoMeta(filmMode: 'Classic Chrome'))?.name, 'Kodachrome 64');
    expect(matchKata(all, const PhotoMeta()), isNull);
    expect(matchKata(all, const PhotoMeta(filmMode: 'Nostalgic Neg. Plus Ultra')), isNull);
    expect(matchKata(<Recipe>[], const PhotoMeta(filmMode: 'Velvia')), isNull);
  });
}
