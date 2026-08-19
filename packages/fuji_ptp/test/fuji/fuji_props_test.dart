import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/src/fuji/fuji_props.dart';

void main() {
  test('film sim codes and mono set', () {
    expect(FilmSim.classicChrome, 11);
    expect(FilmSim.acros, 12);
    expect(FilmSim.realaAce, 20);
    expect(FilmSim.isMono(FilmSim.acrosR), isTrue);
    expect(FilmSim.isMono(FilmSim.velvia), isFalse);
    expect(FilmSim.labels[FilmSim.nostalgicNeg], 'Nostalgic Neg');
    expect(FilmSim.abbr[FilmSim.classicChrome], 'CC');
  });
  test('NR tables are inverse of each other', () {
    for (final e in nrEncode.entries) {
      expect(nrDecode[e.value], e.key);
    }
    expect(nrEncode[-4], 0x8000);
    expect(nrEncode[0], 0x2000);
    expect(nrEncode[4], 0x5000);
  });
  test('write order matches X RAW Studio and covers all preset props', () {
    expect(presetWriteOrder.first, 0xD18D);
    expect(presetWriteOrder.indexOf(0xD199) < presetWriteOrder.indexOf(0xD19C), isTrue);
    expect(presetWriteOrder.indexOf(0xD19C) < presetWriteOrder.indexOf(0xD19A), isTrue);
    expect(presetWriteOrder.toSet().length, presetWriteOrder.length);
    for (var p = 0xD18D; p <= 0xD1A5; p++) {
      expect(presetWriteOrder, contains(p));
    }
  });
  test('WB modes', () {
    expect(WbMode.colorTemp, 0x8007);
    expect(WbMode.ambiencePriority, 0x8021);
    expect(WbMode.labels[WbMode.daylight], 'Daylight');
  });
}
