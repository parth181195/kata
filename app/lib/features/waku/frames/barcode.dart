import 'package:flutter/material.dart';

/// Code 39, the barcode a museum accession number actually carries — it needs
/// no check digit and encodes letters, which is why collections used it. Each
/// character is nine elements: five bars and four spaces, three of the nine
/// wide. Recovered from the label card that shipped in commit 16be887.
const _code39 = <String, String>{
  '0': 'nnnwwnwnn', '1': 'wnnwnnnnw', '2': 'nnwwnnnnw', '3': 'wnwwnnnnn', '4': 'nnnwwnnnw',
  '5': 'wnnwwnnnn', '6': 'nnwwwnnnn', '7': 'nnnwnnwnw', '8': 'wnnwnnwnn', '9': 'nnwwnnwnn',
  'A': 'wnnnnwnnw', 'B': 'nnwnnwnnw', 'C': 'wnwnnwnnn', 'D': 'nnnnwwnnw', 'E': 'wnnnwwnnn',
  'F': 'nnwnwwnnn', 'G': 'nnnnnwwnw', 'H': 'wnnnnwwnn', 'I': 'nnwnnwwnn', 'J': 'nnnnwwwnn',
  'K': 'wnnnnnnww', 'L': 'nnwnnnnww', 'M': 'wnwnnnnwn', 'N': 'nnnnwnnww', 'O': 'wnnnwnnwn',
  'P': 'nnwnwnnwn', 'Q': 'nnnnnnwww', 'R': 'wnnnnnwwn', 'S': 'nnwnnnwwn', 'T': 'nnnnwnwwn',
  'U': 'wwnnnnnnw', 'V': 'nwwnnnnnw', 'W': 'wwwnnnnnn', 'X': 'nwnnwnnnw', 'Y': 'wwnnwnnnn',
  'Z': 'nwwnwnnnn', '-': 'nwnnnnwnw', '.': 'wwnnnnwnn', ' ': 'nwwnnnwnn', '*': 'nwnnwnwnn',
};

/// The bar pattern for [value]: true = ink, false = paper, one entry per narrow
/// module. Wide elements are three modules, and every character is bracketed by
/// the '*' start and stop pair.
///
/// Characters Code 39 can't encode are dropped: a barcode with a gap in it beats
/// an export that throws halfway through saving someone's picture.
List<bool> code39Bars(String value) {
  final chars = ['*', ...value.toUpperCase().split('').where(_code39.containsKey), '*'];
  final out = <bool>[];
  for (var ci = 0; ci < chars.length; ci++) {
    final pattern = _code39[chars[ci]]!;
    for (var i = 0; i < pattern.length; i++) {
      final wide = pattern[i] == 'w';
      final ink = i.isEven; // elements alternate bar, space, bar…
      for (var k = 0; k < (wide ? 3 : 1); k++) {
        out.add(ink);
      }
    }
    if (ci < chars.length - 1) out.add(false); // inter-character gap
  }
  return out;
}

/// Draws [value] as Code 39 across the full width it is given.
class BarcodePainter extends CustomPainter {
  BarcodePainter(this.value, this.color);
  final String value;
  final Color color;

  @override
  void paint(Canvas c, Size s) {
    final bars = code39Bars(value);
    if (bars.isEmpty || s.width <= 0) return;
    c.clipRect(Offset.zero & s);
    final w = s.width / bars.length;
    final p = Paint()..color = color;
    for (var i = 0; i < bars.length; i++) {
      // the overlap closes the seam between adjacent ink modules, which would
      // otherwise show as a hairline at fractional module widths
      if (bars[i]) c.drawRect(Rect.fromLTWH(i * w, 0, w + 0.3, s.height), p);
    }
  }

  @override
  bool shouldRepaint(BarcodePainter o) => o.value != value || o.color != color;
}
