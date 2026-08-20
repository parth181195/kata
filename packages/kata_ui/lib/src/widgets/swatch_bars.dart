import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// The five tone settings, drawn from a centre line: above for positive, below for negative.
///
/// It used to be decoration — heights nudged into a pleasant range and greys picked by an
/// arithmetic trick — which meant two very different recipes could look identical. Now the
/// mark reads: a flat row is a neutral kata, tall upper bars a contrasty one, and the order
/// is always highlight · shadow · colour · sharpness · clarity.
class SwatchBars extends StatelessWidget {
  const SwatchBars({super.key, required this.values, this.abbr, this.size = 32, this.labels = kToneLabels});

  /// Five values in -1..1, in [labels] order.
  final List<double> values;
  final String? abbr;
  final double size;
  final List<String> labels;

  static const kToneLabels = ['Highlight', 'Shadow', 'Colour', 'Sharpness', 'Clarity'];

  /// Normalises the raw OFR numbers to -1..1 against each field's own range.
  static List<double> fromTones({
    required num highlight,
    required num shadow,
    required num color,
    required num sharpness,
    required num clarity,
  }) {
    // 0 is the camera's neutral for every one of these, so it maps to the axis and each
    // side is scaled by its own reach (highlight/shadow run -2..+4, so -2 and +4 are both ends).
    double n(num v, num min, num max) {
      if (v == 0) return 0;
      return v > 0 ? (v / max).clamp(0.0, 1.0).toDouble() : -(v / min).clamp(0.0, 1.0).toDouble();
    }

    return [
      n(highlight, -2, 4),
      n(shadow, -2, 4),
      n(color, -4, 4),
      n(sharpness, -4, 4),
      n(clarity, -5, 5),
    ];
  }

  String get _tooltip {
    final parts = <String>[];
    for (var i = 0; i < values.length && i < labels.length; i++) {
      final v = values[i];
      parts.add('${labels[i]} ${v == 0 ? 'neutral' : (v > 0 ? 'up' : 'down')}');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final bars = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TonePainter(values, p.fg, p.muted, p.hairline)),
    );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Tooltip(message: _tooltip, child: bars),
      if (abbr != null) ...[const SizedBox(height: 4), Text(abbr!, style: KataType.displayStyle(size: 10, color: p.muted, letterSpacing: 0))],
    ]);
  }
}

class _TonePainter extends CustomPainter {
  _TonePainter(this.values, this.fg, this.axis, this.faint);
  final List<double> values;
  final Color fg, axis, faint;

  @override
  void paint(Canvas c, Size s) {
    final n = values.length;
    if (n == 0) return;
    final gap = s.width * 0.06;
    final w = (s.width - gap * (n - 1)) / n;
    final mid = s.height / 2;
    c.drawLine(Offset(0, mid), Offset(s.width, mid), Paint()..color = axis..strokeWidth = 0.8);
    for (var i = 0; i < n; i++) {
      final v = values[i].clamp(-1.0, 1.0);
      final x = i * (w + gap);
      final h = (mid - 1) * v.abs();
      if (h < 0.8) {
        // a neutral setting is a mark on the axis, not an invisible bar
        c.drawRect(Rect.fromLTWH(x, mid - 1, w, 2), Paint()..color = faint);
        continue;
      }
      final top = v > 0 ? mid - h : mid;
      c.drawRect(Rect.fromLTWH(x, top, w, h), Paint()..color = fg);
    }
  }

  @override
  bool shouldRepaint(_TonePainter o) => !identical(o.values, values) || o.fg != fg;
}
