import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// The correlated grain tile, generated once per spec on the Dart side and
/// sampled by the overlay shader — the AV1-template architecture from
/// docs/design/waku-grain.md, with the tile's spectrum authored as a
/// difference of Gaussians (band-pass: clump energy, no flat white noise).
/// Convolution wraps, so the tile tiles seamlessly.
class GrainTemplate {
  /// The preview tile. Exports generate a larger one at a proportionally larger
  /// [grainPx], which resolves the same tooth more finely instead of shrinking
  /// it — see GrainOverlay.geometry.
  static const int size = 128;

  /// Deterministic: same (seed, grainPx, size) → identical bytes.
  /// [grainPx] is the clump size in TEMPLATE TEXELS; the shader maps texels to
  /// the sheet, so the size on paper comes out of the pair, not from this alone.
  static Float64List field({required int seed, required double grainPx, int size = GrainTemplate.size}) {
    final rnd = math.Random(seed);
    final n = size * size;
    final white = Float64List(n);
    for (var i = 0; i < n; i += 2) {
      // Box–Muller pair
      final u1 = math.max(rnd.nextDouble(), 1e-12);
      final u2 = rnd.nextDouble();
      final m = math.sqrt(-2 * math.log(u1));
      white[i] = m * math.cos(2 * math.pi * u2);
      if (i + 1 < n) white[i + 1] = m * math.sin(2 * math.pi * u2);
    }
    // band-pass: blur at the grain scale minus a wider blur
    final fine = _blur(white, grainPx * 0.55, size);
    final coarse = _blur(white, grainPx * 1.6, size);
    final out = Float64List(n);
    var mean = 0.0;
    for (var i = 0; i < n; i++) {
      out[i] = fine[i] - coarse[i];
      mean += out[i];
    }
    mean /= n;
    var varAcc = 0.0;
    for (var i = 0; i < n; i++) {
      out[i] -= mean;
      varAcc += out[i] * out[i];
    }
    final std = math.sqrt(varAcc / n);
    if (std > 0) {
      for (var i = 0; i < n; i++) {
        out[i] /= std; // unit variance, zero mean
      }
    }
    return out;
  }

  /// Separable Gaussian with wrap-around indexing (keeps the tile seamless).
  static Float64List _blur(Float64List src, double sigma, int size) {
    if (sigma < 0.3) return Float64List.fromList(src);
    final radius = math.max(1, (sigma * 3).ceil());
    final k = Float64List(2 * radius + 1);
    var sum = 0.0;
    for (var i = -radius; i <= radius; i++) {
      k[i + radius] = math.exp(-(i * i) / (2 * sigma * sigma));
      sum += k[i + radius];
    }
    for (var i = 0; i < k.length; i++) {
      k[i] /= sum;
    }
    final tmp = Float64List(size * size);
    final dst = Float64List(size * size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        var a = 0.0;
        for (var i = -radius; i <= radius; i++) {
          a += src[y * size + ((x + i) % size + size) % size] * k[i + radius];
        }
        tmp[y * size + x] = a;
      }
    }
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        var a = 0.0;
        for (var i = -radius; i <= radius; i++) {
          a += tmp[(((y + i) % size + size) % size) * size + x] * k[i + radius];
        }
        dst[y * size + x] = a;
      }
    }
    return dst;
  }

  /// Encodes the field as a gray image: 0.5 = zero, std mapped to ~0.22 so
  /// ±2.3σ fits without clipping. The shader recovers g = (tex − 0.5)/0.22.
  static Uint8List bytes({required int seed, required double grainPx, int size = GrainTemplate.size}) {
    final f = field(seed: seed, grainPx: grainPx, size: size);
    final out = Uint8List(size * size * 4);
    for (var i = 0; i < f.length; i++) {
      final v = (127.5 + f[i] * 0.22 * 255).round().clamp(0, 255);
      out[i * 4] = v;
      out[i * 4 + 1] = v;
      out[i * 4 + 2] = v;
      out[i * 4 + 3] = 255;
    }
    return out;
  }

  static Future<ui.Image> image({required int seed, required double grainPx, int size = GrainTemplate.size}) async {
    // Export tiles are big enough to stutter the UI isolate (the blur radius
    // grows with grainPx); the preview tile stays inline so widget tests and
    // first paint don't wait on an isolate spawn.
    final data = size > GrainTemplate.size
        ? await Isolate.run(() => bytes(seed: seed, grainPx: grainPx, size: size))
        : bytes(seed: seed, grainPx: grainPx, size: size);
    final buf = await ui.ImmutableBuffer.fromUint8List(data);
    final desc = ui.ImageDescriptor.raw(buf, width: size, height: size, pixelFormat: ui.PixelFormat.rgba8888);
    final codec = await desc.instantiateCodec();
    final frame = await codec.getNextFrame();
    codec.dispose();
    desc.dispose();
    buf.dispose();
    return frame.image;
  }
}
