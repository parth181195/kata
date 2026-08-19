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
  const KataListRow({super.key, required this.title, this.sub, this.value, this.onTap, this.onLongPress, this.trailing, this.enabled = true});
  final String title;
  final String? sub;
  final String? value;
  final VoidCallback? onTap, onLongPress;
  final Widget? trailing;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return InkWell(
      onTap: enabled ? onTap : null,
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hairline))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 13, weight: FontWeight.w600, color: enabled ? p.fg : p.muted, height: 1.2)),
              if (sub != null) ...[const SizedBox(height: 3), Text(sub!, maxLines: 2, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.3))],
            ]),
          ),
          if (value != null) ...[
            const SizedBox(width: 12),
            Flexible(child: Text(value!.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: KataType.monoStyle(size: 10.5, weight: FontWeight.w500, color: p.muted))),
          ],
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ]),
      ),
    );
  }
}
