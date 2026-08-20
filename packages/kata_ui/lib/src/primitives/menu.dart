import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

/// One row in a [showKataMenu] menu. `value` is returned from the future when picked.
class KataMenuItem<T> {
  const KataMenuItem(this.value, this.label, {this.icon, this.trailing, this.destructive = false, this.enabled = true, this.selected = false, this.submenu});
  final T value;
  final String label;
  final IconData? icon;
  /// Right-aligned mono hint ("C3", "Soon", "⌘E"…).
  final String? trailing;
  final bool destructive;
  final bool enabled;
  /// Single-select menus: shows a dot on the selected row.
  final bool selected;
  /// 5b: a child menu opens only when it has 3+ children; on phones it replaces the parent with a back row.
  final List<KataMenuItem<T>>? submenu;
}

/// Divider between menu sections.
class KataMenuDivider<T> extends KataMenuItem<T> {
  const KataMenuDivider(T value) : super(value, '');
}

/// Anchored menu per design 5b: R14 panel, 6dp padding, 44dp items (R11), 15dp icons, 11dp gap,
/// hairline dividers inset 12dp, destructive rows red and last. Closes on outside tap and scroll.
/// [title] names the object for long-press context menus.
Future<T?> showKataMenu<T>(
  BuildContext context, {
  required List<KataMenuItem<T>> items,
  String? title,
  Offset? position,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final box = context.findRenderObject() as RenderBox?;
  final anchor = position ?? (box == null ? overlay.size.center(Offset.zero) : box.localToGlobal(box.size.bottomRight(Offset.zero) - Offset(box.size.width, 0)));
  final stack = <List<KataMenuItem<T>>>[items];
  final titles = <String?>[title];
  T? result;
  await showGeneralDialog<void>(
    context: context,
    barrierLabel: 'menu',
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    transitionBuilder: (c, a, _, child) => Opacity(opacity: a.value, child: child),
    pageBuilder: (dialogContext, _, _) => StatefulBuilder(
      builder: (c, setState) {
        final p = c.kata;
        final current = stack.last;
        final curTitle = titles.last;
        Widget row(KataMenuItem<T> it) {
          if (it is KataMenuDivider<T>) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Container(height: 1, color: p.hairline),
            );
          }
          final fg = !it.enabled ? p.muted : (it.destructive ? p.red : p.fg);
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: !it.enabled
                  ? null
                  : () {
                      if (it.submenu != null) {
                        setState(() {
                          stack.add(it.submenu!);
                          titles.add(it.label);
                        });
                      } else {
                        result = it.value;
                        Navigator.of(dialogContext).pop();
                      }
                    },
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  if (it.icon != null) ...[Icon(it.icon, size: 15, color: fg), const SizedBox(width: 11)],
                  Expanded(child: Text(it.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 13, weight: FontWeight.w600, color: fg, height: 1))),
                  if (it.selected) Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: p.fg)),
                  if (it.trailing != null) ...[
                    const SizedBox(width: 11),
                    Text(it.trailing!.toUpperCase(), style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: it.enabled ? p.muted : p.hairline)),
                  ],
                  if (it.submenu != null) ...[const SizedBox(width: 11), Text('›', style: KataType.bodyStyle(size: 14, color: p.muted, height: 1))],
                ]),
              ),
            ),
          );
        }

        final screen = MediaQuery.sizeOf(c);
        const w = 244.0;
        final left = anchor.dx.clamp(12.0, screen.width - w - 12);
        final estH = 12 + current.length * 44 + (curTitle != null || stack.length > 1 ? 40 : 0);
        final top = anchor.dy.clamp(12.0, (screen.height - estH - 12).clamp(12.0, double.infinity));
        return Stack(children: [
          Positioned(
            left: left,
            top: top,
            width: w,
            child: Material(
              color: p.bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: p.hairline, width: KataStroke.hairline)),
              clipBehavior: Clip.antiAlias,
              elevation: 12,
              shadowColor: Colors.black,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (stack.length > 1)
                    // 5b: on narrow screens the child replaces the parent with a back row
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => setState(() {
                          stack.removeLast();
                          titles.removeLast();
                        }),
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(children: [
                            Text('‹', style: KataType.bodyStyle(size: 15, color: p.muted, height: 1)),
                            const SizedBox(width: 11),
                            Text((titles.last ?? '').toUpperCase(), style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.14)),
                          ]),
                        ),
                      ),
                    )
                  else if (curTitle != null)
                    Container(
                      height: 36,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
                      alignment: Alignment.centerLeft,
                      child: Text(curTitle.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.14)),
                    ),
                  ...current.map(row),
                ]),
              ),
            ),
          ),
        ]);
      },
    ),
  );
  return result;
}
