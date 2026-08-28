import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:share_plus/share_plus.dart';


/// The render-and-deliver pipeline for the share cards. Rasterise a boundary, then hand the PNG to the platform's way of
/// getting a file to the user.

/// Renders [boundaryKey]'s RepaintBoundary to PNG. Pass [pixelRatio] to fix the
/// scale (the share cards do), or [targetShortSide] to hit a resolution
/// regardless of preview size.
Future<Uint8List> rasterizePng(
  GlobalKey boundaryKey, {
  double? pixelRatio,
  double targetShortSide = 2048,
  bool settle = true,
  Duration imageWait = const Duration(seconds: 8),
}) async {
  final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final ratio = pixelRatio ?? (targetShortSide / boundary.size.shortestSide).clamp(1.0, 6.0);
  try {
    if (settle) {
      // Every image under the boundary has to have decoded, or the first share
      // of a recipe ships a card with a grey box where its sample frame goes —
      // two frames of settling is a race against the network, and the network
      // usually wins. Bounded, so an offline device still gets its card, with
      // the placeholder it can actually see.
      await _imagesUnder(boundaryKey.currentContext!).timeout(imageWait, onTimeout: () {});
      // and a couple of frames so what arrived has painted
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
    }
    final img = await boundary.toImage(pixelRatio: ratio);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return bytes!.buffer.asUint8List();
  } finally {
    // nothing to restore
  }
}

/// Completes when every [Image] in [root]'s subtree has a decoded frame.
Future<void> _imagesUnder(BuildContext root) async {
  final providers = <ImageProvider>[];
  void walk(Element e) {
    final w = e.widget;
    if (w is Image) providers.add(w.image);
    e.visitChildren(walk);
  }

  root.visitChildElements(walk);
  if (providers.isEmpty) return;

  await Future.wait([
    for (final p in providers)
      () {
        final done = Completer<void>();
        final stream = p.resolve(createLocalImageConfiguration(root));
        late final ImageStreamListener l;
        l = ImageStreamListener(
          (_, _) {
            if (!done.isCompleted) done.complete();
            stream.removeListener(l);
          },
          onError: (_, _) {
            // a broken image is still a decided image: the card shows its fallback
            if (!done.isCompleted) done.complete();
            stream.removeListener(l);
          },
        );
        stream.addListener(l);
        return done.future;
      }(),
  ]);
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


/// Several files in one go — the framed photo and its code card. Mobile puts
/// both on one share sheet; desktop asks where to save each.
Future<bool> deliverPngs(BuildContext context, List<(String name, Uint8List png)> files, {String? subject, String? text}) async {
  if (_isDesktop) {
    var any = false;
    for (final (name, png) in files) {
      if (!context.mounted) return any;
      any = await deliverPng(context, png, name: name) || any;
    }
    return any;
  }
  await Share.shareXFiles([for (final (name, png) in files) XFile.fromData(png, name: name, mimeType: 'image/png')], subject: subject, text: text);
  return true;
}
