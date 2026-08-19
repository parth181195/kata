import 'dart:typed_data';

import 'camera_preset.dart';
import 'fuji_props.dart';

Uint8List u16le(int v) => Uint8List.fromList([v & 0xFF, (v >> 8) & 0xFF]);
int i16le(Uint8List b) => ByteData.sublistView(b).getInt16(0, Endian.little);
int u16leOf(Uint8List b) => ByteData.sublistView(b).getUint16(0, Endian.little);

/// Pure conversion between raw preset property bytes and [CameraPreset].
class PresetCodec {
  /// [raw] maps prop code -> payload bytes as read from the camera (D18E..D1A5; missing = unsupported).
  static CameraPreset decode({required String name, required Map<int, Uint8List> raw}) {
    int? i(int code) {
      final b = raw[code];
      return (b == null || b.length < 2) ? null : i16le(b);
    }

    int? u(int code) {
      final b = raw[code];
      return (b == null || b.length < 2) ? null : u16leOf(b);
    }

    int tone(int? v) => (v == null || v == -32768) ? 0 : v;
    int? toneOrNull(int? v) => v == null ? null : tone(v);

    final filmSim = u(0xD192) ?? FilmSim.provia;
    final extras = <int, Uint8List>{
      for (final c in rawPassthroughProps)
        if (raw[c] != null) c: Uint8List.fromList(raw[c]!),
    };
    final kelvin = u(0xD19C);
    return CameraPreset(
      name: name,
      filmSim: filmSim,
      dynamicRange: u(0xD190),
      grain: u(0xD195) ?? GrainEnum.off,
      colorChrome: u(0xD196),
      colorChromeBlue: u(0xD197),
      smoothSkin: u(0xD198),
      wbMode: u(0xD199) ?? WbMode.auto,
      wbShiftR: i(0xD19A) ?? 0,
      wbShiftB: i(0xD19B) ?? 0,
      wbKelvin: (kelvin == null || kelvin == 0) ? null : kelvin,
      highlightX10: tone(i(0xD19D)),
      shadowX10: tone(i(0xD19E)),
      colorX10: toneOrNull(i(0xD19F)),
      sharpnessX10: tone(i(0xD1A0)),
      highIsoNrRaw: u(0xD1A1) ?? 0x2000,
      clarityX10: tone(i(0xD1A2)),
      monoWcX10: toneOrNull(i(0xD193)),
      monoMgX10: toneOrNull(i(0xD194)),
      rawExtras: extras,
    );
  }

  /// Value-conditional encoding (capability filtering happens in PresetWriter).
  /// Omits: D193/D194 unless mono && != 0; D19C unless WB == colorTemp && kelvin set; D19F when mono;
  /// D198 when smoothSkin == null. Passthrough props included only if present in rawExtras.
  static Map<int, Uint8List> encode(CameraPreset p) {
    final out = <int, Uint8List>{};
    void put(int code, int v) => out[code] = u16le(v & 0xFFFF);

    for (final e in p.rawExtras.entries) {
      out[e.key] = Uint8List.fromList(e.value);
    }
    put(0xD190, p.dynamicRange ?? 100);
    put(0xD192, p.filmSim);
    if (p.isMono) {
      if ((p.monoWcX10 ?? 0) != 0) put(0xD193, p.monoWcX10!);
      if ((p.monoMgX10 ?? 0) != 0) put(0xD194, p.monoMgX10!);
    }
    put(0xD195, p.grain);
    put(0xD196, p.colorChrome ?? Effect.off);
    put(0xD197, p.colorChromeBlue ?? Effect.off);
    if (p.smoothSkin != null) put(0xD198, p.smoothSkin!);
    put(0xD199, p.wbMode);
    if (p.wbMode == WbMode.colorTemp && p.wbKelvin != null) put(0xD19C, p.wbKelvin!);
    put(0xD19A, p.wbShiftR);
    put(0xD19B, p.wbShiftB);
    put(0xD19D, p.highlightX10);
    put(0xD19E, p.shadowX10);
    if (!p.isMono) put(0xD19F, p.colorX10 ?? 0);
    put(0xD1A0, p.sharpnessX10);
    put(0xD1A1, p.highIsoNrRaw);
    put(0xD1A2, p.clarityX10);
    return out;
  }
}
