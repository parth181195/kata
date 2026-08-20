import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';

import '../core/auth/auth_repository.dart';
import '../core/fuji/camera_service.dart';
import 'desktop_camera.dart';
import 'desktop_library.dart';
import 'desktop_settings.dart';

/// Desktop shell per Kata Desktop.dc.html: 52px top bar (wordmark · context · camera pill · account)
/// + 200px rail (Library / Saved / Mine / Camera / Settings) + content. Mobile keeps its own shell.
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});
  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

enum DesktopSection { library, saved, mine, camera, settings }

class _DesktopShellState extends ConsumerState<DesktopShell> {
  DesktopSection _section = DesktopSection.library;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Send CloseSession before we die: otherwise the camera stays latched in USB RAW CONV
    // mode from its side and never falls back to charging until replugged.
    _lifecycle = AppLifecycleListener(onExitRequested: () async {
      await ref.read(cameraServiceProvider.notifier).disconnect();
      return AppExitResponse.exit;
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final cam = ref.watch(cameraServiceProvider);
    final user = ref.watch(sessionProvider).valueOrNull?.user;
    final body = switch (_section) {
      DesktopSection.library => const DesktopLibrary(),
      DesktopSection.saved => const DesktopLibrary(savedOnly: true),
      DesktopSection.mine => const DesktopLibrary(mineOnly: true),
      DesktopSection.camera => const DesktopCamera(),
      DesktopSection.settings => const DesktopSettings(),
    };
    final camPill = switch (cam) {
      CameraReady(:final caps) => KataStatusPill(KataStatus.connected, label: '${caps.model} · C1–C${caps.slotCount}'),
      CameraConnecting() => const KataStatusPill(KataStatus.disconnected, label: 'CONNECTING'),
      _ => const KataStatusPill(KataStatus.noCamera),
    };
    return Scaffold(
      body: Column(children: [
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hairline))),
          child: Row(children: [
            Text('KATA 型', style: KataType.displayStyle(size: 17, weight: FontWeight.w900, color: p.fg, letterSpacing: 0.05)),
            const SizedBox(width: 14),
            Text(_section.name.toUpperCase(), style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16)),
            const Spacer(),
            camPill,
            const SizedBox(width: 12),
            if (user != null)
              Tooltip(
                message: user.email,
                child: InkWell(
                  onTap: () => setState(() => _section = DesktopSection.settings),
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(radius: 14, backgroundColor: p.surface, foregroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null, child: Text(user.displayName.isEmpty ? '?' : user.displayName[0], style: KataType.bodyStyle(size: 11, weight: FontWeight.w600, color: p.fg))),
                ),
              ),
          ]),
        ),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 200,
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
              decoration: BoxDecoration(border: Border(right: BorderSide(color: p.hairline))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (s, label) in [
                  (DesktopSection.library, 'Library'),
                  (DesktopSection.saved, 'Saved'),
                  (DesktopSection.mine, 'Mine'),
                  (DesktopSection.camera, 'Camera'),
                ])
                  _railItem(p, label, s),
                const Spacer(),
                _railItem(p, 'Settings', DesktopSection.settings),
              ]),
            ),
            Expanded(child: body),
          ]),
        ),
      ]),
    );
  }

  Widget _railItem(KataPalette p, String label, DesktopSection s) {
    final on = _section == s;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: on ? p.fg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _section = s),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: Text(label, style: KataType.bodyStyle(size: 13, weight: FontWeight.w600, color: on ? p.bg : p.dim, height: 1)),
          ),
        ),
      ),
    );
  }
}
