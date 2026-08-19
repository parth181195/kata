import 'package:ofr/ofr.dart';

import 'fuji/camera_preset.dart';
import 'fuji/fuji_props.dart';

class MappingResult<T> {
  const MappingResult(this.value, this.notes);
  final T value;
  final List<String> notes;
}

/// OFR recipe <-> CameraPreset. Reports (as notes) anything the wire protocol cannot express yet.
class OfrMapper {
  static const _drToInt = {'DR100': 100, 'DR200': 200, 'DR400': 400, 'DR-Auto': kDrAuto};
  static const _intToDr = {100: 'DR100', 200: 'DR200', 400: 'DR400', kDrAuto: 'DR-Auto'};
  static const _effectToInt = {'Off': Effect.off, 'Weak': Effect.weak, 'Strong': Effect.strong};
  static const _intToEffect = {Effect.off: 'Off', Effect.weak: 'Weak', Effect.strong: 'Strong'};

  static MappingResult<CameraPreset> toPreset(OfrRecipe r) {
    final notes = <String>[];
    final mono = OfrEnums.isMonoName(r.filmSimulation);

    var name = r.name ?? '';
    if (name.length > 25) {
      name = name.substring(0, 25);
      notes.add('Name truncated to 25 characters.');
    }

    int? dr = r.dynamicRange == null ? null : _drToInt[r.dynamicRange!];
    if (r.dRangePriority != 'Off') {
      notes.add('D-Range Priority (${r.dRangePriority}) cannot be written over USB yet; DR100 used — set it on the camera.');
      dr = 100;
    }

    int grain;
    if (r.grainRoughness == 'Off') {
      grain = GrainEnum.off;
    } else {
      final large = r.grainSize == 'Large';
      grain = r.grainRoughness == 'Strong'
          ? (large ? GrainEnum.strongLarge : GrainEnum.strongSmall)
          : (large ? GrainEnum.weakLarge : GrainEnum.weakSmall);
    }

    final wb = OfrEnums.wbToCode[r.whiteBalance] ?? WbMode.auto;
    if (wb == WbMode.whitePriority) notes.add('WB "Auto (white priority)" wire value is unverified; check the camera.');
    if (wb == WbMode.custom1 || wb == WbMode.custom2 || wb == WbMode.custom3) {
      notes.add('Custom WB wire values are unverified; check the camera.');
    }

    int x10(num? v) => ((v ?? 0) * 10).round();

    final preset = CameraPreset(
      name: name,
      filmSim: OfrEnums.filmSimToCode[r.filmSimulation] ?? FilmSim.provia,
      dynamicRange: dr ?? 100,
      grain: grain,
      colorChrome: mono ? null : _effectToInt[r.colorChromeEffect ?? 'Off'],
      colorChromeBlue: mono ? null : _effectToInt[r.colorChromeFxBlue ?? 'Off'],
      wbMode: wb,
      wbShiftR: r.whiteBalanceRed,
      wbShiftB: r.whiteBalanceBlue,
      wbKelvin: wb == WbMode.colorTemp ? r.wbKelvin : null,
      highlightX10: x10(r.highlight),
      shadowX10: x10(r.shadow),
      colorX10: mono ? null : x10(r.color),
      sharpnessX10: x10(r.sharpness),
      highIsoNrRaw: nrEncode[r.highIsoNr] ?? 0x2000,
      clarityX10: x10(r.clarity),
      monoWcX10: mono ? x10(r.monochromaticColorWarmCool) : null,
      monoMgX10: mono ? x10(r.monochromaticColorMagentaGreen) : null,
    );
    return MappingResult(preset, notes);
  }

  static OfrRecipe fromPreset(CameraPreset p, {List<String> sensors = const [], String? sourceAttribution}) {
    final mono = p.isMono;
    final grainOff = p.grain == GrainEnum.off;
    final strong = p.grain == GrainEnum.strongSmall || p.grain == GrainEnum.strongLarge;
    final large = p.grain == GrainEnum.weakLarge || p.grain == GrainEnum.strongLarge;
    num tone(int x10) => x10 % 10 == 0 ? x10 ~/ 10 : x10 / 10;
    return OfrRecipe(
      name: p.name.isEmpty ? null : p.name,
      sensors: sensors,
      sourceAttribution: sourceAttribution,
      filmSimulation: OfrEnums.codeToFilmSim[p.filmSim] ?? 'Provia',
      dynamicRange: _intToDr[p.dynamicRange ?? 100] ?? 'DR100',
      dRangePriority: 'Off',
      grainRoughness: grainOff ? 'Off' : (strong ? 'Strong' : 'Weak'),
      grainSize: grainOff ? null : (large ? 'Large' : 'Small'),
      colorChromeEffect: mono ? null : _intToEffect[p.colorChrome ?? Effect.off],
      colorChromeFxBlue: mono ? null : _intToEffect[p.colorChromeBlue ?? Effect.off],
      whiteBalance: OfrEnums.codeToWb[p.wbMode] ?? 'Auto',
      wbKelvin: p.wbMode == WbMode.colorTemp ? p.wbKelvin : null,
      whiteBalanceRed: p.wbShiftR,
      whiteBalanceBlue: p.wbShiftB,
      highlight: tone(p.highlightX10),
      shadow: tone(p.shadowX10),
      color: mono ? null : (p.colorX10 ?? 0) ~/ 10,
      sharpness: p.sharpnessX10 ~/ 10,
      highIsoNr: nrDecode[p.highIsoNrRaw & 0xFFFF] ?? 0,
      clarity: p.clarityX10 ~/ 10,
      monochromaticColorWarmCool: mono ? (p.monoWcX10 ?? 0) ~/ 10 : null,
      monochromaticColorMagentaGreen: mono ? (p.monoMgX10 ?? 0) ~/ 10 : null,
    );
  }

  /// Editorial default sensors for a body model string from DeviceInfo.
  static List<String> sensorsForModel(String model) {
    final m = model.toUpperCase().replaceAll(' ', '');
    if (m.startsWith('GFX')) return const ['GFX'];
    const xtV = {'X-T5', 'X-H2', 'X-H2S', 'X-S20', 'X-T50', 'X-M5', 'X-E5', 'X-T30III', 'X100VI'};
    const xtIV = {'X-T4', 'X-T3', 'X-PRO3', 'X100V', 'X-S10', 'X-E4', 'X-T30', 'X-T30II'};
    const xtIII = {'X-T2', 'X-PRO2', 'X100F', 'X-T20', 'X-E3', 'X-H1'};
    if (xtV.contains(m)) return const ['X-Trans V'];
    if (xtIV.contains(m)) return const ['X-Trans IV'];
    if (xtIII.contains(m)) return const ['X-Trans III'];
    return const [];
  }
}
