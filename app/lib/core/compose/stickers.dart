import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The fastener kit from the mood board: washi tape, push pin, hanko stamp —
/// drawn procedurally so they stay crisp at export scale. A frame declares
/// which stickers it allows and how many; users place them within that
/// allowance — move and tilt, nothing else.
enum StickerType {
  tape('Tape'),
  pin('Pin'),
  hanko('Hanko');

  const StickerType(this.label);
  final String label;

  /// Logical size at placement scale (width, height) before rotation.
  Size get size => switch (this) {
        tape => const Size(86, 26),
        pin => const Size(26, 26),
        hanko => const Size(34, 34),
      };
}

class StickerInstance {
  StickerInstance({required this.id, required this.type, required this.pos, this.angle = 0, this.seed = 1});
  final String id;
  final StickerType type;
  /// Centre position as fractions of the canvas.
  Offset pos;
  double angle;
  final int seed;
}

class StickerWidget extends StatelessWidget {
  const StickerWidget({super.key, required this.type, required this.seed});
  final StickerType type;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final s = type.size;
    return CustomPaint(size: s, painter: _StickerPainter(type, seed));
  }
}

class _StickerPainter extends CustomPainter {
  _StickerPainter(this.type, this.seed);
  final StickerType type;
  final int seed;

  @override
  void paint(Canvas c, Size s) {
    switch (type) {
      case StickerType.tape:
        _tape(c, s);
      case StickerType.pin:
        _pin(c, s);
      case StickerType.hanko:
        _hanko(c, s);
    }
  }

  /// Translucent mustard washi with torn ends.
  void _tape(Canvas c, Size s) {
    final rnd = math.Random(seed);
    final path = Path()..moveTo(3, 0);
    path.lineTo(s.width - 3, 0);
    // torn right end: jagged small notches
    var y = 0.0;
    while (y < s.height - 2) {
      final step = 3 + rnd.nextDouble() * 3;
      path.lineTo(s.width - 3 + (rnd.nextDouble() * 5 - 1.5), y + step / 2);
      path.lineTo(s.width - 3, math.min(y + step, s.height));
      y += step;
    }
    path.lineTo(3, s.height);
    y = s.height;
    while (y > 2) {
      final step = 3 + rnd.nextDouble() * 3;
      path.lineTo(3 - (rnd.nextDouble() * 5 - 1.5), y - step / 2);
      path.lineTo(3, math.max(y - step, 0));
      y -= step;
    }
    path.close();
    c.drawShadow(path, const Color(0x55000000), 2, true);
    c.drawPath(path, Paint()..color = const Color(0x93D9C878));
    // faint fibre streaks
    final fibre = Paint()
      ..color = const Color(0x18FFFFFF)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final fy = rnd.nextDouble() * s.height;
      c.drawLine(Offset(4, fy), Offset(s.width - 4, fy), fibre);
    }
  }

  /// A round-head push pin with a highlight and grounded shadow.
  void _pin(Canvas c, Size s) {
    final centre = Offset(s.width / 2, s.height / 2 - 1);
    c.drawOval(Rect.fromCenter(center: Offset(centre.dx + 2, s.height - 3), width: 10, height: 3.4), Paint()..color = const Color(0x44000000));
    c.drawCircle(centre, 8.2, Paint()..color = const Color(0xFF8C1F13));
    c.drawCircle(centre, 8.2, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0x40000000));
    c.drawCircle(Offset(centre.dx - 2.6, centre.dy - 2.8), 2.4, Paint()..color = const Color(0x66FFFFFF));
  }

  /// The 枠 seal: red rounded square, worn ink, white glyph.
  void _hanko(Canvas c, Size s) {
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, s.width - 2, s.height - 2), const Radius.circular(5));
    c.drawRRect(rect, Paint()..color = const Color(0xE0B3402B));
    // worn ink: nick the edges with tiny background-coloured bites
    final rnd = math.Random(seed + 7);
    final bite = Paint()..blendMode = BlendMode.dstOut;
    c.saveLayer(Rect.fromLTWH(-2, -2, s.width + 4, s.height + 4), Paint());
    c.drawRRect(rect, Paint()..color = const Color(0xE0B3402B));
    for (var i = 0; i < 7; i++) {
      final edge = rnd.nextInt(4);
      final t = rnd.nextDouble();
      final p = switch (edge) {
        0 => Offset(s.width * t, 1),
        1 => Offset(s.width * t, s.height - 1),
        2 => Offset(1, s.height * t),
        _ => Offset(s.width - 1, s.height * t),
      };
      c.drawCircle(p, 0.8 + rnd.nextDouble() * 1.4, bite..color = const Color(0xFF000000));
    }
    c.restore();
    final tp = TextPainter(
      text: const TextSpan(text: '枠', style: TextStyle(fontSize: 22, color: Color(0xFFF6F1E6), fontWeight: FontWeight.w600, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset((s.width - tp.width) / 2, (s.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(_StickerPainter o) => o.type != type || o.seed != seed;
}
