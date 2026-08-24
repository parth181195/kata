import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as im;
import 'package:kata/features/waku/waku_import.dart';

Uint8List _jpeg({int w = 12, int h = 9}) => Uint8List.fromList(im.encodeJpg(im.Image(width: w, height: h)));
Uint8List _png() => Uint8List.fromList(im.encodePng(im.Image(width: 6, height: 6)));

void main() {
  test('native formats pass through untouched', () {
    final png = _png();
    expect(prepareWakuImageSync(png), same(png));
    final jpg = _jpeg();
    expect(prepareWakuImageSync(jpg), same(jpg));
  });

  test('RAF: the embedded JPEG preview is pulled out via the header offsets', () {
    final preview = _jpeg(w: 24, h: 18);
    final head = BytesBuilder();
    head.add('FUJIFILMCCD-RAW '.codeUnits);
    while (head.length < 84) {
      head.addByte(0);
    }
    const off = 200;
    head.add((ByteData(8)
          ..setUint32(0, off)
          ..setUint32(4, preview.length))
        .buffer
        .asUint8List());
    while (head.length < off) {
      head.addByte(0xEE);
    }
    head.add(preview);
    head.add(List.filled(64, 0xEE)); // trailing sensor data stand-in
    final out = prepareWakuImageSync(head.toBytes());
    expect(out, isNotNull);
    expect(out, equals(preview));
  });

  test('TIFF-based RAW: the largest embedded JPEG wins', () {
    final small = _jpeg(w: 8, h: 6);
    final large = _jpeg(w: 32, h: 24);
    final b = BytesBuilder();
    b.add([0x49, 0x49, 0x2A, 0x00]); // II TIFF magic, like a DNG
    b.add(List.filled(120, 0x11));
    b.add(small);
    b.add(List.filled(37, 0x22));
    b.add(large);
    b.add(List.filled(50, 0x33));
    final out = prepareWakuImageSync(b.toBytes());
    expect(out, isNotNull);
    expect(out, equals(large));
  });

  test('garbage comes back null, not a crash', () {
    expect(prepareWakuImageSync(Uint8List.fromList(List.filled(4096, 0xAB))), isNull);
    expect(prepareWakuImageSync(Uint8List(4)), isNull);
  });
}
