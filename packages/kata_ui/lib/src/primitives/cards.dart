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
    this.outlineWidth = 1,
    this.dashed = false,
    this.onTap,
    this.fill,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? outline;
  final double outlineWidth;
  final bool dashed;
  final VoidCallback? onTap;
  final Color? fill;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: dashed ? BorderSide.none : BorderSide(color: outline ?? p.hairline, width: outlineWidth),
    );
    Widget body = Material(
      color: fill ?? Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
    if (dashed) body = CustomPaint(foregroundPainter: _DashedBorder(outline ?? p.hairline, radius), child: body);
    return body;
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color, this.radius);
  final Color color;
  final double radius;
  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        c.drawPath(m.extractPath(d, d + 4), paint);
        d += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder o) => o.color != color || o.radius != radius;
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
