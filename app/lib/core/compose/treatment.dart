import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How far each imperfection may go on this object. A museum label allows
/// almost none; a stamp that went through the post allows plenty.
class TreatmentBounds {
  const TreatmentBounds({this.slip = 0.012, this.bleed = 1.2, this.pressure = 0.22, this.speckles = 40, this.wear = 1.0});

  /// Registration slip, as a fraction of the object's size.
  final double slip;

  /// Blur radius on printed marks, in logical pixels at preview scale.
  final double bleed;

  /// Peak density variation across the sheet, 0..1.
  final double pressure;

  /// Maximum number of specks and hairs.
  final int speckles;

  /// 0 = pristine, 1 = fully allowed wear (a torn perforation, a bent corner).
  final double wear;
}

/// One draw from those bounds. Everything here is decided by the seed, so an
/// output is reproducible and a shuffle is just a different number.
class Treatment {
  const Treatment({required this.slip, required this.turn, required this.bleed, required this.pressure, required this.speckles, required this.wear});

  final Offset slip;

  /// Rotation of the slipped layer, radians — slip and turn come from the same
  /// mis-feed, so they're drawn together.
  final double turn;
  final double bleed, pressure;
  final int speckles;
  final double wear;

  static const none = Treatment(slip: Offset.zero, turn: 0, bleed: 0, pressure: 0, speckles: 0, wear: 0);

  static Treatment draw(TreatmentBounds b, int seed) {
    final r = math.Random(seed);
    double sym(double max) => (r.nextDouble() * 2 - 1) * max;
    return Treatment(
      slip: Offset(sym(b.slip), sym(b.slip)),
      turn: sym(b.slip * 20),
      bleed: r.nextDouble() * b.bleed,
      pressure: r.nextDouble() * b.pressure,
      speckles: b.speckles == 0 ? 0 : r.nextInt(b.speckles + 1),
      wear: r.nextDouble() * b.wear,
    );
  }
}

/// Dust, hairs and specks — the print shop wasn't clean.
class SpecklePainter extends CustomPainter {
  SpecklePainter(this.treatment, this.seed);
  final Treatment treatment;
  final int seed;

  @override
  void paint(Canvas c, Size s) {
    final r = math.Random(seed ^ 0x9E3);
    final p = Paint();
    for (var i = 0; i < treatment.speckles; i++) {
      final dark = r.nextBool();
      p.color = (dark ? Colors.black : Colors.white).withValues(alpha: 0.05 + r.nextDouble() * 0.16);
      final at = Offset(r.nextDouble() * s.width, r.nextDouble() * s.height);
      if (r.nextInt(5) == 0) {
        final path = Path()..moveTo(at.dx, at.dy);
        var q = at;
        for (var k = 0; k < 3; k++) {
          q += Offset((r.nextDouble() - 0.5) * s.width * 0.05, (r.nextDouble() - 0.5) * s.width * 0.05);
          path.lineTo(q.dx, q.dy);
        }
        c.drawPath(
            path,
            p
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.7);
      } else {
        c.drawCircle(at, 0.4 + r.nextDouble() * 1.1, p..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(SpecklePainter o) => o.seed != seed || o.treatment.speckles != treatment.speckles;
}

/// Uneven pressure: low-frequency density variation, as if the platen wasn't
/// quite flat. A few soft overlay blooms, which is enough at print scale.
class PressurePainter extends CustomPainter {
  PressurePainter(this.treatment, this.seed);
  final Treatment treatment;
  final int seed;

  @override
  void paint(Canvas c, Size s) {
    if (treatment.pressure <= 0) return;
    final r = math.Random(seed ^ 0x51);
    for (var i = 0; i < 5; i++) {
      final centre = Offset(r.nextDouble() * s.width, r.nextDouble() * s.height);
      final radius = s.width * (0.35 + r.nextDouble() * 0.4);
      c.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.white.withValues(alpha: treatment.pressure * 0.5), Colors.white.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: centre, radius: radius))
          ..blendMode = BlendMode.overlay,
      );
    }
  }

  @override
  bool shouldRepaint(PressurePainter o) => o.seed != seed || o.treatment.pressure != treatment.pressure;
}
