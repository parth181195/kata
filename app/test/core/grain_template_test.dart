import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/grain_template.dart';

void main() {
  test('the field is deterministic, zero-mean, unit-variance', () {
    final a = GrainTemplate.field(seed: 7, grainPx: 1.7);
    final b = GrainTemplate.field(seed: 7, grainPx: 1.7);
    expect(a, equals(b)); // same spec → identical tile, exports reproducible
    var mean = 0.0;
    for (final v in a) {
      mean += v;
    }
    mean /= a.length;
    var varAcc = 0.0;
    for (final v in a) {
      varAcc += (v - mean) * (v - mean);
    }
    expect(mean.abs(), lessThan(1e-9));
    expect(math.sqrt(varAcc / a.length), closeTo(1.0, 1e-9));
  });

  test('different seeds give different tiles; grain size changes correlation', () {
    final a = GrainTemplate.field(seed: 7, grainPx: 1.7);
    final b = GrainTemplate.field(seed: 8, grainPx: 1.7);
    expect(a, isNot(equals(b)));

    // lag-1 autocorrelation grows with clump size — the band-pass is real
    double lag1(List<double> f) {
      const n = GrainTemplate.size;
      var acc = 0.0;
      for (var y = 0; y < n; y++) {
        for (var x = 0; x < n; x++) {
          acc += f[y * n + x] * f[y * n + (x + 1) % n];
        }
      }
      return acc / (n * n);
    }

    final fine = lag1(GrainTemplate.field(seed: 7, grainPx: 1.7));
    final coarse = lag1(GrainTemplate.field(seed: 7, grainPx: 3.1));
    expect(fine, greaterThan(0)); // correlated, not white noise
    expect(coarse, greaterThan(fine)); // bigger grain → stronger neighbor correlation
  });

  test('the tile is seamless: wrap-around correlation matches interior correlation', () {
    final f = GrainTemplate.field(seed: 7, grainPx: 3.1);
    const n = GrainTemplate.size;
    // correlation across the tile edge (x = n-1 ↔ x = 0)
    var edge = 0.0;
    for (var y = 0; y < n; y++) {
      edge += f[y * n + (n - 1)] * f[y * n];
    }
    edge /= n;
    // a seam would show up as edge correlation far below interior lag-1
    var interior = 0.0;
    for (var y = 0; y < n; y++) {
      interior += f[y * n + 63] * f[y * n + 64];
    }
    interior /= n;
    expect((edge - interior).abs(), lessThan(0.35)); // same statistical family
    expect(edge, greaterThan(0));
  });
}
