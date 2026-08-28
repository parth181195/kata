import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as im;

/// Rotate, flip and crop are baked into the bytes: the card then draws a
/// plain photograph and the export needs no placement state. Each returns a
/// fresh JPEG; the original is kept by the caller for Reset.
Future<Uint8List> rotatePhoto(Uint8List bytes, {int quarterTurns = 1}) => Isolate.run(() => rotatePhotoSync(bytes, quarterTurns: quarterTurns));
Future<Uint8List> flipPhoto(Uint8List bytes) => Isolate.run(() => flipPhotoSync(bytes));
Future<Uint8List> cropPhoto(Uint8List bytes, Rect fraction) => Isolate.run(() => cropPhotoSync(bytes, fraction));

@pragma('vm:entry-point')
Uint8List rotatePhotoSync(Uint8List bytes, {int quarterTurns = 1}) {
  final src = _decode(bytes);
  if (src == null) return bytes;
  final out = im.copyRotate(src, angle: 90 * (quarterTurns % 4));
  return _jpeg(out);
}

@pragma('vm:entry-point')
Uint8List flipPhotoSync(Uint8List bytes) {
  final src = _decode(bytes);
  if (src == null) return bytes;
  return _jpeg(im.flipHorizontal(src));
}

/// [fraction] is the kept region as fractions of the image (0–1 on both axes).
@pragma('vm:entry-point')
Uint8List cropPhotoSync(Uint8List bytes, Rect fraction) {
  final src = _decode(bytes);
  if (src == null) return bytes;
  final l = (fraction.left.clamp(0.0, 1.0) * src.width).round();
  final t = (fraction.top.clamp(0.0, 1.0) * src.height).round();
  final w = (fraction.width.clamp(0.0, 1.0) * src.width).round().clamp(1, src.width - l);
  final h = (fraction.height.clamp(0.0, 1.0) * src.height).round().clamp(1, src.height - t);
  return _jpeg(im.copyCrop(src, x: l, y: t, width: w, height: h));
}

Uint8List _jpeg(im.Image img) => Uint8List.fromList(im.encodeJpg(img, quality: 92));

/// Decode, or null for bytes that aren't an image at all (the decoders throw on some).
im.Image? _decode(Uint8List bytes) {
  try {
    return im.decodeImage(bytes);
  } catch (_) {
    return null;
  }
}
