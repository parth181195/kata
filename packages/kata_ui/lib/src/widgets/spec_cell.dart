import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

class SpecItem {
  const SpecItem(this.label, this.value, {this.display = false, this.rulerT});
  final String label;
  final String value;
  final bool display; // Doto for film sim
  final double? rulerT; // 0..1 marker position for tone cells
}

class Ruler extends StatelessWidget {
  const Ruler({super.key, required this.t, this.height = 10});
  final double t;
  final double height;
  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size(double.infinity, height + 4), painter: _RulerPainter(context.kata.hairline, context.kata.fg, t.clamp(0, 1), height));
}

class _RulerPainter extends CustomPainter {
  _RulerPainter(this.tick, this.marker, this.t, this.h);
  final Color tick, marker;
  final double t, h;
  @override
  void paint(Canvas c, Size s) {
    final tp = Paint()..color = tick;
    for (var x = 0.0; x < s.width; x += 7) {
      c.drawRect(Rect.fromLTWH(x, 2, 1, h), tp);
    }
    c.drawRect(Rect.fromLTWH((s.width - 1.5) * t, 0, 1.5, h + 4), Paint()..color = marker);
  }

  @override
  bool shouldRepaint(_RulerPainter o) => o.t != t || o.tick != tick;
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
      if (item.rulerT != null) ...[const SizedBox(height: 6), Ruler(t: item.rulerT!)],
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
