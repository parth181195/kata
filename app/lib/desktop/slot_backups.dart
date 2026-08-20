import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';
import 'package:path_provider/path_provider.dart';

import '../core/fuji/camera_service.dart';
import '../data/recipe.dart';
import 'desktop_camera.dart';

/// A snapshot of every occupied custom slot, stored as OFR JSON so restores go through the
/// exact same mapper + review-diff path as any other write. Kata takes one automatically
/// before every write; users can take and restore them manually.
class SlotBackup {
  const SlotBackup({required this.id, required this.model, required this.firmware, required this.takenAt, required this.auto, required this.slots});
  final String id;
  final String model;
  final String firmware;
  final DateTime takenAt;
  final bool auto;
  final Map<int, OfrRecipe> slots; // occupied slots only

  String get signature => (slots.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map((e) => '${e.key}:${OfrHasher.compute(e.value)}').join('|');

  Map<String, dynamic> toJson() => {
        'id': id,
        'model': model,
        'firmware': firmware,
        'takenAt': takenAt.toIso8601String(),
        'auto': auto,
        'slots': slots.map((k, v) => MapEntry('$k', v.toJson())),
      };

  static SlotBackup fromJson(Map<String, dynamic> j) => SlotBackup(
        id: j['id'] as String,
        model: j['model'] as String? ?? '?',
        firmware: j['firmware'] as String? ?? '',
        takenAt: DateTime.tryParse(j['takenAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        auto: j['auto'] == true,
        slots: (j['slots'] as Map<String, dynamic>).map((k, v) => MapEntry(int.parse(k), OfrRecipe.fromJson(v as Map<String, dynamic>))),
      );
}

final slotBackupsProvider = StateNotifierProvider<SlotBackupStore, List<SlotBackup>>((_) => SlotBackupStore());

class SlotBackupStore extends StateNotifier<List<SlotBackup>> {
  SlotBackupStore() : super(const []) {
    _load();
  }
  static const _keep = 20;

  Future<File> _file() async => File('${(await getApplicationSupportDirectory()).path}/slot_backups.json');

  Future<void> _load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final list = (jsonDecode(await f.readAsString()) as List).cast<Map<String, dynamic>>();
      state = list.map(SlotBackup.fromJson).toList();
    } catch (_) {/* corrupt file → start fresh */}
  }

  Future<void> _save() async {
    final f = await _file();
    await f.writeAsString(jsonEncode(state.map((b) => b.toJson()).toList()));
  }

  /// Snapshot the occupied slots. Returns null when there is nothing to back up or when the
  /// newest backup already has identical contents (no duplicate spam).
  Future<SlotBackup?> takeBackup(CameraReady st, {required bool auto}) async {
    final sensors = OfrMapper.sensorsForModel(st.caps.model);
    final slots = <int, OfrRecipe>{};
    for (var i = 0; i < st.slots.length; i++) {
      final preset = st.slots[i];
      var ofr = OfrMapper.fromPreset(preset, sensors: sensors);
      if (ofr.name == null || ofr.name!.isEmpty) ofr = ofr.copyWith(name: preset.name.isEmpty ? ofr.filmSimulation : preset.name);
      slots[i + 1] = ofr;
    }
    if (slots.isEmpty) return null;
    final b = SlotBackup(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36), model: st.caps.model, firmware: st.caps.firmware, takenAt: DateTime.now(), auto: auto, slots: slots);
    if (state.isNotEmpty && state.first.signature == b.signature && state.first.model == b.model) return null;
    state = [b, ...state].take(_keep).toList();
    await _save();
    return b;
  }

  Future<void> delete(String id) async {
    state = state.where((b) => b.id != id).toList();
    await _save();
  }
}

/// Queue a backup's slots for writing (skipping slots the camera already matches) and open the
/// standard review diff. Never writes without confirmation.
Future<void> restoreBackup(BuildContext context, WidgetRef ref, SlotBackup b) async {
  final st = ref.read(cameraServiceProvider);
  if (st is! CameraReady) {
    KataToast.show(context, 'Connect a camera to restore');
    return;
  }
  final queue = <int, Recipe>{};
  for (final e in b.slots.entries) {
    if (e.key > st.caps.slotCount) continue;
    final cur = e.key <= st.slots.length ? st.slots[e.key - 1] : null;
    if (cur != null && OfrHasher.compute(OfrMapper.fromPreset(cur, sensors: OfrMapper.sensorsForModel(st.caps.model))) == OfrHasher.compute(e.value)) continue;
    queue[e.key] = Recipe(id: 'backup:${b.id}:${e.key}', ofr: e.value, source: RecipeSource.camera);
  }
  if (queue.isEmpty) {
    KataToast.show(context, 'Camera already matches this backup');
    return;
  }
  ref.read(writeQueueProvider.notifier).state = queue;
  await showWriteReview(context, ref);
}

// ---------------------------------------------------------------- dialog
Future<void> showSlotBackupsDialog(BuildContext context, WidgetRef ref) => showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: c.kata.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.kata.hairline)),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560), child: const _BackupsDialog()),
      ),
    );

class _BackupsDialog extends ConsumerWidget {
  const _BackupsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    final backups = ref.watch(slotBackupsProvider);
    final st = ref.watch(cameraServiceProvider);
    final connected = st is CameraReady;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SLOT BACKUPS', style: KataType.displayStyle(size: 20, color: p.fg)),
          const SizedBox(height: 6),
          Text('Snapshots of what was in the camera. Kata takes one automatically before every write. Restoring opens the same review diff — empty slots are left alone.', style: KataType.bodyStyle(size: 12, color: p.muted, height: 1.4)),
        ]),
      ),
      const SizedBox(height: 14),
      Flexible(
        child: backups.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
                child: KataCard(dashed: true, child: Text('No backups yet. Connect a camera and press Back up — or just write something; Kata snapshots the slots first.', style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.5))),
              )
            : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: backups.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: p.hairline),
                itemBuilder: (_, i) => _row(context, ref, p, backups[i], connected),
              ),
      ),
      const SizedBox(height: 18),
    ]);
  }

  Widget _row(BuildContext context, WidgetRef ref, KataPalette p, SlotBackup b, bool connected) {
    final d = b.takenAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final when = '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
    final names = (b.slots.entries.toList()..sort((a, x) => a.key.compareTo(x.key))).map((e) => 'C${e.key} ${(e.value.name ?? '').toUpperCase()}').join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(when, style: KataType.monoStyle(size: 10.5, weight: FontWeight.w500, color: p.fg)),
              const SizedBox(width: 8),
              Text('${b.model.toUpperCase()} · ${b.slots.length} KATA${b.slots.length == 1 ? '' : 'S'}${b.auto ? ' · AUTO' : ''}', style: KataType.monoStyle(size: 9, color: p.muted, letterSpacing: 0.12)),
            ]),
            const SizedBox(height: 4),
            Text(names, maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 8.5, color: p.dim)),
          ]),
        ),
        const SizedBox(width: 10),
        KataPillButton(
          label: 'Restore',
          kind: KataButtonKind.secondary,
          display: false,
          height: 30,
          expand: false,
          onPressed: !connected
              ? null
              : () async {
                  Navigator.of(context).pop();
                  await restoreBackup(context, ref, b);
                },
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: () => ref.read(slotBackupsProvider.notifier).delete(b.id),
          icon: Icon(Icons.close, size: 14, color: p.muted),
          tooltip: 'Delete backup',
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}
