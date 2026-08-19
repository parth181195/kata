import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';
import '../tokens.dart';
import 'pill_button.dart';
import 'rows.dart';
import 'sheet.dart';

/// Editing variant of a spec cell (design 2a): mono label, big value, −/+ circles and a ruler with min/0/max marks.
class KataStepper extends StatelessWidget {
  const KataStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.format,
    this.enabled = true,
  });
  final String label;
  final num value;
  final num min, max, step;
  final ValueChanged<num> onChanged;
  final String Function(num)? format;
  final bool enabled;

  String _fmt(num v) {
    if (format != null) return format!(v);
    final isInt = v == v.roundToDouble();
    final s = isInt ? v.toInt().toString() : v.toStringAsFixed(1);
    return v > 0 ? '+$s' : s;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final t = max == min ? 0.0 : ((value - min) / (max - min)).clamp(0.0, 1.0);
    final canDec = enabled && value - step >= min - 1e-9;
    final canInc = enabled && value + step <= max + 1e-9;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KataRadii.card),
        border: Border.all(color: p.hairline, width: KataStroke.hairline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: KataType.bodyStyle(size: 8.5, weight: FontWeight.w500, color: p.muted, height: 1).copyWith(letterSpacing: 8.5 * 0.16)),
              const SizedBox(height: 6),
              Text(_fmt(value), style: KataType.monoStyle(size: 20, color: enabled ? p.fg : p.muted, height: 1)),
            ]),
          ),
          KataIconCircle(size: 38, onPressed: canDec ? () => onChanged(_snap(value - step)) : null, child: Text('−', style: KataType.bodyStyle(size: 18, color: canDec ? p.fg : p.muted, height: 1))),
          const SizedBox(width: 8),
          KataIconCircle(size: 38, onPressed: canInc ? () => onChanged(_snap(value + step)) : null, child: Text('+', style: KataType.bodyStyle(size: 18, color: canInc ? p.fg : p.muted, height: 1))),
        ]),
        const SizedBox(height: 10),
        _BigRuler(t: t, zeroT: (min < 0 && max > 0) ? (-min / (max - min)) : null),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_fmt(min), style: KataType.monoStyle(size: 8.5, color: p.muted, height: 1)),
          if (min < 0 && max > 0) Text('0', style: KataType.monoStyle(size: 8.5, color: p.muted, height: 1)),
          Text(_fmt(max), style: KataType.monoStyle(size: 8.5, color: p.muted, height: 1)),
        ]),
      ]),
    );
  }

  num _snap(num v) {
    // keep ints as ints when the step is integral
    final r = (v / step).round() * step;
    return step == step.roundToDouble() ? r.round() : double.parse(r.toStringAsFixed(2));
  }
}

class _BigRuler extends StatelessWidget {
  const _BigRuler({required this.t, this.zeroT});
  final double t;
  final double? zeroT;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return SizedBox(
      height: 18,
      child: CustomPaint(painter: _BigRulerPainter(p.hairline, p.fg, p.muted, t, zeroT)),
    );
  }
}

class _BigRulerPainter extends CustomPainter {
  _BigRulerPainter(this.tick, this.marker, this.zero, this.t, this.zeroT);
  final Color tick, marker, zero;
  final double t;
  final double? zeroT;
  @override
  void paint(Canvas c, Size s) {
    final tp = Paint()..color = tick..strokeWidth = 1;
    for (var x = 0.0; x <= s.width; x += 7) {
      c.drawLine(Offset(x, s.height - 10), Offset(x, s.height), tp);
    }
    if (zeroT != null) {
      final zx = zeroT! * s.width;
      c.drawLine(Offset(zx, s.height - 14), Offset(zx, s.height), Paint()..color = zero..strokeWidth = 1);
    }
    final x = t * s.width;
    c.drawLine(Offset(x, 0), Offset(x, s.height), Paint()..color = marker..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_BigRulerPainter o) => o.t != t || o.tick != tick || o.zeroT != zeroT;
}

/// Label + current value + chevron; tapping opens [showKataPicker].
class KataPickerRow extends StatelessWidget {
  const KataPickerRow({super.key, required this.label, required this.value, required this.options, required this.onChanged, this.hint, this.enabled = true});
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool enabled;
  @override
  Widget build(BuildContext context) => KataListRow(
    title: label,
    value: value ?? (hint ?? '—'),
    enabled: enabled,
    onTap: () async {
      final picked = await showKataPicker(context, title: label, options: options, selected: value);
      if (picked != null) onChanged(picked);
    },
  );
}

/// Sheet list picker; returns the picked option or null.
Future<String?> showKataPicker(BuildContext context, {required String title, required List<String> options, String? selected, String? eyebrow}) =>
    showKataSheet<String>(
      context,
      builder: (c) => KataSheet(
        eyebrow: eyebrow ?? 'Choose',
        title: title,
        children: [
          for (final o in options)
            KataTapScale(
              child: InkWell(
                onTap: () => Navigator.of(c).pop(o),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.kata.hairline))),
                  child: Row(children: [
                    Expanded(child: Text(o, style: KataType.bodyStyle(size: 13.5, weight: o == selected ? FontWeight.w600 : FontWeight.w400, color: c.kata.fg, height: 1))),
                    if (o == selected) Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: c.kata.fg)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
