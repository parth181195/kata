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
  const OffscreenCardHost({super.key, required this.boundaryKey, required this.spec, required this.scale, this.imageFor});
  final GlobalKey boundaryKey;
  final ShareSpec spec;
  final double scale;

  /// Test seam: overrides how the card's sample frames are fetched.
  final ImageProvider Function(String url)? imageFor;
  @override
  Widget build(BuildContext context) {
    final effective = imageFor == null
        ? spec
        : ShareSpec(recipe: spec.recipe, template: spec.template, page: spec.page, inverted: spec.inverted, outline: spec.outline, roundCorners: spec.roundCorners, embedCode: spec.embedCode, credit: spec.credit, imageFor: imageFor!, photos: spec.photos, photoOffset: spec.photoOffset, photoZoom: spec.photoZoom, photoSize: spec.photoSize, camera: spec.camera);
    // The outer boundary caches the scaled composite as one layer. Without it
    // the full-size boundary is re-rasterised through the FittedBox on every
    // scroll frame, which on macOS came out as torn vertical streaks.
    // width only: page 1 is as tall as it needs, and the FittedBox scales the
    // card's natural size to the width, whatever its height turns out to be
    return RepaintBoundary(
      child: SizedBox(
        width: kCardWidth * scale,
        child: FittedBox(
          fit: BoxFit.contain,
          child: RepaintBoundary(key: boundaryKey, child: ShareCard(effective)),
        ),
      ),
    );
  }
}
