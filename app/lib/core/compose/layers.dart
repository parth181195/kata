import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'grain.dart';
import 'stickers.dart';

/// Shared composition base — kata share cards and Waku frames are the same
/// machine: a fixed, ordered stack of layers, bottom to top. Users never add,
/// remove, or reorder layers — each layer only offers the interactions its
/// frame gave it (place the photo, edit a text slot, drag the slots marked
/// draggable). Selection reveals those handles; it never adds abilities.
sealed class ComposeLayer {
  const ComposeLayer();
}

/// Backdrop or decoration painted by the frame. Never interactive. [grain]
/// textures the surface itself — a curation choice baked into the frame, not a
/// user control; the photo keeps whatever grain the camera gave it.
class ComposeSurface extends ComposeLayer {
  const ComposeSurface(this.child, {this.grain});
  final Widget child;
  final GrainSpec? grain;
}

/// The window the photo shows through. The photo's freedoms are placement
/// only — pan/zoom/straighten/flip live on the photo widget; the window's
/// geometry belongs to the frame.
class ComposePhotoWindow extends ComposeLayer {
  const ComposePhotoWindow({required this.rect, this.shadow});
  final Rect rect;
  final List<BoxShadow>? shadow;

  static const selectionId = 'photo';
}

/// An editable text slot. Lives inside [region]; when [draggable], the user
/// may slide it around within that region — nothing more.
class ComposeTextSlot extends ComposeLayer {
  const ComposeTextSlot(
      {required this.id,
      required this.region,
      required this.style,
      this.invitation = 'ADD A LINE',
      this.draggable = false,
      this.align = Alignment.center,
      this.maxLines = 1,
      this.maxChars = 40,
      this.scalable = false,
      this.minScale = 0.8,
      this.maxScale = 1.6,
      this.rotatable = false,
      this.maxAngle = 0.21,
      this.inkChoices = const []});
  final String id;
  final Rect region;
  final TextStyle style;
  final String invitation;
  final bool draggable;
  final Alignment align;
  /// Capacity is the frame's call: how many lines this spot holds, and how
  /// much ink fits before the pen runs off the paper.
  final int maxLines;
  final int maxChars;
  /// P2 handles — each one exists only where the frame grants it.
  final bool scalable;
  final double minScale;
  final double maxScale;
  final bool rotatable;
  /// Radians either way; the default is a handwriting tilt, not a rotation.
  final double maxAngle;
  /// Curated ink palette; empty = the frame's ink is fixed.
  final List<Color> inkChoices;
}

/// Renders a layer stack and routes the permitted interactions back up.
class ComposeCanvasView extends StatefulWidget {
  const ComposeCanvasView({
    super.key,
    required this.layers,
    required this.photo,
    required this.textOf,
    required this.dragOf,
    required this.editingId,
    required this.onTapText,
    required this.onDragText,
    required this.editorBuilder,
    required this.canvasSize,
    this.stickers = const [],
    this.onStickerChanged,
    this.scaleOf = _one,
    this.angleOf = _zero,
    this.inkOf = _noInk,
    this.onScaleText,
    this.onRotateText,
    this.selectedId,
    this.onSelect,
    this.chromeColor = const Color(0xFFFFFFFF),
    this.hideInvitations = false,
  });

  static double _one(String _) => 1;
  static double _zero(String _) => 0;
  static Color? _noInk(String _) => null;

  final Size canvasSize;
  /// Fasteners placed by the user within the frame's allowance. Rendered
  /// topmost — tape sits ON the print, like on the board.
  final List<StickerInstance> stickers;
  final void Function(String id, Offset posFraction, double angle)? onStickerChanged;
  final double Function(String id) scaleOf;
  final double Function(String id) angleOf;
  final Color? Function(String id) inkOf;
  /// Absolute, already clamped to the slot's declared range.
  final void Function(String id, double scale)? onScaleText;
  final void Function(String id, double angle)? onRotateText;

  final List<ComposeLayer> layers;
  final Widget photo;
  final String Function(String id) textOf;
  /// Drag offset for a slot, as fractions of its region (so it survives resize).
  final Offset Function(String id) dragOf;
  final String? editingId;
  final void Function(String id) onTapText;
  /// Reports the slot's new ABSOLUTE offset, as fractions of its region —
  /// snapping and frame-edge clamping have already been applied.
  final void Function(String id, Offset fraction) onDragText;
  final Widget Function(String id, ComposeTextSlot slot, TextStyle effective) editorBuilder;
  /// The selected element ('photo' or a slot id). Chrome renders only while
  /// set — exports pass null and rasterise clean.
  final String? selectedId;
  final void Function(String? id)? onSelect;
  final Color chromeColor;
  /// Export renders with the empty-slot invitations hidden.
  final bool hideInvitations;

  @override
  State<ComposeCanvasView> createState() => _ComposeCanvasViewState();
}

class _ComposeCanvasViewState extends State<ComposeCanvasView> {
  static const _snapTol = 6.0;
  static const _guideColor = Color(0xFFDB3B26); // the board's one hard red
  List<double> _vGuides = const [];
  List<double> _hGuides = const [];
  // The gesture accumulates on the RAW position; snapping only shapes what is
  // shown. Snapping the stored position instead glues the slot to the guide —
  // every new delta would restart from the snapped point and re-snap.
  Offset? _rawCenter;
  String? _dragId;

  List<ComposeLayer> get layers => widget.layers;
  Widget get photo => widget.photo;
  String Function(String id) get textOf => widget.textOf;
  Offset Function(String id) get dragOf => widget.dragOf;
  String? get editingId => widget.editingId;
  void Function(String id) get onTapText => widget.onTapText;
  Widget Function(String id, ComposeTextSlot slot, TextStyle effective) get editorBuilder => widget.editorBuilder;
  double _rawScale = 1;
  double _rawAngle = 0;
  String? _scaleId;
  String? _angleId;

  /// The slot's style with the user's ink and scale applied.
  TextStyle _effectiveStyle(ComposeTextSlot slot) {
    var st = slot.style;
    final ink = widget.inkOf(slot.id);
    if (ink != null) st = st.copyWith(color: ink);
    final sc = widget.scaleOf(slot.id);
    if (sc != 1 && st.fontSize != null) st = st.copyWith(fontSize: st.fontSize! * sc);
    return st;
  }

  void _scaleSlot(ComposeTextSlot slot, Offset delta) {
    if (_scaleId != slot.id) {
      _rawScale = widget.scaleOf(slot.id);
      _scaleId = slot.id;
    }
    _rawScale += (delta.dx + delta.dy) / 140;
    widget.onScaleText?.call(slot.id, _rawScale.clamp(slot.minScale, slot.maxScale));
  }

  void _rotateSlot(ComposeTextSlot slot, Offset delta) {
    if (_angleId != slot.id) {
      _rawAngle = widget.angleOf(slot.id);
      _angleId = slot.id;
    }
    _rawAngle += delta.dx / 120;
    var a = _rawAngle.clamp(-slot.maxAngle, slot.maxAngle);
    if (a.abs() < 0.03) a = 0; // snaps level, raw keeps accumulating
    widget.onRotateText?.call(slot.id, a);
  }

  void _endHandleDrag() {
    _scaleId = null;
    _angleId = null;
  }

  StickerInstance? _sticker(String? id) {
    if (id == null || !id.startsWith('sticker:')) return null;
    for (final st in widget.stickers) {
      if (st.id == id) return st;
    }
    return null;
  }

  void _dragSticker(StickerInstance st, Offset delta) {
    final cs = widget.canvasSize;
    final p = Offset((st.pos.dx + delta.dx / cs.width).clamp(0.0, 1.0), (st.pos.dy + delta.dy / cs.height).clamp(0.0, 1.0));
    widget.onStickerChanged?.call(st.id, p, st.angle);
  }

  void _rotateSticker(StickerInstance st, Offset delta) {
    if (_angleId != st.id) {
      _rawAngle = st.angle;
      _angleId = st.id;
    }
    _rawAngle += delta.dx / 90;
    var a = _rawAngle;
    if (a.abs() < 0.05) a = 0; // level snap, raw keeps accumulating
    widget.onStickerChanged?.call(st.id, st.pos, a);
  }
  String? get selectedId => widget.selectedId;
  void Function(String? id)? get onSelect => widget.onSelect;
  Color get chromeColor => widget.chromeColor;
  bool get hideInvitations => widget.hideInvitations;

  Rect? get _photoRect {
    for (final l in layers) {
      if (l is ComposePhotoWindow) return l.rect;
    }
    return null;
  }

  /// The slot's text metrics: [box] is the padded body (chrome, clamping),
  /// [ink] the glyphs' own extent — edge snaps align the INK to the photo,
  /// not the padding around it.
  (Size box, double inkL, double inkR) _slotSizes(ComposeTextSlot slot) {
    final text = textOf(slot.id).trim();
    final shown = (text.isEmpty ? slot.invitation : text).toUpperCase();
    final tp = TextPainter(
      text: TextSpan(text: shown, style: _effectiveStyle(slot)),
      maxLines: slot.maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: slot.region.width - 24);
    // tp.width includes the trailing letter-spacing after the last glyph, so
    // the painted ink is NOT centred in the layout box — it hangs left. Snap
    // by the ink's actual offsets from the body centre, from selection boxes.
    var inkL = -tp.width / 2;
    var inkR = tp.width / 2;
    final boxes = tp.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: shown.length));
    if (boxes.isNotEmpty) {
      var l = double.infinity, r = -double.infinity;
      for (final b in boxes) {
        l = math.min(l, b.left);
        r = math.max(r, b.right);
      }
      final spacing = _effectiveStyle(slot).letterSpacing ?? 0;
      inkL = l - tp.width / 2;
      inkR = (r - spacing) - tp.width / 2;
    }
    return (Size(tp.width + 20, tp.height + 12), inkL, inkR);
  }

  Size _slotTextSize(ComposeTextSlot slot) => _slotSizes(slot).$1;

  void _dragSlot(ComposeTextSlot slot, Offset delta) {
    final region = slot.region;
    final (size, inkL, inkR) = _slotSizes(slot);
    if (_dragId != slot.id || _rawCenter == null) {
      final current = dragOf(slot.id);
      _rawCenter = region.center + Offset(current.dx * region.width, current.dy * region.height);
      _dragId = slot.id;
    }
    _rawCenter = _rawCenter! + delta;
    var center = _rawCenter!;
    Offset next;
    final v = <double>[];
    final h = <double>[];
    final pr = _photoRect;
    if (pr != null) {
      // centre first, then edges — one snap per axis
      if ((center.dx - pr.center.dx).abs() < _snapTol) {
        center = Offset(pr.center.dx, center.dy);
        v.add(pr.center.dx);
      } else if ((center.dx + inkL - pr.left).abs() < _snapTol) {
        center = Offset(pr.left - inkL, center.dy);
        v.add(pr.left);
      } else if ((center.dx + inkR - pr.right).abs() < _snapTol) {
        center = Offset(pr.right - inkR, center.dy);
        v.add(pr.right);
      }
    }
    if ((center.dy - region.center.dy).abs() < _snapTol) {
      center = Offset(center.dx, region.center.dy);
      h.add(region.center.dy);
    }
    // the ink stays on the frame: clamp the text box inside the canvas
    final cs = widget.canvasSize;
    center = Offset(
      center.dx.clamp(size.width / 2 + 2, cs.width - size.width / 2 - 2),
      center.dy.clamp(size.height / 2 + 2, cs.height - size.height / 2 - 2),
    );
    next = Offset((center.dx - region.center.dx) / region.width, (center.dy - region.center.dy) / region.height);
    setState(() {
      _vGuides = v;
      _hGuides = h;
    });
    widget.onDragText(slot.id, next);
  }

  void _endDrag() => setState(() {
        _vGuides = const [];
        _hGuides = const [];
        _rawCenter = null;
        _dragId = null;
      });

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // tap on bare frame ground = deselect
      if (onSelect != null) Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onSelect!(null))),
      for (final l in layers)
        switch (l) {
          ComposeSurface(:final child, :final grain) => Positioned.fill(
              child: IgnorePointer(child: grain == null || grain.isOff ? child : GrainOverlay(spec: grain, child: child)),
            ),
          ComposePhotoWindow(:final rect, :final shadow) => Positioned.fromRect(
              rect: rect,
              child: _chromed(
                selected: selectedId == ComposePhotoWindow.selectionId,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: onSelect == null ? null : () => onSelect!(ComposePhotoWindow.selectionId),
                  child: shadow == null ? photo : DecoratedBox(decoration: BoxDecoration(boxShadow: shadow), child: photo),
                ),
              ),
            ),
          final ComposeTextSlot slot => _slot(slot),
        },
      for (final st in widget.stickers) _stickerView(st),
      if (_vGuides.isNotEmpty || _hGuides.isNotEmpty)
        Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _GuidePainter(_vGuides, _hGuides, _guideColor)))),
      ..._handleOverlay(),
      ..._stickerHandles(),
    ]);
  }

  Widget _stickerView(StickerInstance st) {
    final cs = widget.canvasSize;
    final size = st.type.size;
    final selected = selectedId == st.id;
    return Positioned(
      left: st.pos.dx * cs.width - size.width / 2,
      top: st.pos.dy * cs.height - size.height / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelect == null ? null : () => onSelect!(st.id),
        onPanUpdate: widget.onStickerChanged == null ? null : (d) => _dragSticker(st, d.delta),
        child: Transform.rotate(
          angle: st.angle,
          child: _chromed(selected: selected, child: StickerWidget(type: st.type, seed: st.seed)),
        ),
      ),
    );
  }

  List<Widget> _stickerHandles() {
    final st = _sticker(selectedId);
    if (st == null || hideInvitations || widget.onStickerChanged == null) return const [];
    final cs = widget.canvasSize;
    final top = st.pos.dy * cs.height - st.type.size.height / 2;
    return [
      Positioned(
        left: st.pos.dx * cs.width - 12,
        top: top - 30,
        child: GestureDetector(
          key: const ValueKey('sticker-rotate'),
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => _rotateSticker(st, d.delta),
          onPanEnd: (_) => _endHandleDrag(),
          onPanCancel: _endHandleDrag,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: chromeColor, border: Border.all(color: const Color(0x66000000), width: 0.5))),
              Container(width: 1, height: 7, color: chromeColor),
            ]),
          ),
        ),
      ),
    ];
  }

  /// The interactive handles for the active text slot, positioned in canvas
  /// space so every one of them is fully hit-testable.
  List<Widget> _handleOverlay() {
    if (hideInvitations) return const [];
    ComposeTextSlot? slot;
    for (final l in layers) {
      if (l is ComposeTextSlot && (selectedId == l.id || editingId == l.id)) slot = l;
    }
    if (slot == null) return const [];
    final editing = editingId == slot.id;
    final drag = dragOf(slot.id);
    final size = _slotTextSize(slot);
    final center = slot.region.center + Offset(drag.dx * slot.region.width, drag.dy * slot.region.height);
    final box = Rect.fromCenter(center: center, width: size.width, height: size.height);
    Widget handleDot({double w = 10, double h = 10, BoxShape shape = BoxShape.circle}) => Container(
        width: w, height: h, decoration: BoxDecoration(shape: shape, color: chromeColor, border: Border.all(color: const Color(0x66000000), width: 0.5)));
    return [
      if (editing && slot.draggable)
        Positioned(
          left: center.dx - 20,
          top: box.top - 22,
          child: GestureDetector(
            key: const ValueKey('slot-grip'),
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => _dragSlot(slot!, d.delta),
            onPanEnd: (_) => _endDrag(),
            onPanCancel: _endDrag,
            child: Container(
              width: 40,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: chromeColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0x66000000), width: 0.5)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x99000000))),
                ],
              ]),
            ),
          ),
        ),
      if (!editing && slot.rotatable)
        Positioned(
          left: center.dx - 12,
          top: box.top - 30,
          child: GestureDetector(
            key: const ValueKey('slot-rotate'),
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => _rotateSlot(slot!, d.delta),
            onPanEnd: (_) => _endHandleDrag(),
            onPanCancel: _endHandleDrag,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [handleDot(), Container(width: 1, height: 7, color: chromeColor)]),
            ),
          ),
        ),
      if (!editing && slot.scalable)
        Positioned(
          left: box.right - 10,
          top: box.bottom - 10,
          child: GestureDetector(
            key: const ValueKey('slot-scale'),
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => _scaleSlot(slot!, d.delta),
            onPanEnd: (_) => _endHandleDrag(),
            onPanCancel: _endHandleDrag,
            child: Padding(padding: const EdgeInsets.all(6), child: handleDot(w: 9, h: 9, shape: BoxShape.rectangle)),
          ),
        ),
    ];
  }

  /// Selection chrome: hairline box + corner ticks in the kata language.
  /// Purely visual — the interactive handles live on the canvas overlay,
  /// where the whole canvas is hit-testable (a Stack never hit-tests outside
  /// its own bounds, so handles hanging off the box would be unclickable).
  Widget _chromed({required bool selected, required Widget child}) {
    if (!selected) return child;
    Widget tick() => Container(width: 6, height: 6, decoration: BoxDecoration(color: chromeColor, border: Border.all(color: const Color(0x66000000), width: 0.5)));
    return Stack(clipBehavior: Clip.none, fit: StackFit.passthrough, children: [
      child,
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: chromeColor, width: 1))),
        ),
      ),
      for (final a in const [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight])
        Positioned.fill(child: IgnorePointer(child: Align(alignment: a, child: tick()))),
    ]);
  }

  Widget _slot(ComposeTextSlot slot) {
    final drag = dragOf(slot.id);
    final dx = drag.dx * slot.region.width;
    final dy = drag.dy * slot.region.height;
    final editing = editingId == slot.id;
    final selected = selectedId == slot.id;
    final text = textOf(slot.id).trim();
    final st = _effectiveStyle(slot);
    final Widget body;
    if (editing) {
      body = editorBuilder(slot.id, slot, st);
    } else if (text.isEmpty) {
      body = hideInvitations
          ? const SizedBox.shrink()
          : Text(slot.invitation, style: st.copyWith(color: (st.color ?? Colors.black).withValues(alpha: 0.32)));
    } else {
      body = Text(text.toUpperCase(), maxLines: slot.maxLines, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: st);
    }
    return Positioned.fromRect(
      rect: slot.region,
      child: ClipRect(
        clipBehavior: selected || editing ? Clip.none : Clip.hardEdge,
        child: Align(
          alignment: slot.align,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTapText(slot.id),
              onPanUpdate: slot.draggable && !editing ? (d) => _dragSlot(slot, d.delta) : null,
              onPanEnd: slot.draggable && !editing ? (_) => _endDrag() : null,
              onPanCancel: slot.draggable && !editing ? _endDrag : null,
              child: Transform.rotate(
                angle: widget.angleOf(slot.id),
                child: _chromed(
                  selected: selected || editing,
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: body),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _GuidePainter extends CustomPainter {
  _GuidePainter(this.v, this.h, this.color);
  final List<double> v;
  final List<double> h;
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 0.8;
    for (final x in v) {
      c.drawLine(Offset(x, 0), Offset(x, s.height), p);
    }
    for (final y in h) {
      c.drawLine(Offset(0, y), Offset(s.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter o) => o.v != v || o.h != h || o.color != color;
}
