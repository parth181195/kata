import 'package:ofr/ofr.dart';
import 'package:test/test.dart';

const good = OfrRecipe(filmSimulation: 'Classic Chrome', dynamicRange: 'DR400', dRangePriority: 'Off', grainRoughness: 'Weak',
    grainSize: 'Small', colorChromeEffect: 'Weak', colorChromeFxBlue: 'Off', whiteBalance: 'Daylight', whiteBalanceRed: 2,
    whiteBalanceBlue: -5, highlight: -1, shadow: 0.5, color: 2, sharpness: -2, highIsoNr: -4, clarity: 0, name: 'Kodachrome 64');

List<String> fields(List<OfrIssue> l) => l.map((i) => i.field).toList();

void main() {
  test('valid recipe has no issues', () => expect(OfrValidator.validate(good), isEmpty));

  test('ranges', () {
    final bad = good.copyWith(clarity: 9, whiteBalanceRed: 10, highlight: 4.5, sharpness: -5, highIsoNr: 5);
    final f = fields(OfrValidator.validate(bad));
    expect(f, containsAll(['clarity', 'white_balance_red', 'highlight', 'sharpness', 'high_iso_nr']));
  });

  test('half-step tones only', () {
    expect(fields(OfrValidator.validate(good.copyWith(shadow: 0.3))), contains('shadow'));
    expect(OfrValidator.validate(good.copyWith(shadow: 1.5)), isEmpty);
  });

  test('enum membership', () {
    expect(fields(OfrValidator.validate(good.copyWith(filmSimulation: 'Kodak'))), contains('film_simulation'));
    expect(fields(OfrValidator.validate(good.copyWith(whiteBalance: 'Cloudy'))), contains('white_balance'));
    expect(fields(OfrValidator.validate(good.copyWith(dynamicRange: 'DR800'))), contains('dynamic_range'));
  });

  test('omission rules', () {
    final drp = good.copyWith(dRangePriority: 'Weak');
    expect(fields(OfrValidator.validate(drp)), containsAll(['dynamic_range', 'highlight', 'shadow']));
    expect(fields(OfrValidator.validate(good.copyWith(grainRoughness: 'Off'))), contains('grain_size'));
    final mono = good.copyWith(filmSimulation: 'Acros STD');
    expect(fields(OfrValidator.validate(mono)), containsAll(['color', 'color_chrome_effect', 'color_chrome_fx_blue']));
    expect(fields(OfrValidator.validate(good.copyWith(monochromaticColorWarmCool: 2))), contains('monochromatic_color_warm_cool'));
    expect(fields(OfrValidator.validate(good.copyWith(wbKelvin: 5600))), contains('wb_kelvin'));
    expect(fields(OfrValidator.validate(good.copyWith(whiteBalance: 'Kelvin'))), contains('wb_kelvin'));
    expect(OfrValidator.validate(good.copyWith(whiteBalance: 'Kelvin', wbKelvin: 5600)), isEmpty);
  });

  test('name length and version are warnings/errors', () {
    final issues = OfrValidator.validate(good.copyWith(name: 'x' * 30, v: 2));
    expect(issues.firstWhere((i) => i.field == 'name').severity, OfrSeverity.warning);
    expect(issues.firstWhere((i) => i.field == 'v').severity, OfrSeverity.error);
    expect(OfrValidator.hasErrors(issues), isTrue);
  });
}
