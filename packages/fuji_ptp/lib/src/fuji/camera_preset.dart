import 'dart:typed_data';

import 'fuji_props.dart';

/// Decoded contents of one Custom Settings slot. Nullable = not present on this body / not applicable.
class CameraPreset {
  const CameraPreset({
    this.name = '',
    required this.filmSim,
    this.dynamicRange,
    this.grain = GrainEnum.off,
    this.colorChrome,
    this.colorChromeBlue,
    this.smoothSkin,
    this.wbMode = WbMode.auto,
    this.wbShiftR = 0,
    this.wbShiftB = 0,
    this.wbKelvin,
    this.highlightX10 = 0,
    this.shadowX10 = 0,
    this.colorX10,
    this.sharpnessX10 = 0,
    this.highIsoNrRaw = 0x2000,
    this.clarityX10 = 0,
    this.monoWcX10,
    this.monoMgX10,
    this.rawExtras = const {},
  });

  final String name;
  final int filmSim;
  final int? dynamicRange; // 100 / 200 / 400 / kDrAuto
  final int grain; // GrainEnum 1..5
  final int? colorChrome; // Effect 1..3
  final int? colorChromeBlue; // Effect 1..3
  final int? smoothSkin; // Effect 1..3, absent on some bodies
  final int wbMode; // WbMode
  final int wbShiftR; // -9..9
  final int wbShiftB; // -9..9
  final int? wbKelvin; // 2500..10000
  final int highlightX10; // -20..40
  final int shadowX10; // -20..40
  final int? colorX10; // -40..40, null for mono
  final int sharpnessX10; // -40..40
  final int highIsoNrRaw; // nrEncode values
  final int clarityX10; // -50..50
  final int? monoWcX10; // -90..90, mono only
  final int? monoMgX10; // -90..90, mono only
  final Map<int, Uint8List> rawExtras; // D18E, D18F, D191, D1A3, D1A4, D1A5 bytes copied from the slot

  bool get isMono => FilmSim.isMono(filmSim);

  CameraPreset copyWith({
    String? name,
    int? filmSim,
    int? dynamicRange,
    bool clearDynamicRange = false,
    int? grain,
    int? colorChrome,
    int? colorChromeBlue,
    int? smoothSkin,
    int? wbMode,
    int? wbShiftR,
    int? wbShiftB,
    int? wbKelvin,
    bool clearWbKelvin = false,
    int? highlightX10,
    int? shadowX10,
    int? colorX10,
    bool clearColor = false,
    int? sharpnessX10,
    int? highIsoNrRaw,
    int? clarityX10,
    int? monoWcX10,
    int? monoMgX10,
    Map<int, Uint8List>? rawExtras,
  }) =>
      CameraPreset(
        name: name ?? this.name,
        filmSim: filmSim ?? this.filmSim,
        dynamicRange: clearDynamicRange ? null : (dynamicRange ?? this.dynamicRange),
        grain: grain ?? this.grain,
        colorChrome: colorChrome ?? this.colorChrome,
        colorChromeBlue: colorChromeBlue ?? this.colorChromeBlue,
        smoothSkin: smoothSkin ?? this.smoothSkin,
        wbMode: wbMode ?? this.wbMode,
        wbShiftR: wbShiftR ?? this.wbShiftR,
        wbShiftB: wbShiftB ?? this.wbShiftB,
        wbKelvin: clearWbKelvin ? null : (wbKelvin ?? this.wbKelvin),
        highlightX10: highlightX10 ?? this.highlightX10,
        shadowX10: shadowX10 ?? this.shadowX10,
        colorX10: clearColor ? null : (colorX10 ?? this.colorX10),
        sharpnessX10: sharpnessX10 ?? this.sharpnessX10,
        highIsoNrRaw: highIsoNrRaw ?? this.highIsoNrRaw,
        clarityX10: clarityX10 ?? this.clarityX10,
        monoWcX10: monoWcX10 ?? this.monoWcX10,
        monoMgX10: monoMgX10 ?? this.monoMgX10,
        rawExtras: rawExtras ?? this.rawExtras,
      );

  static bool _extrasEqual(Map<int, Uint8List> a, Map<int, Uint8List> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final o = b[e.key];
      if (o == null || o.length != e.value.length) return false;
      for (var i = 0; i < o.length; i++) {
        if (o[i] != e.value[i]) return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is CameraPreset &&
      name == other.name &&
      filmSim == other.filmSim &&
      dynamicRange == other.dynamicRange &&
      grain == other.grain &&
      colorChrome == other.colorChrome &&
      colorChromeBlue == other.colorChromeBlue &&
      smoothSkin == other.smoothSkin &&
      wbMode == other.wbMode &&
      wbShiftR == other.wbShiftR &&
      wbShiftB == other.wbShiftB &&
      wbKelvin == other.wbKelvin &&
      highlightX10 == other.highlightX10 &&
      shadowX10 == other.shadowX10 &&
      colorX10 == other.colorX10 &&
      sharpnessX10 == other.sharpnessX10 &&
      highIsoNrRaw == other.highIsoNrRaw &&
      clarityX10 == other.clarityX10 &&
      monoWcX10 == other.monoWcX10 &&
      monoMgX10 == other.monoMgX10 &&
      _extrasEqual(rawExtras, other.rawExtras);

  @override
  int get hashCode => Object.hash(name, filmSim, dynamicRange, grain, colorChrome, colorChromeBlue, smoothSkin, wbMode,
      wbShiftR, wbShiftB, wbKelvin, highlightX10, shadowX10, colorX10, sharpnessX10, highIsoNrRaw, clarityX10, monoWcX10,
      monoMgX10);

  @override
  String toString() =>
      'CameraPreset($name sim=$filmSim dr=$dynamicRange wb=0x${wbMode.toRadixString(16)} hl=$highlightX10 sh=$shadowX10)';
}
