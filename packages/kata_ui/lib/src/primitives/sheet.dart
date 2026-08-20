import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';
import '../tokens.dart';

class KataSheet extends StatelessWidget {
  const KataSheet({super.key, this.eyebrow, this.title, required this.children, this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 22)});
  final String? eyebrow;
  final String? title;
  final List<Widget> children;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        border: Border(top: BorderSide(color: p.hairline, width: KataStroke.hairline)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(KataRadii.sheet)),
      ),
      padding: padding,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: p.hairline, borderRadius: BorderRadius.circular(2)))),
        if (eyebrow != null || title != null) ...[
          const SizedBox(height: 16),
          if (eyebrow != null) Text(eyebrow!.toUpperCase(), style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16)),
          if (title != null) ...[const SizedBox(height: 6), Text(title!.toUpperCase(), style: KataType.displayStyle(size: 22, color: p.fg))],
        ],
        const SizedBox(height: 16),
        ...children,
      ]),
    );
  }
}

/// A sheet on a phone, a centred panel on anything desktop-sized. Bottom sheets rely on a
/// thumb and a short screen; on a wide window they slide up from a corner of the user's
/// vision and cover a fraction of it, so the same content is shown as a modal panel instead.
Future<T?> showKataSheet<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  final wide = MediaQuery.sizeOf(context).width >= KataLayout.sheetBreakpoint;
  if (!wide) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      sheetAnimationStyle: const AnimationStyle(duration: KataMotion.sheetIn, reverseDuration: KataMotion.sheetOut, curve: KataMotion.curve, reverseCurve: Curves.easeOut),
      builder: (c) => SafeArea(
        top: false,
        child: SingleChildScrollView(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom), child: builder(c)),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierColor: Colors.black.withValues(alpha: 0.60),
    builder: (c) {
      final p = c.kata;
      return Dialog(
        backgroundColor: p.bg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: p.hairline, width: KataStroke.hairline)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: KataLayout.sheetWidth, maxHeight: MediaQuery.sizeOf(c).height * 0.86),
          child: SingleChildScrollView(child: builder(c)),
        ),
      );
    },
  );
}
