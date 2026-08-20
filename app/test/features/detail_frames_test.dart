import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

const _base = OfrRecipe(
    name: 'Beach Chrome', sensors: ['X-Trans V'], filmSimulation: 'Classic Chrome', dynamicRange: 'DR200',
    dRangePriority: 'Off', grainRoughness: 'Weak', whiteBalance: 'Daylight', whiteBalanceRed: 1, whiteBalanceBlue: -2,
    highlight: 0, shadow: 0, color: 0, sharpness: 0, highIsoNr: -2, clarity: 0);

Recipe _withPhotos(int n) => Recipe(
      id: 'r-$n',
      ofr: _base.copyWith(name: 'Kata $n', hash: OfrHasher.compute(_base.copyWith(name: 'Kata $n'))),
      imageUrls: [for (var i = 0; i < n; i++) 'https://cdn.example/$n-$i.jpg'],
    );

/// The hero frame plus one per extra photo — and never an empty placeholder.
Future<int> _framesFor(WidgetTester t, int photos) async {
  final r = _withPhotos(photos);
  await pumpKata(t, initialLocation: '/recipe/${r.id}', api: FakeRecipeApi([r]));
  await t.pumpAndSettle();
  expect(find.textContaining('KATA $photos'.toUpperCase()), findsWidgets, reason: 'detail opened');
  return find.byType(FrameSlot).evaluate().length;
}

void main() {
  testWidgets('the photo strip shows one frame per photo, never an empty one', (t) async {
    // 4 photos: hero + a full row of 3
    expect(await _framesFor(t, 4), 4);
  });

  testWidgets('two photos give the hero plus a single frame', (t) async {
    expect(await _framesFor(t, 2), 2);
  });

  testWidgets('a lone photo shows the hero and no strip at all', (t) async {
    expect(await _framesFor(t, 1), 1);
  });

  testWidgets('more than four photos still cap the strip at three', (t) async {
    expect(await _framesFor(t, 6), 4);
  });
}
