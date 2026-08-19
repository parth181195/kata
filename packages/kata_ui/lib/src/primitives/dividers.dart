import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

class DottedDivider extends StatelessWidget {
  const DottedDivider({super.key, this.height = 1, this.color});
  final double height;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(double.infinity, height), painter: _DotsPainter(color ?? context.kata.hairline, height));
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color, this.h);
  final Color color;
  final double h;
  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()..color = color;
    for (var x = 0.0; x < s.width; x += 5) {
      c.drawRect(Rect.fromLTWH(x, 0, 2, h), paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter o) => o.color != color;
}

/// `Q-MENU ORDER ·········` style section header.
class EyebrowDivider extends StatelessWidget {
  const EyebrowDivider(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Row(children: [
      Text(text.toUpperCase(), style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16)),
      const SizedBox(width: 10),
      const Expanded(child: DottedDivider()),
    ]);
  }
}
