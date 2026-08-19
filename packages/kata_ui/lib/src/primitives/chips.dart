import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

class KataChip extends StatelessWidget {
  const KataChip({super.key, required this.label, this.selected = false, this.onTap, this.dot = false});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool dot;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Material(
      color: selected ? p.fg : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: selected ? Colors.transparent : p.hairline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (dot) ...[
              Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? p.bg : p.muted)),
              const SizedBox(width: 6),
            ],
            Text(label.toUpperCase(), style: KataType.monoStyle(size: 10.5, weight: FontWeight.w500, color: selected ? p.bg : p.dim)),
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
