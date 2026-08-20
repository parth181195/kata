import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../core/fuji/camera_service.dart';
import '../../core/fuji/slot_identity.dart';
import 'publish_from_camera.dart';
import 'camera_art.dart';
import 'connection_guide.dart';
import 'slot_panel.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});
  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  int? _selected;

  @override
  void initState() {
    super.initState();
    // Plug a camera in while this screen is open and it connects on its own. Silent: on
    // Android a permission grant is a system dialog, so that still waits for a tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(cameraServiceProvider.notifier).enableAutoConnect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(cameraServiceProvider);
    return Scaffold(
      body: SafeArea(
        child: switch (st) {
          CameraReady() => _connected(context, st),
          _ => _disconnected(context, st),
        },
      ),
    );
  }

  // ------------------------------------------------------------ disconnected / connecting / failed

  Widget _disconnected(BuildContext context, CameraState st) {
    final p = context.kata;
    final svc = ref.read(cameraServiceProvider.notifier);
    final connecting = st is CameraConnecting;
    final failed = st is CameraFailed;
    String reasonText(CameraFailure r) => switch (r) {
          CameraFailure.noDevice => 'No Fujifilm camera on USB',
          CameraFailure.permissionDenied => 'USB permission was denied',
          CameraFailure.claimFailed => 'Another app is holding the camera',
          CameraFailure.sessionFailed => 'Camera refused the PTP session',
          CameraFailure.notPresetCapable => 'This body/mode does not expose custom slots over USB',
          CameraFailure.io => 'Camera stopped responding',
        };
    Widget kv(String k, String v) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(k, style: KataType.bodyStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, height: 1.3).copyWith(letterSpacing: 9.5 * 0.12))),
          const SizedBox(width: 10),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: KataType.monoStyle(size: 11, color: p.fg, height: 1.35))),
        ]);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Row(children: [
          Expanded(child: Text('CAMERA', style: KataType.displayStyle(size: 24, color: p.fg))),
          KataStatusPill(KataStatus.disconnected, label: connecting ? 'CONNECTING' : (st is CameraDisconnected && st.reason == CameraFailure.noDevice ? 'NO CAMERA' : 'DISCONNECTED')),
        ]),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), children: [
          const CameraArt(caption: 'LINE ART · MIRRORLESS BODY\nUSB-C PORT HIGHLIGHTED'),
          const SizedBox(height: 10),
          Center(
            child: KataPillButton(
              label: 'Which cameras work?',
              kind: KataButtonKind.secondary,
              display: false,
              height: 34,
              expand: false,
              onPressed: () => context.push('/cameras'),
            ),
          ),
          const SizedBox(height: 16),
          ChecklistStep(
            n: 1,
            title: 'Set two camera menu items',
            active: true,
            sub: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(children: [kv('CONNECTION MODE', 'USB RAW CONV./\nBACKUP RESTORE'), const SizedBox(height: 7), kv('USB POWER SUPPLY', 'OFF / COMM ON')]),
            ),
          ),
          const SizedBox(height: 14),
          const DottedDivider(),
          const SizedBox(height: 14),
          const ChecklistStep(n: 2, title: 'Camera off, plug in USB-C', sub: Text('A data cable, not charge-only. Wait for the small indicator lamp on the camera to light up — that means the phone sees it.')),
          const SizedBox(height: 14),
          const DottedDivider(),
          const SizedBox(height: 14),
          const ChecklistStep(n: 3, title: 'Lamp lit? Power on, then Connect', sub: Text('Only switch the camera on after the lamp is lit. Kata reads your C-slots first — nothing is written yet.')),
          const SizedBox(height: 16),
          if (failed) ...[
            IssueCard(title: "Couldn't connect", rows: [IssueRow(reasonText(st.reason), st.detail ?? '')]),
            const SizedBox(height: 16),
          ],
          InkWell(
            onTap: () => showConnectionGuide(context),
            child: Container(
              padding: const EdgeInsets.only(top: 13, bottom: 13),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.surface))),
              child: Row(children: [
                Expanded(child: Text('Connection guide', style: KataType.bodyStyle(size: 12.5, weight: FontWeight.w600, color: p.dim, height: 1))),
                Text('CABLES · OTG · WHAT WENT WRONG', style: KataType.monoStyle(size: 8.5, color: p.muted, letterSpacing: 0.12)),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 16, color: p.muted),
              ]),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: KataBigRound(
          label: connecting ? st.step : (failed ? 'Retry' : 'Connect'),
          sub: connecting ? null : 'USB-C',
          loading: connecting,
          onPressed: connecting ? null : svc.connect,
        ),
      ),
    ]);
  }

  // ------------------------------------------------------------ connected

  Widget _connected(BuildContext context, CameraReady st) {
    final p = context.kata;
    final svc = ref.read(cameraServiceProvider.notifier);
    final sensors = OfrMapper.sensorsForModel(st.caps.model);
    final sel = _selected != null && _selected! <= st.slots.length ? _selected : null;
    String drOf(CameraPreset s) => s.dynamicRange == kDrAuto ? 'DR AUTO' : 'DR${s.dynamicRange ?? 100}';
    String wbOf(CameraPreset s) => s.wbMode == WbMode.colorTemp && s.wbKelvin != null ? '${s.wbKelvin}K' : (WbMode.labels[s.wbMode] ?? 'WB');

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(st.caps.model.toUpperCase(), style: KataType.displayStyle(size: 24, color: p.fg))),
            KataStatusPill(KataStatus.connected, label: st.busy ? st.busyWith!.toUpperCase() : null),
          ]),
          const SizedBox(height: 5),
          Text('FW ${st.caps.firmware} · ${sensors.isEmpty ? 'FUJIFILM' : sensors.first.toUpperCase()} · ${st.caps.slotCount} SLOTS', style: KataType.monoStyle(size: 10.5, color: p.muted, height: 1.4)),
        ]),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
          Row(children: [
            Expanded(child: Text('CUSTOM SLOTS', style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16))),
            InkWell(onTap: st.busy ? null : svc.refreshSlots, child: Text('READ ALL ↻', style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.dim, letterSpacing: 0.16))),
          ]),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 11, crossAxisSpacing: 11, mainAxisExtent: 128),
            itemCount: st.slots.length,
            itemBuilder: (_, i) {
              final s = st.slots[i];
              // Match the slot back to a kata so the card shows its real name (cameras keep
              // at most 25 characters, and the X-S20 keeps none) and flags in-camera edits.
              final ident = identifySlot(ref, st.caps.model, i + 1, s);
              final title = ident.recipe?.name ?? (s.name.isEmpty ? (FilmSim.labels[s.filmSim] ?? 'Slot ${i + 1}') : s.name);
              return SlotCard(
                slot: i + 1,
                state: SlotCardState.filled,
                selected: sel == i + 1,
                title: title,
                line1: ident.edited ? 'EDITED · FROM ${ident.origin!.name}' : (FilmSim.labels[s.filmSim] ?? ''),
                line2: '${drOf(s)} · ${wbOf(s)}',
                onTap: () => setState(() => _selected = i + 1),
                onRefresh: st.busy ? null : svc.refreshSlots,
              );
            },
          ),
          if (sel != null) ...[
            const SizedBox(height: 18),
            Container(height: 1, color: p.surface),
            const SizedBox(height: 14),
            SlotPanel(
              slot: sel,
              preset: st.slots[sel - 1],
              model: st.caps.model,
              busy: st.busy,
              identity: identifySlot(ref, st.caps.model, sel, st.slots[sel - 1]),
              // Save / publish what is actually in the slot — including anything dialled in
              // on the body since Kata wrote it.
              onSave: () => showPublishFromCamera(context, ref, slot: sel),
              onOverwrite: () {
                KataToast.show(context, 'Pick a kata, then Write to camera');
                context.go('/library');
              },
            ),
          ],
        ]),
      ),
    ]);
  }
}

