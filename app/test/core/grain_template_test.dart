import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/grain.dart';
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

  test('the tooth keeps its size on the sheet at every export scale', () {
    // the bug this pins: grain used to be locked to output pixels, so a 4x
    // export rendered it 4x finer than the preview the user tuned by eye
    const spec = GrainSpec(strength: GrainStrength.weak, matchPx: 1.7);
    final preview = GrainGeometry.of(spec, dpr: 2, raster: 1);
    for (final raster in [1.0, 2.0, 3.5, 4.0, 9.0]) {
      final g = GrainGeometry.of(spec, dpr: 2, raster: raster);
      expect(g.clumpOnSheet, closeTo(preview.clumpOnSheet, 1e-9), reason: 'raster=$raster');
      expect(g.repeatOnSheet, closeTo(preview.repeatOnSheet, 1e-9), reason: 'raster=$raster');
    }
  });

  test('a bigger export buys template resolution, and stops at the cap', () {
    const spec = GrainSpec(strength: GrainStrength.weak, matchPx: 1.7);
    expect(GrainGeometry.of(spec, dpr: 2, raster: 1).templateSize, GrainTemplate.size);
    expect(GrainGeometry.of(spec, dpr: 2, raster: 3.2).templateSize, GrainTemplate.size * 4);
    // past the cap the tile is magnified rather than regenerated — still the
    // same tooth, just softer, instead of an ever-growing CPU bill
    expect(GrainGeometry.of(spec, dpr: 2, raster: 40).tile, GrainGeometry.maxTile);
  });

  test('the template holds its statistics when it is generated bigger', () {
    // export tiles are generated at tile x the size AND tile x the clump, so
    // the field must stay the same family, not turn to mush or to white noise
    double lag1(List<double> f, int n) {
      var acc = 0.0;
      for (var y = 0; y < n; y++) {
        for (var x = 0; x < n; x++) {
          acc += f[y * n + x] * f[y * n + (x + 1) % n];
        }
      }
      return acc / (n * n);
    }

    final small = GrainTemplate.field(seed: 7, grainPx: 1.7);
    final big = GrainTemplate.field(seed: 7, grainPx: 1.7 * 3, size: GrainTemplate.size * 3);
    expect(big.length, GrainTemplate.size * 3 * GrainTemplate.size * 3);
    // lag-1 correlation rises with the bigger clump measured in its own texels
    expect(lag1(big, GrainTemplate.size * 3), greaterThan(lag1(small, GrainTemplate.size)));
  });
}
