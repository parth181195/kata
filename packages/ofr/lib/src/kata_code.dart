import 'ofr_enums.dart';
import 'ofr_recipe.dart';

/// Kata Code v1 — the compact, human-readable payload that lives inside the QR on every share card.
///
/// `kata1:` + fixed-order body tokens (omitted = camera default) + `;k=v` meta (percent-encoded, `+` = space).
/// Example: `kata1:CC,DR400,WB5800/+2-3,HL+1,SD-0.5,CO+2,SH+1,NR-4,GR-WS,CCR-S,CCB-W;n=Kodachrome+64;a=Fuji+X+Weekly;v=xt4,xt5`
///
/// Tone tokens are two letters (HL highlight, SD shadow, CO colour, SH sharpness, CL clarity,
/// NR noise reduction) so a card stays readable off paper; the single-letter H/S/C of the
/// first cards still decode.
///
/// Decoding is forward-compatible: unknown tokens are skipped and reported in [KataCodeResult.warnings].
class KataCode {
  static const prefix = 'kata1:';

  static const _filmToCode = <String, String>{
    'Provia': 'PV', 'Velvia': 'VV', 'Astia': 'AS', 'Classic Chrome': 'CC', 'Pro Neg. Hi': 'PH', 'Pro Neg. Std': 'PS',
    'Classic Negative': 'CN', 'Eterna': 'ET', 'Eterna Bleach Bypass': 'EB', 'Nostalgic Negative': 'NN', 'Reala Ace': 'RA',
    'Acros STD': 'AC', 'Acros Yellow': 'ACY', 'Acros Red': 'ACR', 'Acros Green': 'ACG',
    'Monochrome STD': 'MO', 'Monochrome Yellow': 'MOY', 'Monochrome Red': 'MOR', 'Monochrome Green': 'MOG', 'Sepia': 'SP',
  };
  static final _codeToFilm = {for (final e in _filmToCode.entries) e.value: e.key};

  static const _wbToCode = <String, String>{
    'Auto': 'A', 'Auto (white priority)': 'AW', 'Auto (ambience priority)': 'AA', 'Daylight': 'D', 'Shade': 'S', 'Incandescent': 'I',
    'Fluorescent 1': 'F1', 'Fluorescent 2': 'F2', 'Fluorescent 3': 'F3', 'Underwater': 'U', 'Custom 1': 'C1', 'Custom 2': 'C2', 'Custom 3': 'C3',
  };
  static final _codeToWb = {for (final e in _wbToCode.entries) e.value: e.key};

  static const _sensorToCode = <String, String>{
    'X-Trans I': 'xt1', 'X-Trans II': 'xt2', 'X-Trans III': 'xt3', 'X-Trans IV': 'xt4', 'X-Trans V': 'xt5',
    'GFX': 'gfx', 'Bayer': 'bayer', 'EXR-CMOS': 'exr', 'Full Spectrum': 'fs',
  };
  static final _codeToSensor = {for (final e in _sensorToCode.entries) e.value: e.key};

  static const _lvl = {'Off': 'O', 'Weak': 'W', 'Strong': 'S', 'Auto': 'A'};
  static final _lvlBack = {for (final e in _lvl.entries) e.value: e.key};

  /// Is this string a Kata Code (any version prefix `kata<digits>:`)?
  static bool looksLike(String s) => RegExp(r'^\s*kata\d+:').hasMatch(s);

  // ---------------------------------------------------------------- encode

  static String encode(OfrRecipe r, {String? credit}) {
    final b = <String>[];
    b.add(_filmToCode[r.filmSimulation] ?? 'PV');
    if (r.dynamicRange != null) b.add(r.dynamicRange == 'DR-Auto' ? 'DRA' : r.dynamicRange!);
    if (r.dRangePriority != 'Off') b.add('DP-${_lvl[r.dRangePriority] ?? 'A'}');
    final wb = StringBuffer('WB');
    if (r.whiteBalance == 'Kelvin') {
      wb.write(r.wbKelvin ?? 5500);
    } else {
      wb.write(_wbToCode[r.whiteBalance] ?? 'A');
    }
    if (r.whiteBalanceRed != 0 || r.whiteBalanceBlue != 0) wb.write('/${_sgnAlways(r.whiteBalanceRed)}${_sgnAlways(r.whiteBalanceBlue)}');
    b.add(wb.toString());
    void num_(String k, num? v) {
      if (v != null && v != 0) b.add('$k${_sgn(v)}');
    }
    // HL/SD/CO, not H/S/C: a printed card is read by people, and S/SH and C/CL/CCR were
    // only unambiguous to the parser. Old codes still decode — see the aliases below.
    num_('HL', r.highlight);
    num_('SD', r.shadow);
    num_('CO', r.color);
    num_('SH', r.sharpness);
    num_('NR', r.highIsoNr);
    num_('CL', r.clarity);
    if (r.grainRoughness != 'Off') b.add('GR-${_lvl[r.grainRoughness] ?? 'W'}${r.grainSize == 'Large' ? 'L' : (r.grainSize == 'Small' ? 'S' : '')}');
    // explicit Off is kept (the OFR hash distinguishes "Off" from "not stated")
    if (r.colorChromeEffect != null) b.add('CCR-${_lvl[r.colorChromeEffect] ?? 'W'}');
    if (r.colorChromeFxBlue != null) b.add('CCB-${_lvl[r.colorChromeFxBlue] ?? 'W'}');
    num_('MW', r.monochromaticColorWarmCool);
    num_('MM', r.monochromaticColorMagentaGreen);
    final ec = r.extra['x_exposure_comp'];
    if (ec is num && ec != 0) b.add('EC${_sgn(ec)}');

    final meta = <String>[];
    if (r.name != null && r.name!.isNotEmpty) meta.add('n=${_enc(r.name!)}');
    final a = credit ?? r.sourceAttribution;
    if (a != null && a.isNotEmpty) meta.add('a=${_enc(a)}');
    if (r.sensors.isNotEmpty) meta.add('v=${r.sensors.map((s) => _sensorToCode[s] ?? _enc(s)).join(',')}');
    if (r.sourceUrl != null && r.sourceUrl!.isNotEmpty) meta.add('u=${_enc(r.sourceUrl!)}');
    return '$prefix${b.join(',')}${meta.isEmpty ? '' : ';${meta.join(';')}'}';
  }

  // ---------------------------------------------------------------- decode

  static KataCodeResult decode(String input) {
    final s = input.trim();
    final m = RegExp(r'^kata(\d+):(.*)$', dotAll: true).firstMatch(s);
    if (m == null) throw const FormatException('Not a Kata Code (expected a kata1: prefix)');
    final version = int.parse(m.group(1)!);
    final warnings = <String>[];
    if (version != 1) warnings.add('Kata Code v$version — decoding as v1');
    final rest = m.group(2)!.replaceAll(RegExp(r'\s+'), '');
    final semi = rest.indexOf(';');
    final body = semi < 0 ? rest : rest.substring(0, semi);
    final metaStr = semi < 0 ? '' : rest.substring(semi + 1);

    var film = 'Provia';
    String? dr;
    var drp = 'Off';
    var wbMode = 'Auto';
    int? kelvin;
    var wbR = 0, wbB = 0;
    num? highlight, shadow;
    int? color;
    var sharp = 0, nr = 0, clarity = 0;
    var grain = 'Off';
    String? grainSize, ccr, ccb;
    int? mw, mm;
    num? ec;

    int? asInt(String v) => int.tryParse(v);
    num? asNum(String v) => num.tryParse(v);

    for (final tok in body.split(',')) {
      if (tok.isEmpty) continue;
      if (_codeToFilm.containsKey(tok)) {
        film = _codeToFilm[tok]!;
      } else if (tok == 'DRA') {
        dr = 'DR-Auto';
      } else if (RegExp(r'^DR\d+$').hasMatch(tok)) {
        dr = tok;
      } else if (tok.startsWith('DP-')) {
        drp = _lvlBack[tok.substring(3)] ?? 'Off';
      } else if (tok.startsWith('WB')) {
        var w = tok.substring(2);
        final slash = w.indexOf('/');
        if (slash >= 0) {
          final shift = RegExp(r'^([+-]\d+)([+-]\d+)$').firstMatch(w.substring(slash + 1));
          if (shift != null) {
            wbR = int.parse(shift.group(1)!);
            wbB = int.parse(shift.group(2)!);
          } else {
            warnings.add('WB shift "${w.substring(slash + 1)}" not understood');
          }
          w = w.substring(0, slash);
        }
        if (RegExp(r'^\d+$').hasMatch(w)) {
          wbMode = 'Kelvin';
          kelvin = int.parse(w);
        } else {
          wbMode = _codeToWb[w] ?? (() {
            warnings.add('WB "$w" not understood');
            return 'Auto';
          })();
        }
      } else if (tok.startsWith('GR-')) {
        final v = tok.substring(3);
        grain = _lvlBack[v.isEmpty ? 'W' : v[0]] ?? 'Weak';
        if (v.length > 1) grainSize = v[1] == 'L' ? 'Large' : 'Small';
      } else if (tok.startsWith('CCR-')) {
        ccr = _lvlBack[tok.substring(4)] ?? 'Weak';
      } else if (tok.startsWith('CCB-')) {
        ccb = _lvlBack[tok.substring(4)] ?? 'Weak';
      } else {
        final mm2 = RegExp(r'^([A-Z]+)([+-]?[\d.]+)$').firstMatch(tok);
        if (mm2 == null) {
          warnings.add('unknown token "$tok"');
          continue;
        }
        final k = mm2.group(1)!, v = mm2.group(2)!;
        switch (k) {
          case 'HL' || 'H': highlight = asNum(v);
          case 'SD' || 'S': shadow = asNum(v);
          case 'CO' || 'C': color = asInt(v);
          case 'SH': sharp = asInt(v) ?? 0;
          case 'NR': nr = asInt(v) ?? 0;
          case 'CL': clarity = asInt(v) ?? 0;
          case 'MW': mw = asInt(v);
          case 'MM': mm = asInt(v);
          case 'EC': ec = asNum(v);
          default: warnings.add('unknown token "$tok"');
        }
      }
    }

    String? name, credit, url;
    final sensors = <String>[];
    if (metaStr.isNotEmpty) {
      for (final kv in metaStr.split(';')) {
        final eq = kv.indexOf('=');
        if (eq <= 0) continue;
        final k = kv.substring(0, eq), v = _dec(kv.substring(eq + 1));
        switch (k) {
          case 'n': name = v;
          case 'a': credit = v;
          case 'u': url = v;
          case 'v':
            for (final c in v.split(',')) {
              if (c.isEmpty) continue;
              sensors.add(_codeToSensor[c] ?? c);
            }
          default: warnings.add('unknown meta "$k"');
        }
      }
    }

    final mono = OfrEnums.isMonoName(film);
    final recipe = OfrRecipe(
      name: name,
      sensors: sensors,
      sourceUrl: url,
      sourceAttribution: credit,
      filmSimulation: film,
      dynamicRange: dr,
      dRangePriority: drp,
      grainRoughness: grain,
      grainSize: grain == 'Off' ? null : grainSize,
      colorChromeEffect: ccr,
      colorChromeFxBlue: ccb,
      whiteBalance: wbMode,
      wbKelvin: kelvin,
      whiteBalanceRed: wbR,
      whiteBalanceBlue: wbB,
      highlight: highlight ?? 0,
      shadow: shadow ?? 0,
      color: mono ? null : (color ?? 0),
      sharpness: sharp,
      highIsoNr: nr,
      clarity: clarity,
      monochromaticColorWarmCool: mono ? (mw ?? 0) : null,
      monochromaticColorMagentaGreen: mono ? (mm ?? 0) : null,
      extra: ec == null ? const {} : {'x_exposure_comp': ec},
    );
    return KataCodeResult(recipe: recipe, credit: credit, warnings: warnings, version: version);
  }

  // ---------------------------------------------------------------- helpers
  static String _sgn(num v) {
    final s = v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return v > 0 ? '+$s' : s;
  }

  static String _sgnAlways(num v) => v >= 0 ? '+${_sgn(v).replaceFirst('+', '')}' : _sgn(v);

  static String _enc(String s) => Uri.encodeComponent(s).replaceAll('%20', '+').replaceAll('%2C', ',');
  static String _dec(String s) => Uri.decodeComponent(s.replaceAll('+', ' '));
}

class KataCodeResult {
  const KataCodeResult({required this.recipe, this.credit, this.warnings = const [], this.version = 1});
  final OfrRecipe recipe;
  final String? credit;
  final List<String> warnings;
  final int version;
  /// Settings present in the payload (for "n settings decoded").
  int get settingsCount => recipe.toJson().keys.where((k) => !OfrRecipe.envelopeKeys.contains(k)).length;
}
