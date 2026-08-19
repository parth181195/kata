import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

class ChecklistStep extends StatelessWidget {
  const ChecklistStep({super.key, required this.n, required this.title, this.sub, this.active = false});
  final int n;
  final String title;
  final Widget? sub;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final c = active ? p.fg : p.muted;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c)),
        child: Text('$n', style: KataType.displayStyle(size: 12, color: c, letterSpacing: 0)),
      ),
      const SizedBox(width: 13),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: KataType.bodyStyle(size: 13, weight: FontWeight.w600, color: p.fg, height: 1.35)),
          if (sub != null) ...[
            const SizedBox(height: 3),
            DefaultTextStyle(style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.45), child: sub!),
          ],
        ]),
      ),
    ]);
  }
}
