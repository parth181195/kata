import 'package:flutter/material.dart';

import '../motion.dart';
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
      shape: StadiumBorder(side: BorderSide(color: selected && enabled ? Colors.transparent : p.hairline, width: KataStroke.hairline)),
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
  /// [height] 42 suits a dense desktop toolbar; phone screens should pass something at or
  /// above the 48px touch target — [KataSearchField.touch].
  const KataSearchField({super.key, this.hint = 'Search', this.onChanged, this.controller, this.height = 42});

  /// Comfortable size for a primary, thumb-reached search box.
  static const touch = 54.0;

  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final big = height >= 48;
    final text = big ? 14.0 : 12.5;
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: big ? 18 : 15),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(height / 2), border: Border.all(color: p.hairline, width: KataStroke.hairline)),
      child: Row(children: [
        Container(
          width: big ? 15 : 13,
          height: big ? 15 : 13,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.muted, width: 1.5)),
        ),
        SizedBox(width: big ? 12 : 10),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: KataType.bodyStyle(size: text, color: p.fg, height: 1),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: KataType.bodyStyle(size: text, color: p.muted, height: 1),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Two or three named choices in one pill — reads its state as words rather than a switch
/// position, so nobody has to learn which side means what. (KataSegmented in fields.dart is
/// the wider tab strip; this is the inline control that replaces a toggle.)
class KataChoice<T> extends StatelessWidget {
  const KataChoice({super.key, required this.values, required this.selected, required this.label, required this.onChanged, this.height = 30});
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Container(
      height: height,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: p.hairline, width: KataStroke.hairline),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final v in values)
          GestureDetector(
            onTap: v == selected ? null : () => onChanged(v),
            child: AnimatedContainer(
              duration: KataMotion.tap,
              padding: EdgeInsets.symmetric(horizontal: height * 0.42),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height / 2),
                color: v == selected ? p.fg : Colors.transparent,
              ),
              child: Text(
                label(v).toUpperCase(),
                style: KataType.monoStyle(size: height * 0.32, weight: FontWeight.w500, color: v == selected ? p.bg : p.muted, letterSpacing: 0.1),
              ),
            ),
          ),
      ]),
    );
  }
}
