import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/treatment.dart';

void main() {
  test('a drawn treatment never exceeds the bounds the frame allowed', () {
    const tight = TreatmentBounds(slip: 0.004, bleed: 0.3, pressure: 0.05, speckles: 6, wear: 0);
    for (var seed = 0; seed < 300; seed++) {
      final t = Treatment.draw(tight, seed);
      expect(t.slip.dx.abs(), lessThanOrEqualTo(0.004));
      expect(t.slip.dy.abs(), lessThanOrEqualTo(0.004));
      expect(t.bleed, inInclusiveRange(0, 0.3));
      expect(t.pressure, inInclusiveRange(0, 0.05));
      expect(t.speckles, inInclusiveRange(0, 6));
      expect(t.wear, 0, reason: 'a frame that forbids wear must never get any');
    }
  });

  test('the same seed draws the same treatment', () {
    const b = TreatmentBounds();
    expect(Treatment.draw(b, 11).slip, Treatment.draw(b, 11).slip);
    expect(Treatment.draw(b, 11).speckles, Treatment.draw(b, 11).speckles);
  });

  test('different seeds draw different treatments', () {
    const b = TreatmentBounds();
    final seen = {for (var s = 0; s < 20; s++) Treatment.draw(b, s).speckles};
    expect(seen.length, greaterThan(3), reason: 'the roll is not actually varying');
  });
}
