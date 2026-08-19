import 'package:flutter/material.dart';

import '../theme.dart';

/// 4 icon-only tabs: Library ▭, Camera ◯, Mine ⊔, Profile ◠ — dot under the active one.
class KataBottomNav extends StatelessWidget {
  const KataBottomNav({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    Widget icon(int i) {
      final c = i == index ? p.fg : p.muted;
      final side = BorderSide(color: c, width: 1.5);
      return switch (i) {
        0 => Container(width: 18, height: 14, decoration: BoxDecoration(border: Border.fromBorderSide(side), borderRadius: BorderRadius.circular(2))),
        1 => Container(width: 17, height: 17, decoration: BoxDecoration(border: Border.fromBorderSide(side), shape: BoxShape.circle)),
        2 => Container(width: 14, height: 17, decoration: BoxDecoration(border: Border(left: side, right: side, top: side))),
        _ => Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(border: Border(left: side, right: side, top: side), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
          ),
      };
    }

    return Container(
      height: 64,
      decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.dark ? p.surface : p.hairline))),
      child: Row(children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: InkWell(
              key: ValueKey('nav-$i'),
              onTap: () => onTap(i),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                icon(i),
                const SizedBox(height: 6),
                Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: i == index ? p.fg : Colors.transparent)),
              ]),
            ),
          ),
      ]),
    );
  }
}
