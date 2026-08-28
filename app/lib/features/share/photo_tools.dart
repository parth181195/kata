import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as im;

/// Rotate and flip are baked into the bytes — the card then draws a plain
/// photograph. (Placement — where it sits, how far in — is the spec's, not the
/// bytes'.) Each returns a fresh JPEG; the original is kept by the caller.
Future<Uint8List> rotatePhoto(Uint8List bytes, {int quarterTurns = 1}) => Isolate.run(() => rotatePhotoSync(bytes, quarterTurns: quarterTurns));
Future<Uint8List> flipPhoto(Uint8List bytes) => Isolate.run(() => flipPhotoSync(bytes));

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

Uint8List _jpeg(im.Image img) => Uint8List.fromList(im.encodeJpg(img, quality: 92));

/// Decode, or null for bytes that aren't an image at all (the decoders throw on some).
im.Image? _decode(Uint8List bytes) {
  try {
    return im.decodeImage(bytes);
  } catch (_) {
    return null;
  }
}
