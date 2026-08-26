import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/compose/grain.dart';
import '../../../core/compose/layers.dart';
import '../../../core/compose/roll.dart';
import '../../../core/compose/treatment.dart';
import '../../../core/compose/voice.dart';
import 'frame.dart';

/// A postage stamp, mounted on a card. Its identity — the perforated edge, the
/// white margin, the corner denomination, and a postmark that laps off onto the
/// mount because the clerk wasn't aiming — is authored and never rolls. The
/// voice, the ink, the mount's colour and the wear all do.
class StampObject extends WakuObject {
  const StampObject();

  @override
  String get id => 'stamp';

  @override
  String get label => 'Stamp';

  @override
  Allowances get allowances => const Allowances(
        voices: {VoiceId.postOffice, VoiceId.bureau, VoiceId.civic, VoiceId.deco},
        inkFamily: 'postmark',
        treatment: TreatmentBounds(slip: 0.014, bleed: 1.3, pressure: 0.26, speckles: 40, wear: 1),
        inkOn: Color(0xFFF4EFE3), // the stamp's own paper
        grounds: [Color(0xFF7E2418), Color(0xFF1F3D34), Color(0xFF23324D), Color(0xFF4A3C22), Color(0xFF12100E)],
      );

  @override
  List<ComposeLayer> build(ObjectContext ctx) {
    final s = ctx.size;
    final roll = ctx.roll;

    // The stamp is an object ON something, so it never fills the sheet. It also
    // has one shape — a stamp is 4:5-ish whatever you post it on — so on a
    // story it simply sits smaller with more mount around it.
    final maxW = s.width * 0.72;
    final maxH = s.height * 0.62;
    var stampW = maxW;
    var stampH = stampW * 1.26;
    if (stampH > maxH) {
      stampH = maxH;
      stampW = stampH / 1.26;
    }
    // centred, riding a touch high: a mounted specimen leaves more card below
    // it than above, the way an album page is laid out
    final stamp = Rect.fromLTWH((s.width - stampW) / 2, (s.height - stampH) * 0.42, stampW, stampH);
    final face = stamp.deflate(stampW * 0.085);
    final photoRect = Rect.fromLTRB(face.left, stamp.top + stampH * 0.13, face.right, stamp.bottom - stampH * 0.155);
    final (clump, amount) = ctx.grain.onSheet(photoRect.width);

    return [
      ComposeSurface(ColoredBox(color: roll.ground)),
      ComposeGrainSheet(GrainSpec.measured(clumpPx: clump, amount: amount, seed: roll.seed)),
      ComposeSurface(CustomPaint(painter: PressurePainter(roll.treatment, roll.seed))),
      // the stamp's paper, perforated
      ComposeSurface(Padding(
        padding: EdgeInsets.fromLTRB(stamp.left, stamp.top, s.width - stamp.right, s.height - stamp.bottom),
        child: ClipPath(
          clipper: PerforationClipper(roll.treatment, roll.seed),
          child: ColoredBox(color: allowances.inkOn),
        ),
      )),
      ComposePhotoWindow(rect: photoRect),
      // country line: the film simulation is who issued this stamp
      ComposeTextSlot(
        id: 'country',
        region: Rect.fromLTRB(face.left, stamp.top + stampH * 0.035, face.right, stamp.top + stampH * 0.125),
        style: roll.voice.textStyle(stampW * 0.062, roll.ink, tracking: 0.14),
        invitation: 'KATA',
        prefill: ctx.kataName ?? ctx.meta.filmMode,
        align: Alignment.center,
        maxChars: 22,
        fitRegion: true,
      ),
      // denomination: what the shot cost in light
      ComposeTextSlot(
        id: 'denomination',
        region: Rect.fromLTRB(face.left, stamp.bottom - stampH * 0.165, face.left + face.width * 0.52, stamp.bottom - stampH * 0.015),
        style: roll.voice.displayStyle(stampW * 0.26, roll.ink),
        invitation: '400',
        prefill: ctx.meta.iso == null ? null : '${ctx.meta.iso}',
        align: Alignment.bottomLeft,
        maxChars: 6,
        fitRegion: true,
      ),
      ComposeTextSlot(
        id: 'issue',
        region: Rect.fromLTRB(face.left + face.width * 0.5, stamp.bottom - stampH * 0.13, face.right, stamp.bottom - stampH * 0.03),
        style: roll.voice.dataStyle(stampW * 0.062, roll.ink.withValues(alpha: 0.85)),
        invitation: 'ISO',
        prefill: ctx.meta.dateTime == null ? null : '${ctx.meta.dateTime!.year}',
        align: Alignment.bottomRight,
        maxChars: 14,
        fitRegion: true,
      ),
      // the postmark is a second pass, so it slips and it laps onto the mount
      ComposeSurface(CustomPaint(painter: PostmarkPainter(roll, stamp, ctx.meta.model, ctx.meta.dateTime))),
      ComposeSurface(CustomPaint(painter: SpecklePainter(roll.treatment, roll.seed))),
      ComposeGrainSheet(GrainSpec.measured(clumpPx: clump, amount: amount * 0.33, seed: roll.seed), overInk: true),
    ];
  }
}

/// Punches perforations out of the stamp's rectangle. Gauge ~13; a tooth or two
/// may fail to tear, which is what the treatment's wear buys.
class PerforationClipper extends CustomClipper<Path> {
  PerforationClipper(this.treatment, this.seed);
  final Treatment treatment;
  final int seed;

  @override
  Path getClip(Size size) {
    final pitch = size.width / 13;
    final r = pitch * 0.30;
    final missing = (treatment.wear * 3).floor();
    final holes = Path();
    void row(int n, Offset Function(int) at) {
      for (var i = 0; i <= n; i++) {
        if (missing > 0 && i % 7 == missing) continue;
        holes.addOval(Rect.fromCircle(center: at(i), radius: r));
      }
    }

    final nx = math.max(1, (size.width / pitch).floor());
    final ny = math.max(1, (size.height / pitch).floor());
    row(nx, (i) => Offset(i * size.width / nx, 0));
    row(nx, (i) => Offset(i * size.width / nx, size.height));
    row(ny, (i) => Offset(0, i * size.height / ny));
    row(ny, (i) => Offset(size.width, i * size.height / ny));
    return Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), holes);
  }

  @override
  bool shouldReclip(PerforationClipper o) => o.seed != seed;
}

/// The circular date stamp: arced place text, a date slug, wavy killer bars
/// running off the edge.
class PostmarkPainter extends CustomPainter {
  PostmarkPainter(this.roll, this.stamp, this.place, this.when);
  final Roll roll;
  final Rect stamp;
  final String? place;
  final DateTime? when;

  @override
  void paint(Canvas c, Size s) {
    final ink = roll.ink;
    final t = roll.treatment;
    final radius = stamp.width * 0.21;
    final centre = stamp.topLeft + Offset(stamp.width * (0.27 + t.slip.dx * 8), stamp.height * (0.34 + t.slip.dy * 8));

    c.save();
    c.translate(centre.dx, centre.dy);
    c.rotate(t.turn);
    final stroke = Paint()
      ..color = ink.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.05
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.01, t.bleed * 0.35));
    c.drawCircle(Offset.zero, radius, stroke);
    c.drawCircle(Offset.zero, radius * 0.80, stroke..strokeWidth = radius * 0.028);

    _arc(c, (place ?? 'FUJIFILM').toUpperCase(), radius * 0.90, -math.pi * 0.72, roll.voice.dataStyle(radius * 0.22, ink), true);
    final d = when ?? DateTime(2026);
    final date = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year % 100}';
    final tp = TextPainter(text: TextSpan(text: date, style: roll.voice.dataStyle(radius * 0.26, ink)), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    c.restore();

    final bars = Paint()
      ..color = ink.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.055
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.01, t.bleed * 0.4));
    final gap = radius * 0.24;
    for (var i = 0; i < 5; i++) {
      final path = Path();
      final y0 = centre.dy - radius * 0.5 + i * gap;
      for (var x = 0.0; x <= stamp.width * 0.72; x += 4) {
        // one phase for every bar: a wavy-line cancel is a single die, so
        // the lines run parallel rather than wandering apart
        final y = y0 + math.sin((x / stamp.width) * math.pi * 3) * radius * 0.045;
        final p = Offset(centre.dx + x - radius * 0.2, y);
        if (x == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      c.drawPath(path, bars);
    }
  }

  void _arc(Canvas c, String text, double r, double startAngle, TextStyle style, bool outward) {
    var angle = startAngle;
    for (final ch in text.split('')) {
      final tp = TextPainter(text: TextSpan(text: ch, style: style), textDirection: TextDirection.ltr)..layout();
      final step = (tp.width * 1.25) / r;
      c.save();
      c.rotate(angle + step / 2);
      c.translate(0, outward ? -r : r);
      if (!outward) c.rotate(math.pi);
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
      angle += step;
    }
  }

  @override
  bool shouldRepaint(PostmarkPainter o) => o.roll.seed != roll.seed;
}
