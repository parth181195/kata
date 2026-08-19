import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Google "G" in greyscale — four arcs + the bar, drawn as strokes so it stays crisp at 18px.
/// Tones are ordered blue, green, yellow, red (the brand order, mapped to greys by luminance).
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 18, this.tones = const [Color(0xFF000000), Color(0xFF5C5C5C), Color(0xFF8A8A8A), Color(0xFF2E2E2E)]});
  final double size;
  final List<Color> tones;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _GPainter(tones));
}

class _GPainter extends CustomPainter {
  _GPainter(this.tones);
  final List<Color> tones;
  @override
  void paint(Canvas c, Size s) {
    final w = s.width * 0.2;
    final r = (s.width - w) / 2;
    final center = Offset(s.width / 2, s.height / 2);
    final rect = Rect.fromCircle(center: center, radius: r);
    Paint stroke(Color col) => Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.butt;
    const d = math.pi / 180;
    // angles clockwise from 3 o'clock; the opening sits top-right (315°→360°)
    c.drawArc(rect, 0, 50 * d, false, stroke(tones[0])); // blue: bar level → lower right
    c.drawArc(rect, 50 * d, 85 * d, false, stroke(tones[1])); // green: bottom
    c.drawArc(rect, 135 * d, 90 * d, false, stroke(tones[2])); // yellow: left
    c.drawArc(rect, 225 * d, 92 * d, false, stroke(tones[3])); // red: top
    // bar: from just right of centre to the outer edge, same thickness as the ring
    c.drawRect(Rect.fromLTWH(center.dx - w * 0.1, center.dy - w / 2, r + w / 2 + w * 0.1, w), Paint()..color = tones[0]);
  }

  @override
  bool shouldRepaint(_GPainter o) => o.tones != tones;
}
