import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Reads a Kata Code (or any QR payload) out of an image file's bytes.
///
/// Share cards are screenshots, photos of screens, or re-encoded exports, so a single decode
/// attempt is not enough: we try the image as-is, then progressively downscaled, then inverted
/// (light-on-dark cards are Kata's default). Returns null when nothing decodes.
String? decodeQrFromImageBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  // Big screenshots decode slowly and no better; cap the long edge.
  var base = decoded;
  const maxEdge = 1600;
  final longEdge = base.width > base.height ? base.width : base.height;
  if (longEdge > maxEdge) {
    base = img.copyResize(base, width: base.width >= base.height ? maxEdge : null, height: base.height > base.width ? maxEdge : null, interpolation: img.Interpolation.average);
  }
  for (final scale in const [1.0, 0.6, 0.4]) {
    final w = (base.width * scale).round();
    if (w < 40) continue;
    final scaled = scale == 1.0 ? base : img.copyResize(base, width: w, interpolation: img.Interpolation.average);
    for (final invert in const [false, true]) {
      final frame = invert ? img.invert(scaled.clone()) : scaled;
      final hit = _tryDecode(frame);
      if (hit != null) return hit;
    }
  }
  return null;
}

String? _tryDecode(img.Image frame) {
  final pixels = Int32List(frame.width * frame.height);
  var i = 0;
  for (var y = 0; y < frame.height; y++) {
    for (var x = 0; x < frame.width; x++) {
      final p = frame.getPixel(x, y);
      pixels[i++] = (0xFF << 24) | (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();
    }
  }
  try {
    final source = RGBLuminanceSource(frame.width, frame.height, pixels);
    final bitmap = BinaryBitmap(HybridBinarizer(source));
    final hints = DecodeHints()..put(DecodeHintType.tryHarder);
    return QRCodeReader().decode(bitmap, hints: hints).text;
  } catch (_) {
    return null;
  }
}
