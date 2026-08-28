import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';
import '../tokens.dart';

/// Marks a sheet shown as a dialog (desktop): no drag handle, no top edge of
/// its own — the dialog already draws one, and nothing there slides.
class KataSheetDialog extends InheritedWidget {
  const KataSheetDialog({super.key, required super.child});
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<KataSheetDialog>() != null;
  @override
  bool updateShouldNotify(KataSheetDialog oldWidget) => false;
}

class KataSheet extends StatelessWidget {
  const KataSheet({super.key, this.eyebrow, this.title, required this.children, this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 22), this.leading});
  final String? eyebrow;
  final String? title;
  final List<Widget> children;
  final EdgeInsets padding;

  /// Shown beside the content when there's room (a card preview, say) instead of above it.
  final Widget? leading;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final dialog = KataSheetDialog.of(context);
    return Container(
      decoration: dialog
          ? BoxDecoration(color: p.bg)
          : BoxDecoration(
              color: p.bg,
              border: Border(top: BorderSide(color: p.hairline, width: KataStroke.hairline)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(KataRadii.sheet)),
            ),
      padding: dialog ? padding.copyWith(top: padding.top + 8) : padding,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // the handle is a promise the sheet slides; a dialog makes none
        if (!dialog) Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: p.hairline, borderRadius: BorderRadius.circular(2)))),
        if (eyebrow != null || title != null) ...[
          const SizedBox(height: 16),
          if (eyebrow != null) Text(eyebrow!.toUpperCase(), style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16)),
          if (title != null) ...[const SizedBox(height: 6), Text(title!.toUpperCase(), style: KataType.displayStyle(size: 22, color: p.fg))],
        ],
        const SizedBox(height: 16),
        if (leading == null)
          ...children
        else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Flexible(child: leading!),
            const SizedBox(width: 22),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children)),
          ]),
      ]),
    );
  }
}

/// A sheet on a phone, a centred panel on anything desktop-sized. Bottom sheets rely on a
/// thumb and a short screen; on a wide window they slide up from a corner of the user's
/// vision and cover a fraction of it, so the same content is shown as a modal panel instead.
Future<T?> showKataSheet<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true, double? maxWidth}) {
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
          constraints: BoxConstraints(maxWidth: maxWidth ?? KataLayout.sheetWidth, maxHeight: MediaQuery.sizeOf(c).height * 0.86),
          child: SingleChildScrollView(child: KataSheetDialog(child: builder(c))),
        ),
      );
    },
  );
}
