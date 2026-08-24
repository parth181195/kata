import 'package:flutter/material.dart';

import 'grain.dart';

/// Shared composition base — kata share cards and Waku frames are the same
/// machine: a fixed, ordered stack of
/// layers, bottom to top. Users never add, remove, or reorder layers — each
/// layer only offers the interactions its frame gave it (pan/zoom the photo,
/// edit a text slot, drag the slots marked draggable).
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

/// The window the photo shows through. Interaction (pan/pinch) belongs to the
/// photo widget itself.
class ComposePhotoWindow extends ComposeLayer {
  const ComposePhotoWindow({required this.rect, this.shadow});
  final Rect rect;
  final List<BoxShadow>? shadow;
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
  /// Export renders with the empty-slot invitations hidden.
  final bool hideInvitations;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      for (final l in layers)
        switch (l) {
          ComposeSurface(:final child, :final grain) => Positioned.fill(
              child: IgnorePointer(child: grain == null || grain.isOff ? child : GrainOverlay(spec: grain, child: child)),
            ),
          ComposePhotoWindow(:final rect, :final shadow) => Positioned.fromRect(
              rect: rect,
              child: shadow == null ? photo : DecoratedBox(decoration: BoxDecoration(boxShadow: shadow), child: photo),
            ),
          final ComposeTextSlot slot => _slot(slot),
        },
    ]);
  }

  Widget _slot(ComposeTextSlot slot) {
    final drag = dragOf(slot.id);
    final dx = drag.dx * slot.region.width;
    final dy = drag.dy * slot.region.height;
    final editing = editingId == slot.id;
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
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: body),
            ),
          ),
        ),
      ),
    );
  }
}
