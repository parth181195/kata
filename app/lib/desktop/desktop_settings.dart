import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../core/auth/auth_repository.dart';
import '../core/fuji/camera_service.dart';
import '../data/recipe_repository.dart';
import '../features/onboarding/onboarding_state.dart';
import 'desktop_import.dart';
import 'slot_backups.dart';

/// Design 1j: account, the connected body, slot backups, write behaviour and data export.
class DesktopSettings extends ConsumerWidget {
  const DesktopSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    final user = ref.watch(sessionProvider).valueOrNull?.user;
    final cam = ref.watch(cameraServiceProvider);
    final backups = ref.watch(slotBackupsProvider);
    final repo = ref.watch(recipeRepositoryProvider);
    final ready = cam is CameraReady ? cam : null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(padding: const EdgeInsets.all(24), children: [
          KataSectionHeader('Account'),
          const SizedBox(height: 8),
          KataListRow(title: user?.displayName ?? 'Not signed in', sub: user?.email, value: user?.isAdmin == true ? 'Admin' : null),
          if (user != null)
            KataListRow(
              title: 'My camera & looks',
              sub: 'What the library opens on',
              value: user.preferences.body ?? user.preferences.sensor ?? 'SET UP',
              onTap: () => ref.read(redoOnboardingProvider.notifier).state = true,
            ),
          if (user != null) KataListRow(title: 'Sign out', onTap: () => ref.read(sessionProvider.notifier).signOut()),

          const SizedBox(height: 20),
          KataSectionHeader('Camera'),
          const SizedBox(height: 8),
          KataListRow(
            title: ready?.caps.model ?? 'No camera connected',
            sub: ready == null ? 'Plug one in — Kata connects on its own' : 'Firmware ${ready.caps.firmware} · C1–C${ready.caps.slotCount} · ${ready.caps.supportedProps.length} properties',
            value: ready == null ? null : 'READY',
          ),
          if (ready != null)
            KataListRow(
              title: 'Eject',
              sub: 'Close the USB session so the camera can charge on the same cable',
              onTap: () => ref.read(cameraServiceProvider.notifier).disconnect(),
            )
          else
            KataListRow(title: 'Scan for a camera', onTap: () => ref.read(cameraServiceProvider.notifier).connect()),
          KataListRow(
            title: 'Linux setup',
            sub: 'One udev rule stops the desktop grabbing the camera first — docs/ops/kata-desktop.md',
            value: 'HELP',
            onTap: () async {
              await Clipboard.setData(const ClipboardData(
                  text: 'echo \'SUBSYSTEM=="usb", ATTR{idVendor}=="04cb", MODE="0666", TAG+="uaccess", ENV{ID_GPHOTO2}="", ENV{GPHOTO2_DRIVER}=""\' | sudo tee /etc/udev/rules.d/70-kata-fuji.rules && sudo udevadm control --reload'));
              if (context.mounted) KataToast.show(context, 'Setup command copied — run it once, then replug');
            },
          ),

          const SizedBox(height: 20),
          KataSectionHeader('Slot backups'),
          const SizedBox(height: 8),
          KataListRow(
            title: backups.isEmpty ? 'No backups yet' : '${backups.length} backup${backups.length == 1 ? '' : 's'}',
            sub: 'Kata snapshots every slot before it writes — restore any of them',
            value: 'OPEN',
            onTap: () => showSlotBackupsDialog(context, ref),
          ),
          KataListRow(
            title: 'Back up now',
            sub: ready == null ? 'Needs a connected camera' : 'Snapshot C1–C${ready.caps.slotCount} as they are',
            enabled: ready != null,
            onTap: ready == null
                ? null
                : () async {
                    await ref.read(cameraServiceProvider.notifier).refreshSlots();
                    final fresh = ref.read(cameraServiceProvider);
                    if (fresh is! CameraReady) return;
                    final b = await ref.read(slotBackupsProvider.notifier).takeBackup(fresh, auto: false);
                    if (context.mounted) KataToast.show(context, b == null ? 'Nothing new to back up' : 'Backed up ${b.slots.length} slots');
                  },
          ),

          const SizedBox(height: 20),
          KataSectionHeader('Write behaviour'),
          const SizedBox(height: 8),
          const KataListRow(title: 'Review every write', sub: 'Kata always shows the field-level diff before sending anything', value: 'ALWAYS'),
          const KataListRow(title: 'Back up before writing', sub: 'Automatic, and re-read first so the snapshot matches the camera', value: 'ON'),
          const KataListRow(title: 'Preset names', sub: 'Trimmed to 25 ASCII characters; bodies that store none get an empty name', value: 'SAFE'),

          const SizedBox(height: 20),
          KataSectionHeader('Data'),
          const SizedBox(height: 8),
          KataListRow(
            title: 'Export my katas',
            sub: '${repo.mine.length} draft${repo.mine.length == 1 ? '' : 's'} · ${repo.published.length} published — one OFR JSON file',
            value: 'SAVE',
            onTap: () => _exportMine(context, ref),
          ),
          KataListRow(title: 'Import a kata', sub: 'Card image, .ofr.json, or a pasted Kata Code', value: 'OPEN', onTap: () => showImportDialog(context)),
          KataListRow(
            title: 'App data folder',
            sub: 'Backups and slot history live here',
            value: 'COPY',
            onTap: () async {
              final dir = await getApplicationSupportDirectory();
              await Clipboard.setData(ClipboardData(text: dir.path));
              if (context.mounted) KataToast.show(context, 'Path copied');
            },
          ),

          const SizedBox(height: 20),
          KataSectionHeader('About'),
          const SizedBox(height: 8),
          const KataListRow(title: 'Kata for Linux', value: '0.2 · Desktop preview'),
          KataCard(
            dashed: true,
            child: Text('Kata is open source. Recipes and your @handle also live on the web: kata.parthjansari.dev/library.',
                style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.5)),
          ),
        ]),
      ),
    );
  }

  Future<void> _exportMine(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(recipeRepositoryProvider);
    final all = [...repo.mine, ...repo.published];
    if (all.isEmpty) {
      KataToast.show(context, 'Nothing to export yet');
      return;
    }
    final body = const JsonEncoder.withIndent('  ').convert({
      'v': 1,
      'exported': DateTime.now().toIso8601String(),
      'recipes': [for (final r in all) r.ofr.toJson()],
    });
    final path = await FilePicker.platform.saveFile(dialogTitle: 'Export my katas', fileName: 'kata-export.ofr.json', bytes: utf8.encode(body));
    if (path == null) return;
    // Linux/macOS return a path without writing: do it ourselves when the file isn't there yet.
    final f = File(path);
    if (!await f.exists() || (await f.length()) == 0) await f.writeAsString(body);
    if (context.mounted) KataToast.show(context, 'Exported ${all.length} katas');
  }
}
