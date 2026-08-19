import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// Text field: eyebrow label, hairline pill, optional unit suffix, × clear, error caption.
class KataTextField extends StatelessWidget {
  const KataTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.unit,
    this.error,
    this.onChanged,
    this.onClear,
    this.keyboardType,
    this.maxLines = 1,
    this.mono = false,
    this.autofocus = false,
  });
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? unit;
  final String? error;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool mono;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final hasError = error != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label.toUpperCase(), style: KataType.labelStyle(color: hasError ? p.red : p.muted)),
      const SizedBox(height: 6),
      Container(
        constraints: BoxConstraints(minHeight: maxLines > 1 ? 56 : 42),
        padding: EdgeInsets.symmetric(horizontal: 15, vertical: maxLines > 1 ? 10 : 0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(21), border: Border.all(color: hasError ? p.red : p.hairline, width: KataStroke.hairline)),
        child: Row(crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: keyboardType,
              maxLines: maxLines,
              autofocus: autofocus,
              cursorColor: p.fg,
              style: mono ? KataType.monoStyle(size: 12.5, color: p.fg, height: 1.4) : KataType.bodyStyle(size: 13, color: p.fg, height: 1.2),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: KataType.bodyStyle(size: 13, color: p.muted, height: 1.2),
                contentPadding: EdgeInsets.symmetric(vertical: maxLines > 1 ? 0 : 12),
              ),
            ),
          ),
          if (unit != null) ...[const SizedBox(width: 8), Text(unit!, style: KataType.monoStyle(size: 12, color: p.muted))],
          if (onClear != null) ...[
            const SizedBox(width: 8),
            GestureDetector(onTap: onClear, child: Text('×', style: KataType.bodyStyle(size: 16, color: p.muted, height: 1))),
          ],
        ]),
      ),
      if (hasError) ...[
        const SizedBox(height: 6),
        Text(error!.toUpperCase(), style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.red, letterSpacing: 0.1)),
      ],
    ]);
  }
}

/// Segmented control (ALL · MINE · SAVED): pills in a hairline track, selected = inverted.
class KataSegmented extends StatelessWidget {
  const KataSegmented({super.key, required this.labels, required this.index, required this.onChanged, this.counts});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final List<int?>? counts;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: p.hairline, width: KataStroke.hairline)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Material(
              color: i == index ? p.fg : Colors.transparent,
              borderRadius: BorderRadius.circular(17),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(child: Text(labels[i].toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 10.5, weight: FontWeight.w500, color: i == index ? p.bg : p.dim))),
                    if (counts != null && counts![i] != null) ...[
                      const SizedBox(width: 7),
                      Text('${counts![i]}', style: KataType.monoStyle(size: 10.5, weight: FontWeight.w500, color: i == index ? p.bg.withValues(alpha: 0.6) : p.muted)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Underlined tab strip (COLOUR · B&W · MINE 3).
class KataTabs extends StatelessWidget {
  const KataTabs({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Container(
      height: 40,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.surface, width: KataStroke.hairline))),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          InkWell(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == index ? p.fg : Colors.transparent, width: 1.5))),
              alignment: Alignment.center,
              child: Text(labels[i].toUpperCase(), style: KataType.monoStyle(size: 10.5, weight: FontWeight.w500, color: i == index ? p.fg : p.muted)),
            ),
          ),
      ]),
    );
  }
}
