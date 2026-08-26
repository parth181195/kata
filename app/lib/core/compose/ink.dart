import 'dart:math' as math;
import 'dart:ui';

/// The inks an object is printed in. A postmark is red-black; an archive label
/// is maroon-black; a lab print is cyan-black. The photograph biases the choice
/// *within* the family — it never gets to make a stamp green.
class InkFamily {
  const InkFamily(this.name, this.anchors);
  final String name;

  /// The family's poles. A drawn ink is a mix of the photo's nearest colour and
  /// one of these, so it always reads as that object's ink.
  final List<Color> anchors;
}

const kInkFamilies = <String, InkFamily>{
  'postmark': InkFamily('postmark', [Color(0xFF8C2A18), Color(0xFF2A1512), Color(0xFF6E1F14)]),
  'archive': InkFamily('archive', [Color(0xFF5B1A22), Color(0xFF1C1A18), Color(0xFF43121A)]),
  'lab': InkFamily('lab', [Color(0xFF9FD4E6), Color(0xFFE8EDF2), Color(0xFFBFD8C4)]),
};

/// Re-imposes [anchor]'s channel ranking on [mixed]: same values, ordered the
/// way the family orders them.
Color _keepFamily(Color anchor, Color mixed) {
  final a = [anchor.r, anchor.g, anchor.b];
  final m = [mixed.r, mixed.g, mixed.b]..sort();
  // rank 0 = the anchor's smallest channel, and so on
  final rank = [0, 1, 2]..sort((x, y) => a[x].compareTo(a[y]));
  final out = List<double>.filled(3, 0);
  for (var i = 0; i < 3; i++) {
    out[rank[i]] = m[i];
  }
  return Color.from(alpha: 1, red: out[0], green: out[1], blue: out[2]);
}

double _lin(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _relativeLuminance(Color c) => 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

/// WCAG contrast ratio, 1..21.
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a), lb = _relativeLuminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Draws an ink for this object from this photograph, then forces it legible.
Color pickInk({required InkFamily family, required List<Color> palette, required Color ground, required int seed}) {
  final r = math.Random(seed);
  final anchor = family.anchors[r.nextInt(family.anchors.length)];

  // the photo's most saturated colour, if it has one worth borrowing
  Color? borrowed;
  var best = 0.0;
  for (final c in palette) {
    final mx = math.max(c.r, math.max(c.g, c.b)), mn = math.min(c.r, math.min(c.g, c.b));
    final sat = mx <= 0 ? 0.0 : (mx - mn) / mx;
    if (sat > best) {
      best = sat;
      borrowed = c;
    }
  }
  // 0.25..0.55 of the photo's colour: enough to tie the ink to the picture.
  // The mix takes the photo's chroma and lightness but keeps the anchor's
  // channel ordering, so a field of green can never turn a postmark green.
  var ink = borrowed == null ? anchor : _keepFamily(anchor, Color.lerp(anchor, borrowed, 0.25 + r.nextDouble() * 0.30)!);

  // Legibility is not negotiable. Push away from the ground, whichever way that
  // is: an ink family for a dark ground is light, and vice versa.
  final away = _relativeLuminance(ground) > 0.35 ? const Color(0xFF120A08) : const Color(0xFFF6F1E6);
  for (var i = 0; i < 14 && contrastRatio(ink, ground) < 3.0; i++) {
    ink = Color.lerp(ink, away, 0.18)!;
  }
  return ink;
}
