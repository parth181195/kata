// THROWAWAY SPIKE — not wired into the app, not tested, delete after the call.
//
// Question it answers: does "authored object + rolled surface" close the gap
// between our layouts and the reference objects? One frame (the postage stamp),
// built as a real object — perforated edge, denomination, arced postmark that
// overlaps the stamp — with three axes rolled from a single seed:
//
//   voice      a type pairing (display / text / data) from Google Fonts
//   ink        the printed colours, taken from the photograph's own palette
//   treatment  the imperfection: registration slip, bleed, uneven pressure,
//              speckle, and the grain we already measure
//
// Renders nine seeds of the same photo so variety and craft can be judged at once.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'features/waku/waku_exif.dart';
import 'features/waku/waku_palette.dart';

const _photo = '/home/parth/WebstormProjects/fuji/web/landing/img/hero-1.jpg';

// ---------------------------------------------------------------- the axes

/// A type pairing. The frame lists which of these suit it; the shot biases
/// which one is drawn.
class Voice {
  const Voice(this.name, this.display, this.text, this.data, {this.displayWeight = FontWeight.w700, this.tight = false});
  final String name;
  final String display; // the denomination, the big mark
  final String text; // the country line
  final String data; // dates, codes
  final FontWeight displayWeight;
  final bool tight;

  TextStyle displayStyle(double size, Color c) =>
      GoogleFonts.getFont(display, fontSize: size, fontWeight: displayWeight, color: c, height: 1, letterSpacing: tight ? -size * 0.03 : 0);
  TextStyle textStyle(double size, Color c, {FontWeight w = FontWeight.w500, double spacing = 0.12}) =>
      GoogleFonts.getFont(text, fontSize: size, fontWeight: w, color: c, height: 1.1, letterSpacing: size * spacing);
  TextStyle dataStyle(double size, Color c) => GoogleFonts.getFont(data, fontSize: size, fontWeight: FontWeight.w500, color: c, height: 1);
}

const _voices = [
  Voice('post office', 'Oswald', 'Barlow Condensed', 'Space Mono', tight: true),
  Voice('bureau', 'Archivo Black', 'IBM Plex Sans', 'IBM Plex Mono'),
  Voice('deco', 'Playfair Display', 'Cormorant Garamond', 'Courier Prime', displayWeight: FontWeight.w900),
  Voice('civic', 'Bebas Neue', 'Work Sans', 'Roboto Mono'),
];

/// What the roll produced for one output.
class Roll {
  Roll(this.seed, List<Color> palette, PhotoMeta meta) : _r = math.Random(seed) {
    voice = _voices[_r.nextInt(_voices.length)];
    final sorted = [...palette]..sort((a, b) => _lum(a).compareTo(_lum(b)));
    // the card under the stamp: the photo's dark end, pushed further down
    // a mounted specimen sits on a chosen card, not on the photo's mud
    const cards = [Color(0xFF7E2418), Color(0xFF1F3D34), Color(0xFF23324D), Color(0xFF4A3C22), Color(0xFF12100E)];
    ground = _mix(cards[_r.nextInt(cards.length)], sorted.isEmpty ? const Color(0xFF241F1B) : sorted.first, 0.28);
    // the stamp's own paper: warm off-white, tinted a little by the photo
    paper = _mix(sorted.isEmpty ? const Color(0xFFEFE9DC) : sorted.last, const Color(0xFFF4EFE3), 0.82);
    // the printed ink: the most saturated thing in the picture, forced legible
    final vivid = palette.isEmpty ? const Color(0xFFB0341F) : palette.reduce((a, b) => _sat(a) > _sat(b) ? a : b);
    ink = _legibleOn(paper, _mix(vivid, const Color(0xFF8C2A18), 0.35));
    // treatment
    slip = Offset((_r.nextDouble() - 0.5) * 0.012, (_r.nextDouble() - 0.5) * 0.012);
    postmarkTurn = (_r.nextDouble() - 0.5) * 0.5;
    bleed = 0.4 + _r.nextDouble() * 0.9;
    pressure = 0.10 + _r.nextDouble() * 0.16;
    speckles = 14 + _r.nextInt(26);
    missingPerf = _r.nextInt(3); // a stamp torn a little unevenly
    denomination = ['1', '2', '5', '10', '20'][_r.nextInt(5)];
  }

  final int seed;
  final math.Random _r;
  late final Voice voice;
  late final Color ground, paper, ink;
  late final Offset slip; // registration, in fractions of the stamp
  late final double postmarkTurn, bleed, pressure;
  late final int speckles, missingPerf;
  late final String denomination;
  math.Random get rnd => _r;

  static double _lum(Color c) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
  static double _sat(Color c) {
    final mx = math.max(c.r, math.max(c.g, c.b)), mn = math.min(c.r, math.min(c.g, c.b));
    return mx <= 0 ? 0 : (mx - mn) / mx;
  }

  static Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
  static Color _legibleOn(Color ground, Color ink) {
    var out = ink;
    for (var i = 0; i < 6 && (_lum(ground) - _lum(out)).abs() < 0.35; i++) {
      out = _mix(out, const Color(0xFF1A0E0A), 0.25);
    }
    return out;
  }
}

// ---------------------------------------------------------------- the object

class StampFrame extends StatelessWidget {
  const StampFrame({super.key, required this.photo, required this.roll, required this.meta});
  final Uint8List photo;
  final Roll roll;
  final PhotoMeta meta;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final s = box.biggest;
        // the stamp sits on a card, a little off-centre like a mounted specimen
        final stampW = s.width * 0.72;
        final stampH = stampW * 1.26;
        final left = (s.width - stampW) / 2;
        final top = s.height * 0.5 - stampH / 2;
        final stamp = Rect.fromLTWH(left, top, stampW, stampH);
        return Stack(fit: StackFit.expand, children: [
          ColoredBox(color: roll.ground),
          CustomPaint(painter: _CardPainter(roll)),
          Positioned.fromRect(
            rect: stamp,
            child: ClipPath(
              clipper: _PerfClipper(roll),
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: roll.paper),
                _StampFace(photo: photo, roll: roll, meta: meta),
              ]),
            ),
          ),
          // the postmark is printed after, and misses: it laps onto the card
          CustomPaint(painter: _PostmarkPainter(roll, stamp, meta)),
          CustomPaint(painter: _WearPainter(roll)),
        ]);
      });
}

/// Denomination, country line, and the photograph inside its white margin.
class _StampFace extends StatelessWidget {
  const _StampFace({required this.photo, required this.roll, required this.meta});
  final Uint8List photo;
  final Roll roll;
  final PhotoMeta meta;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final m = w * 0.085;
        final headH = h * 0.13;
        final footH = h * 0.155;
        return Stack(children: [
          Positioned(
            left: m,
            top: headH,
            right: m,
            bottom: footH,
            child: DecoratedBox(
              decoration: BoxDecoration(border: Border.all(color: roll.ink.withValues(alpha: 0.30), width: 0.6)),
              child: Padding(padding: const EdgeInsets.all(1.2), child: Image.memory(photo, fit: BoxFit.cover)),
            ),
          ),
          // country line, top
          Positioned(
            left: m,
            top: h * 0.045,
            right: m,
            child: Text(
              (meta.filmMode ?? 'KATA').toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              style: roll.voice.textStyle(w * 0.062, roll.ink, spacing: 0.14),
            ),
          ),
          // denomination, foot left; date, foot right
          Positioned(
            left: m,
            bottom: h * 0.035,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(roll.denomination, style: roll.voice.displayStyle(w * 0.20, roll.ink)),
              const SizedBox(width: 3),
              Padding(
                padding: EdgeInsets.only(bottom: w * 0.028),
                child: Text('ISO', style: roll.voice.dataStyle(w * 0.052, roll.ink)),
              ),
            ]),
          ),
          Positioned(
            right: m,
            bottom: h * 0.05,
            child: Text(
              meta.iso == null ? '400' : '${meta.iso}',
              style: roll.voice.dataStyle(w * 0.062, roll.ink.withValues(alpha: 0.85)),
            ),
          ),
        ]);
      });
}

/// Punches the perforations out of the stamp's rectangle.
class _PerfClipper extends CustomClipper<Path> {
  _PerfClipper(this.roll);
  final Roll roll;

  @override
  Path getClip(Size size) {
    final pitch = size.width / 13; // gauge ~13
    final r = pitch * 0.30;
    final holes = Path();
    void row(int n, Offset Function(int) at) {
      for (var i = 0; i <= n; i++) {
        if (roll.missingPerf > 0 && i % 7 == roll.missingPerf) continue; // a tooth that didn't tear
        holes.addOval(Rect.fromCircle(center: at(i), radius: r));
      }
    }

    final nx = (size.width / pitch).floor();
    final ny = (size.height / pitch).floor();
    row(nx, (i) => Offset(i * size.width / nx, 0));
    row(nx, (i) => Offset(i * size.width / nx, size.height));
    row(ny, (i) => Offset(0, i * size.height / ny));
    row(ny, (i) => Offset(size.width, i * size.height / ny));
    return Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), holes);
  }

  @override
  bool shouldReclip(_PerfClipper o) => o.roll.seed != roll.seed;
}

/// The card the stamp is mounted on: uneven ink density and a hairline rule.
class _CardPainter extends CustomPainter {
  _CardPainter(this.roll);
  final Roll roll;

  @override
  void paint(Canvas c, Size s) {
    // uneven pressure across the card, low frequency
    final r = math.Random(roll.seed ^ 0x51);
    for (var i = 0; i < 5; i++) {
      final centre = Offset(r.nextDouble() * s.width, r.nextDouble() * s.height);
      c.drawCircle(
        centre,
        s.width * (0.35 + r.nextDouble() * 0.4),
        Paint()
          ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: roll.pressure * 0.5), Colors.white.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: centre, radius: s.width * 0.6))
          ..blendMode = BlendMode.overlay,
      );
    }
  }

  @override
  bool shouldRepaint(_CardPainter o) => o.roll.seed != roll.seed;
}

/// The circular date stamp: arced place text, a date slug, wavy killer bars.
/// Printed in a second pass, so it slips and it laps over the stamp's edge.
class _PostmarkPainter extends CustomPainter {
  _PostmarkPainter(this.roll, this.stamp, this.meta);
  final Roll roll;
  final Rect stamp;
  final PhotoMeta meta;

  @override
  void paint(Canvas c, Size s) {
    final ink = roll.ink;
    final radius = stamp.width * 0.21;
    final centre = stamp.topLeft +
        Offset(stamp.width * (0.13 + roll.slip.dx * 8), stamp.height * (0.14 + roll.slip.dy * 8));

    c.save();
    c.translate(centre.dx, centre.dy);
    c.rotate(roll.postmarkTurn);

    final stroke = Paint()
      ..color = ink.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.05
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, roll.bleed * 0.35);
    c.drawCircle(Offset.zero, radius, stroke);
    c.drawCircle(Offset.zero, radius * 0.80, stroke..strokeWidth = radius * 0.028);

    // place name around the top of the ring
    _arc(c, (meta.model ?? 'FUJIFILM').toUpperCase(), radius * 0.90, -math.pi * 0.78, roll.voice.dataStyle(radius * 0.20, ink), true);
    // date across the middle
    final d = meta.dateTime ?? DateTime(2026, 1, 18);
    final date = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year % 100}';
    final tp = TextPainter(
      text: TextSpan(text: date, style: roll.voice.dataStyle(radius * 0.26, ink)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
    _arc(c, 'KATA', radius * 0.90, math.pi * 0.22, roll.voice.dataStyle(radius * 0.20, ink), false);
    c.restore();

    // killer bars, running off the stamp onto the card
    final bars = Paint()
      ..color = ink.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.055
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, roll.bleed * 0.4);
    final gap = radius * 0.24;
    for (var i = 0; i < 5; i++) {
      final path = Path();
      final y0 = centre.dy - radius * 0.5 + i * gap;
      for (var x = 0.0; x <= stamp.width * 0.72; x += 4) {
        final y = y0 + math.sin((x / stamp.width) * math.pi * 3 + i) * radius * 0.045;
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
  bool shouldRepaint(_PostmarkPainter o) => o.roll.seed != roll.seed;
}

/// Dust, hairs and specks — the print shop wasn't clean.
class _WearPainter extends CustomPainter {
  _WearPainter(this.roll);
  final Roll roll;

  @override
  void paint(Canvas c, Size s) {
    final r = math.Random(roll.seed ^ 0x9E3);
    final p = Paint();
    for (var i = 0; i < roll.speckles; i++) {
      final dark = r.nextBool();
      p.color = (dark ? Colors.black : Colors.white).withValues(alpha: 0.05 + r.nextDouble() * 0.16);
      final at = Offset(r.nextDouble() * s.width, r.nextDouble() * s.height);
      if (r.nextInt(5) == 0) {
        // a hair
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
  bool shouldRepaint(_WearPainter o) => o.roll.seed != roll.seed;
}

// ---------------------------------------------------------------- harness

void main() => runApp(const _App());

class _App extends StatefulWidget {
  const _App();
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  final _bytes = File(_photo).readAsBytesSync();
  List<Color> _palette = const [];
  PhotoMeta _meta = const PhotoMeta();
  int _base = 1;

  @override
  void initState() {
    super.initState();
    () async {
      final p = await extractPalette(_bytes);
      final m = await readPhotoMeta(_bytes);
      if (mounted) {
        setState(() {
          _palette = p ?? const [];
          _meta = m.isEmpty ? const PhotoMeta(model: 'X-S20', iso: 400, filmMode: 'CLASSIC CHROME') : m;
        });
      }
    }();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0E0E0E),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => setState(() => _base += 9),
            label: const Text('shuffle'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 4 / 5,
              children: [
                for (var i = 0; i < 9; i++)
                  StampFrame(photo: _bytes, roll: Roll(_base + i, _palette, _meta), meta: _meta),
              ],
            ),
          ),
        ),
      );
}
