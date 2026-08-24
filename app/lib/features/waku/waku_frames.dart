import 'package:flutter/material.dart';

import '../../core/compose/grain.dart';
import '../../core/compose/layers.dart';
import 'waku_exif.dart';

/// The Waku gallery is curated: a frame ships only when it has something of
/// its own. One for now — the instant print. Each frame is a fixed layer
/// stack; what users may touch is declared per layer, never changed by them.
enum WakuFrame {
  polaroid('Polaroid'),
  archive('Label'),
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


/// Archive label card: the photo mounted on cream stock, a maroon museum
/// tombstone beside it — artist, italic title, then the facts the photo
/// already knows (camera + film simulation, shot date, via EXIF prefill) and
/// an accession number with its Code 39 barcode. Wave 2 of the curated
/// gallery; anatomy per docs/design/waku-frames.md.
List<ComposeLayer> labelLayers(Size size, double unit, {PhotoMeta meta = const PhotoMeta()}) {
  final m = unit * 1.3;
  final photoBottom = size.height * 0.66;
  final cardTop = photoBottom + unit * 0.8;
  final cardLeft = m;
  final cardWidth = size.width * 0.60;
  final cardBottom = size.height - m;
  final pc = unit * 0.55; // card padding
  final ink = const Color(0xFFEFE6D4); // cream ink on maroon
  final accession = _accession(meta);
  final lineH = (size.shortestSide * 0.030).clamp(9.0, 22.0);

  TextStyle mono(double f) => TextStyle(
      fontFamily: 'JetBrains Mono', package: 'kata_ui', fontSize: (size.shortestSide * f).clamp(6.5, 15.0), fontWeight: FontWeight.w500, letterSpacing: 0.6, color: ink);

  final hasCameraFacts = meta.make != null || meta.model != null || meta.filmMode != null;
  final mediumPrefill = !hasCameraFacts
      ? null
      : [
          [meta.make, meta.model].whereType<String>().join(' '),
          ?meta.filmMode,
        ].where((x) => x.isNotEmpty).join(' · ');

  String? datePrefill;
  if (meta.dateTime != null) {
    const months = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
    final d = meta.dateTime!;
    datePrefill = '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  return [
    const ComposeSurface(ColoredBox(color: Color(0xFFF2EDE2)), grain: GrainSpec(strength: GrainStrength.weak, size: GrainSize.small)),
    // the card, its accession line and barcode — fixed furniture, like a museum wall
    ComposeSurface(
      _LabelCard(rect: Rect.fromLTRB(cardLeft, cardTop, cardLeft + cardWidth, cardBottom), padding: pc, accession: accession, accessionStyle: mono(0.020)),
    ),
    ComposePhotoWindow(
      rect: Rect.fromLTRB(m, m, size.width - m, photoBottom),
      shadow: const [BoxShadow(color: Color(0x3D3A2A1C), blurRadius: 14, offset: Offset(0, 6))],
    ),
    ComposeTextSlot(
      id: 'artist',
      region: Rect.fromLTRB(cardLeft + pc, cardTop + pc * 0.8, cardLeft + cardWidth - pc, cardTop + pc * 0.8 + lineH * 1.25),
      style: TextStyle(
          fontFamily: 'JetBrains Mono', package: 'kata_ui', fontSize: lineH * 0.82, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: ink),
      invitation: 'ARTIST',
      align: Alignment.centerLeft,
      maxChars: 28,
    ),
    ComposeTextSlot(
      id: 'title',
      region: Rect.fromLTRB(cardLeft + pc, cardTop + pc * 0.8 + lineH * 1.3, cardLeft + cardWidth - pc, cardTop + pc * 0.8 + lineH * 2.6),
      style: TextStyle(fontFamily: 'Inter', package: 'kata_ui', fontSize: lineH * 0.8, fontStyle: FontStyle.italic, color: ink),
      invitation: 'Untitled',
      align: Alignment.centerLeft,
      maxChars: 36,
      uppercase: false, // titles keep their case, like the wall does
    ),
    ComposeTextSlot(
      id: 'medium',
      region: Rect.fromLTRB(cardLeft + pc, cardTop + pc * 0.8 + lineH * 2.85, cardLeft + cardWidth - pc, cardTop + pc * 0.8 + lineH * 3.85),
      style: mono(0.021),
      invitation: 'MEDIUM',
      prefill: mediumPrefill,
      align: Alignment.centerLeft,
      maxChars: 40,
    ),
    ComposeTextSlot(
      id: 'date',
      region: Rect.fromLTRB(cardLeft + pc, cardTop + pc * 0.8 + lineH * 3.95, cardLeft + cardWidth - pc, cardTop + pc * 0.8 + lineH * 4.95),
      style: mono(0.021),
      invitation: 'DATE',
      prefill: datePrefill,
      align: Alignment.centerLeft,
      maxChars: 24,
    ),
  ];
}

String _accession(PhotoMeta meta) {
  final d = meta.dateTime;
  if (d == null) return 'KATA.0000.00';
  return 'KATA.${d.year}.${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

class _LabelCard extends StatelessWidget {
  const _LabelCard({required this.rect, required this.padding, required this.accession, required this.accessionStyle});
  final Rect rect;
  final double padding;
  final String accession;
  final TextStyle accessionStyle;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fromRect(
        rect: rect,
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFF5E211B), borderRadius: BorderRadius.circular(2), boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 8, offset: Offset(0, 3))]),
          padding: EdgeInsets.all(padding),
          child: Align(
            alignment: Alignment.bottomLeft,
            // scale-safe down to thumbnail size
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: (rect.width - padding * 2) * 0.42,
                height: (rect.height * 0.16).clamp(10.0, 26.0),
                child: CustomPaint(painter: Code39Painter(accession.replaceAll(RegExp(r'[^0-9]'), ''), const Color(0xFFEFE6D4))),
              ),
                const SizedBox(width: 8),
                Text(accession, style: accessionStyle),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
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
