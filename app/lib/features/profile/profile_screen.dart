import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../core/auth/auth_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    Widget row(String title, {String? trailing, VoidCallback? onTap, VoidCallback? onLongPress}) =>
        KataListRow(title: title, value: trailing, onTap: onTap, onLongPress: onLongPress);
    final user = ref.watch(sessionProvider).valueOrNull?.user;
    final initials = (user?.displayName.isNotEmpty ?? false)
        ? user!.displayName.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join()
        : '型';
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 20), children: [
          Text('PROFILE', style: KataType.displayStyle(size: 24, color: p.fg)),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.hairline)),
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              child: user?.photoUrl != null
                  ? CachedNetworkImage(imageUrl: user!.photoUrl!, fit: BoxFit.cover, width: 54, height: 54, errorWidget: (_, _, _) => Text(initials, style: KataType.displayStyle(size: 16, color: p.fg, letterSpacing: 0)))
                  : Text(initials, style: KataType.displayStyle(size: user == null ? 22 : 16, weight: user == null ? FontWeight.w400 : FontWeight.w800, color: p.fg, letterSpacing: 0)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((user?.displayName.isNotEmpty ?? false) ? user!.displayName.toUpperCase() : 'SIGNED IN', maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 16, color: p.fg)),
                const SizedBox(height: 4),
                Text(user?.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.2)),
                if (user?.isAdmin ?? false) ...[
                  const SizedBox(height: 6),
                  const KataChip(label: 'Admin', selected: true, dot: true),
                ],
              ]),
            ),
          ]),
          const SizedBox(height: 24),
          row(
            'My camera & looks',
            trailing: user?.preferences.body ?? user?.preferences.sensor ?? 'SET UP',
            onTap: () => context.push('/onboarding'),
          ),
          row('Sign out', onTap: () => ref.read(sessionProvider.notifier).signOut()),
          row('Supported cameras', trailing: '${KnownBody.all.length} bodies', onTap: () => context.push('/cameras')),
          row('About Kata · OFR spec · Licences', trailing: 'MIT'),
          row('Component kit', trailing: '/KIT', onTap: () => context.push('/kit')),
          row('Version', trailing: '0.2.0 · LONG-PRESS FOR PROBE', onLongPress: () => context.push('/probe')),
        ]),
      ),
    );
  }
}
