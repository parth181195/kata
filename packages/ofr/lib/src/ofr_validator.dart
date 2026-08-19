import 'ofr_enums.dart';
import 'ofr_recipe.dart';

enum OfrSeverity { error, warning }

class OfrIssue {
  const OfrIssue(this.field, this.message, {this.severity = OfrSeverity.error});
  final String field;
  final String message;
  final OfrSeverity severity;
  @override
  String toString() => '$field: $message';
}

/// OFR v1 structural validation: enums, ranges, half-steps, omission rules.
class OfrValidator {
  static bool hasErrors(List<OfrIssue> l) => l.any((i) => i.severity == OfrSeverity.error);

  static List<OfrIssue> validate(OfrRecipe r) {
    final out = <OfrIssue>[];
    void err(String f, String m) => out.add(OfrIssue(f, m));
    void warn(String f, String m) => out.add(OfrIssue(f, m, severity: OfrSeverity.warning));
    void range(String f, num? v, num min, num max) {
      if (v != null && (v < min || v > max)) err(f, 'range $min…$max');
    }

    void oneOf(String f, String? v, List<String> allowed, {bool required = false}) {
      if (v == null) {
        if (required) err(f, 'required');
        return;
      }
      if (!allowed.contains(v)) err(f, 'unknown value "$v"');
    }

    void halfStep(String f, num? v) {
      if (v != null && (v * 2) % 1 != 0) err(f, 'whole or half steps only');
    }

    if (r.v != 1) err('v', 'unsupported version ${r.v}');
    if ((r.name ?? '').length > 25) warn('name', 'longer than 25 chars; will be truncated on camera');

    oneOf('film_simulation', r.filmSimulation, OfrEnums.filmSims, required: true);
    for (final s in r.sensors) {
      if (!OfrEnums.sensors.contains(s)) warn('sensors', 'unknown sensor "$s"');
    }
    oneOf('dynamic_range', r.dynamicRange, OfrEnums.dynamicRanges);
    oneOf('d_range_priority', r.dRangePriority, OfrEnums.dRangePriorities, required: true);
    oneOf('grain_roughness', r.grainRoughness, OfrEnums.grainRoughness, required: true);
    oneOf('grain_size', r.grainSize, OfrEnums.grainSizes);
    oneOf('color_chrome_effect', r.colorChromeEffect, OfrEnums.effects);
    oneOf('color_chrome_fx_blue', r.colorChromeFxBlue, OfrEnums.effects);
    oneOf('white_balance', r.whiteBalance, OfrEnums.wbModes, required: true);

    range('wb_kelvin', r.wbKelvin, 2500, 10000);
    range('white_balance_red', r.whiteBalanceRed, -9, 9);
    range('white_balance_blue', r.whiteBalanceBlue, -9, 9);
    range('highlight', r.highlight, -2, 4);
    range('shadow', r.shadow, -2, 4);
    halfStep('highlight', r.highlight);
    halfStep('shadow', r.shadow);
    range('color', r.color, -4, 4);
    range('sharpness', r.sharpness, -4, 4);
    range('high_iso_nr', r.highIsoNr, -4, 4);
    range('clarity', r.clarity, -5, 5);
    range('monochromatic_color_warm_cool', r.monochromaticColorWarmCool, -9, 9);
    range('monochromatic_color_magenta_green', r.monochromaticColorMagentaGreen, -9, 9);

    // omission rules
    final drpOn = r.dRangePriority != 'Off';
    if (drpOn) {
      if (r.dynamicRange != null) err('dynamic_range', 'omit when d_range_priority is not Off');
      if (r.highlight != null) err('highlight', 'omit when d_range_priority is not Off');
      if (r.shadow != null) err('shadow', 'omit when d_range_priority is not Off');
    }
    if (r.grainRoughness == 'Off' && r.grainSize != null) err('grain_size', 'omit when grain_roughness is Off');
    if (r.grainRoughness != 'Off' && r.grainSize == null && OfrEnums.grainRoughness.contains(r.grainRoughness)) {
      warn('grain_size', 'missing; will use Small');
    }
    final mono = OfrEnums.isMonoName(r.filmSimulation);
    if (mono) {
      if (r.color != null) err('color', 'omit for monochrome film simulations');
      if (r.colorChromeEffect != null) err('color_chrome_effect', 'omit for monochrome film simulations');
      if (r.colorChromeFxBlue != null) err('color_chrome_fx_blue', 'omit for monochrome film simulations');
    } else {
      if (r.monochromaticColorWarmCool != null) err('monochromatic_color_warm_cool', 'only for monochrome film simulations');
      if (r.monochromaticColorMagentaGreen != null) {
        err('monochromatic_color_magenta_green', 'only for monochrome film simulations');
      }
    }
    if (r.whiteBalance == 'Kelvin') {
      if (r.wbKelvin == null) err('wb_kelvin', 'required when white_balance is Kelvin');
    } else if (r.wbKelvin != null) {
      err('wb_kelvin', 'omit unless white_balance is Kelvin');
    }
    return out;
  }
}
