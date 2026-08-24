import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:image/image.dart' as im;

/// Five swatches out of the photo itself — the poster's calibration strip is
/// the picture's own palette, ordered dark to light like a printer's bar.
Future<List<Color>?> extractPalette(Uint8List bytes, {int count = 5}) => Isolate.run(() => extractPaletteSync(bytes, count: count));

@pragma('vm:entry-point')
List<Color>? extractPaletteSync(Uint8List bytes, {int count = 5}) {
  final decoded = im.decodeImage(bytes);
  if (decoded == null) return null;
  final small = im.copyResize(decoded, width: 48, interpolation: im.Interpolation.average);

  // popularity in a 4-bit/channel histogram
  final buckets = <int, List<int>>{}; // key -> [count, rSum, gSum, bSum]
  for (final px in small) {
    final r = px.r.toInt(), g = px.g.toInt(), b = px.b.toInt();
    final key = (r >> 4 << 8) | (g >> 4 << 4) | (b >> 4);
    final e = buckets.putIfAbsent(key, () => [0, 0, 0, 0]);
    e[0]++;
    e[1] += r;
    e[2] += g;
    e[3] += b;
  }
  final ranked = buckets.values.toList()..sort((a, b) => b[0].compareTo(a[0]));

  // greedy pick with a minimum spread, so five near-identical grays don't win
  final picked = <List<double>>[]; // [r,g,b]
  for (final e in ranked) {
    final c = [e[1] / e[0], e[2] / e[0], e[3] / e[0]];
    final farEnough = picked.every((q) {
      final dr = q[0] - c[0], dg = q[1] - c[1], db = q[2] - c[2];
      return dr * dr + dg * dg + db * db > 900; // ~30 per channel
    });
    if (farEnough) picked.add(c);
    if (picked.length == count) break;
  }
  // relax the spread if the photo is too uniform to fill the strip
  for (final e in ranked) {
    if (picked.length == count) break;
    final c = [e[1] / e[0], e[2] / e[0], e[3] / e[0]];
    if (!picked.any((q) => q[0] == c[0] && q[1] == c[1] && q[2] == c[2])) picked.add(c);
  }
  if (picked.isEmpty) return null;

  picked.sort((a, b) {
    double luma(List<double> c) => 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2];
    return luma(a).compareTo(luma(b));
  });
  return [for (final c in picked) Color.fromARGB(255, c[0].round(), c[1].round(), c[2].round())];
}
