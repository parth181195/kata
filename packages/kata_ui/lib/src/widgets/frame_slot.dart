import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// Image area; shows a dotted grey placeholder when no image.
class FrameSlot extends StatelessWidget {
  const FrameSlot({super.key, this.image, this.radius = 12, this.placeholder, this.fit = BoxFit.cover});
  final ImageProvider? image;
  final double radius;
  final String? placeholder;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: image != null
          ? Image(image: image!, fit: fit, width: double.infinity, height: double.infinity)
          : CustomPaint(
              painter: _DotGrid(p.hairline, p.dark ? p.surface : p.code),
              child: Center(
                child: Text((placeholder ?? '').toUpperCase(), textAlign: TextAlign.center, style: KataType.monoStyle(size: 8.5, color: p.muted, letterSpacing: 0.1)),
              ),
            ),
    );
  }
}

class _DotGrid extends CustomPainter {
  _DotGrid(this.dot, this.bg);
  final Color dot, bg;
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = bg);
    final p = Paint()..color = dot;
    for (var y = 7.0; y < s.height; y += 14) {
      for (var x = 7.0; x < s.width; x += 14) {
        c.drawCircle(Offset(x, y), 1, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGrid o) => o.dot != dot || o.bg != bg;
}
