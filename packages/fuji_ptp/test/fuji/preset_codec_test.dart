import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/src/fuji/fuji_props.dart';
import 'package:fuji_ptp/src/fuji/preset_codec.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);

/// X-S20 C1 after the probe wrote Acros (2026-08-19).
final xs20c1 = <int, Uint8List>{
  0xD18E: b([0x07, 0x00]), 0xD18F: b([0x02, 0x00]), 0xD190: b([0xff, 0xff]), 0xD191: b([0x00, 0x00]),
  0xD192: b([0x0c, 0x00]), 0xD193: b([0x00, 0x00]), 0xD194: b([0x00, 0x00]), 0xD195: b([0x03, 0x00]),
  0xD196: b([0x03, 0x00]), 0xD197: b([0x02, 0x00]), /* no D198 on X-S20 */ 0xD199: b([0x02, 0x00]),
  0xD19A: b([0x02, 0x00]), 0xD19B: b([0xfc, 0xff]), 0xD19C: b([0x70, 0x17]), 0xD19D: b([0xf6, 0xff]),
  0xD19E: b([0xf6, 0xff]), 0xD19F: b([0x14, 0x00]), 0xD1A0: b([0xec, 0xff]), 0xD1A1: b([0x00, 0x80]),
  0xD1A2: b([0x00, 0x00]), 0xD1A3: b([0x01, 0x00]), 0xD1A4: b([0x01, 0x00]), 0xD1A5: b([0x07, 0x00]),
};

void main() {
  test('decode X-S20 C1 dump', () {
    final p = PresetCodec.decode(name: '', raw: xs20c1);
    expect(p.filmSim, FilmSim.acros);
    expect(p.isMono, isTrue);
    expect(p.dynamicRange, kDrAuto);
    expect(p.grain, GrainEnum.strongSmall);
    expect(p.colorChrome, Effect.strong);
    expect(p.colorChromeBlue, Effect.weak);
    expect(p.smoothSkin, isNull);
    expect(p.wbMode, WbMode.auto);
    expect(p.wbShiftR, 2);
    expect(p.wbShiftB, -4);
    expect(p.wbKelvin, 6000);
    expect(p.highlightX10, -10);
    expect(p.shadowX10, -10);
    expect(p.colorX10, 20);
    expect(p.sharpnessX10, -20);
    expect(p.highIsoNrRaw, 0x8000);
    expect(p.clarityX10, 0);
    expect(p.monoWcX10, 0);
    expect(p.monoMgX10, 0);
    expect(p.rawExtras.keys.toSet(), rawPassthroughProps);
    expect(p.rawExtras[0xD1A5], b([0x07, 0x00]));
  });

  test('decode treats 0x8000 tone sentinel as 0 and missing optional props as null', () {
    final raw = Map<int, Uint8List>.from(xs20c1)
      ..[0xD19D] = b([0x00, 0x80])
      ..remove(0xD19C)
      ..remove(0xD19F);
    final p = PresetCodec.decode(name: 'X', raw: raw);
    expect(p.highlightX10, 0);
    expect(p.wbKelvin, isNull);
    expect(p.colorX10, isNull);
    expect(p.name, 'X');
  });

  test('u16le / i16le helpers', () {
    expect(u16le(0x8007), b([0x07, 0x80]));
    expect(i16le(b([0xfc, 0xff])), -4);
    expect(i16le(b([0x00, 0x80])), -32768);
  });
}
