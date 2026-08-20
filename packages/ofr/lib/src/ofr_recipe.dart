import 'ofr_enums.dart';

/// Open Fuji Recipe v1 document. Field names mirror the spec; unknown keys kept in [extra].
class OfrRecipe {
  const OfrRecipe({
    this.v = 1,
    this.hash,
    this.name,
    this.sensors = const [],
    this.sourceUrl,
    this.sourceAttribution,
    required this.filmSimulation,
    this.dynamicRange,
    required this.dRangePriority,
    required this.grainRoughness,
    this.grainSize,
    this.colorChromeEffect,
    this.colorChromeFxBlue,
    required this.whiteBalance,
    this.wbKelvin,
    required this.whiteBalanceRed,
    required this.whiteBalanceBlue,
    this.highlight,
    this.shadow,
    this.color,
    required this.sharpness,
    required this.highIsoNr,
    required this.clarity,
    this.monochromaticColorWarmCool,
    this.monochromaticColorMagentaGreen,
    this.extra = const {},
  });

  // envelope
  final int v;
  final String? hash;
  final String? name;
  final List<String> sensors;
  final String? sourceUrl;
  final String? sourceAttribution;
  // settings
  final String filmSimulation;
  final String? dynamicRange;
  final String dRangePriority;
  final String grainRoughness;
  final String? grainSize;
  final String? colorChromeEffect;
  final String? colorChromeFxBlue;
  final String whiteBalance;
  final int? wbKelvin;
  final int whiteBalanceRed;
  final int whiteBalanceBlue;
  final num? highlight;
  final num? shadow;
  final int? color;
  final int sharpness;
  final int highIsoNr;
  final int clarity;
  final int? monochromaticColorWarmCool;
  final int? monochromaticColorMagentaGreen;
  final Map<String, dynamic> extra;

  static const envelopeKeys = {'v', 'hash', 'name', 'sensors', 'source_url', 'source_attribution'};
  static const settingsKeys = {
    'film_simulation', 'dynamic_range', 'd_range_priority', 'grain_roughness', 'grain_size', 'color_chrome_effect',
    'color_chrome_fx_blue', 'white_balance', 'wb_kelvin', 'white_balance_red', 'white_balance_blue', 'highlight', 'shadow',
    'color', 'sharpness', 'high_iso_nr', 'clarity', 'monochromatic_color_warm_cool', 'monochromatic_color_magenta_green',
  };

  factory OfrRecipe.fromJson(Map<String, dynamic> j) {
    int? asInt(dynamic x) => x == null ? null : (x as num).toInt();
    const known = {...envelopeKeys, ...settingsKeys};
    return OfrRecipe(
      v: asInt(j['v']) ?? 1,
      hash: j['hash'] as String?,
      name: j['name'] as String?,
      sensors: (j['sensors'] as List?)?.cast<String>() ?? const [],
      sourceUrl: j['source_url'] as String?,
      sourceAttribution: j['source_attribution'] as String?,
      filmSimulation: (j['film_simulation'] ?? '') as String,
      dynamicRange: j['dynamic_range'] as String?,
      dRangePriority: (j['d_range_priority'] ?? 'Off') as String,
      grainRoughness: (j['grain_roughness'] ?? 'Off') as String,
      grainSize: j['grain_size'] as String?,
      colorChromeEffect: j['color_chrome_effect'] as String?,
      colorChromeFxBlue: j['color_chrome_fx_blue'] as String?,
      whiteBalance: (j['white_balance'] ?? 'Auto') as String,
      wbKelvin: asInt(j['wb_kelvin']),
      whiteBalanceRed: asInt(j['white_balance_red']) ?? 0,
      whiteBalanceBlue: asInt(j['white_balance_blue']) ?? 0,
      highlight: j['highlight'] as num?,
      shadow: j['shadow'] as num?,
      color: asInt(j['color']),
      sharpness: asInt(j['sharpness']) ?? 0,
      highIsoNr: asInt(j['high_iso_nr']) ?? 0,
      clarity: asInt(j['clarity']) ?? 0,
      monochromaticColorWarmCool: asInt(j['monochromatic_color_warm_cool']),
      monochromaticColorMagentaGreen: asInt(j['monochromatic_color_magenta_green']),
      extra: {for (final e in j.entries) if (!known.contains(e.key)) e.key: e.value},
    );
  }

  /// Settings fields only (plus extras), no envelope. Used by hasher/validator.
  Map<String, dynamic> settingsJson() {
    final m = <String, dynamic>{
      'film_simulation': filmSimulation,
      if (dynamicRange != null) 'dynamic_range': dynamicRange,
      'd_range_priority': dRangePriority,
      'grain_roughness': grainRoughness,
      if (grainSize != null) 'grain_size': grainSize,
      if (colorChromeEffect != null) 'color_chrome_effect': colorChromeEffect,
      if (colorChromeFxBlue != null) 'color_chrome_fx_blue': colorChromeFxBlue,
      'white_balance': whiteBalance,
      if (wbKelvin != null) 'wb_kelvin': wbKelvin,
      'white_balance_red': whiteBalanceRed,
      'white_balance_blue': whiteBalanceBlue,
      if (highlight != null) 'highlight': highlight,
      if (shadow != null) 'shadow': shadow,
      if (color != null) 'color': color,
      'sharpness': sharpness,
      'high_iso_nr': highIsoNr,
      'clarity': clarity,
      if (monochromaticColorWarmCool != null) 'monochromatic_color_warm_cool': monochromaticColorWarmCool,
      if (monochromaticColorMagentaGreen != null) 'monochromatic_color_magenta_green': monochromaticColorMagentaGreen,
    };
    m.addAll(extra);
    return m;
  }

  Map<String, dynamic> toJson() => {
        'v': v,
        if (hash != null) 'hash': hash,
        if (name != null) 'name': name,
        if (sensors.isNotEmpty) 'sensors': sensors,
        if (sourceUrl != null) 'source_url': sourceUrl,
        if (sourceAttribution != null) 'source_attribution': sourceAttribution,
        ...settingsJson(),
      };

  bool get isMono => OfrEnums.isMonoName(filmSimulation);

  OfrRecipe copyWith({
    int? v,
    String? hash,
    bool clearHash = false,
    String? name,
    List<String>? sensors,
    String? sourceUrl,
    String? sourceAttribution,
    String? filmSimulation,
    String? dynamicRange,
    bool clearDynamicRange = false,
    String? dRangePriority,
    String? grainRoughness,
    String? grainSize,
    bool clearGrainSize = false,
    String? colorChromeEffect,
    bool clearColorChrome = false,
    String? colorChromeFxBlue,
    String? whiteBalance,
    int? wbKelvin,
    bool clearKelvin = false,
    int? whiteBalanceRed,
    int? whiteBalanceBlue,
    num? highlight,
    bool clearHighlight = false,
    num? shadow,
    bool clearShadow = false,
    int? color,
    bool clearColor = false,
    int? sharpness,
    int? highIsoNr,
    int? clarity,
    int? monochromaticColorWarmCool,
    int? monochromaticColorMagentaGreen,
    bool clearMonochromatic = false,
    Map<String, dynamic>? extra,
  }) =>
      OfrRecipe(
        v: v ?? this.v,
        hash: clearHash ? null : (hash ?? this.hash),
        name: name ?? this.name,
        sensors: sensors ?? this.sensors,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        sourceAttribution: sourceAttribution ?? this.sourceAttribution,
        filmSimulation: filmSimulation ?? this.filmSimulation,
        dynamicRange: clearDynamicRange ? null : (dynamicRange ?? this.dynamicRange),
        dRangePriority: dRangePriority ?? this.dRangePriority,
        grainRoughness: grainRoughness ?? this.grainRoughness,
        grainSize: clearGrainSize ? null : (grainSize ?? this.grainSize),
        colorChromeEffect: clearColorChrome ? null : (colorChromeEffect ?? this.colorChromeEffect),
        colorChromeFxBlue: clearColorChrome ? null : (colorChromeFxBlue ?? this.colorChromeFxBlue),
        whiteBalance: whiteBalance ?? this.whiteBalance,
        wbKelvin: clearKelvin ? null : (wbKelvin ?? this.wbKelvin),
        whiteBalanceRed: whiteBalanceRed ?? this.whiteBalanceRed,
        whiteBalanceBlue: whiteBalanceBlue ?? this.whiteBalanceBlue,
        highlight: clearHighlight ? null : (highlight ?? this.highlight),
        shadow: clearShadow ? null : (shadow ?? this.shadow),
        color: clearColor ? null : (color ?? this.color),
        sharpness: sharpness ?? this.sharpness,
        highIsoNr: highIsoNr ?? this.highIsoNr,
        clarity: clarity ?? this.clarity,
        monochromaticColorWarmCool: clearMonochromatic ? null : (monochromaticColorWarmCool ?? this.monochromaticColorWarmCool),
        monochromaticColorMagentaGreen: clearMonochromatic ? null : (monochromaticColorMagentaGreen ?? this.monochromaticColorMagentaGreen),
        extra: extra ?? this.extra,
      );
}
