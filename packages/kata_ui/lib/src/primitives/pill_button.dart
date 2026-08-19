import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

enum KataButtonKind { primary, secondary, tonal, danger }

class KataPillButton extends StatelessWidget {
  const KataPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = KataButtonKind.primary,
    this.leading,
    this.height = 58,
    this.expand = true,
    this.display = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final KataButtonKind kind;
  final Widget? leading;
  final double height;
  final bool expand;
  final bool display;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final enabled = onPressed != null;
    final Color bg, fg, border;
    switch (kind) {
      case KataButtonKind.primary:
        bg = enabled ? p.fg : p.surface;
        fg = enabled ? p.bg : p.muted;
        border = Colors.transparent;
      case KataButtonKind.secondary:
        bg = Colors.transparent;
        fg = enabled ? p.dim : p.muted;
        border = p.hairline;
      case KataButtonKind.tonal:
        bg = p.surface;
        fg = p.dim;
        border = Colors.transparent;
      case KataButtonKind.danger:
        bg = Colors.transparent;
        fg = p.red;
        border = p.red;
    }
    final style = display
        ? KataType.displayStyle(size: 15, color: fg, letterSpacing: 0.03)
        : KataType.bodyStyle(size: 12.5, weight: FontWeight.w600, color: fg, height: 1);
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Flexible(child: Text(display ? label.toUpperCase() : label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ],
    );
    return Material(
      color: bg,
      shape: StadiumBorder(side: BorderSide(color: border, width: KataStroke.hairline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(height: height, padding: const EdgeInsets.symmetric(horizontal: 26), alignment: Alignment.center, child: child),
      ),
    );
  }
}

class KataIconCircle extends StatelessWidget {
  const KataIconCircle({super.key, required this.child, this.onPressed, this.size = 44, this.filled = false});
  final Widget child;
  final VoidCallback? onPressed;
  final double size;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Material(
      color: filled ? p.fg : Colors.transparent,
      shape: CircleBorder(side: BorderSide(color: filled ? Colors.transparent : p.hairline, width: KataStroke.hairline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: IconTheme(data: IconThemeData(color: filled ? p.bg : p.dim, size: size * 0.4), child: DefaultTextStyle(style: KataType.bodyStyle(size: size * 0.36, color: filled ? p.bg : p.dim, height: 1), child: child)),
          ),
        ),
      ),
    );
  }
}

/// The big round primary control (Connect).
class KataBigRound extends StatelessWidget {
  const KataBigRound({super.key, required this.label, this.sub, this.onPressed, this.size = 108});
  final String label;
  final String? sub;
  final VoidCallback? onPressed;
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Material(
      color: onPressed == null ? p.surface : p.fg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label.toUpperCase(), style: KataType.displayStyle(size: 15, color: onPressed == null ? p.muted : p.bg)),
            if (sub != null) ...[
              const SizedBox(height: 5),
              Text(sub!, style: KataType.monoStyle(size: 8.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.14)),
            ],
          ]),
        ),
      ),
    );
  }
}
