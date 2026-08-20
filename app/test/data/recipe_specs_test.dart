import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/recipe_specs.dart';
import 'package:ofr/ofr.dart';

const kodachrome = OfrRecipe(name: 'Kodachrome 64', filmSimulation: 'Classic Chrome', dynamicRange: 'DR400', dRangePriority: 'Off',
    grainRoughness: 'Weak', grainSize: 'Small', colorChromeEffect: 'Weak', colorChromeFxBlue: 'Off', whiteBalance: 'Daylight',
    whiteBalanceRed: 2, whiteBalanceBlue: -5, highlight: -1, shadow: 0.5, color: 2, sharpness: -2, highIsoNr: -4, clarity: 0);
const mono = OfrRecipe(name: 'M', filmSimulation: 'Acros Red', dynamicRange: 'DR200', dRangePriority: 'Off', grainRoughness: 'Strong',
    grainSize: 'Large', whiteBalance: 'Auto', whiteBalanceRed: 2, whiteBalanceBlue: -3, highlight: 2, shadow: 3, sharpness: 2,
    highIsoNr: -2, clarity: -2, monochromaticColorWarmCool: 2, monochromaticColorMagentaGreen: -1);

void main() {
  test('items follow Q-menu order and format values', () {
    final items = RecipeSpecs.items(kodachrome);
    expect(items.map((i) => i.label).toList(), [
      'Film Sim', 'Dynamic Range', 'Grain', 'Color Chrome', 'CC Blue', 'White Balance', 'WB Shift R/B',
      'Highlight', 'Shadow', 'Color', 'Sharpness', 'High ISO NR', 'Clarity',
    ]);
    expect(items[0].value, 'CLASSIC CHROME', reason: 'values are uppercase; the face is the body font now');
    expect(items[0].display, isFalse, reason: 'Doto is for titles, not values people read');
    expect(items[2].value, 'WEAK/SM');
    expect(items[6].value, '+2 / −5');
    expect(items[7].value, '−1');
    expect(items[8].value, '+0.5');
    expect(items[7].rulerT, closeTo((-1 + 2) / 6, 0.001));
  });
  test('mono variant swaps Color/CC for Warm-Cool + Magenta-Green', () {
    final labels = RecipeSpecs.items(mono).map((i) => i.label).toList();
    expect(labels, contains('Warm / Cool'));
    expect(labels, contains('Magenta / Green'));
    expect(labels, isNot(contains('Color')));
    expect(labels, isNot(contains('Color Chrome')));
  });
  test('summary and abbr', () {
    expect(RecipeSpecs.summary(kodachrome), 'Classic Chrome · DR400 · Daylight');
    expect(RecipeSpecs.summary(kodachrome.copyWith(whiteBalance: 'Kelvin', wbKelvin: 5800)), 'Classic Chrome · DR400 · 5800K');
    expect(RecipeSpecs.summary(kodachrome.copyWith(dynamicRange: 'DR-Auto')), 'Classic Chrome · DR Auto · Daylight');
    expect(RecipeSpecs.filmAbbr(kodachrome), 'CC');
    expect(RecipeSpecs.compact(kodachrome).map((i) => i.label).toList(), ['Highlight', 'Shadow', 'Grain']);
  });
}
