import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/waku/dev_roll_grid.dart';
import 'features/waku/frames/frame.dart';
import 'features/waku/waku_exif.dart';
import 'features/waku/waku_grain_measure.dart';
import 'features/waku/waku_palette.dart';
const _photo = '/home/parth/WebstormProjects/fuji/web/landing/img/hero-1.jpg';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final bytes = File(_photo).readAsBytesSync();
  final meta = await readPhotoMeta(bytes);
  final palette = await extractPalette(bytes) ?? const <Color>[];
  final grain = await measurePhotoGrain(bytes);
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DevRollGrid(
      photo: bytes,
      meta: meta.isEmpty ? const PhotoMeta(model: 'X-S20', iso: 400, filmMode: 'CLASSIC CHROME') : meta,
      palette: palette,
      grain: grain,
      object: kObjects.firstWhere((o) => o.id == 'negative'),
    ),
  ));
}
