import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    Widget row(String title, {String? trailing, VoidCallback? onTap, VoidCallback? onLongPress}) => InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            height: 52,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hairline))),
            child: Row(children: [
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 13, weight: FontWeight.w600, color: p.fg, height: 1))),
              if (trailing != null) Flexible(child: Text(trailing, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: KataType.monoStyle(size: 10.5, color: p.muted))),
            ]),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 20), children: [
          Text('PROFILE', style: KataType.displayStyle(size: 24, color: p.fg)),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 54, height: 54, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.hairline)), alignment: Alignment.center,
                child: Text('型', style: KataType.displayStyle(size: 22, weight: FontWeight.w400, color: p.fg, letterSpacing: 0))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SIGNED IN', style: KataType.displayStyle(size: 16, color: p.fg)),
                const SizedBox(height: 4),
                Text('Google account · Plan 3 wires real auth', maxLines: 2, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.2)),
              ]),
            ),
          ]),
          const SizedBox(height: 24),
          row('Sign out', onTap: () async {
            await ref.read(signedInProvider.notifier).set(false);
            if (context.mounted) context.go('/signin');
          }),
          row('About Kata · OFR spec · Licences', trailing: 'MIT'),
          row('Component kit', trailing: '/KIT', onTap: () => context.push('/kit')),
          row('Version', trailing: '0.1.0 · LONG-PRESS FOR PROBE', onLongPress: () => context.push('/probe')),
        ]),
      ),
    );
  }
}
