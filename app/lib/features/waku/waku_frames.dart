import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/compose/grain.dart';
import '../../core/compose/layers.dart';
import 'waku_exif.dart';

/// The Waku gallery is curated: a frame ships only when it has something of
/// its own. One for now — the instant print. Each frame is a fixed layer
/// stack; what users may touch is declared per layer, never changed by them.
enum WakuFrame {
  polaroid('Polaroid', canvasAspect: 88 / 107),
  poster('Poster', canvasAspect: 2 / 3, photoRatioAdjustable: true),
  words('Words', canvasAspect: 0.72, photoRatioAdjustable: true),
  custom('Custom');

  const WakuFrame(this.label, {this.canvasAspect, this.photoRatioAdjustable = false});
  final String label;
  /// A real print has one shape: frames with a fixed sheet ignore the user's
  /// canvas ratio. When [photoRatioAdjustable], the ratio chips shape the
  /// photo window inside the sheet instead.
  final double? canvasAspect;
  final bool photoRatioAdjustable;
}

/// Fits a window of [aspect] inside [area], centred — how fixed-sheet frames
/// place their photo when the user picks a ratio.
Rect fitPhotoRect(Rect area, double? aspect) {
  if (aspect == null) return area;
  var w = area.width;
  var h = w / aspect;
  if (h > area.height) {
    h = area.height;
    w = h * aspect;
  }
  return Rect.fromCenter(center: area.center, width: w, height: h);
}

/// The stock's tooth follows the photo's own grain: ISO is the honest proxy.
double grainPxForIso(int? iso) {
  if (iso == null || iso <= 0) return GrainSize.small.px;
  final stops = (math.log(iso / 200) / math.ln2);
  return (1.3 + 0.30 * stops).clamp(1.2, 3.4);
}

/// Instant-print: bright white stock, tight even sides, the classic deep chin.
/// Layers, bottom → top: paper · photo window · the chin's hand-written line
/// (editable, and draggable along the chin like a real pen would wander).
List<ComposeLayer> polaroidLayers(Size size, double unit, {PhotoMeta meta = const PhotoMeta()}) {
  final m = unit * 0.72;
  final chin = unit * 2.9;
  return [
    // the stock itself has tooth — our call, per frame; users don't touch grain
    const ComposeSurface(ColoredBox(color: Color(0xFFFBFAF6))),
    ComposePhotoWindow(
      rect: Rect.fromLTRB(m, m * 1.15, size.width - m, size.height - chin),
      shadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 3, offset: Offset(0, 1))],
    ),
    ComposeTextSlot(
      id: 'chin',
      region: Rect.fromLTRB(m, size.height - chin, size.width - m, size.height),
      style: chinStyle(size),
      draggable: true,
      // a real chin holds about two handwritten lines before the pen falls off
      maxLines: 2,
      maxChars: 56,
      // handwriting sits smaller or larger, tilts a little, and comes in
      // whatever pen was lying around — all still the frame's palette
      scalable: true,
      rotatable: true,
      inkChoices: [Color(0xFF3A362E), Color(0xFF3D4E6B), Color(0xFFB3402B)],
    ),
    ComposeGrainSheet(GrainSpec(strength: GrainStrength.weak, matchPx: grainPxForIso(meta.iso))),
  ];
}

/// Any image of yours as the frame. Surround mode: the image behind, the photo
/// floating inset on a shadow. Overlay mode (a PNG with a transparent window):
/// the photo fills and the frame draws over it.
List<ComposeLayer> customLayers(Size size, double unit, {required Widget frameImage, required bool overlay}) {
  if (overlay) {
    return [
      ComposePhotoWindow(rect: Offset.zero & size),
      ComposeSurface(frameImage),
    ];
  }
  final inset = unit * 1.4;
  return [
    ComposeSurface(frameImage),
    ComposePhotoWindow(
      rect: Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset),
      shadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 16, offset: Offset(0, 5))],
    ),
  ];
}

/// The chin text style at this canvas size — shared by label and inline editor
/// so the swap is invisible.
TextStyle chinStyle(Size size) => TextStyle(
      fontFamily: 'JetBrains Mono',
      package: 'kata_ui',
      fontSize: (size.shortestSide * 0.026).clamp(8.0, 17.0),
      fontWeight: FontWeight.w500,
      letterSpacing: 1.4,
      color: const Color(0xFF3A362E),
    );


/// Film-poster frame: the mid-century one-sheet grid, proportioned after the
/// Interstellar/GET OUT school. Cream stock; a calibration strip cut from the
/// photo's own palette; the kata mark; credit columns (bold head, italic
/// value) fed by EXIF; a massive w900 title; the photo on the lower half with
/// a broad quiet foot. Nothing moves — the grid is the design.
List<ComposeLayer> posterLayers(Size size, double unit, {PhotoMeta meta = const PhotoMeta(), List<Color>? palette, double? photoAspect}) {
  final m = size.width * 0.095;
  const ink = Color(0xFF1A1916);
  final headY = size.height * 0.125;
  final headH = (size.shortestSide * 0.0155).clamp(5.0, 11.0);
  final photoTop = size.height * 0.415;
  final photoBottom = size.height * 0.87;
  final usable = size.width - 2 * m;
  final colW = usable / 5;

  TextStyle small({FontWeight w = FontWeight.w400, FontStyle? style}) => TextStyle(
      fontFamily: 'Inter', package: 'kata_ui', fontSize: (size.shortestSide * 0.0148).clamp(4.5, 10.0), fontWeight: w, fontStyle: style, height: 1.25, color: ink);

  String? exposurePrefill;
  if (meta.iso != null || meta.fNumber != null || meta.exposure != null) {
    exposurePrefill = [
      if (meta.fNumber != null) 'f/${meta.fNumber!.toStringAsFixed(meta.fNumber! == meta.fNumber!.roundToDouble() ? 0 : 1)}',
      ?meta.exposure,
      if (meta.iso != null) 'ISO ${meta.iso}',
    ].join(' ');
  }
  String? datePrefill;
  if (meta.dateTime != null) {
    final d = meta.dateTime!;
    datePrefill = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }
  final cameraPrefill = [meta.make, meta.model].whereType<String>().join(' ');

  // slots pad their ink 10px for the tap target; regions start 10 early so the
  // ink itself sits on the column line the headers use
  ComposeTextSlot credit(String id, int col, String invitation, String? prefill) => ComposeTextSlot(
        id: id,
        region: Rect.fromLTWH(m + col * colW - 10, headY + headH * 1.45, colW - 4, headH * 3.4),
        style: small(style: FontStyle.italic),
        invitation: invitation,
        prefill: prefill,
        align: Alignment.topLeft,
        maxLines: 2,
        maxChars: 24,
        uppercase: false,
      );

  return [
    const ComposeSurface(ColoredBox(color: Color(0xFFF0EBDD))),
    ComposeSurface(_PosterFurniture(margin: m, headY: headY, headStyle: small(w: FontWeight.w700), colW: colW, palette: palette)),
    ComposePhotoWindow(rect: fitPhotoRect(Rect.fromLTRB(m, photoTop, size.width - m, photoBottom), photoAspect)),
    ComposeTextSlot(
      id: 'title',
      region: Rect.fromLTRB(m - 10, size.height * 0.245, size.width - m, photoTop - unit * 0.4),
      style: TextStyle(
          fontFamily: 'Inter',
          package: 'kata_ui',
          fontSize: (size.shortestSide * 0.175).clamp(18.0, 220.0),
          fontWeight: FontWeight.w900,
          height: 0.9,
          letterSpacing: -1.5,
          color: ink),
      invitation: 'UNTITLED',
      align: Alignment.topLeft,
      maxLines: 2,
      maxChars: 18,
      scalable: true,
      minScale: 0.55,
      maxScale: 1.15,
    ),
    credit('camera', 0, 'camera', cameraPrefill.isEmpty ? null : cameraPrefill),
    credit('lens', 1, 'lens', meta.focalMm == null ? null : '${meta.focalMm!.round()}mm'),
    credit('film', 2, 'film', meta.filmMode),
    credit('exposure', 3, 'exposure', exposurePrefill),
    credit('date', 4, 'date', datePrefill),
    ComposeGrainSheet(GrainSpec(strength: GrainStrength.weak, matchPx: grainPxForIso(meta.iso))),
  ];
}

/// The one-sheet's fixed furniture: the photo-palette strip, credit headers,
/// and the kata mark.
class _PosterFurniture extends StatelessWidget {
  const _PosterFurniture({required this.margin, required this.headY, required this.headStyle, required this.colW, this.palette});
  final double margin;
  final double headY;
  final TextStyle headStyle;
  final double colW;
  final List<Color>? palette;

  static const _fallbackChips = [Color(0xFF15130F), Color(0xFF2E6E71), Color(0xFF4C7A3F), Color(0xFFD9A62E), Color(0xFFC2482B)];
  static const _heads = ['CAMERA', 'LENS', 'FILM', 'EXPOSURE', 'DATE'];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final chips = (palette == null || palette!.isEmpty) ? _fallbackChips : palette!;
      final chipW = (w * 0.034).clamp(4.0, 34.0);
      final chipH = chipW * 0.56;
      final markSize = (w * 0.085).clamp(12.0, 90.0);
      return Stack(children: [
        Positioned(
          left: margin,
          top: box.maxHeight * 0.048,
          child: Row(children: [for (final c in chips) Container(width: chipW, height: chipH, color: c)]),
        ),
        Positioned(
          right: margin,
          top: box.maxHeight * 0.038,
          child: SizedBox(width: markSize, height: markSize, child: CustomPaint(painter: _KataMarkPainter(headStyle.color!))),
        ),
        for (var i = 0; i < _heads.length; i++)
          Positioned(left: margin + i * colW, top: headY, width: colW - 4, child: Text(_heads[i], style: headStyle)),
      ]);
    });
  }
}

/// The kata mark: the 型 seal in its ring, as the app wears it.
class _KataMarkPainter extends CustomPainter {
  _KataMarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final st = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s.shortestSide * 0.05).clamp(0.6, 2.2);
    final r = s.shortestSide / 2 - st.strokeWidth;
    c.drawCircle(s.center(Offset.zero), r, st);
    final tp = TextPainter(
      text: TextSpan(text: '型', style: TextStyle(fontSize: s.shortestSide * 0.52, color: color, fontWeight: FontWeight.w600, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset((s.width - tp.width) / 2, (s.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(_KataMarkPainter o) => o.color != color;
}

/// "words." dictionary poster — frame #3. Warm-gray stock; a boxed ka ta.
/// mark; the shot year running vertical up the left; the photo square-set
/// right of centre with the film simulation ghosted along its edge; the big
/// lowercase word with its full stop; [noun]; an etymology line prefilled
/// from the exposure; a small quoted line at the foot. Every slot is fixed —
/// this grid is the design.
List<ComposeLayer> wordsLayers(Size size, double unit, {PhotoMeta meta = const PhotoMeta(), double? photoAspect}) {
  const ink = Color(0xFF26241F);
  final w = size.width, h = size.height;
  final photo = fitPhotoRect(Rect.fromLTRB(w * 0.30, h * 0.265, w * 0.925, h * 0.79), photoAspect);

  TextStyle inter(double f, {FontWeight wt = FontWeight.w400, FontStyle? style, double height = 1.35, Color color = ink}) => TextStyle(
      fontFamily: 'Inter', package: 'kata_ui', fontSize: (size.shortestSide * f).clamp(5.0, 200.0), fontWeight: wt, fontStyle: style, height: height, color: color);

  String? aboutPrefill;
  if (meta.fNumber != null || meta.exposure != null || meta.iso != null || meta.model != null) {
    final bits = [
      if (meta.fNumber != null) 'f/${meta.fNumber!.toStringAsFixed(meta.fNumber! == meta.fNumber!.roundToDouble() ? 0 : 1)}',
      ?meta.exposure,
      if (meta.iso != null) 'iso ${meta.iso}',
    ].join(', ');
    final cam = [meta.make, meta.model].whereType<String>().join(' ').toLowerCase();
    aboutPrefill = [if (bits.isNotEmpty) 'shot at $bits', if (cam.isNotEmpty) 'on $cam'].join(' — ');
  }

  return [
    const ComposeSurface(ColoredBox(color: Color(0xFFE7E4DA))),
    ComposeSurface(_WordsFurniture(photo: photo, ink: ink, year: meta.dateTime?.year.toString(), sim: meta.filmMode)),
    ComposePhotoWindow(rect: photo),
    ComposeTextSlot(
      id: 'word',
      region: Rect.fromLTRB(w * 0.07, h * 0.44, w * 0.72, h * 0.60),
      style: inter(0.092, wt: FontWeight.w800, height: 0.95, color: ink).copyWith(letterSpacing: -1),
      invitation: 'Untitled.',
      align: Alignment.bottomLeft,
      uppercase: false,
      maxChars: 14,
      scalable: true,
      minScale: 0.6,
      maxScale: 1.2,
    ),
    ComposeTextSlot(
      id: 'pos',
      region: Rect.fromLTRB(w * 0.07, h * 0.612, w * 0.30, h * 0.652),
      style: inter(0.020, style: FontStyle.italic),
      invitation: '[noun]',
      align: Alignment.centerLeft,
      uppercase: false,
      maxChars: 18,
    ),
    ComposeTextSlot(
      id: 'about',
      region: Rect.fromLTRB(w * 0.07, h * 0.662, w * 0.55, h * 0.745),
      style: inter(0.0185, height: 1.4, color: const Color(0xB326241F)),
      invitation: 'where this one came from',
      prefill: aboutPrefill,
      align: Alignment.topLeft,
      uppercase: false,
      maxLines: 3,
      maxChars: 110,
    ),
    ComposeTextSlot(
      id: 'quote',
      region: Rect.fromLTRB(w * 0.16, h * 0.862, w * 0.84, h * 0.905),
      style: inter(0.019, wt: FontWeight.w500),
      invitation: 'the pleasant earthy smell after rain',
      align: Alignment.center,
      uppercase: false,
      maxChars: 48,
    ),
    ComposeGrainSheet(GrainSpec(strength: GrainStrength.weak, matchPx: grainPxForIso(meta.iso))),
  ];
}

/// The words-poster furniture: boxed mark, index rule, vertical year, ghost sim.
class _WordsFurniture extends StatelessWidget {
  const _WordsFurniture({required this.photo, required this.ink, this.year, this.sim});
  final Rect photo;
  final Color ink;
  final String? year;
  final String? sim;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final short = w < h ? w : h;
      TextStyle mono(double f, {Color? c, FontWeight wt = FontWeight.w500, double ls = 1.2}) => TextStyle(
          fontFamily: 'JetBrains Mono', package: 'kata_ui', fontSize: (short * f).clamp(4.0, 40.0), fontWeight: wt, letterSpacing: ls, color: c ?? ink, height: 1.1);
      final boxSize = (short * 0.135).clamp(18.0, 120.0);
      return Stack(children: [
        // the ka ta. mark
        Positioned(
          right: w * 0.075,
          top: h * 0.042,
          child: Container(
            width: boxSize,
            height: boxSize,
            padding: EdgeInsets.all(boxSize * 0.14),
            decoration: BoxDecoration(border: Border.all(color: ink, width: (boxSize * 0.045).clamp(0.8, 3.0))),
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              child: Text('ka\nta.', style: TextStyle(fontFamily: 'Inter', package: 'kata_ui', fontWeight: FontWeight.w800, height: 1.02, color: ink, fontSize: 20)),
            ),
          ),
        ),
        // index over the photo's right shoulder, double-ruled
        Positioned(
          right: w - photo.right,
          top: h * 0.215,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('001', style: mono(0.020)),
            SizedBox(height: short * 0.006),
            Container(width: short * 0.045, height: 1, color: ink),
            SizedBox(height: short * 0.004),
            Container(width: short * 0.045, height: 1, color: ink),
          ]),
        ),
        // the year, reading up the left margin
        if (year != null)
          Positioned(
            left: w * 0.045,
            top: h * 0.24,
            child: RotatedBox(quarterTurns: 3, child: Text('($year) ▾', style: mono(0.020))),
          ),
        // film simulation ghosted along the photo's right edge
        if (sim != null)
          Positioned(
            left: photo.right - short * 0.052,
            top: photo.top + h * 0.02,
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(sim!, style: mono(0.034, c: ink.withValues(alpha: 0.16), wt: FontWeight.w600, ls: 2)),
            ),
          ),
        // quotation marks flanking the foot line
        Positioned(left: w * 0.115, top: h * 0.858, child: Text('\u201C', style: mono(0.034, wt: FontWeight.w700))),
        Positioned(right: w * 0.115, top: h * 0.858, child: Text('\u201D', style: mono(0.034, wt: FontWeight.w700))),
      ]);
    });
  }
}
