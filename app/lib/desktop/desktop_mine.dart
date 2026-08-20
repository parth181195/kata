import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:kata_ui/kata_ui.dart';

import '../core/fuji/camera_service.dart';
import '../data/recipe.dart';
import '../data/recipe_repository.dart';
import '../data/recipe_specs.dart';
import '../features/history/version_history_sheet.dart';
import 'desktop_camera.dart';
import 'desktop_import.dart';
import 'desktop_shell.dart';
import '../core/fuji/slot_identity.dart';

enum _Tab { all, published, drafts, inSlots }

/// Design 1h: my katas as a table — state, version, which slot holds them, and bulk
/// export / write straight from the rows.
class DesktopMine extends ConsumerStatefulWidget {
  const DesktopMine({super.key});
  @override
  ConsumerState<DesktopMine> createState() => _DesktopMineState();
}

class _DesktopMineState extends ConsumerState<DesktopMine> {
  final _selected = <String>{};
  _Tab _tab = _Tab.all;

  /// recipeId → slot number, for whatever is in the camera right now.
  Map<String, int> _inSlots(WidgetRef ref) {
    final st = ref.watch(cameraServiceProvider);
    if (st is! CameraReady) return const {};
    final out = <String, int>{};
    for (var i = 0; i < st.slots.length; i++) {
      final id = identifySlot(ref, st.caps.model, i + 1, st.slots[i]);
      final r = id.recipe ?? id.origin;
      if (r != null) out[r.id] = i + 1;
    }
    return out;
  }

  Future<void> _exportSelection(List<Recipe> rows) async {
    final picked = rows.where((r) => _selected.contains(r.id)).toList();
    final all = picked.isEmpty ? rows : picked;
    if (all.isEmpty) return;
    final body = const JsonEncoder.withIndent('  ').convert({
      'v': 1,
      'exported': DateTime.now().toIso8601String(),
      'recipes': [for (final r in all) r.ofr.toJson()],
    });
    final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export ${all.length} kata${all.length == 1 ? '' : 's'}', fileName: 'kata-export.ofr.json', bytes: utf8.encode(body));
    if (path == null) return;
    final f = File(path);
    if (!await f.exists() || (await f.length()) == 0) await f.writeAsString(body);
    if (mounted) KataToast.show(context, 'Exported ${all.length} katas');
  }

  /// Queue the selection onto free slots (or the ones they already occupy) and review.
  Future<void> _writeSelection(List<Recipe> rows, CameraReady st, Map<String, int> inSlots) async {
    final picked = rows.where((r) => _selected.contains(r.id)).toList();
    if (picked.isEmpty) return;
    final queue = Map<int, Recipe>.from(ref.read(writeQueueProvider));
    final taken = {...queue.keys, ...inSlots.values};
    for (final r in picked) {
      final existing = inSlots[r.id];
      if (existing != null) {
        queue[existing] = r; // rewrite where it already lives
        continue;
      }
      final free = List.generate(st.caps.slotCount, (i) => i + 1).where((s) => !taken.contains(s)).firstOrNull;
      if (free == null) {
        if (mounted) KataToast.show(context, 'Only ${st.caps.slotCount} slots — queued what fits');
        break;
      }
      taken.add(free);
      queue[free] = r;
    }
    ref.read(writeQueueProvider.notifier).state = queue;
    if (mounted) await showWriteReview(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final repo = ref.watch(recipeRepositoryProvider);
    final cam = ref.watch(cameraServiceProvider);
    final ready = cam is CameraReady ? cam : null;
    final inSlots = _inSlots(ref);
    final all = repo.mine;
    final rows = switch (_tab) {
      _Tab.all => all,
      _Tab.published => all.where((r) => !r.isDraft).toList(),
      _Tab.drafts => all.where((r) => r.isDraft).toList(),
      _Tab.inSlots => all.where((r) => inSlots.containsKey(r.id)).toList(),
    };
    _selected.removeWhere((id) => !all.any((r) => r.id == id));

    return Column(children: [
      // ---- header: tabs + actions
      Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hairline))),
        child: Row(children: [
          Text('MINE · ${all.length} KATA${all.length == 1 ? '' : 'S'}', style: KataType.displayStyle(size: 18, color: p.fg)),
          const SizedBox(width: 16),
          // narrow windows scroll the tabs rather than overflowing the header
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final (tab, label, n) in [
                  (_Tab.all, 'All', all.length),
                  (_Tab.published, 'Published', all.where((r) => !r.isDraft).length),
                  (_Tab.drafts, 'Drafts', all.where((r) => r.isDraft).length),
                  (_Tab.inSlots, 'In slots', inSlots.length),
                ]) ...[
                  KataChip(label: '$label $n', selected: _tab == tab, onTap: () => setState(() => _tab = tab)),
                  const SizedBox(width: 7),
                ],
              ]),
            ),
          ),
          const SizedBox(width: 8),
          KataPillButton(label: 'Import', kind: KataButtonKind.secondary, display: false, height: 32, expand: false, onPressed: () => showImportDialog(context)),
          const SizedBox(width: 8),
          if (ready != null) ...[
            KataPillButton(
              label: 'Read from camera',
              kind: KataButtonKind.secondary,
              display: false,
              height: 32,
              expand: false,
              onPressed: () async {
                final slot = await showKataMenu<int>(context,
                    title: 'Read which slot?', items: [for (var i = 1; i <= ready.caps.slotCount; i++) KataMenuItem(i, 'C$i', icon: Icons.download)]);
                if (slot == null || !context.mounted) return;
                final ofr = OfrMapper.fromPreset(ready.slots[slot - 1], sensors: OfrMapper.sensorsForModel(ready.caps.model));
                DesktopShell.of(context)?.openEditorWith(ofr);
              },
            ),
            const SizedBox(width: 8),
          ],
          KataPillButton(label: 'New kata', height: 32, expand: false, onPressed: () => DesktopShell.of(context)?.openEditor()),
        ]),
      ),
      // ---- column heads
      Container(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hairline))),
        child: Row(children: [
          SizedBox(
            width: 34,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _Check(
                on: rows.isNotEmpty && rows.every((r) => _selected.contains(r.id)),
                onTap: () => setState(() {
                  final allOn = rows.every((r) => _selected.contains(r.id));
                  for (final r in rows) {
                    allOn ? _selected.remove(r.id) : _selected.add(r.id);
                  }
                }),
              ),
            ),
          ),
          _head(p, 'KATA', flex: 4),
          _head(p, 'SETTINGS', flex: 4),
          _head(p, 'SENSOR', flex: 2),
          _head(p, 'STATE', flex: 2),
          _head(p, 'IN SLOT', flex: 1),
          const SizedBox(width: 200), // actions column
        ]),
      ),
      Expanded(
        child: rows.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(
                    switch (_tab) {
                      _Tab.drafts => 'No drafts — anything you save without publishing lands here.',
                      _Tab.published => "Nothing published yet. Publish a kata and it shows up here with its version history.",
                      _Tab.inSlots => ready == null ? 'Connect a camera to see which of your katas are loaded.' : 'None of your katas are in the camera right now.',
                      _Tab.all => 'No katas yet. Start one with New kata, or import a card.',
                    },
                    textAlign: TextAlign.center,
                    style: KataType.bodyStyle(size: 12.5, color: p.muted, height: 1.5),
                  ),
                ),
              )
            : ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: p.hairline),
                itemBuilder: (_, i) => _row(p, rows[i], inSlots[rows[i].id], ready),
              ),
      ),
      // ---- selection bar
      Container(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
        child: Row(children: [
          Text(
            '${_selected.isEmpty ? 'NONE' : '${_selected.length}'} SELECTED · ${rows.length} OF ${all.length} SHOWN',
            style: KataType.monoStyle(size: 9, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16),
          ),
          const Spacer(),
          KataPillButton(
            label: _selected.isEmpty ? 'Export all shown' : 'Export selection',
            kind: KataButtonKind.secondary,
            display: false,
            height: 34,
            expand: false,
            onPressed: rows.isEmpty ? null : () => _exportSelection(rows),
          ),
          const SizedBox(width: 8),
          KataPillButton(
            label: 'Write selection',
            height: 34,
            expand: false,
            onPressed: (_selected.isEmpty || ready == null) ? null : () => _writeSelection(rows, ready, inSlots),
          ),
        ]),
      ),
    ]);
  }

  Widget _head(KataPalette p, String label, {required int flex}) =>
      Expanded(flex: flex, child: Text(label, style: KataType.monoStyle(size: 8.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.18)));

  Widget _row(KataPalette p, Recipe r, int? slot, CameraReady? ready) {
    final on = _selected.contains(r.id);
    final ofr = r.ofr;
    return Material(
      color: on ? p.surface : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => on ? _selected.remove(r.id) : _selected.add(r.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
          child: Row(children: [
            SizedBox(
              width: 34,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Check(on: on, onTap: () => setState(() => on ? _selected.remove(r.id) : _selected.add(r.id))),
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 13, color: p.fg, letterSpacing: 0)),
                const SizedBox(height: 2),
                Text(
                  r.isDraft ? 'LOCAL DRAFT' : (r.hidden ? 'HIDDEN BY A CURATOR' : (r.verified ? 'VERIFIED' : 'IN REVIEW')),
                  style: KataType.monoStyle(size: 8, color: p.muted, letterSpacing: 0.12),
                ),
              ]),
            ),
            Expanded(
              flex: 4,
              child: Text('${ofr.filmSimulation} · ${RecipeSpecs.dr(ofr)}'.toUpperCase(),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 9, color: p.dim)),
            ),
            Expanded(
              flex: 2,
              child: Text(ofr.sensors.isEmpty ? '—' : ofr.sensors.first.toUpperCase(),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 9, color: p.dim)),
            ),
            Expanded(
              flex: 2,
              child: Text(
                r.isDraft ? 'DRAFT' : (r.hidden ? 'HIDDEN' : 'PUBLISHED'),
                style: KataType.monoStyle(size: 9, weight: FontWeight.w500, color: r.isDraft || r.hidden ? p.dim : p.fg, letterSpacing: 0.12),
              ),
            ),
            Expanded(
              flex: 1,
              child: slot == null
                  ? Text('—', style: KataType.monoStyle(size: 9, color: p.muted))
                  : Container(
                      width: 26,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border.all(color: p.fg), borderRadius: BorderRadius.circular(5)),
                      child: Text('C$slot', style: KataType.monoStyle(size: 8.5, weight: FontWeight.w600, color: p.fg)),
                    ),
            ),
            SizedBox(
              width: 200,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (!r.isDraft)
                  _link(p, 'History', () => showVersionHistoryDialog(context, r)),
                _link(p, 'Edit', () => DesktopShell.of(context)?.openEditor(id: r.id)),
                if (ready != null)
                  _link(p, slot == null ? 'Write' : 'Rewrite', () async {
                    final target = slot ??
                        await showKataMenu<int>(context,
                            title: 'Write to which slot?',
                            items: [for (var i = 1; i <= ready.caps.slotCount; i++) KataMenuItem(i, 'C$i', icon: Icons.save_alt)]);
                    if (target == null || !mounted) return;
                    ref.read(writeQueueProvider.notifier).update((q) => {...q, target: r});
                    if (mounted) await showWriteReview(context, ref);
                  }),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _link(KataPalette p, String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(left: 10),
        child: InkWell(
          onTap: onTap,
          child: Text(label.toUpperCase(), style: KataType.monoStyle(size: 8.5, weight: FontWeight.w500, color: p.dim, letterSpacing: 0.14)),
        ),
      );
}

class _Check extends StatelessWidget {
  const _Check({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      // the ink must not spill into the name column beside it
      customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
      child: Container(
        width: 17,
        height: 17,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: on ? p.fg : p.hairline, width: on ? 1.5 : 1),
          color: on ? p.fg : Colors.transparent,
        ),
        child: on ? Center(child: Text('✓', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: p.bg, height: 1))) : null,
      ),
    );
  }
}
