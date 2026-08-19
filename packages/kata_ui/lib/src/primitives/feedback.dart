import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';
import 'pill_button.dart';

/// White-outline notice with a "!" badge (e.g. "Turn the dial off C3 and back…").
class KataBanner extends StatelessWidget {
  const KataBanner({super.key, required this.child, this.badge = '!', this.outline});
  final Widget child;
  final String badge;
  final Color? outline;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final c = outline ?? p.fg;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: c)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c)),
          child: Text(badge, style: KataType.displayStyle(size: 11, color: c, letterSpacing: 0)),
        ),
        const SizedBox(width: 12),
        Expanded(child: DefaultTextStyle(style: KataType.bodyStyle(size: 12, color: p.fg, height: 1.55), child: child)),
      ]),
    );
  }
}

/// Empty / error / permission state block: big circle glyph, Doto title, body, optional action.
class KataEmptyState extends StatelessWidget {
  const KataEmptyState({super.key, required this.glyph, required this.title, this.body, this.actionLabel, this.onAction, this.dashed = true});
  final String glyph;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool dashed;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: dashed ? null : BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: p.hairline)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.hairline)),
          child: Text(glyph, style: KataType.displayStyle(size: 15, color: p.muted, letterSpacing: 0)),
        ),
        const SizedBox(height: 12),
        Text(title.toUpperCase(), textAlign: TextAlign.center, style: KataType.displayStyle(size: 17, color: p.fg, letterSpacing: 0, height: 1.15)),
        if (body != null) ...[
          const SizedBox(height: 8),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 230), child: Text(body!, textAlign: TextAlign.center, style: KataType.bodyStyle(size: 12, color: p.muted, height: 1.5))),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: 14),
          KataPillButton(label: actionLabel!, display: false, expand: false, height: 40, onPressed: onAction),
        ],
      ]),
    );
  }
}

/// Modal confirmation ("Overwrite C3?") — destructive confirmations stay modal (no swipe-away).
Future<bool?> showKataDialog(BuildContext context, {required String title, required String body, required String confirmLabel, String cancelLabel = 'Cancel', bool destructive = false}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.60),
    builder: (c) {
      final p = c.kata;
      return Dialog(
        backgroundColor: p.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: p.hairline)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(), style: KataType.displayStyle(size: 20, color: p.fg)),
            const SizedBox(height: 10),
            Text(body, style: KataType.bodyStyle(size: 12.5, color: p.dim, height: 1.5)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: KataPillButton(label: cancelLabel, kind: KataButtonKind.secondary, display: false, height: 50, onPressed: () => Navigator.of(c).pop(false))),
              const SizedBox(width: 10),
              Expanded(child: KataPillButton(label: confirmLabel, kind: destructive ? KataButtonKind.danger : KataButtonKind.primary, display: !destructive, height: 50, onPressed: () => Navigator.of(c).pop(true))),
            ]),
          ]),
        ),
      );
    },
  );
}

/// Skeleton placeholder card while loading.
class KataSkeletonCard extends StatelessWidget {
  const KataSkeletonCard({super.key, this.height = 104});
  final double height;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    Widget bar(double w, double h) => Container(width: w, height: h, decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(4)));
    return Container(
      height: height,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: p.hairline)),
      child: Row(children: [
        Container(width: 78, height: 78, decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12))),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [bar(140, 14), const SizedBox(height: 8), bar(180, 10), const SizedBox(height: 6), bar(100, 10)])),
      ]),
    );
  }
}
