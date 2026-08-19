import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/src/fuji/camera_preset.dart';
import 'package:fuji_ptp/src/fuji/fuji_props.dart';
import 'package:fuji_ptp/src/fuji/preset_codec.dart';
import 'package:fuji_ptp/src/fuji/preset_writer.dart';

Uint8List b(List<int> l) => Uint8List.fromList(l);

final xs20Caps = CameraCapabilities(
  model: 'X-S20', firmware: '3.30', pid: 0x02f7, slotCount: 4,
  supportedProps: {for (var p = 0xD18C; p <= 0xD1A5; p++) if (p != 0xD198) p},
);
final extras = {0xD18E: b([7, 0]), 0xD18F: b([4, 0]), 0xD191: b([0, 0]), 0xD1A3: b([1, 0]), 0xD1A4: b([1, 0]), 0xD1A5: b([7, 0])};

/// Kodachrome 64 (OFR README example) as a CameraPreset.
final kodachrome = CameraPreset(
  name: 'Kodachrome 64', filmSim: FilmSim.classicChrome, dynamicRange: 400, grain: GrainEnum.weakSmall,
  colorChrome: Effect.weak, colorChromeBlue: Effect.off, wbMode: WbMode.daylight, wbShiftR: 2, wbShiftB: -5,
  highlightX10: -10, shadowX10: 5, colorX10: 20, sharpnessX10: -20, highIsoNrRaw: nrEncode[-4]!, clarityX10: 0,
  rawExtras: extras,
);

void main() {
  test('encode Kodachrome produces exact bytes', () {
    final m = PresetCodec.encode(kodachrome);
    expect(m[0xD190], b([0x90, 0x01])); // 400
    expect(m[0xD192], b([0x0B, 0x00]));
    expect(m[0xD195], b([0x02, 0x00]));
    expect(m[0xD196], b([0x02, 0x00]));
    expect(m[0xD197], b([0x01, 0x00]));
    expect(m[0xD199], b([0x04, 0x00]));
    expect(m.containsKey(0xD19C), isFalse); // not Kelvin
    expect(m[0xD19A], b([0x02, 0x00]));
    expect(m[0xD19B], b([0xFB, 0xFF])); // -5
    expect(m[0xD19D], b([0xF6, 0xFF])); // -10
    expect(m[0xD19E], b([0x05, 0x00]));
    expect(m[0xD19F], b([0x14, 0x00]));
    expect(m[0xD1A0], b([0xEC, 0xFF]));
    expect(m[0xD1A1], b([0x00, 0x80]));
    expect(m[0xD1A2], b([0x00, 0x00]));
    expect(m.containsKey(0xD193), isFalse);
    expect(m.containsKey(0xD198), isFalse);
    expect(m[0xD1A5], b([7, 0]));
  });

  test('plan order matches X RAW Studio, name first and fatal, no D198 on X-S20', () {
    final plan = PresetWriter.plan(kodachrome, xs20Caps);
    final codes = plan.map((w) => w.code).toList();
    expect(codes.first, 0xD18D);
    expect(plan.first.fatal, isTrue);
    expect(plan.where((w) => w.fatal).length, 1);
    expect(codes, [0xD18D, 0xD18E, 0xD18F, 0xD190, 0xD191, 0xD192, 0xD195, 0xD196, 0xD197, 0xD199, 0xD19A, 0xD19B,
      0xD19D, 0xD19E, 0xD19F, 0xD1A0, 0xD1A1, 0xD1A2, 0xD1A3, 0xD1A4, 0xD1A5]);
    expect(plan.first.bytes[0], 'Kodachrome 64'.length + 1);
  });

  test('plan: mono recipe drops D19F and includes D193/D194 only when non-zero', () {
    final mono = kodachrome.copyWith(filmSim: FilmSim.acrosR, monoWcX10: 20, monoMgX10: 0);
    final codes = PresetWriter.plan(mono, xs20Caps).map((w) => w.code).toList();
    expect(codes, isNot(contains(0xD19F)));
    expect(codes, contains(0xD193));
    expect(codes, isNot(contains(0xD194)));
  });

  test('plan: Kelvin written right after D199 and before D19A', () {
    final k = kodachrome.copyWith(wbMode: WbMode.colorTemp, wbKelvin: 5800);
    final codes = PresetWriter.plan(k, xs20Caps).map((w) => w.code).toList();
    expect(codes.indexOf(0xD19C), codes.indexOf(0xD199) + 1);
    expect(codes.indexOf(0xD19A), codes.indexOf(0xD19C) + 1);
  });

  test('plan: DR-Auto encodes as 0xFFFF; unsupported props are dropped', () {
    final a = kodachrome.copyWith(dynamicRange: kDrAuto, smoothSkin: Effect.weak);
    final plan = PresetWriter.plan(a, xs20Caps);
    expect(plan.firstWhere((w) => w.code == 0xD190).bytes, b([0xFF, 0xFF]));
    expect(plan.any((w) => w.code == 0xD198), isFalse); // X-S20 lacks D198
    final caps7 = CameraCapabilities(model: 'X100VI', firmware: '1.0', pid: 0x0305, slotCount: 7,
        supportedProps: {for (var p = 0xD18C; p <= 0xD1A5; p++) p});
    expect(PresetWriter.plan(a, caps7).any((w) => w.code == 0xD198), isTrue);
  });

  test('capabilities helpers', () {
    expect(xs20Caps.presetProtocol, isTrue);
    expect(xs20Caps.hasSmoothSkin, isFalse);
    expect(CameraCapabilities(model: 'X-T4', firmware: '1', pid: 1, slotCount: 0, supportedProps: {0xD185}).presetProtocol, isFalse);
  });
}
