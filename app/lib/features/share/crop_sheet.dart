import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';

/// Crop by placing: the photo sits under a window of the chosen shape; pan and
/// pinch it, and what the window shows is what's kept. Returns the kept region
/// as fractions of the image, or null when dismissed.
Future<Rect?> showCropSheet(BuildContext context, Uint8List photo) => showKataSheet<Rect>(context, maxWidth: 720, builder: (_) => _CropSheet(photo: photo));

enum _CropShape {
  r3x2('3:2', 3 / 2),
  r4x3('4:3', 4 / 3),
  square('1:1', 1),
  r4x5('4:5', 4 / 5),
  r16x9('16:9', 16 / 9);

  const _CropShape(this.label, this.aspect);
  final String label;
  final double aspect;
}

class _CropSheet extends StatefulWidget {
  const _CropSheet({required this.photo});
  final Uint8List photo;
  @override
  State<_CropSheet> createState() => _CropSheetState();
}

class _CropSheetState extends State<_CropSheet> {
  final _viewer = TransformationController();
  final _windowKey = GlobalKey();
  _CropShape _shape = _CropShape.r3x2;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    // the image's own size decides how the cover-fit maps window → pixels
    final stream = MemoryImage(widget.photo).resolve(const ImageConfiguration());
    late final ImageStreamListener l;
    l = ImageStreamListener((info, _) {
      if (mounted) setState(() => _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
      stream.removeListener(l);
    });
    stream.addListener(l);
  }

  @override
  void dispose() {
    _viewer.dispose();
    super.dispose();
  }

  /// What the window shows, as a fraction of the image. The window's child is
  /// the image cover-fitted to the window; the viewer's matrix maps window
  /// space to that child, so invert it for the visible rect, then undo the
  /// cover fit.
  Rect? _keptFraction() {
    final box = _windowKey.currentContext?.findRenderObject() as RenderBox?;
    final img = _imageSize;
    if (box == null || img == null) return null;
    final win = box.size;
    final inv = Matrix4.inverted(_viewer.value);
    final tl = MatrixUtils.transformPoint(inv, Offset.zero);
    final br = MatrixUtils.transformPoint(inv, Offset(win.width, win.height));
    final visible = Rect.fromPoints(tl, br); // in child (window-sized) coords
    // cover fit: scale so the image fills the window, centred
    final scale = (win.width / img.width) > (win.height / img.height) ? win.width / img.width : win.height / img.height;
    final drawnW = img.width * scale, drawnH = img.height * scale;
    final ox = (win.width - drawnW) / 2, oy = (win.height - drawnH) / 2;
    Rect r = Rect.fromLTRB((visible.left - ox) / drawnW, (visible.top - oy) / drawnH, (visible.right - ox) / drawnW, (visible.bottom - oy) / drawnH);
    r = Rect.fromLTRB(r.left.clamp(0.0, 1.0), r.top.clamp(0.0, 1.0), r.right.clamp(0.0, 1.0), r.bottom.clamp(0.0, 1.0));
    return r.width <= 0 || r.height <= 0 ? null : r;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return KataSheet(
      eyebrow: 'Photo',
      title: 'Crop',
      children: [
        Text('Drag and pinch the photo; the window is what’s kept.', style: KataType.bodyStyle(size: 12, color: p.muted, height: 1.4)),
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final s in _CropShape.values)
            KataChip(
                label: s.label,
                selected: _shape == s,
                onTap: () => setState(() {
                      _shape = s;
                      _viewer.value = Matrix4.identity();
                    })),
        ]),
        const SizedBox(height: 14),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
            child: AspectRatio(
              aspectRatio: _shape.aspect,
              child: Container(
                key: _windowKey,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: p.hairline)),
                child: InteractiveViewer(
                  transformationController: _viewer,
                  minScale: 1,
                  maxScale: 6,
                  constrained: true,
                  child: Image.memory(widget.photo, fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        KataPillButton(
          label: 'Keep this',
          height: 48,
          onPressed: _imageSize == null
              ? null
              : () {
                  final r = _keptFraction();
                  if (r != null) Navigator.of(context).pop(r);
                },
        ),
      ],
    );
  }
}
