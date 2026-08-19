import 'package:flutter/material.dart';

import '../theme.dart';

/// 6×4 grid of dots that light up with progress (writing screen).
class DotMatrixProgress extends StatelessWidget {
  const DotMatrixProgress({super.key, required this.progress, this.columns = 6, this.rows = 4, this.dot = 10, this.gap = 9});
  final double progress;
  final int columns, rows;
  final double dot, gap;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final total = columns * rows;
    final lit = (progress.clamp(0, 1) * total).round();
    return SizedBox(
      width: columns * dot + (columns - 1) * gap,
      child: Wrap(spacing: gap, runSpacing: gap, children: [
        for (var i = 0; i < total; i++)
          Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < lit ? p.fg : (i == lit ? p.muted : (i == lit + 1 ? p.hairline : p.surface)),
            ),
          ),
      ]),
    );
  }
}
