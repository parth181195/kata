import 'package:flutter/material.dart';

import '../../core/compose/grain.dart';
import '../../core/compose/layers.dart';

/// The Waku gallery is curated: a frame ships only when it has something of
/// its own. One for now — the instant print. Each frame is a fixed layer
/// stack; what users may touch is declared per layer, never changed by them.
enum WakuFrame {
  polaroid('Polaroid'),
  custom('Custom');

  const WakuFrame(this.label);
  final String label;
}

/// Instant-print: bright white stock, tight even sides, the classic deep chin.
/// Layers, bottom → top: paper · photo window · the chin's hand-written line
/// (editable, and draggable along the chin like a real pen would wander).
List<ComposeLayer> polaroidLayers(Size size, double unit) {
  final m = unit * 0.72;
  final chin = unit * 2.9;
  return [
    // the stock itself has tooth — our call, per frame; users don't touch grain
    const ComposeSurface(ColoredBox(color: Color(0xFFFBFAF6)), grain: GrainSpec(strength: GrainStrength.weak, size: GrainSize.small)),
    ComposePhotoWindow(
      rect: Rect.fromLTRB(m, m * 1.15, size.width - m, size.height - chin),
      shadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 3, offset: Offset(0, 1))],
    ),
    ComposeTextSlot(
      id: 'chin',
      region: Rect.fromLTRB(m, size.height - chin, size.width - m, size.height),
      style: chinStyle(size),
      draggable: true,
      // a real chin holds about two handwritten lines before the pen falls off
      maxLines: 2,
      maxChars: 56,
    ),
  ];
}

/// Any image of yours as the frame. Surround mode: the image behind, the photo
/// floating inset on a shadow. Overlay mode (a PNG with a transparent window):
/// the photo fills and the frame draws over it.
List<ComposeLayer> customLayers(Size size, double unit, {required Widget frameImage, required bool overlay}) {
  if (overlay) {
    return [
      ComposePhotoWindow(rect: Offset.zero & size),
      ComposeSurface(frameImage),
    ];
  }
  final inset = unit * 1.4;
  return [
    ComposeSurface(frameImage),
    ComposePhotoWindow(
      rect: Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset),
      shadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 16, offset: Offset(0, 5))],
    ),
  ];
}

/// The chin text style at this canvas size — shared by label and inline editor
/// so the swap is invisible.
TextStyle chinStyle(Size size) => TextStyle(
      fontFamily: 'JetBrains Mono',
      package: 'kata_ui',
      fontSize: (size.shortestSide * 0.026).clamp(8.0, 17.0),
      fontWeight: FontWeight.w500,
      letterSpacing: 1.4,
      color: const Color(0xFF3A362E),
    );
