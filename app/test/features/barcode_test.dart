import 'package:flutter_test/flutter_test.dart';
import 'package:kata/features/waku/frames/barcode.dart';

void main() {
  test('Code 39 brackets the value with its start and stop character', () {
    final bars = code39Bars('A');
    // '*' start + 'A' + '*' stop; every character is nine elements, three wide
    expect(bars.length, greaterThan(27));
    expect(code39Bars('A'), code39Bars('a'), reason: 'Code 39 is upper-case only');
  });

  test('different values give different bars', () {
    expect(code39Bars('KATA1'), isNot(code39Bars('KATA2')));
  });

  test('unsupported characters are dropped rather than throwing mid-export', () {
    expect(() => code39Bars('KATA-64!'), returnsNormally);
  });

  test('every character is nine elements: five bars, four spaces, three wide', () {
    // one character between the start and stop pair, so three characters and
    // two inter-character gaps: 3 × (6 narrow + 3 wide × 3) + 2
    expect(code39Bars('A').length, 3 * (6 + 9) + 2);
    expect(code39Bars('KATA').length, 6 * (6 + 9) + 5);
  });

  test('a value starts and ends with ink — the quiet zone is the caller\'s', () {
    final bars = code39Bars('KATA');
    expect(bars.first, isTrue);
    expect(bars.last, isTrue);
  });
}
