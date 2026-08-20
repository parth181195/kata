import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:ofr/ofr.dart';

const kodachrome = OfrRecipe(name: 'Kodachrome 64', sensors: ['X-Trans IV'], filmSimulation: 'Classic Chrome', dynamicRange: 'DR400',
    dRangePriority: 'Off', grainRoughness: 'Weak', grainSize: 'Small', colorChromeEffect: 'Weak', colorChromeFxBlue: 'Off',
    whiteBalance: 'Daylight', whiteBalanceRed: 2, whiteBalanceBlue: -5, highlight: -1, shadow: 0.5, color: 2, sharpness: -2,
    highIsoNr: -4, clarity: 0);

void main() {
  test('OFR -> CameraPreset (Kodachrome)', () {
    final m = OfrMapper.toPreset(kodachrome);
    final p = m.value;
    expect(m.notes, isEmpty);
    expect(p.name, 'Kodachrome 64');
    expect(p.filmSim, FilmSim.classicChrome);
    expect(p.dynamicRange, 400);
    expect(p.grain, GrainEnum.weakSmall);
    expect(p.colorChrome, Effect.weak);
    expect(p.colorChromeBlue, Effect.off);
    expect(p.wbMode, WbMode.daylight);
    expect(p.wbKelvin, isNull);
    expect(p.wbShiftR, 2);
    expect(p.wbShiftB, -5);
    expect(p.highlightX10, -10);
    expect(p.shadowX10, 5);
    expect(p.colorX10, 20);
    expect(p.sharpnessX10, -20);
    expect(p.highIsoNrRaw, 0x8000);
    expect(p.clarityX10, 0);
    expect(p.monoWcX10, isNull);
  });

  test('DR-Auto, Kelvin, mono, grain large', () {
    final r = kodachrome.copyWith(dynamicRange: 'DR-Auto', whiteBalance: 'Kelvin', wbKelvin: 5800, grainSize: 'Large',
        grainRoughness: 'Strong', filmSimulation: 'Acros Red', clearColor: true, clearColorChrome: true,
        monochromaticColorWarmCool: 2, monochromaticColorMagentaGreen: -1);
    final p = OfrMapper.toPreset(r).value;
    expect(p.dynamicRange, kDrAuto);
    expect(p.wbMode, WbMode.colorTemp);
    expect(p.wbKelvin, 5800);
    expect(p.grain, GrainEnum.strongLarge);
    expect(p.filmSim, FilmSim.acrosR);
    expect(p.colorX10, isNull);
    expect(p.monoWcX10, 20);
    expect(p.monoMgX10, -10);
  });

  test('notes for things the wire cannot express', () {
    final r = kodachrome.copyWith(dRangePriority: 'Weak', clearDynamicRange: true, clearHighlight: true, clearShadow: true,
        whiteBalance: 'Auto (white priority)', name: 'A very very long recipe name indeed');
    final m = OfrMapper.toPreset(r);
    expect(m.value.dynamicRange, 100);
    expect(m.value.name.length, 25);
    expect(m.notes.join(' '), contains('D-Range Priority'));
    expect(m.notes.join(' '), contains('white priority'));
    expect(m.notes.join(' '), contains('truncated'));
  });

  test('CameraPreset -> OFR and round trip', () {
    final p = OfrMapper.toPreset(kodachrome).value;
    final back = OfrMapper.fromPreset(p, sensors: ['X-Trans IV']);
    expect(back.filmSimulation, 'Classic Chrome');
    expect(back.dynamicRange, 'DR400');
    expect(back.dRangePriority, 'Off');
    expect(back.grainRoughness, 'Weak');
    expect(back.grainSize, 'Small');
    expect(back.whiteBalance, 'Daylight');
    expect(back.shadow, 0.5);
    expect(back.highIsoNr, -4);
    expect(back.toJson()..remove('name'), kodachrome.toJson()..remove('name'));
    final auto = OfrMapper.fromPreset(p.copyWith(dynamicRange: kDrAuto, grain: GrainEnum.off));
    expect(auto.dynamicRange, 'DR-Auto');
    expect(auto.grainRoughness, 'Off');
    expect(auto.grainSize, isNull);
  });

  test('sensorsForModel', () {
    expect(OfrMapper.sensorsForModel('X-S20'), ['X-Trans V']);
    expect(OfrMapper.sensorsForModel('X100VI'), ['X-Trans V']);
    expect(OfrMapper.sensorsForModel('GFX100 II'), ['GFX']);
    expect(OfrMapper.sensorsForModel('X-T4'), ['X-Trans IV']);
    expect(OfrMapper.sensorsForModel('Unknown'), isEmpty);
  });

  test('settings-only hash is a fixpoint across mapper roundtrips (slot identification)', () {
    String h(OfrRecipe r) => OfrHasher.compute(r, scheme: HashScheme.v1SettingsOnly);
    OfrRecipe rt(OfrRecipe r) => OfrMapper.fromPreset(OfrMapper.toPreset(r).value, sensors: const ['X-Trans V']);
    final k1 = rt(kodachrome), k2 = rt(k1);
    expect(h(k2), h(k1));
    final mono = kodachrome.copyWith(filmSimulation: 'Acros Red', clearColor: true, clearColorChrome: true,
        monochromaticColorWarmCool: 2, monochromaticColorMagentaGreen: -1, grainRoughness: 'Strong', grainSize: 'Large');
    final m1 = rt(mono), m2 = rt(m1);
    expect(h(m2), h(m1));
    expect(h(m1) == h(k1), isFalse);
  });
}
