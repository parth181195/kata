import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';

import '../core/auth/auth_repository.dart';

class DesktopSettings extends ConsumerWidget {
  const DesktopSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    final user = ref.watch(sessionProvider).valueOrNull?.user;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
          KataSectionHeader('Account'),
          const SizedBox(height: 8),
          KataListRow(title: user?.displayName ?? '—', sub: user?.email, value: user?.isAdmin == true ? 'Admin' : null),
          KataListRow(title: 'Sign out', onTap: () => ref.read(sessionProvider.notifier).signOut()),
          const SizedBox(height: 18),
          KataSectionHeader('About'),
          const SizedBox(height: 8),
          const KataListRow(title: 'Kata for Linux', value: '0.2 · Desktop preview'),
          KataCard(
            dashed: true,
            child: Text('Slot backups and write-behaviour options land with the next desktop build. Manage recipes and your @handle on the web: kata.parthjansari.dev/library.', style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.5)),
          ),
        ]),
      ),
    );
  }
}
