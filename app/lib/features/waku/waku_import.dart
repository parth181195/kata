import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as im;

/// What the Waku pickers accept. RAW support means pulling the embedded JPEG
/// preview out — every camera RAW carries one at (near) full resolution.
const wakuImportExtensions = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'raf', 'dng', 'nef', 'arw', 'cr2', 'cr3', 'orf', 'rw2', 'srw', 'pef', 'tif', 'tiff'];

/// Turns whatever the picker returned into bytes `Image.memory` can decode,
/// or null when nothing usable is inside. Heavy scans run off the UI isolate.
Future<Uint8List?> prepareWakuImage(Uint8List bytes) => Isolate.run(() => prepareWakuImageSync(bytes));

@pragma('vm:entry-point')
Uint8List? prepareWakuImageSync(Uint8List b) {
  if (b.length < 16) return null;
  if (_isNativelyDecodable(b)) return b;
  final raf = _rafPreview(b);
  if (raf != null) return raf;
  final jpeg = _largestEmbeddedJpeg(b);
  if (jpeg != null) return jpeg;
  if (_isTiff(b)) {
    // a plain TIFF (no preview to steal): decode and re-encode as PNG
    final t = im.decodeTiff(b);
    if (t != null) return Uint8List.fromList(im.encodePng(t));
  }
  return null;
}

bool _isNativelyDecodable(Uint8List b) {
  if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true; // JPEG
  if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return true; // PNG
  if (b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) return true; // WebP
  if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) return true; // GIF
  return false;
}

bool _isTiff(Uint8List b) =>
    (b[0] == 0x49 && b[1] == 0x49 && b[2] == 0x2A && b[3] == 0x00) || (b[0] == 0x4D && b[1] == 0x4D && b[2] == 0x00 && b[3] == 0x2A);

/// Fujifilm RAF: magic string, then big-endian JPEG-preview offset at 84 and
/// length at 88. The preview is the camera's own full-size JPEG.
Uint8List? _rafPreview(Uint8List b) {
  const magic = 'FUJIFILMCCD-RAW';
  if (b.length < 96) return null;
  for (var i = 0; i < magic.length; i++) {
    if (b[i] != magic.codeUnitAt(i)) return null;
  }
  final d = ByteData.sublistView(b);
  final off = d.getUint32(84);
  final len = d.getUint32(88);
  if (off <= 0 || len <= 16 || off + len > b.length) return null;
  if (b[off] != 0xFF || b[off + 1] != 0xD8) return null;
  return Uint8List.sublistView(b, off, off + len);
}

/// TIFF-based RAWs (DNG, NEF, ARW, CR2, …) and CR3 all embed one or more JPEG
/// previews. Walk the file for JPEG starts, size each candidate from its SOF
/// marker, and hand back the largest.
Uint8List? _largestEmbeddedJpeg(Uint8List b) {
  var bestArea = -1;
  var bestStart = -1;
  var bestEnd = -1;
  var i = 0;
  var candidates = 0;
  while (i < b.length - 4 && candidates < 64) {
    if (b[i] == 0xFF && b[i + 1] == 0xD8 && b[i + 2] == 0xFF) {
      final parsed = _walkJpeg(b, i);
      if (parsed != null) {
        candidates++;
        final (w, h, end) = parsed;
        final area = w * h;
        if (area > bestArea) {
          bestArea = area;
          bestStart = i;
          bestEnd = end;
        }
        i = end; // don't rediscover thumbnails inside this one
        continue;
      }
    }
    i++;
  }
  if (bestStart < 0) return null;
  return Uint8List.sublistView(b, bestStart, bestEnd);
}

/// Walks segment markers from a JPEG SOI. Returns (width, height, endOffset)
/// or null when the run isn't a plausible JPEG.
(int, int, int)? _walkJpeg(Uint8List b, int start) {
  var i = start + 2;
  var w = 0, h = 0;
  while (i + 4 <= b.length) {
    if (b[i] != 0xFF) return null;
    final marker = b[i + 1];
    if (marker == 0xD8) return null; // nested SOI: not a clean stream
    if (marker == 0xD9) return (w, h, i + 2); // EOI before SOS: header-only, unlikely
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    final len = (b[i + 2] << 8) | b[i + 3];
    if (len < 2 || i + 2 + len > b.length) return null;
    if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC) {
      // SOFn: precision(1) height(2) width(2)
      if (len >= 7) {
        h = (b[i + 5] << 8) | b[i + 6];
        w = (b[i + 7] << 8) | b[i + 8];
      }
    }
    if (marker == 0xDA) {
      // SOS: entropy-coded data until EOI
      var j = i + 2 + len;
      while (j + 1 < b.length) {
        if (b[j] == 0xFF && b[j + 1] == 0xD9) return (w, h, j + 2);
        j++;
      }
      return null;
    }
    i += 2 + len;
  }
  return null;
}
