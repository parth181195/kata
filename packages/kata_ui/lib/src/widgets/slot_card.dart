import 'package:flutter/material.dart';

import '../primitives/cards.dart';
import '../theme.dart';
import '../tokens.dart';

enum SlotCardState { filled, onDial, empty }

class SlotCard extends StatelessWidget {
  const SlotCard({
    super.key,
    required this.slot,
    required this.state,
    this.title,
    this.line1,
    this.line2,
    this.selected = false,
    this.onTap,
    this.onRefresh,
  });
  final int slot;
  final SlotCardState state;
  final String? title, line1, line2;
  final bool selected;
  final VoidCallback? onTap, onRefresh;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final empty = state == SlotCardState.empty;
    final onDial = state == SlotCardState.onDial;
    final strong = selected || onDial;
    final badge = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onDial ? p.fg : Colors.transparent,
        borderRadius: BorderRadius.circular(KataRadii.slot),
        border: onDial ? null : Border.all(color: empty ? p.muted : p.fg),
      ),
      child: Text('C$slot', style: KataType.displayStyle(size: 12, color: onDial ? p.bg : (empty ? p.muted : p.fg), letterSpacing: 0)),
    );
    Widget trailing = const SizedBox.shrink();
    if (onDial) {
      trailing = Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: p.fg)),
        child: Text('ON DIAL', style: KataType.monoStyle(size: 8.5, weight: FontWeight.w500, color: p.fg)),
      );
    } else if (selected) {
      trailing = Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: p.fg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text('✓', style: TextStyle(fontFamily: KataType.body, fontSize: 9, fontWeight: FontWeight.w600, color: p.bg, height: 1)),
      );
    } else if (onRefresh != null && !empty) {
      trailing = GestureDetector(
        onTap: onRefresh,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.hairline)),
          alignment: Alignment.center,
          child: Text('↻', style: KataType.bodyStyle(size: 11, color: p.muted, height: 1)),
        ),
      );
    }
    return KataCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      dashed: empty,
      outline: strong ? p.fg : p.hairline,
      outlineWidth: strong ? 1.5 : 1,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [badge, trailing]),
        const SizedBox(height: 10),
        Text(
          (empty ? 'Empty' : (title ?? '')).toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KataType.displayStyle(size: 14, color: empty ? p.muted : p.fg, letterSpacing: 0, height: 1.1),
        ),
        const SizedBox(height: 4),
        Text(
          empty ? 'FACTORY DEFAULT\nTAP TO FILL' : '${(line1 ?? '').toUpperCase()}\n${(line2 ?? '').toUpperCase()}',
          style: KataType.monoStyle(size: 10.5, color: p.muted, height: 1.5),
        ),
      ]),
    );
  }
}
