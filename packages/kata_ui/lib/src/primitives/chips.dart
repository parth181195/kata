import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// Filter chip; `onRemove` turns it into an input chip (label ×), `count` appends a count, `enabled:false` dims it.
class KataChip extends StatelessWidget {
  const KataChip({super.key, required this.label, this.selected = false, this.onTap, this.dot = false, this.onRemove, this.count, this.enabled = true, this.leadingPlus = false});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool dot;
  final VoidCallback? onRemove;
  final int? count;
  final bool enabled;
  final bool leadingPlus;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final fg = !enabled ? p.muted : (selected ? p.bg : p.dim);
    return Material(
      color: selected && enabled ? p.fg : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: selected && enabled ? Colors.transparent : p.hairline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dot) ...[
              Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? p.bg : p.muted)),
              const SizedBox(width: 6),
            ],
            if (leadingPlus) ...[Text('+', style: KataType.monoStyle(size: 11, weight: FontWeight.w500, color: fg)), const SizedBox(width: 5)],
            Text(label.toUpperCase(), style: KataType.monoStyle(size: 10.5, weight: FontWeight.w500, color: fg)),
            if (count != null) ...[
              const SizedBox(width: 7),
              Container(
                height: 16,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: selected ? p.bg : p.surface),
                child: Text('$count', style: KataType.monoStyle(size: 9, weight: FontWeight.w500, color: selected ? p.fg : p.dim, height: 1)),
              ),
            ],
            if (onRemove != null) ...[
              const SizedBox(width: 7),
              GestureDetector(onTap: onRemove, child: Text('×', style: KataType.bodyStyle(size: 13, color: fg, height: 1))),
            ],
          ]),
        ),
      ),
    );
  }
}

class KataSearchField extends StatelessWidget {
  const KataSearchField({super.key, this.hint = 'Search', this.onChanged, this.controller});
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(21), border: Border.all(color: p.hairline)),
      child: Row(children: [
        Container(width: 13, height: 13, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.muted, width: 1.5))),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: KataType.bodyStyle(size: 12.5, color: p.fg, height: 1),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: KataType.bodyStyle(size: 12.5, color: p.muted, height: 1),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ]),
    );
  }
}
