import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// Section header: mono eyebrow label, e.g. SETTINGS.
class KataSectionHeader extends StatelessWidget {
  const KataSectionHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(child: Text(text.toUpperCase(), style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16))),
        ?trailing,
      ]),
    );
  }
}

/// List row: title (+ optional sub), trailing value in mono, hairline below.
class KataListRow extends StatelessWidget {
  const KataListRow({super.key, required this.title, this.sub, this.value, this.onTap, this.onLongPress, this.trailing, this.enabled = true, this.contentInset = 0, this.selected = false, this.inkRadius = 12});
  final String title;
  final String? sub;
  final String? value;
  final VoidCallback? onTap, onLongPress;
  final Widget? trailing;
  final bool enabled;

  /// Picked, in a list you choose from: the text brightens and a tick sits at the very end
  /// of the line. Use this instead of passing a tick through [value], which floats mid-row.
  final bool selected;

  /// Corner radius of the pressed/hover highlight. Rounded suits an inset card-like row;
  /// pass 0 for a full-bleed list, where rounded corners float oddly against square rows.
  final double inkRadius;

  /// Pads the text *inside* the highlight. Zero on a phone, where the page's own margin does
  /// that job; on a wide row the label would otherwise sit on the highlight's edge.
  final double contentInset;

  /// The ink highlight bleeds [inkBleed] px past the text on both sides (text stays aligned with the
  /// surrounding content; the pressed state doesn't start on the same pixel as the label).
  static const inkBleed = 12.0;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final content = Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 13, weight: FontWeight.w600, color: enabled ? p.fg : p.muted, height: 1.2)),
          if (sub != null) ...[
            const SizedBox(height: 3),
            Text(sub!, maxLines: 2, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 11.5, color: selected ? p.fg : p.muted, height: 1.3)),
          ],
        ]),
      ),
      if (value != null) ...[
        const SizedBox(width: 12),
        // shrink-wrapped, so it sits at the end of the line rather than floating in a share
        // of the leftover space
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(value!.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: KataType.monoStyle(size: 10.5, weight: FontWeight.w500, color: p.muted)),
        ),
      ],
      if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      if (selected) ...[
        const SizedBox(width: 12),
        Text('✓', style: KataType.bodyStyle(size: 14, weight: FontWeight.w700, color: p.fg, height: 1)),
      ],
    ]);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hairline, width: KataStroke.hairline))),
      child: Stack(clipBehavior: Clip.none, children: [
        // ink layer: bleeds past the text on both sides so the pressed state never starts on the label's first pixel
        Positioned(
          left: -inkBleed,
          right: -inkBleed,
          top: 0,
          bottom: 0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(onTap: enabled ? onTap : null, onLongPress: onLongPress, borderRadius: BorderRadius.circular(inkRadius)),
          ),
        ),
        IgnorePointer(
          ignoring: trailing == null, // a custom trailing widget (switch, button) keeps its own taps
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: contentInset),
            child: content,
          ),
        ),
      ]),
    );
  }
}
