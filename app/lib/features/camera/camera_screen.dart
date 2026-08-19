import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../core/fuji/camera_service.dart';
import '../../data/recipe_repository.dart';
import '../../data/recipe.dart';
import 'slot_panel.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});
  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  int? _selected;
  bool _trouble = false;

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
          Container(
            height: 158,
            alignment: Alignment.center,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: p.hairline)),
            child: CustomPaint(
              painter: _HatchPainter(p.surface),
              child: Center(child: Text('[ LINE-ART PLACEHOLDER ]\nMIRRORLESS BODY · USB-C PORT HIGHLIGHTED', textAlign: TextAlign.center, style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.1, height: 1.6))),
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
            onTap: () => setState(() => _trouble = !_trouble),
            child: Container(
              padding: const EdgeInsets.only(top: 13, bottom: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.surface))),
              child: Row(children: [
                Expanded(child: Text('Troubleshooting', style: KataType.bodyStyle(size: 12.5, weight: FontWeight.w600, color: p.dim, height: 1))),
                Icon(_trouble ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: p.muted),
              ]),
            ),
          ),
          if (_trouble)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '• Close other apps that use USB (file managers, gallery importers).\n• Use the cable that came with the camera; many C-C cables are charge-only.\n• X-M5: try CONNECTION MODE → USB TETHER SHOOTING (FIXED).\n• If the phone says "Charging this device", replug with the camera already on.',
                style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.5),
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: KataBigRound(
          label: connecting ? st.step : (failed ? 'Retry' : 'Connect'),
          sub: connecting ? null : 'USB-C',
          onPressed: connecting ? null : svc.connect,
        ),
      ),
    ]);
  }

  // ------------------------------------------------------------ connected

  Widget _connected(BuildContext context, CameraReady st) {
    final p = context.kata;
    final svc = ref.read(cameraServiceProvider.notifier);
    final lib = ref.read(recipeRepositoryProvider);
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
              final title = s.name.isEmpty ? (FilmSim.labels[s.filmSim] ?? 'Slot ${i + 1}') : s.name;
              return SlotCard(
                slot: i + 1,
                state: SlotCardState.filled,
                selected: sel == i + 1,
                title: title,
                line1: FilmSim.labels[s.filmSim] ?? '',
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
              onSave: () async {
                final ofr = OfrMapper.fromPreset(st.slots[sel - 1], sensors: sensors, sourceAttribution: 'Read from ${st.caps.model}');
                final named = ofr.name == null ? ofr.copyWith(name: '${FilmSim.labels[st.slots[sel - 1].filmSim]} C$sel') : ofr;
                await lib.addImported(named, source: RecipeSource.camera);
                if (context.mounted) KataToast.show(context, 'Saved to Mine');
              },
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

class _HatchPainter extends CustomPainter {
  _HatchPainter(this.color);
  final Color color;
  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6;
    for (var x = -s.height; x < s.width; x += 12) {
      c.drawLine(Offset(x, s.height), Offset(x + s.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter o) => o.color != color;
}
