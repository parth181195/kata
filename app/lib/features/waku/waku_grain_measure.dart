import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as im;

/// What the photograph's own grain measures, in the photo's own pixels.
///
/// The frame's texture is set from this: a print is one object, so the sheet
/// should carry the same grain the picture does — clean photo, clean sheet.
/// Inventing a "paper" texture instead is what made the sheet read as stucco
/// beside a smooth photograph (docs/design/waku-grain.md §7).
class PhotoGrain {
  const PhotoGrain({required this.clumpPx, required this.amount, required this.sourceWidth});

  /// Correlation length of the noise, in source pixels.
  final double clumpPx;

  /// Noise amplitude, 0..1 of full scale, measured on the flattest tiles.
  final double amount;

  /// The photo's own width, so the measurement can be scaled to however large
  /// the frame prints it.
  final int sourceWidth;

  static const none = PhotoGrain(clumpPx: 1.2, amount: 0.012, sourceWidth: 1);

  /// The grain as it lands on the sheet when the photo is drawn [renderedWidth]
  /// wide. Size scales with the magnification; amplitude follows Selwyn's law —
  /// granularity falls as 1/√area, so shrinking a photo smooths its grain.
  (double clump, double amount) onSheet(double renderedWidth) {
    final scale = sourceWidth <= 1 ? 1.0 : renderedWidth / sourceWidth;
    return (
      (clumpPx * scale).clamp(0.25, 6.0),
      (amount * math.sqrt(scale.clamp(0.02, 1.0))).clamp(0.004, 0.12),
    );
  }
}

Future<PhotoGrain> measurePhotoGrain(Uint8List bytes) => Isolate.run(() => measurePhotoGrainSync(bytes));

/// Measures the noise floor the way a granularity meter does: find the flattest
/// tiles (grain lives where the picture doesn't), high-pass them so the subject
/// drops out, then take the amplitude and the correlation length of what's left.
@pragma('vm:entry-point')
PhotoGrain measurePhotoGrainSync(Uint8List bytes) {
  try {
    final img = im.decodeImage(bytes);
    if (img == null) return PhotoGrain.none;
    final w = img.width, h = img.height;
    if (w < 96 || h < 96) return PhotoGrain.none;

    // luma at native scale — resampling would destroy the very thing we measure
    const tile = 96;
    final cols = math.min(5, w ~/ tile), rows = math.min(5, h ~/ tile);
    if (cols < 1 || rows < 1) return PhotoGrain.none;

    final candidates = <(double flatness, Float64List luma)>[];
    for (var ty = 0; ty < rows; ty++) {
      for (var tx = 0; tx < cols; tx++) {
        // spread the samples over the frame rather than clustering at a corner
        final ox = ((tx + 1) * w ~/ (cols + 1) - tile ~/ 2).clamp(0, w - tile);
        final oy = ((ty + 1) * h ~/ (rows + 1) - tile ~/ 2).clamp(0, h - tile);
        final lum = Float64List(tile * tile);
        for (var y = 0; y < tile; y++) {
          for (var x = 0; x < tile; x++) {
            final p = img.getPixel(ox + x, oy + y);
            lum[y * tile + x] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / 255.0;
          }
        }
        // flatness = mean |gradient| over a 4px step: edges and detail score high
        var grad = 0.0;
        for (var y = 0; y < tile; y++) {
          for (var x = 0; x + 4 < tile; x++) {
            grad += (lum[y * tile + x + 4] - lum[y * tile + x]).abs();
          }
        }
        candidates.add((grad / (tile * (tile - 4)), lum));
      }
    }
    candidates.sort((a, b) => a.$1.compareTo(b.$1));
    final flat = candidates.take(math.max(1, candidates.length ~/ 3)).toList();

    var amp = 0.0;
    var clump = 0.0;
    for (final (_, lum) in flat) {
      final hp = _highPass(lum, tile);
      var sq = 0.0;
      for (final v in hp) {
        sq += v * v;
      }
      final rms = math.sqrt(sq / hp.length);
      amp += rms;
      clump += _correlationLength(hp, tile);
    }
    amp /= flat.length;
    clump /= flat.length;

    return PhotoGrain(
      // a photo with no noise at all still gets a whisper, or the sheet is dead flat
      clumpPx: clump.clamp(0.6, 6.0),
      amount: amp.clamp(0.004, 0.14),
      sourceWidth: w,
    );
  } catch (_) {
    return PhotoGrain.none;
  }
}

/// Subtracts a 2px box blur: what's left is noise plus the finest detail.
Float64List _highPass(Float64List src, int n) {
  final blur = Float64List(n * n);
  const r = 2;
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      var acc = 0.0;
      var cnt = 0;
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          final sy = y + dy, sx = x + dx;
          if (sy < 0 || sy >= n || sx < 0 || sx >= n) continue;
          acc += src[sy * n + sx];
          cnt++;
        }
      }
      blur[y * n + x] = acc / cnt;
    }
  }
  final out = Float64List(n * n);
  for (var i = 0; i < out.length; i++) {
    out[i] = src[i] - blur[i];
  }
  return out;
}

/// First zero crossing of the horizontal autocorrelation, in pixels.
double _correlationLength(Float64List f, int n) {
  double lag(int d) {
    var acc = 0.0;
    var cnt = 0;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x + d < n; x++) {
        acc += f[y * n + x] * f[y * n + x + d];
        cnt++;
      }
    }
    return cnt == 0 ? 0 : acc / cnt;
  }

  final a0 = lag(0);
  if (a0 <= 0) return 1;
  var prev = 1.0;
  for (var d = 1; d < 12; d++) {
    final c = lag(d) / a0;
    if (c <= 0) return d - 1 + prev / (prev - c);
    prev = c;
  }
  return 12;
}
