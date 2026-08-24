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
  const ComposeTextSlot({required this.id, required this.region, required this.style, this.invitation = 'ADD A LINE', this.draggable = false, this.align = Alignment.center});
  final String id;
  final Rect region;
  final TextStyle style;
  final String invitation;
  final bool draggable;
  final Alignment align;
}

/// Renders a layer stack and routes the permitted interactions back up.
class ComposeCanvasView extends StatelessWidget {
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
    this.selectedId,
    this.onSelect,
    this.chromeColor = const Color(0xFFFFFFFF),
    this.hideInvitations = false,
  });

  final List<ComposeLayer> layers;
  final Widget photo;
  final String Function(String id) textOf;
  /// Drag offset for a slot, as fractions of its region (so it survives resize).
  final Offset Function(String id) dragOf;
  final String? editingId;
  final void Function(String id) onTapText;
  final void Function(String id, Offset fractionDelta) onDragText;
  final Widget Function(String id, ComposeTextSlot slot) editorBuilder;
  /// The selected element ('photo' or a slot id). Chrome renders only while
  /// set — exports pass null and rasterise clean.
  final String? selectedId;
  final void Function(String? id)? onSelect;
  final Color chromeColor;
  /// Export renders with the empty-slot invitations hidden.
  final bool hideInvitations;

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
    ]);
  }

  /// Selection chrome: hairline box + corner ticks in the kata language.
  /// Mostly visual — abilities stay with the layer underneath. While the
  /// inline editor is open the text body belongs to the cursor, so a [grip]
  /// above the box carries the move affordance instead.
  Widget _chromed({required bool selected, required Widget child, void Function(Offset delta)? grip}) {
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
      body = Text(text.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: slot.style);
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
              onPanUpdate: slot.draggable && !editing
                  ? (d) => onDragText(slot.id, Offset(d.delta.dx / slot.region.width, d.delta.dy / slot.region.height))
                  : null,
              child: _chromed(
                selected: selected || editing,
                // editing: the text field owns the body, the grip keeps the move
                grip: editing && slot.draggable ? (d) => onDragText(slot.id, Offset(d.dx / slot.region.width, d.dy / slot.region.height)) : null,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: body),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
