import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';

import 'card_templates.dart';

/// Page 1 on a page of its own: drag the photograph in its frame, pinch (or
/// scroll) to zoom, never past the photo's own edge. Pops with (offset, zoom);
/// Reset puts it back to centred at 1×.
class PlacePhotoScreen extends StatefulWidget {
  const PlacePhotoScreen({super.key, required this.spec, required this.offset, required this.zoom});
  final ShareSpec spec;
  final Offset offset;
  final double zoom;
  @override
  State<PlacePhotoScreen> createState() => _PlacePhotoScreenState();
}

class _PlacePhotoScreenState extends State<PlacePhotoScreen> {
  late Offset _offset = widget.offset;
  late double _zoom = widget.zoom;
  Offset _dragStart = Offset.zero, _offsetStart = Offset.zero;
  double _zoomStart = 1;

  ShareSpec get _spec => ShareSpec(
        recipe: widget.spec.recipe,
        template: widget.spec.template,
        page: SharePage.photo,
        inverted: widget.spec.inverted,
        outline: widget.spec.outline,
        roundCorners: widget.spec.roundCorners,
        embedCode: widget.spec.embedCode,
        credit: widget.spec.credit,
        imageFor: widget.spec.imageFor,
        photos: widget.spec.photos,
        photoOffset: _offset,
        photoZoom: _zoom,
        photoSize: widget.spec.photoSize,
        camera: widget.spec.camera,
      );

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final size = MediaQuery.sizeOf(context);
    // the card as large as the screen allows, with room for the row beneath
    final shown = ((size.width - 32) / kCardWidth).clamp(0.2, 2.0);
    final changed = _offset != Offset.zero || _zoom != 1;
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(children: [
              KataIconCircle(size: 36, onPressed: () => Navigator.of(context).pop(), child: Icon(Icons.close, size: 18, color: p.fg)),
              const SizedBox(width: 12),
              Expanded(child: Text('PLACE THE PHOTO', style: KataType.displayStyle(size: 20, color: p.fg))),
            ]),
          ),
          Text('DRAG TO MOVE · PINCH OR SCROLL TO ZOOM', style: KataType.monoStyle(size: 8.5, color: p.muted, letterSpacing: 0.08)),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                // only so a card taller than the screen can be reached; the
                // drag itself is claimed by the detector below
                physics: const NeverScrollableScrollPhysics(),
                child: Listener(
                  onPointerSignal: (e) {
                    if (e is PointerScrollEvent) setState(() => _zoom = (_zoom * (1 - e.scrollDelta.dy / 600)).clamp(1.0, 6.0));
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (d) {
                      _dragStart = d.focalPoint;
                      _offsetStart = _offset;
                      _zoomStart = _zoom;
                    },
                    onScaleUpdate: (d) => setState(() {
                      _offset = _offsetStart + (d.focalPoint - _dragStart) / shown;
                      _zoom = (_zoomStart * d.scale).clamp(1.0, 6.0);
                    }),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: kCardWidth * shown,
                        child: FittedBox(fit: BoxFit.contain, child: SizedBox(width: kCardWidth, child: ShareCard(_spec))),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
            child: Row(children: [
              Expanded(
                child: KataPillButton(
                  label: 'Reset',
                  kind: KataButtonKind.secondary,
                  display: false,
                  height: 48,
                  onPressed: !changed
                      ? null
                      : () => setState(() {
                            _offset = Offset.zero;
                            _zoom = 1;
                          }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: KataPillButton(label: 'Done', height: 48, onPressed: () => Navigator.of(context).pop((_offset, _zoom)))),
            ]),
          ),
        ]),
      ),
    );
  }
}
