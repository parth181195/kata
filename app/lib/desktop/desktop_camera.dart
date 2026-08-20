import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../core/fuji/camera_service.dart';
import '../data/recipe.dart';
import '../features/camera/camera_art.dart';

/// A queued write: recipe → slot. Cleared after the review dialog commits.
final writeQueueProvider = StateProvider<Map<int, Recipe>>((_) => {});

/// Design 1a/1d: the slot board. Not-connected shows setup; connected shows C1–Cn as drop targets,
/// the pending queue, and "Write n changes" → the 1b field-level diff → writes.
class DesktopCamera extends ConsumerWidget {
  const DesktopCamera({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(cameraServiceProvider);
    return switch (st) {
      CameraReady() => _Board(st: st),
      _ => _NotConnected(state: st),
    };
  }
}

// ---------------------------------------------------------------- 1d not connected
class _NotConnected extends ConsumerWidget {
  const _NotConnected({required this.state});
  final CameraState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    final svc = ref.read(cameraServiceProvider.notifier);
    final connecting = state is CameraConnecting;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CameraArt(height: 170),
              const SizedBox(height: 20),
              Text('PLUG IN A CAMERA', style: KataType.displayStyle(size: 24, color: p.fg)),
              const SizedBox(height: 8),
              Text('You can browse, edit and publish without one. Writing needs a data cable and two menu settings.', style: KataType.bodyStyle(size: 13, color: p.muted, height: 1.5)),
              const SizedBox(height: 16),
              KataPillButton(label: connecting ? 'Scanning…' : 'Scan for camera', height: 48, expand: false, loading: connecting, onPressed: connecting ? null : svc.connect),
            ]),
          ),
          const SizedBox(width: 36),
          SizedBox(
            width: 280,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              KataSectionHeader('Setup · once per body'),
              const SizedBox(height: 10),
              ChecklistStep(n: 1, title: 'Use a data cable', sub: Text("Charge-only cables won't appear. Camera off while you plug in.", style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.4))),
              ChecklistStep(n: 2, title: 'Set two camera menu items', sub: Text('CONNECTION MODE → USB RAW CONV./BACKUP RESTORE · USB POWER SUPPLY → OFF/COMM ON', style: KataType.monoStyle(size: 10, color: p.muted, height: 1.5))),
              ChecklistStep(n: 3, title: 'Power on', sub: Text('Kata reads your slots first — nothing is written until you review a diff.', style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.4))),
              const SizedBox(height: 10),
              KataCard(dashed: true, child: Text('Linux: needs the udev rule from docs/ops/kata-desktop.md once, then replug.', style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.5))),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- 1a slot board
class _Board extends ConsumerWidget {
  const _Board({required this.st});
  final CameraReady st;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    final svc = ref.read(cameraServiceProvider.notifier);
    final queue = ref.watch(writeQueueProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('CAMERA SLOTS', style: KataType.displayStyle(size: 20, color: p.fg)),
          const SizedBox(width: 14),
          Text('${st.caps.slotCount} SLOTS · ${st.caps.model.toUpperCase()} · FW ${st.caps.firmware}', style: KataType.monoStyle(size: 9.5, color: p.muted, letterSpacing: 0.14)),
          const Spacer(),
          KataPillButton(label: 'Read all ↻', kind: KataButtonKind.secondary, display: false, height: 34, expand: false, onPressed: st.busy ? null : svc.refreshSlots),
          const SizedBox(width: 8),
          KataPillButton(
            label: queue.isEmpty ? 'Nothing queued' : 'Write ${queue.length} change${queue.length == 1 ? '' : 's'}',
            height: 34,
            expand: false,
            display: false,
            onPressed: queue.isEmpty || st.busy ? null : () => showWriteReview(context, ref),
          ),
        ]),
        const SizedBox(height: 14),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 300, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.55),
            itemCount: st.caps.slotCount,
            itemBuilder: (_, i) => _SlotTile(slot: i + 1, preset: i < st.slots.length ? st.slots[i] : null, queued: queue[i + 1]),
          ),
        ),
        if (queue.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(children: [
              Text('PENDING', style: KataType.monoStyle(size: 9, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.18)),
              const SizedBox(width: 12),
              for (final e in queue.entries) ...[
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(border: Border.all(color: p.fg), borderRadius: BorderRadius.circular(13)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('C${e.key}', style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.fg)),
                    const SizedBox(width: 6),
                    Text(e.value.name.toUpperCase(), style: KataType.monoStyle(size: 9.5, color: p.dim)),
                  ]),
                ),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              KataPillButton(label: 'Clear queue', kind: KataButtonKind.secondary, display: false, height: 28, expand: false, onPressed: () => ref.read(writeQueueProvider.notifier).state = {}),
            ]),
          ),
      ]),
    );
  }
}

class _SlotTile extends ConsumerWidget {
  const _SlotTile({required this.slot, required this.preset, required this.queued});
  final int slot;
  final CameraPreset? preset;
  final Recipe? queued;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    final cur = preset;
    final filmName = cur == null ? null : (OfrEnums.codeToFilmSim[cur.filmSim] ?? 'Film ${cur.filmSim}');
    final empty = cur == null;
    return DragTarget<Recipe>(
      onAcceptWithDetails: (d) => ref.read(writeQueueProvider.notifier).update((q) => {...q, slot: d.data}),
      builder: (context, cand, _) {
        final hover = cand.isNotEmpty;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hover ? p.fg : (queued != null ? p.fg : p.hairline), width: hover || queued != null ? 1.5 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 34,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border.all(color: p.fg), borderRadius: BorderRadius.circular(6)),
                child: Text('C$slot', style: KataType.displayStyle(size: 11, color: p.fg, letterSpacing: 0)),
              ),
              const Spacer(),
              if (queued != null)
                Text('QUEUED', style: KataType.monoStyle(size: 8.5, weight: FontWeight.w500, color: p.fg, letterSpacing: 0.14))
              else if (hover)
                Text(empty ? 'DROP TO FILL' : 'DROP TO REPLACE', style: KataType.monoStyle(size: 8.5, weight: FontWeight.w500, color: p.fg, letterSpacing: 0.14)),
            ]),
            const Spacer(),
            if (queued != null) ...[
              Text(queued!.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 15, color: p.fg, letterSpacing: 0)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: Text('WAS ${empty ? 'EMPTY' : (cur.name.isEmpty ? filmName : cur.name)}'.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 9, color: p.muted))),
                InkWell(onTap: () => ref.read(writeQueueProvider.notifier).update((q) => {...q}..remove(slot)), child: Text('REVERT ↺', style: KataType.monoStyle(size: 9, weight: FontWeight.w500, color: p.dim))),
              ]),
            ] else if (empty) ...[
              Text('EMPTY', style: KataType.displayStyle(size: 15, color: p.muted, letterSpacing: 0)),
              const SizedBox(height: 4),
              Text('FACTORY DEFAULT · DROP TO FILL', style: KataType.monoStyle(size: 8.5, color: p.muted)),
            ] else ...[
              Text((cur.name.isEmpty ? filmName! : cur.name).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 15, color: p.fg, letterSpacing: 0)),
              const SizedBox(height: 4),
              Text('$filmName${cur.dynamicRange != null ? ' · ${cur.dynamicRange == kDrAuto ? 'DR AUTO' : 'DR${cur.dynamicRange}'}' : ''}'.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 9, color: p.dim)),
            ],
          ]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- 1b write review (field diff)
Future<void> showWriteReview(BuildContext context, WidgetRef ref) async {
  final st = ref.read(cameraServiceProvider);
  if (st is! CameraReady) return;
  final queue = Map<int, Recipe>.from(ref.read(writeQueueProvider));
  if (queue.isEmpty) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => Dialog(
      backgroundColor: c.kata.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.kata.hairline)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 640),
        child: _ReviewDialog(st: st, queue: queue),
      ),
    ),
  );
  if (ok != true) return;
  // write sequentially; the service refreshes each slot after write
  final svc = ref.read(cameraServiceProvider.notifier);
  for (final e in queue.entries) {
    final preset = OfrMapper.toPreset(e.value.ofr).value;
    await svc.writeRecipe(e.key, preset);
  }
  ref.read(writeQueueProvider.notifier).state = {};
}

class _ReviewDialog extends StatelessWidget {
  const _ReviewDialog({required this.st, required this.queue});
  final CameraReady st;
  final Map<int, Recipe> queue;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('REVIEW ${queue.length} WRITE${queue.length == 1 ? '' : 'S'}', style: KataType.displayStyle(size: 20, color: p.fg)),
          const SizedBox(height: 6),
          Text('Nothing is sent to the camera until you confirm. Slots not listed here are untouched.', style: KataType.bodyStyle(size: 12, color: p.muted, height: 1.4)),
        ]),
      ),
      const SizedBox(height: 12),
      Flexible(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          children: [for (final e in queue.entries) _slotDiff(p, e.key, e.value)],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Expanded(child: KataPillButton(label: 'Cancel', kind: KataButtonKind.secondary, display: false, height: 46, onPressed: () => Navigator.of(context).pop(false))),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: KataPillButton(label: 'Write ${queue.length == 1 ? 'the slot' : 'all ${queue.length} slots'}', height: 46, onPressed: () => Navigator.of(context).pop(true))),
        ]),
      ),
    ]);
  }

  Widget _slotDiff(KataPalette p, int slot, Recipe r) {
    final current = slot <= st.slots.length ? st.slots[slot - 1] : null;
    final curOfr = current == null ? null : OfrMapper.fromPreset(current);
    final next = r.ofr;
    final rows = <(String, String, String)>[];
    String show(dynamic v) => v == null ? '—' : (v is num && v > 0 ? '+$v' : '$v');
    void cmp(String label, dynamic a, dynamic b) {
      if ('$a' == '$b') return;
      rows.add((label, show(a), show(b)));
    }

    cmp('Film sim', curOfr?.filmSimulation, next.filmSimulation);
    cmp('Dynamic range', curOfr?.dynamicRange, next.dynamicRange);
    cmp('White balance', curOfr?.whiteBalance, next.whiteBalance);
    cmp('Kelvin', curOfr?.wbKelvin, next.wbKelvin);
    cmp('WB shift R', curOfr?.whiteBalanceRed, next.whiteBalanceRed);
    cmp('WB shift B', curOfr?.whiteBalanceBlue, next.whiteBalanceBlue);
    cmp('Highlight', curOfr?.highlight, next.highlight);
    cmp('Shadow', curOfr?.shadow, next.shadow);
    cmp('Color', curOfr?.color, next.color);
    cmp('Sharpness', curOfr?.sharpness, next.sharpness);
    cmp('High ISO NR', curOfr?.highIsoNr, next.highIsoNr);
    cmp('Clarity', curOfr?.clarity, next.clarity);
    cmp('Grain', '${curOfr?.grainRoughness}/${curOfr?.grainSize}', '${next.grainRoughness}/${next.grainSize}');
    cmp('CC effect', curOfr?.colorChromeEffect, next.colorChromeEffect);
    cmp('CC blue', curOfr?.colorChromeFxBlue, next.colorChromeFxBlue);
    final wasName = current == null ? 'EMPTY' : (current.name.isEmpty ? (OfrEnums.codeToFilmSim[current.filmSim] ?? 'SLOT') : current.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.fg, borderRadius: BorderRadius.circular(6)),
            child: Text('C$slot', style: KataType.displayStyle(size: 11, color: p.bg, letterSpacing: 0)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('${wasName.toUpperCase()} → ${r.name.toUpperCase()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 10.5, weight: FontWeight.w500, color: p.dim))),
          Text(current == null ? 'ALL FIELDS SET' : '${rows.length} FIELDS CHANGE', style: KataType.monoStyle(size: 9, color: p.muted, letterSpacing: 0.12)),
        ]),
        const SizedBox(height: 8),
        if (current != null && rows.isEmpty)
          Text('No differences — the slot already holds these settings.', style: KataType.bodyStyle(size: 11.5, color: p.muted))
        else if (current != null)
          Table(
            columnWidths: const {0: FlexColumnWidth(1.4), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
            children: [
              TableRow(children: [
                Text('FIELD', style: KataType.monoStyle(size: 8, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16)),
                Text('IN CAMERA', style: KataType.monoStyle(size: 8, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16)),
                Text('AFTER WRITE', style: KataType.monoStyle(size: 8, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16)),
              ]),
              for (final row in rows)
                TableRow(children: [
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(row.$1, style: KataType.bodyStyle(size: 11.5, color: p.dim))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(row.$2.toUpperCase(), style: KataType.monoStyle(size: 10.5, color: p.muted))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(row.$3.toUpperCase(), style: KataType.monoStyle(size: 10.5, color: p.fg))),
                ]),
            ],
          ),
      ]),
    );
  }
}
