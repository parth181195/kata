import 'dart:convert';

import 'package:ofr/ofr.dart';
import 'package:test/test.dart';

const kodachromeJson = '''
{
  "v": 1,
  "hash": "a3f2",
  "name": "Kodachrome 64",
  "sensors": ["X-Trans IV"],
  "source_url": "https://fujixweekly.com/2020/05/27/...",
  "source_attribution": "Fuji X Weekly",
  "film_simulation": "Classic Chrome",
  "dynamic_range": "DR400",
  "d_range_priority": "Off",
  "grain_roughness": "Weak",
  "grain_size": "Small",
  "color_chrome_effect": "Weak",
  "color_chrome_fx_blue": "Off",
  "white_balance": "Daylight",
  "white_balance_red": 2,
  "white_balance_blue": -5,
  "highlight": -1,
  "shadow": 0.5,
  "color": 2,
  "sharpness": -2,
  "high_iso_nr": -4,
  "clarity": 0,
  "x_exposure_comp": 0.33
}''';

void main() {
  test('fromJson / toJson round-trip preserves every field incl. unknown extras', () {
    final r = OfrRecipe.fromJson(jsonDecode(kodachromeJson) as Map<String, dynamic>);
    expect(r.v, 1);
    expect(r.name, 'Kodachrome 64');
    expect(r.sensors, ['X-Trans IV']);
    expect(r.filmSimulation, 'Classic Chrome');
    expect(r.dynamicRange, 'DR400');
    expect(r.dRangePriority, 'Off');
    expect(r.grainRoughness, 'Weak');
    expect(r.grainSize, 'Small');
    expect(r.whiteBalance, 'Daylight');
    expect(r.wbKelvin, isNull);
    expect(r.whiteBalanceRed, 2);
    expect(r.whiteBalanceBlue, -5);
    expect(r.highlight, -1);
    expect(r.shadow, 0.5);
    expect(r.color, 2);
    expect(r.highIsoNr, -4);
    expect(r.extra['x_exposure_comp'], 0.33);
    final back = r.toJson();
    expect(back, jsonDecode(kodachromeJson));
  });

  test('toJson omits nulls and keeps a stable key order (envelope first)', () {
    final r = OfrRecipe(v: 1, filmSimulation: 'Acros STD', dRangePriority: 'Off', grainRoughness: 'Off',
        whiteBalance: 'Auto', whiteBalanceRed: 0, whiteBalanceBlue: 0, sharpness: 0, highIsoNr: 0, clarity: 0,
        monochromaticColorWarmCool: 2, monochromaticColorMagentaGreen: -1);
    final j = r.toJson();
    expect(j.containsKey('grain_size'), isFalse);
    expect(j.containsKey('color'), isFalse);
    expect(j.keys.first, 'v');
    expect(j.keys.toList().indexOf('film_simulation') > j.keys.toList().indexOf('v'), isTrue);
  });

  test('settingsJson excludes the envelope', () {
    final r = OfrRecipe.fromJson(jsonDecode(kodachromeJson) as Map<String, dynamic>);
    final s = r.settingsJson();
    for (final k in OfrRecipe.envelopeKeys) {
      expect(s.containsKey(k), isFalse, reason: k);
    }
    expect(s['film_simulation'], 'Classic Chrome');
    expect(s['x_exposure_comp'], 0.33);
  });

  test('enums map names to camera codes', () {
    expect(OfrEnums.filmSimToCode['Classic Chrome'], 11);
    expect(OfrEnums.filmSimToCode['Acros STD'], 12);
    expect(OfrEnums.filmSimToCode['Monochrome Yellow'], 7);
    expect(OfrEnums.filmSimToCode['Nostalgic Negative'], 19);
    expect(OfrEnums.codeToFilmSim[17], 'Classic Negative');
    expect(OfrEnums.isMonoName('Sepia'), isTrue);
    expect(OfrEnums.isMonoName('Velvia'), isFalse);
    expect(OfrEnums.wbToCode['Kelvin'], 0x8007);
    expect(OfrEnums.wbToCode['Auto (ambience priority)'], 0x8021);
    expect(OfrEnums.wbToCode['Custom 2'], 0x8009);
    expect(OfrEnums.codeToWb[0x0004], 'Daylight');
    expect(OfrEnums.sensors, contains('X-Trans V'));
  });
}
