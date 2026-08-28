import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:kata/features/share/photo_tools.dart';

void main() {
  // a 40×20 image: left half red, right half blue
  Uint8List sample() {
    final img = im.Image(width: 40, height: 20);
    for (var y = 0; y < 20; y++) {
      for (var x = 0; x < 40; x++) {
        img.setPixelRgb(x, y, x < 20 ? 255 : 0, 0, x < 20 ? 0 : 255);
      }
    }
    return Uint8List.fromList(im.encodePng(img));
  }

  test('rotate: a quarter turn swaps the sides', () {
    final out = im.decodeImage(rotatePhotoSync(sample()))!;
    expect((out.width, out.height), (20, 40));
  });

  test('flip: mirrors left and right', () {
    final out = im.decodeImage(flipPhotoSync(sample()))!;
    expect(out.getPixel(2, 10).b, greaterThan(200)); // blue now on the left
    expect(out.getPixel(37, 10).r, greaterThan(200));
  });

  test('crop: keeps the fraction asked for', () {
    final out = im.decodeImage(cropPhotoSync(sample(), const Rect.fromLTWH(0.5, 0, 0.5, 1)))!;
    expect((out.width, out.height), (20, 20));
    expect(out.getPixel(5, 5).b, greaterThan(200)); // only the blue half remains
  });

  test('undecodable bytes pass through untouched', () {
    final junk = Uint8List.fromList([1, 2, 3]);
    expect(rotatePhotoSync(junk), same(junk));
  });
}
