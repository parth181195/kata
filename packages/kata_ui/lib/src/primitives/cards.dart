import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import 'dividers.dart';

class KataCard extends StatelessWidget {
  const KataCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = KataRadii.card,
    this.outline,
    this.outlineWidth = KataStroke.hairline,
    this.dashed = false,
    this.dotted = false,
    this.onTap,
    this.fill,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? outline;
  final double outlineWidth;
  final bool dashed;
  /// Outline drawn as a chain of square dots (Nothing-style) instead of a solid hairline.
  /// Solid is used automatically when [outlineWidth] > 1 (selected / emphasised cards).
  final bool dotted;
  final VoidCallback? onTap;
  final Color? fill;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final useDots = dotted && !dashed;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: (dashed || useDots) ? BorderSide.none : BorderSide(color: outline ?? p.hairline, width: outlineWidth),
    );
    Widget body = Material(
      color: fill ?? Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
    if (dashed) body = CustomPaint(foregroundPainter: _DottedBorder(outline ?? p.hairline, radius, dot: 2.5, gap: 7), child: body);
    if (useDots) body = CustomPaint(foregroundPainter: _DottedBorder(outline ?? p.hairline, radius), child: body);
    return body;
  }
}

/// Square dots (2×2) every 5dp along the rounded-rect outline.
class _DottedBorder extends CustomPainter {
  _DottedBorder(this.color, this.radius, {this.dot = 2, this.gap = 5});
  final Color color;
  final double radius, dot, gap;
  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()..color = color;
    final inset = dot / 2;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(inset, inset, s.width - dot, s.height - dot), Radius.circular(radius - inset)));
    for (final m in path.computeMetrics()) {
      // distribute evenly so the loop closes without a seam
      final n = (m.length / gap).floor();
      final step = m.length / n;
      for (var i = 0; i < n; i++) {
        final t = m.getTangentForOffset(i * step);
        if (t == null) continue;
        c.drawRect(Rect.fromCenter(center: t.position, width: dot, height: dot), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DottedBorder o) => o.color != color || o.radius != radius;
}

class IssueRow {
  const IssueRow(this.left, this.right);
  final String left;
  final String right;
}

/// Red-outlined list: "2 FIELDS NEED ATTENTION" / "1 SETTING SKIPPED".
class IssueCard extends StatelessWidget {
  const IssueCard({super.key, required this.title, required this.rows});
  final String title;
  final List<IssueRow> rows;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return KataCard(
      outline: p.red,
      radius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: p.red)),
          const SizedBox(width: 9),
          Expanded(child: Text(title.toUpperCase(), style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.dim, letterSpacing: 0.16))),
        ]),
        for (final r in rows) ...[
          const SizedBox(height: 10),
          const DottedDivider(),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(r.left, style: KataType.bodyStyle(size: 11.5, color: p.dim))),
            const SizedBox(width: 10),
            Flexible(child: Text(r.right.toUpperCase(), textAlign: TextAlign.right, style: KataType.monoStyle(size: 10.5, color: p.muted, height: 1.4))),
          ]),
        ],
      ]),
    );
  }
}

class KataToast {
  static void show(BuildContext context, String text, {String? action, VoidCallback? onAction}) {
    final p = context.kata;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: p.bg,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: p.hairline)),
        content: Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: p.fg)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: KataType.bodyStyle(size: 11.5, color: p.fg, height: 1))),
          if (action != null)
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                onAction?.call();
              },
              child: Text(action.toUpperCase(), style: KataType.monoStyle(size: 10, weight: FontWeight.w500, color: p.muted)),
            ),
        ]),
      ));
  }
}
