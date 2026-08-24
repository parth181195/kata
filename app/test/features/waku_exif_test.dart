import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:kata/features/waku/waku_exif.dart';

Uint8List _jpegWithExif() {
  final img = im.Image(width: 16, height: 12);
  final exif = img.exif;
  exif.imageIfd['Make'] = 'FUJIFILM';
  exif.imageIfd['Model'] = 'X-S20';
  exif.exifIfd['DateTimeOriginal'] = '2026:08:12 18:43:07';
  exif.exifIfd[0x8827] = 400; // ISOSpeedRatings
  exif.exifIfd[0x829D] = im.IfdValueRational(28, 10); // FNumber f/2.8
  exif.exifIfd[0x829A] = im.IfdValueRational(1, 250); // ExposureTime
  exif.exifIfd[0x920A] = im.IfdValueRational(23, 1); // FocalLength
  return Uint8List.fromList(im.encodeJpg(img));
}

void main() {
  _simChecks();
  test('EXIF: the camera facts come out of a JPEG', () async {
    final meta = await readPhotoMetaSync(_jpegWithExif());
    expect(meta.model, 'X-S20');
    expect(meta.make, 'FUJIFILM');
    expect(meta.iso, 400);
    expect(meta.fNumber, closeTo(2.8, 1e-9));
    expect(meta.exposure, '1/250');
    expect(meta.focalMm, closeTo(23, 1e-9));
    expect(meta.dateTime, DateTime(2026, 8, 12, 18, 43, 7));
    expect(meta.line, 'X-S20 · ISO 400 · f/2.8 · 1/250 · 23MM · 12/08 18:43');
  });

  test('EXIF: a bare image comes back empty, not a crash', () async {
    final bare = Uint8List.fromList(im.encodePng(im.Image(width: 4, height: 4)));
    final meta = await readPhotoMetaSync(bare);
    expect(meta.isEmpty, isTrue);
    expect(meta.line, '');
  });
}

void _simChecks() {
  test('Fuji film-sim mapping: FilmMode names, monochrome wins via Saturation', () {
    expect(fujiFilmSimName(0x600, 'Normal'), 'CLASSIC CHROME');
    expect(fujiFilmSimName(0x800, null), 'CLASSIC NEG');
    expect(fujiFilmSimName(null, 'None (B&W)'), 'MONOCHROME'); // package-named value
    expect(fujiFilmSimName(0x000, '1216'), 'ACROS'); // raw 0x4C0 — newer than the package's table
    expect(fujiFilmSimName(0x1234, 'Normal'), isNull); // unknown stays honest
  });
}
