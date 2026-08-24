import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// Tab bar — hairline line-icons + tiny mono labels, dot under the active one.
/// One tab per label; [iconKinds] picks each tab's icon (defaults to label order:
/// 0 library · 1 camera · 2 mine · 3 profile · 4 frame).
class KataBottomNav extends StatelessWidget {
  const KataBottomNav({super.key, required this.index, required this.onTap, this.labels = const ['Library', 'Camera', 'Mine', 'Profile'], this.iconKinds});
  final int index;
  final ValueChanged<int> onTap;
  final List<String> labels;
  final List<int>? iconKinds;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Container(
      height: 64,
      decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.dark ? p.surface : p.hairline))),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: InkWell(
              key: ValueKey('nav-$i'),
              onTap: () => onTap(i),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CustomPaint(size: const Size(22, 18), painter: _NavIcon(iconKinds?[i] ?? i, i == index ? p.fg : p.muted)),
                const SizedBox(height: 5),
                Text(
                  labels[i].toUpperCase(),
                  style: KataType.monoStyle(size: 8, weight: FontWeight.w500, color: i == index ? p.fg : p.muted, letterSpacing: 0.12, height: 1),
                ),
                const SizedBox(height: 4),
                Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: i == index ? p.fg : Colors.transparent)),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Line icons at hairline weight: stacked cards (library), camera body (camera), bookmark (mine), person (profile).
class _NavIcon extends CustomPainter {
  _NavIcon(this.kind, this.color);
  final int kind;
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final st = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = KataStroke.hairline
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final w = s.width, h = s.height;
    switch (kind) {
      case 0: // library — a card in front of a card
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.22, 0.75, w * 0.68, h * 0.7), const Radius.circular(2)), st);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0.75, h * 0.28, w * 0.68, h * 0.7), const Radius.circular(2)), st);
      case 1: // camera — body, viewfinder bump, lens
        final body = RRect.fromRectAndRadius(Rect.fromLTWH(0.75, h * 0.26, w - 1.5, h * 0.72), const Radius.circular(3));
        c.drawRRect(body, st);
        c.drawPath(
          Path()
            ..moveTo(w * 0.3, h * 0.26)
            ..lineTo(w * 0.38, 0.75)
            ..lineTo(w * 0.62, 0.75)
            ..lineTo(w * 0.7, h * 0.26),
          st,
        );
        c.drawCircle(Offset(w / 2, h * 0.62), h * 0.2, st);
      case 2: // mine — bookmark
        c.drawPath(
          Path()
            ..moveTo(w * 0.25, 0.75)
            ..lineTo(w * 0.75, 0.75)
            ..lineTo(w * 0.75, h - 0.75)
            ..lineTo(w * 0.5, h * 0.7)
            ..lineTo(w * 0.25, h - 0.75)
            ..close(),
          st,
        );
      case 3: // profile — head + shoulders
        c.drawCircle(Offset(w / 2, h * 0.3), h * 0.22, st);
        c.drawArc(Rect.fromLTWH(w * 0.18, h * 0.6, w * 0.64, h * 0.9), 3.1416, 3.1416, false, st);
      default: // waku — a frame: outer moulding around an inner window
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0.75, 0.75, w - 1.5, h - 1.5), const Radius.circular(2)), st);
        c.drawRect(Rect.fromLTWH(w * 0.24, h * 0.24, w * 0.52, h * 0.52), st);
    }
  }

  @override
  bool shouldRepaint(_NavIcon o) => o.kind != kind || o.color != color;
}
