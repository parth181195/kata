import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';

/// The frames are the product: each preset is a real design, drawn
/// procedurally so it stays crisp at any export size. `unit` is the mat
/// scale — a fraction of the canvas short side, set by the width slider.
enum WakuFrame {
  gallery('Gallery'),
  museum('Museum'),
  polaroid('Polaroid'),
  film('Film'),
  float('Float'),
  stamp('Stamp'),
  taped('Taped'),
  stack('Stack'),
  journal('Journal'),
  grid('Grid'),
  split('Split'),
  postcard('Postcard'),
  custom('Custom');

  const WakuFrame(this.label);
  final String label;

  /// Caption ink that reads on this frame's surround.
  Color captionColor() => switch (this) {
        gallery || museum || polaroid || taped || split || journal => const Color(0xFF3A362E),
        stack => const Color(0xFF2F2E2B),
        film => const Color(0xFFB8B4AA),
        float => const Color(0xFFD8D5CE),
        stamp => const Color(0xFFD9DCD2),
        grid || custom => Colors.white,
        postcard => const Color(0xFFB3402B),
      };
}

/// Wraps [photo] in the chosen frame. [size] is the finished canvas size,
/// [unit] the mat width in logical px, [caption] an optional line for the frame's
/// caption spot — chin, tape label, headline, edge marking, depending on the design.
class WakuFramed extends StatelessWidget {
  const WakuFramed({super.key, required this.frame, required this.photo, required this.size, required this.unit, this.caption = ''});
  final WakuFrame frame;
  final Widget photo;
  final Size size;
  final double unit;
  final String caption;

  bool get _thumb => size.width < 140; // thumbnails drop fine text and markings

  @override
  Widget build(BuildContext context) {
    final cap = caption.trim();
    final capStyle = KataType.monoStyle(
        size: (size.shortestSide * 0.022).clamp(7.0, 15.0), weight: FontWeight.w500, color: frame.captionColor(), letterSpacing: 0.18);
    return switch (frame) {
      WakuFrame.gallery => _gallery(cap, capStyle),
      WakuFrame.museum => _museum(cap, capStyle),
      WakuFrame.polaroid => _polaroid(cap, capStyle),
      WakuFrame.film => _film(cap, capStyle),
      WakuFrame.float => _float(cap, capStyle),
      WakuFrame.stamp => _stamp(cap, capStyle),
      WakuFrame.taped => _taped(cap),
      WakuFrame.stack => _stack(cap, capStyle),
      WakuFrame.journal => _journal(cap),
      WakuFrame.grid => _grid(cap, capStyle),
      WakuFrame.split => _split(cap),
      WakuFrame.postcard => _postcard(cap),
      WakuFrame.custom => photo, // the screen composes custom frames itself
    };
  }

  Widget _captioned(Widget child, String cap, TextStyle st, {double gap = 0}) => cap.isEmpty
      ? child
      : Column(children: [
          Expanded(child: child),
          Padding(padding: EdgeInsets.only(top: gap), child: Text(cap.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: st)),
        ]);

  /// Subtle paper grain behind the flat surrounds.
  Widget _paper(Color base, {Widget? child}) => CustomPaint(
        painter: _GrainPainter(base),
        child: child,
      );

  /// Classic single mat: warm white, weighted bottom, hairline bevel around the window.
  Widget _gallery(String cap, TextStyle capStyle) {
    final m = unit;
    return Container(
      color: const Color(0xFFF6F4EF),
      padding: EdgeInsets.fromLTRB(m, m, m, m * 1.55),
      child: _captioned(_bevelled(photo, light: const Color(0xFFFFFFFF), dark: const Color(0x33222018)), cap, capStyle, gap: m * 0.45),
    );
  }

  /// Double mat: a cream inner mat visible as a stepped reveal inside the white outer.
  Widget _museum(String cap, TextStyle capStyle) {
    final m = unit;
    return Container(
      color: const Color(0xFFF4F1EA),
      padding: EdgeInsets.fromLTRB(m, m, m, m * 1.4),
      child: _captioned(
        Container(
          color: const Color(0xFFE7DFCC),
          padding: EdgeInsets.all(m * 0.34),
          child: _bevelled(photo, light: const Color(0xFFFFF9EA), dark: const Color(0x40251E12)),
        ),
        cap,
        capStyle,
        gap: m * 0.45,
      ),
    );
  }

  /// Instant-print: tight even sides, the classic deep chin. Caption lives on the chin.
  Widget _polaroid(String cap, TextStyle capStyle) {
    final m = unit * 0.72;
    final chin = unit * 2.9;
    return Container(
      color: const Color(0xFFFBFAF6),
      padding: EdgeInsets.fromLTRB(m, m * 1.15, m, 0),
      child: Column(children: [
        Expanded(child: DecoratedBox(decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 3, offset: Offset(0, 1))]), child: photo)),
        SizedBox(
          height: chin,
          child: Center(child: cap.isEmpty ? null : Text(cap.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: capStyle)),
        ),
      ]),
    );
  }

  /// A 35mm strip: sprocket rows top and bottom, edge markings in the classic amber.
  Widget _film(String cap, TextStyle capStyle) {
    final band = math.max(unit * 1.05, 16.0);
    const bg = Color(0xFF0B0B0A);
    final edge = KataType.monoStyle(size: (band * 0.30).clamp(6.0, 11.0), weight: FontWeight.w500, color: const Color(0xFFC98F2D), letterSpacing: 0.22);
    Widget sprockets({required bool top}) => SizedBox(
          height: band,
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _SprocketPainter())),
            if (!_thumb)
              Positioned(
                left: 4,
                right: 4,
                top: top ? 1 : null,
                bottom: top ? null : 1,
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(top ? 'KATA 400' : '▸ 24', style: edge),
                  Flexible(child: Text(top ? (cap.isEmpty ? 'WAKU' : cap.toUpperCase()) : '24A', maxLines: 1, overflow: TextOverflow.ellipsis, style: edge)),
                ]),
              ),
          ]),
        );
    return Container(
      color: bg,
      padding: EdgeInsets.symmetric(horizontal: unit * 0.55),
      child: Column(children: [
        sprockets(top: true),
        Expanded(child: photo),
        sprockets(top: false),
      ]),
    );
  }

  /// Charcoal surround, the photo floating on a thin keyline.
  Widget _float(String cap, TextStyle capStyle) {
    final m = unit * 1.15;
    return Container(
      color: const Color(0xFF17181A),
      padding: EdgeInsets.fromLTRB(m, m, m, cap.isEmpty ? m : m * 1.5),
      child: _captioned(
        Container(
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE8E5DE), width: 1.2), boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 5))]),
          child: photo,
        ),
        cap,
        capStyle,
        gap: m * 0.4,
      ),
    );
  }

  /// A postage stamp: perforated white paper on a deep textured mat.
  Widget _stamp(String cap, TextStyle capStyle) {
    final m = unit * 1.7;
    final tooth = (unit * 0.34).clamp(3.0, 12.0);
    return _paper(
      const Color(0xFF4B4F44),
      child: Padding(
        padding: EdgeInsets.fromLTRB(m, m, m, cap.isEmpty ? m : m * 1.35),
        child: _captioned(
          ClipPath(
            clipper: _StampClipper(tooth),
            child: Container(
              color: const Color(0xFFEDEBE4),
              padding: EdgeInsets.all(tooth * 2.1),
              child: photo,
            ),
          ),
          cap,
          capStyle,
          gap: m * 0.32,
        ),
      ),
    );
  }

  /// A print taped to paper: slight tilt, white border, two strips of tape.
  Widget _taped(String cap) {
    final m = unit * 1.5;
    final tapeW = (unit * 2.6).clamp(18.0, 120.0);
    final tapeH = tapeW * 0.34;
    Widget tape(double angle) => Transform.rotate(
          angle: angle,
          child: Container(width: tapeW, height: tapeH, color: const Color(0x8CD9C878)),
        );
    return _paper(
      const Color(0xFFF3EFE6),
      child: Stack(children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.fromLTRB(m, m * 1.3, m, cap.isEmpty ? m * 1.3 : m * 2.1),
            child: Transform.rotate(
              angle: -0.024,
              child: Container(
                padding: EdgeInsets.all(unit * 0.5),
                decoration: const BoxDecoration(color: Color(0xFFFDFCF8), boxShadow: [BoxShadow(color: Color(0x30000000), blurRadius: 10, offset: Offset(0, 4))]),
                child: photo,
              ),
            ),
          ),
        ),
        Positioned(top: m * 0.72, left: m * 0.55, child: tape(-0.45)),
        Positioned(top: m * 0.72, right: m * 0.55, child: tape(0.42)),
        if (cap.isNotEmpty)
          Positioned(
            left: m,
            right: m,
            bottom: m * 0.7,
            child: Text(cap, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: KataType.bodyStyle(size: (size.shortestSide * 0.028).clamp(9.0, 18.0), color: const Color(0xFF3A362E)).copyWith(fontStyle: FontStyle.italic)),
          ),
      ]),
    );
  }

  /// Two prints on textured paper — the one behind peeking out at a tilt.
  Widget _stack(String cap, TextStyle capStyle) {
    final m = unit * 1.6;
    Widget print(Widget child, double angle, {List<BoxShadow>? shadow}) => Transform.rotate(
          angle: angle,
          child: Container(
            padding: EdgeInsets.all(unit * 0.55),
            decoration: BoxDecoration(color: const Color(0xFFFEFEFC), boxShadow: shadow ?? const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 3))]),
            child: child,
          ),
        );
    return _paper(
      const Color(0xFFE9E7E2),
      child: Stack(children: [
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(m),
            // the back print: same image, nudged and turned, inert to gestures
            child: IgnorePointer(child: Transform.translate(offset: Offset(-unit * 0.7, unit * 0.5), child: print(Opacity(opacity: 0.96, child: photo), 0.10))),
          ),
        ),
        // accent rules behind the front print, like a designer's crop marks
        Positioned(left: m * 1.1, top: m * 0.8, bottom: m * 0.8, child: Container(width: 1.2, color: const Color(0xFF23221F))),
        Positioned(left: m * 0.9, right: m * 1.2, bottom: m * 0.9, child: Container(height: 1.2, color: const Color(0xFF23221F))),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(m),
            child: print(photo, -0.035),
          ),
        ),
        if (cap.isNotEmpty && !_thumb)
          Positioned(left: m, right: m, bottom: m * 0.28, child: Text(cap.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: capStyle)),
      ]),
    );
  }

  /// An editorial journal page: eyebrow, headline (the caption), rule, then the photo
  /// bleeding off the bottom.
  Widget _journal(String cap) {
    const bg = Color(0xFFF5F3EF);
    const ink = Color(0xFF23221F);
    final m = unit * 1.4;
    final headline = cap.isEmpty ? 'Sunday.' : cap;
    final hs = (size.shortestSide * 0.085).clamp(16.0, 64.0);
    return Container(
      color: bg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(m, m * 0.9, m, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('• • •', style: KataType.monoStyle(size: (hs * 0.22).clamp(6.0, 12.0), color: ink, letterSpacing: 0.2)),
            if (!_thumb) Text('07 / 11', style: KataType.monoStyle(size: (hs * 0.22).clamp(6.0, 12.0), color: const Color(0xFF8D8A83), letterSpacing: 0.2)),
          ]),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(m, m * 0.85, m, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!_thumb) Text('ONE FRAME FROM TODAY', style: KataType.monoStyle(size: (hs * 0.2).clamp(6.0, 11.0), weight: FontWeight.w500, color: const Color(0xFF8D8A83), letterSpacing: 0.26)),
            SizedBox(height: hs * 0.18),
            Text(headline, maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: hs, color: ink, letterSpacing: -0.02)),
            SizedBox(height: hs * 0.3),
            Container(width: hs * 0.9, height: 2, color: ink),
          ]),
        ),
        SizedBox(height: m * 0.9),
        Expanded(child: ClipRect(child: photo)),
      ]),
    );
  }

  /// Full-bleed photo under a fine plotting grid with node dots.
  Widget _grid(String cap, TextStyle capStyle) {
    return Stack(fit: StackFit.expand, children: [
      photo,
      IgnorePointer(child: CustomPaint(painter: _GridPainter())),
      if (!_thumb)
        Positioned(
          left: 8,
          bottom: 8,
          child: Text(cap.isEmpty ? 'KATA · WAKU' : cap.toUpperCase(),
              style: capStyle.copyWith(color: Colors.white, shadows: const [Shadow(color: Color(0x99000000), blurRadius: 5)])),
        ),
    ]);
  }

  /// The photo seen through panes: white gutters slice it into an uneven grid.
  Widget _split(String cap) {
    const bg = Color(0xFFF2EFE9);
    final m = unit * 1.5;
    final ink = const Color(0xFF3A362E);
    return Container(
      color: bg,
      padding: EdgeInsets.fromLTRB(m, cap.isEmpty ? m : m * 1.9, m, m * 1.5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (cap.isNotEmpty) ...[
          Text(cap, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: KataType.bodyStyle(size: (size.shortestSide * 0.04).clamp(11.0, 26.0), color: ink).copyWith(fontStyle: FontStyle.italic)),
          SizedBox(height: m * 0.5),
        ],
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            photo,
            IgnorePointer(child: CustomPaint(painter: _SplitPainter(bg))),
          ]),
        ),
      ]),
    );
  }

  /// A picture postcard: the photo on cream card stock over a red address band.
  Widget _postcard(String cap) {
    const card = Color(0xFFF0E9D8);
    const red = Color(0xFFB3402B);
    final m = unit * 0.9;
    final band = (size.height * 0.16).clamp(24.0, 120.0);
    final ts = (band * 0.30).clamp(7.0, 18.0);
    return Container(
      color: card,
      padding: EdgeInsets.fromLTRB(m, m, m, 0),
      child: Column(children: [
        Expanded(child: _bevelled(photo, light: const Color(0xFFFFFDF4), dark: const Color(0x33442A18))),
        SizedBox(
          height: band,
          child: _thumb
              ? null
              : Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('POST CARD', style: KataType.displayStyle(size: ts * 1.35, color: red, letterSpacing: 0.14)),
                      if (cap.isNotEmpty) ...[
                        SizedBox(height: ts * 0.3),
                        Text(cap, maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: ts * 0.72, weight: FontWeight.w500, color: red, letterSpacing: 0.16)),
                      ],
                    ]),
                  ),
                  Container(
                    width: band * 0.62,
                    height: band * 0.62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border.all(color: red, width: 1)),
                    child: Text('STAMP\nHERE', textAlign: TextAlign.center, style: KataType.monoStyle(size: ts * 0.5, weight: FontWeight.w500, color: red, letterSpacing: 0.2)),
                  ),
                ]),
        ),
      ]),
    );
  }

  /// The cut window's bevel: a light line where the mat board's core shows, a shadow where it overhangs.
  Widget _bevelled(Widget child, {required Color light, required Color dark}) => Container(
        decoration: BoxDecoration(border: Border.all(color: light, width: 2)),
        foregroundDecoration: BoxDecoration(border: Border.all(color: dark, width: 0.8)),
        child: child,
      );
}

class _SprocketPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final hole = Paint()..color = const Color(0xFF34322E);
    final w = s.height * 0.42;
    final h = s.height * 0.30;
    final pitch = w * 2.2;
    for (var x = pitch / 2; x + w < s.width; x += pitch) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, (s.height - h) / 2, w, h), Radius.circular(h * 0.3)), hole);
    }
  }

  @override
  bool shouldRepaint(_SprocketPainter o) => false;
}

/// Perforated stamp edge: semicircular teeth punched out of every side.
class _StampClipper extends CustomClipper<Path> {
  _StampClipper(this.tooth);
  final double tooth;

  @override
  Path getClip(Size s) {
    final punch = Path();
    final pitch = tooth * 2.4;
    for (var x = pitch / 2; x < s.width; x += pitch) {
      punch.addOval(Rect.fromCircle(center: Offset(x, 0), radius: tooth));
      punch.addOval(Rect.fromCircle(center: Offset(x, s.height), radius: tooth));
    }
    for (var y = pitch / 2; y < s.height; y += pitch) {
      punch.addOval(Rect.fromCircle(center: Offset(0, y), radius: tooth));
      punch.addOval(Rect.fromCircle(center: Offset(s.width, y), radius: tooth));
    }
    return Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & s), punch);
  }

  @override
  bool shouldReclip(_StampClipper o) => o.tooth != tooth;
}

/// Deterministic paper grain — a base coat with faint speckle.
class _GrainPainter extends CustomPainter {
  _GrainPainter(this.base);
  final Color base;

  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = base);
    final rnd = math.Random(7);
    final n = (s.width * s.height / 220).clamp(200, 4000).toInt();
    final light = Paint()..color = Colors.white.withValues(alpha: 0.05);
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.06);
    for (var i = 0; i < n; i++) {
      final o = Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height);
      c.drawCircle(o, rnd.nextDouble() * 0.9 + 0.2, i.isEven ? light : dark);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter o) => o.base != base;
}

/// The plotting grid: hairlines with node dots at the crossings.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 0.7;
    final dot = Paint()..color = Colors.white;
    final xs = [for (var i = 1; i < 4; i++) s.width * i / 4];
    final ys = [for (var i = 1; i < 5; i++) s.height * i / 5];
    for (final x in xs) {
      c.drawLine(Offset(x, 0), Offset(x, s.height), line);
    }
    for (final y in ys) {
      c.drawLine(Offset(0, y), Offset(s.width, y), line);
    }
    for (final x in xs) {
      for (final y in ys) {
        c.drawCircle(Offset(x, y), 2.2, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter o) => false;
}

/// White gutters slicing the photo into uneven panes, plus two accent rules.
class _SplitPainter extends CustomPainter {
  _SplitPainter(this.gutterColor);
  final Color gutterColor;

  @override
  void paint(Canvas c, Size s) {
    final g = Paint()..color = gutterColor;
    final gw = (s.shortestSide * 0.035).clamp(4.0, 26.0);
    final vx = s.width * 0.46;
    c.drawRect(Rect.fromLTWH(vx - gw / 2, 0, gw, s.height), g);
    c.drawRect(Rect.fromLTWH(0, s.height * 0.42 - gw / 2, vx, gw), g);
    c.drawRect(Rect.fromLTWH(vx, s.height * 0.58 - gw / 2, s.width - vx, gw), g);
    final ink = Paint()
      ..color = const Color(0xFF23221F)
      ..strokeWidth = 1.1;
    c.drawLine(Offset(-s.width * 0.02, s.height * 0.06), Offset(s.width * 0.1, s.height * 0.06), ink);
    c.drawLine(Offset(s.width * 1.02, s.height * 0.72), Offset(s.width * 0.985, s.height * 0.94), ink);
  }

  @override
  bool shouldRepaint(_SplitPainter o) => o.gutterColor != gutterColor;
}
