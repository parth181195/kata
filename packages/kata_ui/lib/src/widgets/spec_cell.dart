import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

class SpecItem {
  const SpecItem(this.label, this.value, {this.display = false, this.rulerT, this.rulerMin, this.rulerMax});
  final String label;
  final String value;

  /// Doto. Reserved for marks and titles — a value people read should stay in the body face.
  final bool display;
  final double? rulerT; // 0..1 marker position for tone cells

  /// Ends of the scale, written under the ruler: a marker with no scale says nothing.
  final String? rulerMin, rulerMax;
}

class Ruler extends StatelessWidget {
  const Ruler({super.key, required this.t, this.height = 10, this.min, this.max, this.zeroT});
  final double t;
  final double height;

  /// Written at the ends, so a reader can tell +1.5 out of what.
  final String? min, max;

  /// Where zero sits on the scale (0..1), marked with a taller tick.
  final double? zeroT;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final scale = min != null && max != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      CustomPaint(
        size: Size(double.infinity, height + 4),
        painter: _RulerPainter(p.hairline, p.fg, t.clamp(0, 1), height, zeroT, p.muted),
      ),
      if (scale) ...[
        const SizedBox(height: 3),
        // the 0 label has to sit over its tick: centring it in the row puts it in the wrong
        // place on any asymmetric scale (-2…+4 has zero a third of the way along)
        LayoutBuilder(
          builder: (context, box) {
            final style = KataType.monoStyle(size: 7.5, color: p.muted, height: 1);
            return SizedBox(
              height: 9,
              child: Stack(children: [
                Positioned(left: 0, top: 0, child: Text(min!, style: style)),
                Positioned(right: 0, top: 0, child: Text(max!, style: style)),
                if (zeroT != null)
                  Positioned(
                    left: (box.maxWidth * zeroT!) - 3,
                    top: 0,
                    child: Text('0', style: style),
                  ),
              ]),
            );
          },
        ),
      ],
    ]);
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter(this.tick, this.marker, this.t, this.h, this.zeroT, this.zeroColor);
  final Color tick, marker, zeroColor;
  final double t, h;
  final double? zeroT;

  @override
  void paint(Canvas c, Size s) {
    final tp = Paint()..color = tick;
    for (var x = 0.0; x < s.width; x += 7) {
      c.drawRect(Rect.fromLTWH(x, 2, 1, h), tp);
    }
    if (zeroT != null) {
      // the middle of the scale, so a marker just left of centre reads as "slightly negative"
      c.drawRect(Rect.fromLTWH((s.width - 1) * zeroT!, 0, 1, h + 4), Paint()..color = zeroColor);
    }
    c.drawRect(Rect.fromLTWH((s.width - 1.5) * t, 0, 1.5, h + 4), Paint()..color = marker);
  }

  @override
  bool shouldRepaint(_RulerPainter o) => o.t != t || o.tick != tick || o.zeroT != zeroT;
}

/// Where 0 falls between the written ends (e.g. -2…+4 → 1/3 along).
double? _zeroOf(SpecItem i) {
  final lo = double.tryParse((i.rulerMin ?? '').replaceAll('+', ''));
  final hi = double.tryParse((i.rulerMax ?? '').replaceAll('+', ''));
  if (lo == null || hi == null || hi <= lo || lo > 0 || hi < 0) return null;
  return -lo / (hi - lo);
}

class SpecCell extends StatelessWidget {
  const SpecCell(this.item, {super.key, this.valueSize = 15});
  final SpecItem item;
  final double valueSize;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(item.label.toUpperCase(), style: KataType.labelStyle(color: p.muted)),
      const SizedBox(height: 6),
      Text(
        item.display ? item.value.toUpperCase() : item.value,
        style: item.display
            ? KataType.displayStyle(size: valueSize - 1, color: p.fg, letterSpacing: 0)
            : KataType.monoStyle(size: valueSize, color: p.fg, height: 1),
      ),
      if (item.rulerT != null) ...[
        const SizedBox(height: 6),
        Ruler(
          t: item.rulerT!,
          min: item.rulerMin,
          max: item.rulerMax,
          zeroT: _zeroOf(item),
        ),
      ],
    ]);
  }
}

class SpecGrid extends StatelessWidget {
  const SpecGrid(this.items, {super.key, this.columns = 3, this.rowGap = 18, this.colGap = 12, this.valueSize = 15});
  final List<SpecItem> items;
  final int columns;
  final double rowGap, colGap, valueSize;
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += columns) {
      final slice = items.sublist(i, (i + columns).clamp(0, items.length));
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var j = 0; j < columns; j++) ...[
          if (j > 0) SizedBox(width: colGap),
          Expanded(child: j < slice.length ? SpecCell(slice[j], valueSize: valueSize) : const SizedBox()),
        ],
      ]));
      if (i + columns < items.length) rows.add(SizedBox(height: rowGap));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: rows);
  }
}
