import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/compose/export.dart';
import 'card_templates.dart';

/// Renders a [ShareCard] off-screen at [pixelRatio] and returns PNG bytes.
/// Uses an overlay-less approach: a hidden RepaintBoundary inserted into the tree by the caller ([OffscreenCardHost]).
class CardRenderer {
  CardRenderer(this._key);
  final GlobalKey _key;

  Future<Uint8List> toPng({double pixelRatio = 3, bool settle = true}) =>
      rasterizePng(_key, pixelRatio: pixelRatio, settle: settle);
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
