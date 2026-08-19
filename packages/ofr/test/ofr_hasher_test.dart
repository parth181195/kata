import 'package:ofr/ofr.dart';
import 'package:test/test.dart';

const kodachrome = OfrRecipe(v: 1, name: 'Kodachrome 64', sensors: ['X-Trans IV'],
    sourceUrl: 'https://fujixweekly.com/2020/05/27/...', sourceAttribution: 'Fuji X Weekly',
    filmSimulation: 'Classic Chrome', dynamicRange: 'DR400', dRangePriority: 'Off', grainRoughness: 'Weak', grainSize: 'Small',
    colorChromeEffect: 'Weak', colorChromeFxBlue: 'Off', whiteBalance: 'Daylight', whiteBalanceRed: 2, whiteBalanceBlue: -5,
    highlight: -1, shadow: 0.5, color: 2, sharpness: -2, highIsoNr: -4, clarity: 0);

void main() {
  test('canonical JSON: sorted keys, compact, integral doubles as ints', () {
    expect(OfrHasher.canonicalJson({'b': 2.0, 'a': 0.5, 'c': ['x']}), '{"a":0.5,"b":2,"c":["x"]}');
  });
  test('README example hash (v1Sensors)', () {
    expect(OfrHasher.compute(kodachrome), 'ac98f45967554208ac8fd9b485c3b6598beb99f9fd17b941843fff4c0c3ec176');
  });
  test('README example hash (v1SettingsOnly, PR #1)', () {
    expect(OfrHasher.compute(kodachrome, scheme: HashScheme.v1SettingsOnly),
        'b8a167b1a95c0d4aaede28283895407bd11a8b84f96c74521433829c5dcfd565');
  });
  test('name/source do not affect the hash; sensors do (v1Sensors)', () {
    expect(OfrHasher.compute(kodachrome.copyWith(name: 'Other', sourceUrl: 'x')), OfrHasher.compute(kodachrome));
    expect(OfrHasher.compute(kodachrome.copyWith(sensors: ['X-Trans V'])), isNot(OfrHasher.compute(kodachrome)));
  });
}
