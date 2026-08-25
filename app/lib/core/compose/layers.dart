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

/// The stock's tooth. Frames lay it twice: once over the bare ground at full
/// weight, and once over everything printed on it at a third of that, skipping
/// the photograph — ink fills a paper's texture rather than erasing it, and the
/// picture already carries the camera's grain.
class ComposeGrainSheet extends ComposeLayer {
  const ComposeGrainSheet(this.spec, {this.overInk = false});
  final GrainSpec spec;

  /// Lay it over what's already printed instead of under it, skipping the
  /// photograph — that one arrived with the camera's own grain in it.
  final bool overInk;
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
      this.inkChoices = const [],
      this.prefill,
      this.uppercase = true,
      this.fitRegion = false});
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
  /// Auto-filled content (EXIF-fed) shown in full ink and exported — unlike
  /// the invitation — until the user types their own. Editing seeds from it.
  final String? prefill;
  /// Museum labels aren't shouty: slots may keep their case.
  final bool uppercase;

  /// Shrink the type until the line fits its region. A poster title is set to
  /// the sheet, not to a point size: two words at 105pt and five words at 60pt
  /// are the same design, and neither may run into the photograph.
  final bool fitRegion;
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
    this.selectedId,
    this.onSelect,
    this.chromeColor = const Color(0xFFFFFFFF),
    this.hideInvitations = false,
    this.grain = true,
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

  /// Paint the frame's grain. It covers the whole sheet through an overlay
  /// blend, which is a full-canvas composite on every frame — too much to carry
  /// while someone is dragging a photo around. Waku leaves it off in the
  /// preview and switches it on for the one frame it rasterises.
  final bool grain;

  /// A slot's breathing room, from the type it holds — a frame's grid is built
  /// out of line heights, so a fixed 10px would blow a thumbnail's rows apart
  /// and pinch a poster's. Capped so a 200pt title doesn't get 70px of air.
  static EdgeInsets padFor(TextStyle st) {
    final f = st.fontSize ?? 12;
    return EdgeInsets.symmetric(horizontal: (f * 0.35).clamp(3.0, 12.0), vertical: (f * 0.18).clamp(2.0, 8.0));
  }

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
  double _rawAngle = 0;
  String? _angleId;

  /// The slot's style with the user's ink and scale applied, shrunk to the
  /// region when the frame asked for that.
  TextStyle _effectiveStyle(ComposeTextSlot slot) {
    var st = slot.style;
    final ink = widget.inkOf(slot.id);
    if (ink != null) st = st.copyWith(color: ink);
    final sc = widget.scaleOf(slot.id) * _fitScale(slot, st);
    if (sc != 1 && st.fontSize != null) st = st.copyWith(fontSize: st.fontSize! * sc);
    return st;
  }

  /// Largest fraction of the base size at which the slot's text still fits its
  /// region, by bisection. Cheap enough: short strings, and only slots that ask.
  double _fitScale(ComposeTextSlot slot, TextStyle st) {
    if (!slot.fitRegion || st.fontSize == null) return 1;
    final text = textOf(slot.id).trim();
    final base = text.isEmpty ? (slot.prefill?.trim().isNotEmpty == true ? slot.prefill!.trim() : slot.invitation) : text;
    final shown = slot.uppercase ? base.toUpperCase() : base;
    if (shown.isEmpty) return 1;
    final pad = ComposeCanvasView.padFor(st);
    final maxW = slot.region.width - pad.horizontal, maxH = slot.region.height - pad.vertical;
    bool fits(double f) {
      final tp = TextPainter(
        text: TextSpan(text: shown, style: st.copyWith(fontSize: st.fontSize! * f)),
        maxLines: slot.maxLines,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxW);
      return !tp.didExceedMaxLines && tp.height <= maxH && tp.width <= maxW;
    }

    if (fits(1)) return 1;
    var lo = 0.3, hi = 1.0;
    for (var i = 0; i < 10; i++) {
      final mid = (lo + hi) / 2;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  void _endHandleDrag() => _angleId = null;

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
    final base = text.isEmpty ? (slot.prefill?.trim().isNotEmpty == true ? slot.prefill!.trim() : slot.invitation) : text;
    final shown = slot.uppercase ? base.toUpperCase() : base;
    final st = _effectiveStyle(slot);
    final pad = ComposeCanvasView.padFor(st);
    final tp = TextPainter(
      text: TextSpan(text: shown, style: st),
      maxLines: slot.maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: slot.region.width - pad.horizontal);
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
      final spacing = st.letterSpacing ?? 0;
      inkL = l - tp.width / 2;
      inkR = (r - spacing) - tp.width / 2;
    }
    return (Size(tp.width + pad.horizontal, tp.height + pad.vertical), inkL, inkR);
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
              child: IgnorePointer(child: grain == null || grain.isOff || !widget.grain ? child : GrainOverlay(spec: grain, child: child)),
            ),
          ComposeGrainSheet(:final spec, :final overInk) => Positioned.fill(
              child: IgnorePointer(
                child: spec.isOff || !widget.grain
                    ? const SizedBox.shrink()
                    : ClipPath(
                        // the ground pass covers the sheet; the ink pass skips
                        // the photograph, which brought its own grain
                        clipper: _ExceptRect(overInk ? _photoRect : null),
                        child: GrainOverlay(spec: spec, child: const SizedBox.expand()),
                      ),
              ),
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

  /// The move grip for the active text slot, positioned in canvas space so it
  /// stays hit-testable outside the slot's own box. Size and tilt are not here:
  /// handles on a print fight the drag that places the line, and a panel
  /// control can say what it is doing. The frame still decides whether a slot
  /// may be scaled or tilted at all — [ComposeTextSlot.scalable] / [rotatable].
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
    final prefill = slot.prefill?.trim() ?? '';
    final ta = slot.align.x < 0 ? TextAlign.left : (slot.align.x > 0 ? TextAlign.right : TextAlign.center);
    final Widget body;
    if (editing) {
      body = editorBuilder(slot.id, slot, st);
    } else if (text.isEmpty && prefill.isNotEmpty) {
      body = Text(slot.uppercase ? prefill.toUpperCase() : prefill, maxLines: slot.maxLines, overflow: TextOverflow.ellipsis, textAlign: ta, style: st);
    } else if (text.isEmpty) {
      body = hideInvitations
          ? const SizedBox.shrink()
          : Text(slot.invitation, style: st.copyWith(color: (st.color ?? Colors.black).withValues(alpha: 0.32)));
    } else {
      body = Text(slot.uppercase ? text.toUpperCase() : text, maxLines: slot.maxLines, overflow: TextOverflow.ellipsis, textAlign: ta, style: st);
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
                  child: Padding(padding: ComposeCanvasView.padFor(st), child: body),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Everything but [hole] — the sheet minus its window.
class _ExceptRect extends CustomClipper<Path> {
  _ExceptRect(this.hole);
  final Rect? hole;

  @override
  Path getClip(Size size) {
    final p = Path()..addRect(Offset.zero & size);
    if (hole != null) {
      p
        ..addRect(hole!)
        ..fillType = PathFillType.evenOdd;
    }
    return p;
  }

  @override
  bool shouldReclip(_ExceptRect o) => o.hole != hole;
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
