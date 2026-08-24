import 'package:flutter/material.dart';

import 'grain.dart';

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
      {required this.id, required this.region, required this.style, this.invitation = 'ADD A LINE', this.draggable = false, this.align = Alignment.center, this.maxLines = 1, this.maxChars = 40});
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
    this.selectedId,
    this.onSelect,
    this.chromeColor = const Color(0xFFFFFFFF),
    this.hideInvitations = false,
  });

  final Size canvasSize;

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
  final Widget Function(String id, ComposeTextSlot slot) editorBuilder;
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
  static const _snapTol = 5.0;
  static const _guideColor = Color(0xFFDB3B26); // the board's one hard red
  List<double> _vGuides = const [];
  List<double> _hGuides = const [];

  List<ComposeLayer> get layers => widget.layers;
  Widget get photo => widget.photo;
  String Function(String id) get textOf => widget.textOf;
  Offset Function(String id) get dragOf => widget.dragOf;
  String? get editingId => widget.editingId;
  void Function(String id) get onTapText => widget.onTapText;
  Widget Function(String id, ComposeTextSlot slot) get editorBuilder => widget.editorBuilder;
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

  /// Where the slot's text actually is and how big: needed for edge snapping
  /// and for keeping the ink inside the frame.
  Size _slotTextSize(ComposeTextSlot slot) {
    final text = textOf(slot.id).trim();
    final tp = TextPainter(
      text: TextSpan(text: (text.isEmpty ? slot.invitation : text).toUpperCase(), style: slot.style),
      maxLines: slot.maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: slot.region.width - 24);
    return Size(tp.width + 20, tp.height + 12); // + body padding
  }

  void _dragSlot(ComposeTextSlot slot, Offset delta) {
    final region = slot.region;
    final current = dragOf(slot.id);
    var next = Offset(current.dx + delta.dx / region.width, current.dy + delta.dy / region.height);
    final size = _slotTextSize(slot);
    var center = region.center + Offset(next.dx * region.width, next.dy * region.height);
    final v = <double>[];
    final h = <double>[];
    final pr = _photoRect;
    if (pr != null) {
      // centre first, then edges — one snap per axis
      if ((center.dx - pr.center.dx).abs() < _snapTol) {
        center = Offset(pr.center.dx, center.dy);
        v.add(pr.center.dx);
      } else if ((center.dx - size.width / 2 - pr.left).abs() < _snapTol) {
        center = Offset(pr.left + size.width / 2, center.dy);
        v.add(pr.left);
      } else if ((center.dx + size.width / 2 - pr.right).abs() < _snapTol) {
        center = Offset(pr.right - size.width / 2, center.dy);
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
      if (_vGuides.isNotEmpty || _hGuides.isNotEmpty)
        Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _GuidePainter(_vGuides, _hGuides, _guideColor)))),
    ]);
  }

  /// Selection chrome: hairline box + corner ticks in the kata language.
  /// Mostly visual — abilities stay with the layer underneath. While the
  /// inline editor is open the text body belongs to the cursor, so a [grip]
  /// above the box carries the move affordance instead.
  Widget _chromed({required bool selected, required Widget child, void Function(Offset delta)? grip, VoidCallback? onGripEnd}) {
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
      if (grip != null)
        Positioned(
          top: -18,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              key: const ValueKey('slot-grip'),
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => grip(d.delta),
              onPanEnd: (_) => onGripEnd?.call(),
              onPanCancel: () => onGripEnd?.call(),
              child: Container(
                width: 34,
                height: 13,
                decoration: BoxDecoration(color: chromeColor, borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0x66000000), width: 0.5)),
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 3),
                      Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x99000000))),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _slot(ComposeTextSlot slot) {
    final drag = dragOf(slot.id);
    final dx = drag.dx * slot.region.width;
    final dy = drag.dy * slot.region.height;
    final editing = editingId == slot.id;
    final selected = selectedId == slot.id;
    final text = textOf(slot.id).trim();
    final Widget body;
    if (editing) {
      body = editorBuilder(slot.id, slot);
    } else if (text.isEmpty) {
      body = hideInvitations
          ? const SizedBox.shrink()
          : Text(slot.invitation, style: slot.style.copyWith(color: (slot.style.color ?? Colors.black).withValues(alpha: 0.32)));
    } else {
      body = Text(text.toUpperCase(), maxLines: slot.maxLines, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: slot.style);
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
              child: _chromed(
                selected: selected || editing,
                // editing: the text field owns the body, the grip keeps the move
                grip: editing && slot.draggable ? (d) => _dragSlot(slot, d) : null,
                onGripEnd: _endDrag,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: body),
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
