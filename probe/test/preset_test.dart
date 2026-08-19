import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_probe/fuji/preset.dart';

void main() {
  test('film sim', () {
    expect(describePresetValue(0xD192, 11), 'Classic Chrome');
    expect(describePresetValue(0xD192, 99), '? (99)');
  });
  test('WB read as int16 masks to uint16', () {
    expect(describePresetValue(0xD199, -32761), 'Color Temp'); // 0x8007 as int16
    expect(describePresetValue(0xD199, 4), 'Daylight');
  });
  test('tones ×10 and sentinel', () {
    expect(describePresetValue(0xD19D, -10), '-1.0');
    expect(describePresetValue(0xD19E, 5), '+0.5');
    expect(describePresetValue(0xD19D, -32768), '(unset 0x8000)');
  });
  test('high ISO NR lookup', () {
    expect(describePresetValue(0xD1A1, -32768), '-4'); // 0x8000
    expect(describePresetValue(0xD1A1, 0x2000), '0');
    expect(describePresetValue(0xD1A1, 0x5000), '+4');
  });
  test('grain / effects / DR', () {
    expect(describePresetValue(0xD195, 4), 'Weak/Large');
    expect(describePresetValue(0xD196, 3), 'Strong');
    expect(describePresetValue(0xD190, 400), 'DR400%');
  });
  test('unknown prop returns null', () {
    expect(describePresetValue(0xD191, 0), isNull);
  });
}
