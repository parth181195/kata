import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'grain.dart';

/// The one render-and-deliver pipeline: kata share cards and Waku frames both
/// end here. Rasterise a boundary, then hand the PNG to the platform's way of
/// getting a file to the user.

/// Renders [boundaryKey]'s RepaintBoundary to PNG. Pass [pixelRatio] to fix the
/// scale (the share cards do), or [targetShortSide] to hit a resolution
/// regardless of preview size (Waku does).
Future<Uint8List> rasterizePng(GlobalKey boundaryKey, {double? pixelRatio, double targetShortSide = 2048, bool settle = true}) async {
  final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ratio = pixelRatio ?? (targetShortSide / boundary.size.shortestSide).clamp(1.0, 6.0);
  try {
    // the sheet's tooth keeps its size; the export just resolves it finer, and
    // that finer tile has to exist before we rasterise
    GrainOverlay.rasterScale.value = ratio;
    await GrainOverlay.ready();
    if (settle) {
      // wait a couple of frames so images and the re-scaled grain have painted
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
    }
    final img = await boundary.toImage(pixelRatio: ratio);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return bytes!.buffer.asUint8List();
  } finally {
    GrainOverlay.rasterScale.value = 1;
  }
}

bool get _isDesktop => !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);

/// Desktop gets a save dialog (no OS share sheet there); everything else gets
/// the share sheet. Returns false when the user cancelled the save.
Future<bool> deliverPng(BuildContext context, Uint8List png, {required String name, String? subject, String? text}) async {
  if (_isDesktop) {
    // no `bytes:` here — the macOS picker throws on it; we write the file ourselves
    final path = await FilePicker.platform.saveFile(dialogTitle: 'Save $name', fileName: name);
    if (path == null) return false; // cancelled
    await File(path).writeAsBytes(png);
    if (context.mounted) KataToast.show(context, 'Saved $name');
    return true;
  }
  await Share.shareXFiles([XFile.fromData(png, name: name, mimeType: 'image/png')], subject: subject, text: text);
  return true;
}
