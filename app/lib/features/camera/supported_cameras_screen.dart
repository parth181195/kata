import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../core/fuji/camera_service.dart';
import 'camera_art.dart';

/// Every body Kata knows, grouped by what it can do over USB. Honest: only the X-S20 is verified.
class SupportedCamerasScreen extends ConsumerWidget {
  const SupportedCamerasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    final cam = ref.watch(cameraServiceProvider);
    final connectedModel = cam is CameraReady ? cam.caps.model : null;
    final connected = knownBodyFor(connectedModel);

    final tiers = <(String, String, String, List<KnownBody>)>[
      ('Writes recipes', 'X-Processor 5 bodies expose the custom-slot protocol. Verified on the X-S20; the rest are expected to behave the same — tell us when you try one.', 'full',
          KnownBody.all.where((b) => b.usbWrite == UsbWrite.full).toList()),
      ('Probe at connect', 'Older RAW-conversion bodies. Kata checks the USB device info when you plug in and enables writing only if the slot properties are there.', 'probe',
          KnownBody.all.where((b) => b.usbWrite == UsbWrite.probe).toList()),
      ('Connects, read only', 'No custom-slot properties over USB. You can still browse, import and share recipes and type them in by hand.', 'none',
          KnownBody.all.where((b) => b.usbWrite == UsbWrite.none).toList()),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(children: [
              KataIconCircle(size: 40, onPressed: () => context.pop(), child: Icon(Icons.arrow_back_ios_new, size: 14, color: p.dim)),
              const SizedBox(width: 14),
              Expanded(child: Text('CAMERAS', style: KataType.displayStyle(size: 24, color: p.fg))),
              Text('${KnownBody.all.length} BODIES', style: KataType.monoStyle(size: 10.5, weight: FontWeight.w500, color: p.muted)),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 6, 20, 28), children: [
              if (connected != null) ...[
                KataCard(
                  outline: p.fg,
                  outlineWidth: KataStroke.emphasis,
                  child: Row(children: [
                    SizedBox(width: 84, child: CameraArt(slug: connected.slug, height: 56, radius: 10)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('CONNECTED NOW', style: KataType.monoStyle(size: 9, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16)),
                        const SizedBox(height: 4),
                        Text(connected.model.toUpperCase(), style: KataType.displayStyle(size: 18, color: p.fg, letterSpacing: 0)),
                        Text('${connected.generation} · C1–C${connected.slots}', style: KataType.monoStyle(size: 10.5, color: p.dim)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
              ],
              for (final (title, blurb, kind, bodies) in tiers) ...[
                KataSectionHeader(title),
                const SizedBox(height: 6),
                Text(blurb, style: KataType.bodyStyle(size: 12, color: p.muted, height: 1.5)),
                const SizedBox(height: 10),
                for (final b in bodies)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: KataCard(
                      padding: const EdgeInsets.all(10),
                      dotted: kind != 'full',
                      child: Row(children: [
                        SizedBox(width: 84, child: CameraArt(slug: b.slug, height: 56, radius: 10, caption: b.slug.toUpperCase())),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Flexible(child: Text(b.model.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 16, color: p.fg, letterSpacing: 0))),
                              if (b.tested) ...[const SizedBox(width: 6), const VerifiedBadge(size: 14)],
                            ]),
                            const SizedBox(height: 3),
                            Text('${b.generation} · C1–C${b.slots}${b.note != null ? ' · ${b.note}' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 10, color: p.muted, height: 1.35)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        KataStatusPill(
                          switch (kind) { 'full' => KataStatus.connected, 'probe' => KataStatus.disconnected, _ => KataStatus.offline },
                          label: switch (kind) { 'full' => b.tested ? 'TESTED' : 'WRITES', 'probe' => 'PROBE', _ => 'READ' },
                        ),
                      ]),
                    ),
                  ),
                const SizedBox(height: 14),
              ],
              KataCard(
                dashed: true,
                child: Text(
                  'Missing your body? Kata accepts any Fujifilm camera (USB vendor 0x04CB) and asks the camera what it supports — so an unlisted model may still work. Camera set to USB RAW CONV./BACKUP RESTORE.',
                  style: KataType.bodyStyle(size: 12, color: p.muted, height: 1.5),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
