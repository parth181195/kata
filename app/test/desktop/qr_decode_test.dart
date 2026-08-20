import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kata/desktop/qr_decode.dart';
import 'package:ofr/ofr.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _kodachrome = OfrRecipe(
    name: 'Kodachrome 64', sensors: ['X-Trans IV'], filmSimulation: 'Classic Chrome', dynamicRange: 'DR400',
    dRangePriority: 'Off', grainRoughness: 'Weak', grainSize: 'Small', whiteBalance: 'Daylight',
    whiteBalanceRed: 2, whiteBalanceBlue: -5, highlight: -1, shadow: 0.5, color: 2, sharpness: -2, highIsoNr: -4, clarity: 0);

/// Renders a real QR the same way the share card does, then hands the PNG bytes to the decoder.
Future<Uint8List> _qrPng(String payload, {double size = 480}) async {
  final painter = QrPainter(
    data: payload,
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF000000)),
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, size, size), Paint()..color = const Color(0xFFFFFFFF));
  canvas.save();
  canvas.translate(size * 0.1, size * 0.1);
  painter.paint(canvas, Size(size * 0.8, size * 0.8));
  canvas.restore();
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.round(), size.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodes a Kata Code out of a rendered QR image', () async {
    final payload = KataCode.encode(_kodachrome, credit: 'parth');
    final png = await _qrPng(payload);
    final read = decodeQrFromImageBytes(png);
    expect(read, payload);
    final round = KataCode.decode(read!).recipe;
    expect(round.filmSimulation, 'Classic Chrome');
    expect(round.whiteBalanceBlue, -5);
  });

  test('decodes an inverted (light-on-dark) card', () async {
    final payload = KataCode.encode(_kodachrome);
    final png = await _qrPng(payload);
    final inverted = img.encodePng(img.invert(img.decodePng(png)!));
    expect(decodeQrFromImageBytes(Uint8List.fromList(inverted)), payload);
  });

  test('returns null for an image with no code', () async {
    final blank = img.encodePng(img.Image(width: 200, height: 200)..clear(img.ColorRgb8(20, 20, 20)));
    expect(decodeQrFromImageBytes(Uint8List.fromList(blank)), isNull);
  });
}
