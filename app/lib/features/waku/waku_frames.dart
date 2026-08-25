
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/compose/grain.dart';
import '../../core/compose/layers.dart';
import '../../core/compose/sheet_layout.dart';
import 'waku_exif.dart';
import 'waku_grain_measure.dart';

/// The Waku gallery is curated: a frame ships only when it has something of
/// its own. One for now — the instant print. Each frame is a fixed layer
/// stack; what users may touch is declared per layer, never changed by them.
enum WakuFrame {
  polaroid('Polaroid', canvasAspect: 88 / 107),
  // no fixed sheet: the one-sheet is solved for whatever ratio you're posting
  poster('Poster'),
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

/// The sheet's texture, taken from the photograph it carries: a print is one
/// object, so the ground should sit in the same grain as the picture rather
/// than in a paper texture of its own invention. [renderedWidth] is how wide
/// the frame draws the photo — the same grain magnifies with it.
(GrainSpec ground, GrainSpec ink) sheetGrain(PhotoGrain g, double renderedWidth) {
  final (clump, amount) = g.onSheet(renderedWidth);
  return (
    GrainSpec.measured(clumpPx: clump, amount: amount),
    // ink holds the same texture at a third of the weight: it isn't a separate
    // material, it's the same surface seen through what was printed on it
    GrainSpec.measured(clumpPx: clump, amount: amount * 0.33),
  );
}

/// A print hangs from its foot: the photo's bottom edge sits on [bottom] and it
/// grows upward, never past [top]. Centring it in a band instead leaves a foot
/// that changes depth with every ratio — the one thing a printed sheet doesn't do.
Rect hangPhotoRect({required double left, required double right, required double top, required double bottom, double? aspect}) {
  if (aspect == null) return Rect.fromLTRB(left, top, right, bottom);
  var w = right - left;
  var h = w / aspect;
  if (h > bottom - top) {
    h = bottom - top;
    w = h * aspect;
  }
  final cx = (left + right) / 2;
  return Rect.fromLTRB(cx - w / 2, bottom - h, cx + w / 2, bottom);
}

/// Instant-print: bright white stock, tight even sides, the classic deep chin.
/// Layers, bottom → top: paper · photo window · the chin's hand-written line
/// (editable, and draggable along the chin like a real pen would wander).
List<ComposeLayer> polaroidLayers(Size size, double unit, {PhotoMeta meta = const PhotoMeta(), PhotoGrain grain = PhotoGrain.none}) {
  final m = unit * 0.72;
  final chin = unit * 2.9;
  final (groundGrain, inkGrain) = sheetGrain(grain, size.width - 2 * m);
  return [
    // the stock itself has tooth — our call, per frame; users don't touch grain
    const ComposeSurface(ColoredBox(color: Color(0xFFFBFAF6))),
    ComposeGrainSheet(groundGrain),
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
    ComposeGrainSheet(inkGrain, overInk: true),
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


/// Film-poster frame: the mid-century one-sheet, proportioned after the
/// Interstellar/GET OUT school, and solved for whatever shape the sheet is —
/// a story, a feed post, a square. Every measure is a fraction of the width,
/// so type and margins hold their size and the photograph absorbs the rest
/// (see core/compose/sheet_layout.dart).
List<ComposeLayer> posterLayers(Size size, double unit,
    {PhotoMeta meta = const PhotoMeta(), List<Color>? palette, double? photoAspect, PhotoGrain grain = PhotoGrain.none}) {
  const ink = Color(0xFF1A1916);
  final grid = solveSheet(size, const [
    SheetRow.gap(0.055),
    SheetRow.band(0.032, id: 'chips'),
    SheetRow.gap(0.075),
    SheetRow.band(0.042, id: 'tagline'),
    SheetRow.gap(0.030),
    // three rows of label-over-value, each 2.9 line heights, so they can't collide
    SheetRow.band(0.190, id: 'credits'),
    SheetRow.gap(0.035),
    SheetRow.band(0.235, id: 'title'),
    SheetRow.gap(0.030),
    SheetRow.flex(id: 'photo', minWidths: 0.34),
    SheetRow.gap(0.035),
    SheetRow.band(0.058, id: 'byline'),
    SheetRow.gap(0.050),
  ]);
  final w = size.width;
  final photoRect = hangInto(grid['photo'], photoAspect);
  final (groundGrain, inkGrain) = sheetGrain(grain, photoRect.width);
  final credits = grid['credits'];
  final colW = credits.width / 2;
  final rowH = credits.height / 3;
  final headH = math.max(5.0, w * 0.0215);

  // no upper clamp: type is a fraction of the sheet, so it holds its proportion
  // at every size and ratio. The floor is only there for a 58px thumbnail.
  TextStyle small({FontWeight wt = FontWeight.w400, FontStyle? style, double f = 0.0215, Color c = ink}) =>
      TextStyle(fontFamily: 'Inter', package: 'kata_ui', fontSize: math.max(4.5, w * f), fontWeight: wt, fontStyle: style, height: 1.25, color: c);

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

  // Two generous columns beat five thin ones: the value gets room to be read,
  // which is the whole point of a credit. Regions start 10 early so the ink
  // itself lands on the column line the headers use.
  ComposeTextSlot credit(String id, int col, int row, String invitation, String? prefill) => ComposeTextSlot(
        id: id,
        region: Rect.fromLTWH(credits.left + col * colW - 10, credits.top + row * rowH + headH * 1.3, colW - 12, headH * 2.0),
        style: small(style: FontStyle.italic),
        invitation: invitation,
        prefill: prefill,
        align: Alignment.topLeft,
        maxLines: 1,
        maxChars: 30,
        uppercase: false,
      );

  return [
    const ComposeSurface(ColoredBox(color: Color(0xFFF0EBDD))),
    ComposeGrainSheet(groundGrain),
    ComposeSurface(_PosterFurniture(grid: grid, headStyle: small(wt: FontWeight.w700), rowH: rowH, colW: colW, palette: palette)),
    ComposePhotoWindow(rect: photoRect),
    // the line above the title, spread wide the way a one-sheet quotes a review
    ComposeTextSlot(
      id: 'tagline',
      region: grid['tagline'].translate(-10, 0),
      style: small(wt: FontWeight.w500, f: 0.024).copyWith(letterSpacing: math.max(4.5, w * 0.024) * 0.22),
      invitation: 'A QUIET WEEK',
      align: Alignment.centerLeft,
      maxChars: 42,
    ),
    ComposeTextSlot(
      id: 'title',
      region: grid['title'].translate(-10, 0),
      style: TextStyle(
          fontFamily: 'Inter',
          package: 'kata_ui',
          fontSize: math.max(12.0, w * 0.175),
          fontWeight: FontWeight.w900,
          height: 0.9,
          letterSpacing: -1.5,
          color: ink),
      invitation: 'UNTITLED',
      align: Alignment.bottomLeft,
      maxLines: 2,
      maxChars: 24,
      // a title is set to the sheet: long ones shrink instead of running into
      // the photograph, which is what a fixed size did
      fitRegion: true,
      scalable: true,
      minScale: 0.55,
      maxScale: 1.15,
    ),
    credit('camera', 0, 0, 'camera', cameraPrefill.isEmpty ? null : cameraPrefill),
    credit('lens', 0, 1, 'lens', meta.focalMm == null ? null : '${meta.focalMm!.round()}mm'),
    credit('film', 0, 2, 'film', meta.filmMode),
    credit('exposure', 1, 0, 'exposure', exposurePrefill),
    credit('date', 1, 1, 'date', datePrefill),
    // the billing block: who made the picture, in the squeezed one-sheet manner
    ComposeTextSlot(
      id: 'byline',
      region: grid['byline'],
      style: small(wt: FontWeight.w600, f: 0.030).copyWith(letterSpacing: math.max(4.5, w * 0.030) * 0.06),
      invitation: 'YOUR NAME',
      align: Alignment.topCenter,
      maxChars: 34,
    ),
    ComposeGrainSheet(inkGrain, overInk: true),
  ];
}

/// The one-sheet's fixed furniture: the photo-palette strip, the kata mark, the
/// credit headers, and the billing block's rule and imprint. All of it hangs off
/// the solved grid, so it travels with the rows.
class _PosterFurniture extends StatelessWidget {
  const _PosterFurniture({required this.grid, required this.headStyle, required this.rowH, required this.colW, this.palette});
  final SheetGrid grid;
  final TextStyle headStyle;
  final double rowH;
  final double colW;
  final List<Color>? palette;

  static const _fallbackChips = [Color(0xFF15130F), Color(0xFF2E6E71), Color(0xFF4C7A3F), Color(0xFFD9A62E), Color(0xFFC2482B)];
  static const _heads = [(0, 0, 'CAMERA'), (0, 1, 'LENS'), (0, 2, 'FILM'), (1, 0, 'EXPOSURE'), (1, 1, 'DATE')];

  @override
  Widget build(BuildContext context) {
    final chipsRow = grid['chips'];
    final credits = grid['credits'];
    final byline = grid['byline'];
    final ink = headStyle.color!;
    final chips = (palette == null || palette!.isEmpty) ? _fallbackChips : palette!;
    final chipW = chipsRow.height;
    final markSize = grid.size.width * 0.085;
    return Stack(children: [
      Positioned(
        left: chipsRow.left,
        top: chipsRow.top,
        child: Row(children: [for (final c in chips) Container(width: chipW, height: chipW, color: c)]),
      ),
      Positioned(
        right: grid.margin,
        top: chipsRow.center.dy - markSize / 2,
        child: SizedBox(width: markSize, height: markSize, child: CustomPaint(painter: _KataMarkPainter(ink))),
      ),
      for (final (c, r, label) in _heads)
        Positioned(left: credits.left + c * colW, top: credits.top + r * rowH, child: Text(label, style: headStyle)),
      // the billing block's own furniture: a hairline over it, an imprint under
      Positioned(
        left: grid.size.width * 0.34,
        right: grid.size.width * 0.34,
        top: byline.top - byline.height * 0.42,
        child: Container(height: 0.8, color: ink.withValues(alpha: 0.35)),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: byline.bottom + byline.height * 0.18,
        child: Text('PHOTOGRAPHED WITH KATA 型',
            textAlign: TextAlign.center,
            style: headStyle.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: headStyle.fontSize! * 0.82,
              color: ink.withValues(alpha: 0.55),
              letterSpacing: headStyle.fontSize! * 0.14,
            )),
      ),
    ]);
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
List<ComposeLayer> wordsLayers(Size size, double unit, {PhotoMeta meta = const PhotoMeta(), double? photoAspect, PhotoGrain grain = PhotoGrain.none}) {
  const ink = Color(0xFF26241F);
  final w = size.width, h = size.height;
  final photo = fitPhotoRect(Rect.fromLTRB(w * 0.30, h * 0.265, w * 0.925, h * 0.79), photoAspect);
  final (groundGrain, inkGrain) = sheetGrain(grain, photo.width);

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
    ComposeGrainSheet(groundGrain),
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
    ComposeGrainSheet(inkGrain, overInk: true),
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
