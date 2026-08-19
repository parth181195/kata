import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'card_templates.dart';

/// Renders a [ShareCard] off-screen at [pixelRatio] and returns PNG bytes.
/// Uses an overlay-less approach: a hidden RepaintBoundary inserted into the tree by the caller ([OffscreenCardHost]).
class CardRenderer {
  CardRenderer(this._key);
  final GlobalKey _key;

  Future<Uint8List> toPng({double pixelRatio = 3, bool settle = true}) async {
    if (settle) {
      // wait for images (network) to settle a couple of frames
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
    }
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return bytes!.buffer.asUint8List();
  }
}

/// Hosts the full-size card under a RepaintBoundary. Shown scaled in the composer; the same boundary is rasterised for export.
class OffscreenCardHost extends StatelessWidget {
  const OffscreenCardHost({super.key, required this.boundaryKey, required this.spec, required this.scale});
  final GlobalKey boundaryKey;
  final ShareSpec spec;
  final double scale;
  @override
  Widget build(BuildContext context) {
    final h = kCardWidth / spec.ratio.aspect;
    return SizedBox(
      width: kCardWidth * scale,
      height: h * scale,
      child: FittedBox(
        fit: BoxFit.contain,
        child: RepaintBoundary(key: boundaryKey, child: ShareCard(spec)),
      ),
    );
  }
}
