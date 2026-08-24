import 'package:flutter/material.dart';

import '../../core/compose/grain.dart';
import '../../core/compose/layers.dart';
import 'waku_exif.dart';

/// The Waku gallery is curated: a frame ships only when it has something of
/// its own. One for now — the instant print. Each frame is a fixed layer
/// stack; what users may touch is declared per layer, never changed by them.
enum WakuFrame {
  polaroid('Polaroid'),
  poster('Poster'),
  words('Words'),
  custom('Custom');

  const WakuFrame(this.label);
  final String label;
}

/// Instant-print: bright white stock, tight even sides, the classic deep chin.
/// Layers, bottom → top: paper · photo window · the chin's hand-written line
/// (editable, and draggable along the chin like a real pen would wander).
List<ComposeLayer> polaroidLayers(Size size, double unit) {
  final m = unit * 0.72;
  final chin = unit * 2.9;
  return [
    // the stock itself has tooth — our call, per frame; users don't touch grain
    const ComposeSurface(ColoredBox(color: Color(0xFFFBFAF6)), grain: GrainSpec(strength: GrainStrength.weak, size: GrainSize.small)),
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


/// Film-poster frame: the mid-century one-sheet grid. Cream stock, a colour
/// calibration strip and a reel mark up top, tiny credit columns fed by EXIF,
/// a massive black title, and the photo seated on the lower half. Frame #2 of
/// the curated gallery.
List<ComposeLayer> posterLayers(Size size, double unit, {PhotoMeta meta = const PhotoMeta()}) {
  final m = size.width * 0.075;
  const ink = Color(0xFF1A1916);
  final headY = size.height * 0.082;
  final headH = (size.shortestSide * 0.016).clamp(5.0, 12.0);
  final photoTop = size.height * 0.545;
  final usable = size.width - 2 * m;
  final colW = usable / 5;

  TextStyle small({FontWeight w = FontWeight.w500}) => TextStyle(
      fontFamily: 'Inter', package: 'kata_ui', fontSize: (size.shortestSide * 0.0148).clamp(4.5, 10.0), fontWeight: w, height: 1.25, color: ink);

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

  ComposeTextSlot credit(String id, int col, String invitation, String? prefill) => ComposeTextSlot(
        id: id,
        region: Rect.fromLTWH(m + col * colW, headY + headH * 1.5, colW - 6, headH * 3.2),
        style: small(),
        invitation: invitation,
        prefill: prefill,
        align: Alignment.topLeft,
        maxLines: 2,
        maxChars: 24,
      );

  return [
    const ComposeSurface(ColoredBox(color: Color(0xFFF0EBDD)), grain: GrainSpec(strength: GrainStrength.weak, size: GrainSize.small)),
    ComposeSurface(_PosterFurniture(margin: m, headY: headY, headStyle: small(w: FontWeight.w700), colW: colW)),
    ComposePhotoWindow(rect: Rect.fromLTRB(m, photoTop, size.width - m, size.height - m * 0.9)),
    ComposeTextSlot(
      id: 'title',
      region: Rect.fromLTRB(m, headY + headH * 5.4, size.width - m, photoTop - unit * 0.5),
      style: TextStyle(
          fontFamily: 'Inter',
          package: 'kata_ui',
          fontSize: (size.shortestSide * 0.165).clamp(18.0, 200.0),
          fontWeight: FontWeight.w900,
          height: 0.88,
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
    credit('artist', 0, 'YOU', null),
    credit('camera', 1, 'CAMERA', cameraPrefill.isEmpty ? null : cameraPrefill),
    credit('film', 2, 'FILM', meta.filmMode),
    credit('exposure', 3, 'EXPOSURE', exposurePrefill),
    credit('date', 4, 'DATE', datePrefill),
  ];
}

/// The one-sheet's fixed furniture: calibration chips, credit headers, reel mark.
class _PosterFurniture extends StatelessWidget {
  const _PosterFurniture({required this.margin, required this.headY, required this.headStyle, required this.colW});
  final double margin;
  final double headY;
  final TextStyle headStyle;
  final double colW;

  static const _chips = [Color(0xFF15130F), Color(0xFF2E6E71), Color(0xFF4C7A3F), Color(0xFFD9A62E), Color(0xFFC2482B)];
  static const _heads = ['A PHOTO BY', 'CAMERA', 'FILM', 'EXPOSURE', 'DATE'];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final chipW = (box.maxWidth * 0.028).clamp(4.0, 26.0);
      final chipH = chipW * 0.62;
      return Stack(children: [
        Positioned(
          left: margin,
          top: headY - chipH * 2.1,
          child: Row(children: [for (final c in _chips) Container(width: chipW, height: chipH, color: c)]),
        ),
        Positioned(
          right: margin,
          top: headY - chipH * 2.3,
          child: SizedBox(width: chipW * 2.6, height: chipH * 1.7, child: CustomPaint(painter: _ReelMarkPainter(headStyle.color!))),
        ),
        for (var i = 0; i < _heads.length; i++)
          Positioned(left: margin + i * colW, top: headY, width: colW - 6, child: Text(_heads[i], style: headStyle)),
      ]);
    });
  }
}

/// The little festival mark: an oval globe with meridians and a reel hub.
class _ReelMarkPainter extends CustomPainter {
  _ReelMarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final st = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (s.height * 0.06).clamp(0.5, 1.4);
    final r = Rect.fromLTWH(st.strokeWidth, st.strokeWidth, s.width - 2 * st.strokeWidth, s.height - 2 * st.strokeWidth);
    c.drawOval(r, st);
    c.drawLine(Offset(r.left, r.center.dy), Offset(r.right, r.center.dy), st);
    c.drawOval(Rect.fromCenter(center: r.center, width: r.width * 0.55, height: r.height), st);
    c.drawOval(Rect.fromCenter(center: r.center, width: r.width * 0.16, height: r.height * 0.28), st);
  }

  @override
  bool shouldRepaint(_ReelMarkPainter o) => o.color != color;
}

/// Real Code 39: start/stop asterisks around the digits, nine elements per
/// character (three wide), narrow gaps between characters.
class Code39Painter extends CustomPainter {
  Code39Painter(this.digits, this.color);
  final String digits;
  final Color color;

  static const _patterns = {
    '*': 'nwnnwnwnn',
    '0': 'nnnwwnwnn',
    '1': 'wnnwnnnnw',
    '2': 'nnwwnnnnw',
    '3': 'wnwwnnnnn',
    '4': 'nnnwwnnnw',
    '5': 'wnnwwnnnn',
    '6': 'nnwwwnnnn',
    '7': 'nnnwnnwnw',
    '8': 'wnnwnnwnn',
    '9': 'nnwwnnwnn',
  };

  @override
  void paint(Canvas c, Size s) {
    final payload = '*${digits.isEmpty ? '0' : digits}*';
    // total narrow units: per char 6 narrow + 3 wide(=2u each) = 12u, +1 gap
    final units = payload.length * 13 - 1;
    final u = s.width / units;
    final paint = Paint()..color = color;
    var x = 0.0;
    for (final ch in payload.split('')) {
      final pattern = _patterns[ch] ?? _patterns['0']!;
      for (var i = 0; i < pattern.length; i++) {
        final w = (pattern[i] == 'w' ? 2 : 1) * u;
        if (i.isEven) c.drawRect(Rect.fromLTWH(x, 0, w, s.height), paint);
        x += w;
      }
      x += u; // inter-character gap
    }
  }

  @override
  bool shouldRepaint(Code39Painter o) => o.digits != digits || o.color != color;
}


/// "words." dictionary poster — frame #3. Warm-gray stock; a boxed ka ta.
/// mark; the shot year running vertical up the left; the photo square-set
/// right of centre with the film simulation ghosted along its edge; the big
/// lowercase word with its full stop; [noun]; an etymology line prefilled
/// from the exposure; a small quoted line at the foot. Every slot is fixed —
/// this grid is the design.
List<ComposeLayer> wordsLayers(Size size, double unit, {PhotoMeta meta = const PhotoMeta()}) {
  const ink = Color(0xFF26241F);
  final w = size.width, h = size.height;
  final photo = Rect.fromLTRB(w * 0.30, h * 0.265, w * 0.925, h * 0.79);

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
    const ComposeSurface(ColoredBox(color: Color(0xFFE7E4DA)), grain: GrainSpec(strength: GrainStrength.weak, size: GrainSize.small)),
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
