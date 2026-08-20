import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

/// Turns an OFR recipe into the label/value cells the UI renders (camera Q-menu order).
class RecipeSpecs {
  static String _signed(num? v) {
    if (v == null) return '—';
    final s = v % 1 == 0 ? v.toInt().abs().toString() : v.abs().toString();
    return v > 0 ? '+$s' : (v < 0 ? '−$s' : '0');
  }

  static String grain(OfrRecipe r) => r.grainRoughness == 'Off' ? 'OFF' : '${r.grainRoughness.toUpperCase()}/${r.grainSize == 'Large' ? 'LG' : 'SM'}';
  static String dr(OfrRecipe r) =>
      r.dRangePriority != 'Off' ? 'DRP ${r.dRangePriority.toUpperCase()}' : (r.dynamicRange == 'DR-Auto' ? 'DR Auto' : (r.dynamicRange ?? 'DR100'));
  static String wb(OfrRecipe r) => r.whiteBalance == 'Kelvin' && r.wbKelvin != null ? '${r.wbKelvin}K' : r.whiteBalance;
  static double _t(num? v, num min, num max) => (((v ?? 0) - min) / (max - min)).clamp(0, 1).toDouble();

  static List<SpecItem> items(OfrRecipe r, {bool rulers = true}) {
    final mono = r.isMono;
    return [
      SpecItem('Film Sim', r.filmSimulation.toUpperCase()),
      SpecItem('Dynamic Range', dr(r)),
      SpecItem('Grain', grain(r)),
      if (!mono) SpecItem('Color Chrome', (r.colorChromeEffect ?? 'Off').toUpperCase()),
      if (!mono) SpecItem('CC Blue', (r.colorChromeFxBlue ?? 'Off').toUpperCase()),
      SpecItem('White Balance', wb(r).toUpperCase()),
      SpecItem('WB Shift R/B', '${_signed(r.whiteBalanceRed)} / ${_signed(r.whiteBalanceBlue)}'),
      if (mono) SpecItem('Warm / Cool', _signed(r.monochromaticColorWarmCool ?? 0)),
      if (mono) SpecItem('Magenta / Green', _signed(r.monochromaticColorMagentaGreen ?? 0)),
      SpecItem('Highlight', _signed(r.highlight), rulerT: rulers && r.highlight != null ? _t(r.highlight, -2, 4) : null, rulerMin: '-2', rulerMax: '+4'),
      SpecItem('Shadow', _signed(r.shadow), rulerT: rulers && r.shadow != null ? _t(r.shadow, -2, 4) : null, rulerMin: '-2', rulerMax: '+4'),
      if (!mono) SpecItem('Color', _signed(r.color)),
      SpecItem('Sharpness', _signed(r.sharpness)),
      SpecItem('High ISO NR', _signed(r.highIsoNr)),
      SpecItem('Clarity', _signed(r.clarity)),
      if (r.extra['x_exposure_comp'] != null) SpecItem('Exp. Comp', _signed(r.extra['x_exposure_comp'] as num)),
    ];
  }

  static List<SpecItem> compact(OfrRecipe r) => [
        SpecItem('Highlight', _signed(r.highlight)),
        SpecItem('Shadow', _signed(r.shadow)),
        SpecItem('Grain', grain(r)),
      ];

  static String summary(OfrRecipe r) => '${r.filmSimulation} · ${dr(r)} · ${wb(r)}';

  static ({List<double> heights, List<int> greys}) swatch(OfrRecipe r) => SwatchBars.fromTones(
      highlight: r.highlight ?? 0,
      shadow: r.shadow ?? 0,
      color: r.color ?? (r.monochromaticColorWarmCool ?? 0),
      sharpness: r.sharpness,
      clarity: r.clarity);

  static const _abbr = {
    'Provia': 'PRO', 'Velvia': 'VEL', 'Astia': 'AST', 'Classic Chrome': 'CC', 'Pro Neg. Hi': 'PNH', 'Pro Neg. Std': 'PNS',
    'Classic Negative': 'CN', 'Eterna': 'ETR', 'Eterna Bleach Bypass': 'EBB', 'Nostalgic Negative': 'NN', 'Reala Ace': 'RA',
    'Acros STD': 'ACR', 'Acros Yellow': 'A+Y', 'Acros Red': 'A+R', 'Acros Green': 'A+G', 'Monochrome STD': 'MONO',
    'Monochrome Yellow': 'M+Y', 'Monochrome Red': 'M+R', 'Monochrome Green': 'M+G', 'Sepia': 'SEP',
  };
  static String filmAbbr(OfrRecipe r) => _abbr[r.filmSimulation] ?? '?';
}
