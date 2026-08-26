import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/compose/grain.dart';
import '../../../core/compose/layers.dart';
import '../../../core/compose/roll.dart';
import '../../../core/compose/treatment.dart';
import '../../../core/compose/voice.dart';
import '../../share/kata_code_qr.dart';
import 'frame.dart';

/// A 35mm negative strip on a light table. Its identity is measured, because
/// this is an object people have handled: the frame is 36 × 24 mm, the film is
/// 35 mm tall so each margin is 5.5 mm, the perforations are 1.98 × 2.79 mm
/// rounded rectangles at 4.75 mm pitch — round holes are the giveaway of a
/// fake — and the edge print runs through the perforation row, which is where
/// the stock's name goes, and so where the recipe rides.
class NegativeStripObject extends WakuObject {
  const NegativeStripObject();

  /// 135 film, in millimetres. Everything the strip draws is one of these
  /// divided by another, so the strip is right at any size.
  static const _frameW = 36.0, _frameH = 24.0, _filmH = 35.0;
  static const _perfPitch = 4.75, _perfW = 1.98, _perfH = 2.79;
  static const _margin = (_filmH - _frameH) / 2; // 5.5 mm
  /// A perforation's centre, measured in from the film's edge. It is not
  /// centred in the margin: it sits outboard, which is what leaves the 1.6 mm
  /// band between the perforation row and the image where the edge printing
  /// actually goes.
  static const _perfInset = 2.5;
  static const _printBand = _margin - (_perfInset + _perfH / 2); // 1.6 mm
  static const _gutter = 2.0; // between one frame and the next

  @override
  String get id => 'negative';

  @override
  String get label => 'Negative';

  @override
  Allowances get allowances => const Allowances(
        // edge printing is machine type: no serif voice belongs on film
        voices: {VoiceId.bureau, VoiceId.civic, VoiceId.postOffice},
        inkFamily: 'lab',
        // a strip in a sleeve stays cleaner than a stamp in the post
        treatment: TreatmentBounds(slip: 0.005, bleed: 0.6, pressure: 0.12, speckles: 22, wear: 0.4),
        inkOn: _base, // the edge print is on the film, not on the table
        // what the strip is lying on. A light table is the iconic one — the
        // frames glow and the base goes black against it — but a strip also
        // gets looked at on a desk, so the darks stay in the draw.
        grounds: [Color(0xFFDDE3E8), Color(0xFFE9E3D6), Color(0xFF15171A), Color(0xFF241E1A)],
      );

  static const _base = Color(0xFF23201C);

  @override
  List<ComposeLayer> build(ObjectContext ctx) {
    final s = ctx.size;
    final roll = ctx.roll;

    // The strip always runs off both edges of the sheet — a strip you can see
    // the ends of is a strip someone cut for the picture. Its scale comes from
    // the frame, capped so a wide sheet doesn't push the film off the top.
    final byWidth = s.width * 0.86;
    final byHeight = s.height * 0.72 * (_frameW / _filmH);
    final frameW = math.min(byWidth, byHeight);
    final mm = frameW / _frameW; // one millimetre, in pixels
    final stripH = _filmH * mm;

    final strip = Rect.fromLTWH(0, (s.height - stripH) / 2, s.width, stripH);
    final photoRect = Rect.fromCenter(center: Offset(s.width / 2, strip.center.dy), width: frameW, height: _frameH * mm);
    final (clump, amount) = ctx.grain.onSheet(photoRect.width);

    // The edge print sits in the margin, running through the perforation row,
    // exactly as it does on film. It is small: this is machine-printed latent
    // image, not a caption.
    final topBand = Rect.fromLTRB(strip.left, strip.top + (_margin - _printBand) * mm, strip.right, strip.top + _margin * mm);
    final botBand = Rect.fromLTRB(strip.left, strip.bottom - _margin * mm, strip.right, strip.bottom - (_margin - _printBand) * mm);
    final stock = [ctx.kataName ?? ctx.meta.filmMode ?? 'KATA', if (ctx.meta.iso != null) '${ctx.meta.iso}'].join(' ');
    final frameNo = (roll.seed % 36) + 1;

    return [
      ComposeSurface(ColoredBox(color: roll.ground)),
      ComposeGrainSheet(GrainSpec.measured(clumpPx: clump, amount: amount, seed: roll.seed)),
      // the film base, with the neighbouring frames' gutters ruled on it
      ComposeSurface(Padding(
        padding: EdgeInsets.only(top: strip.top, bottom: s.height - strip.bottom),
        child: CustomPaint(painter: FilmBasePainter(frameW: frameW, mm: mm, gutter: _gutter * mm, margin: _margin * mm)),
      )),
      ComposePhotoWindow(rect: photoRect),
      // edge print: the stock is the recipe
      ComposeTextSlot(
        id: 'stock',
        region: Rect.fromLTRB(strip.left + 2 * mm, topBand.top, strip.left + 40 * mm, topBand.bottom),
        style: roll.voice.dataStyle(_printBand * mm * 0.92, roll.ink),
        invitation: 'KATA',
        prefill: stock.toUpperCase(),
        align: Alignment.centerLeft,
        maxChars: 30,
        fitRegion: true,
      ),
      // frame numbers with their arrows, on the opposite edge
      ComposeTextSlot(
        id: 'framenumber',
        region: Rect.fromLTRB(strip.left + 2 * mm, botBand.top, strip.left + 20 * mm, botBand.bottom),
        style: roll.voice.dataStyle(_printBand * mm * 0.86, roll.ink),
        invitation: '12 →12A',
        prefill: '$frameNo →${frameNo}A',
        align: Alignment.centerLeft,
        maxChars: 12,
        fitRegion: true,
      ),
      // punched last: a perforation goes through the edge print too, which is
      // exactly how the stock's name reads on a real strip — interrupted
      ComposeSurface(CustomPaint(painter: SprocketPainter(strip: strip, mm: mm, roll: roll))),
      // The recipe's code. It cannot go in the margin — that band is 1.6 mm,
      // which is a smear at any print size, and the perforations would punch
      // through it. So it goes where a lab prints one: the corner of the frame
      // itself, after the perforations, small enough to read past.
      if (ctx.kataCode != null)
        ComposeSurface(Padding(
          padding: EdgeInsets.fromLTRB(
            photoRect.right - _frameH * mm * 0.19 - _gutter * mm,
            photoRect.bottom - _frameH * mm * 0.19 - _gutter * mm,
            s.width - photoRect.right + _gutter * mm,
            s.height - photoRect.bottom + _gutter * mm,
          ),
          child: LayoutBuilder(builder: (c, b) => KataCodeQr(payload: ctx.kataCode!, size: b.biggest.shortestSide)),
        )),
      ComposeSurface(CustomPaint(painter: SpecklePainter(roll.treatment, roll.seed))),
      ComposeGrainSheet(GrainSpec.measured(clumpPx: clump, amount: amount * 0.33, seed: roll.seed), overInk: true),
    ];
  }
}

/// The film base, and the frames on either side of ours. We only have one
/// photograph, so the neighbours are dense — the rest of the roll, unprinted —
/// separated by the gutter the camera's gate leaves between exposures.
class FilmBasePainter extends CustomPainter {
  FilmBasePainter({required this.frameW, required this.mm, required this.gutter, required this.margin});
  final double frameW, mm, gutter, margin;

  @override
  void paint(Canvas c, Size s) {
    // A painter that draws past its own size paints over whatever was drawn
    // before it — on one canvas the screen hides that, but put two canvases in
    // one layer and the strip erases its neighbour's photograph.
    c.clipRect(Offset.zero & s);
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF23201C));
    // neighbours, stepping outward from ours by one frame + gutter each time,
    // only as far as the sheet can actually show
    final dense = Paint()..color = const Color(0xFF1B1814);
    final top = margin, bottom = s.height - margin;
    final reach = ((s.width / 2 + frameW / 2) / (frameW + gutter)).ceil();
    for (var i = 1; i <= reach; i++) {
      final off = i * (frameW + gutter);
      for (final left in [s.width / 2 - frameW / 2 - off, s.width / 2 - frameW / 2 + off]) {
        c.drawRect(Rect.fromLTWH(left, top, frameW, bottom - top), dense);
      }
    }
  }

  @override
  bool shouldRepaint(FilmBasePainter o) => o.frameW != frameW || o.mm != mm;
}

/// Perforations: 1.98 × 2.79 mm rounded rectangles at 4.75 mm pitch, both
/// edges, centred in the margin. The corner radius is what the eye reads —
/// a circle here and the whole object stops being film.
class SprocketPainter extends CustomPainter {
  SprocketPainter({required this.strip, required this.mm, required this.roll});
  final Rect strip;
  final double mm;
  final Roll roll;

  @override
  void paint(Canvas c, Size s) {
    final pitch = NegativeStripObject._perfPitch * mm;
    final w = NegativeStripObject._perfW * mm, h = NegativeStripObject._perfH * mm;
    final inset = NegativeStripObject._perfInset * mm;
    final r = Radius.circular(math.min(w, h) * 0.26);
    // a perforation is a hole: what shows through it is whatever the strip is
    // lying on, which is the one place the ground reaches inside the film
    final hole = Paint()..color = roll.ground;
    c.clipRect(Offset.zero & s);
    // the strip runs off both edges, so the row is laid from the centre out
    final n = (s.width / pitch).ceil() + 2;
    for (var i = -n; i <= n; i++) {
      final x = s.width / 2 + i * pitch;
      if (x < -pitch || x > s.width + pitch) continue;
      for (final y in [strip.top + inset, strip.bottom - inset]) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: w, height: h), r), hole);
      }
    }
  }

  @override
  bool shouldRepaint(SprocketPainter o) => o.strip != strip || o.mm != mm || o.roll.ground != roll.ground;
}
