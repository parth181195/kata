import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// Five grayscale bars derived from a recipe's tone values + film-sim abbreviation below.
class SwatchBars extends StatelessWidget {
  const SwatchBars({super.key, required this.heights, required this.greys, this.abbr, this.size = 32});
  final List<double> heights; // 5 × 0..1
  final List<int> greys; // 5 × 0..3 → fg, dim, muted, hairline
  final String? abbr;
  final double size;

  static ({List<double> heights, List<int> greys}) fromTones({
    required num highlight,
    required num shadow,
    required num color,
    required num sharpness,
    required num clarity,
  }) {
    double n(num v, num min, num max) => 0.25 + 0.75 * ((v - min) / (max - min)).clamp(0, 1);
    final h = [n(highlight, -2, 4), n(shadow, -2, 4), n(color, -4, 4), n(sharpness, -4, 4), n(clarity, -5, 5)];
    final g = [for (var i = 0; i < 5; i++) ((h[i] * 7).round() + i) % 4];
    return (heights: h, greys: g);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final palette = [p.fg, p.dim, p.muted, p.hairline];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: size,
        height: size,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(child: FractionallySizedBox(heightFactor: heights[i].clamp(0.05, 1), child: ColoredBox(color: palette[greys[i] % 4]))),
          ],
        ]),
      ),
      if (abbr != null) ...[const SizedBox(height: 4), Text(abbr!, style: KataType.displayStyle(size: 10, color: p.muted, letterSpacing: 0))],
    ]);
  }
}
