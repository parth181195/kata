import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../core/fuji/camera_service.dart';
import '../../core/fuji/slot_identity.dart';
import '../../data/recipe_repository.dart';
import '../../data/recipe.dart';

/// Write a recipe into a slot: choose → writing → done / failed.
class WriteSheet extends ConsumerStatefulWidget {
  const WriteSheet({super.key, required this.recipe});
  final Recipe recipe;
  @override
  ConsumerState<WriteSheet> createState() => _WriteSheetState();
}

enum _Phase { choose, writing, done, failed }

class _WriteSheetState extends ConsumerState<WriteSheet> with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.choose;
  int? _slot;
  WriteResult? _result;
  List<String> _notes = const [];
  String? _error;
  late final AnimationController _progress = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _write(CameraReady st) async {
    final slot = _slot!;
    final m = OfrMapper.toPreset(widget.recipe.ofr);
    _notes = m.notes;
    setState(() => _phase = _Phase.writing);
    _progress.forward(from: 0);
    try {
      final r = await ref.read(cameraServiceProvider.notifier).writeRecipe(slot, m.value);
      // remember what landed where, so this slot reads back as this kata (and shows up as
      // "edited on camera" if it's tweaked on the body later)
      final after = ref.read(cameraServiceProvider);
      if (after is CameraReady && slot <= after.slots.length) {
        // fire and forget: the link is in memory immediately; persisting it must never
        // delay (or fail) a write that already reached the camera
        unawaited(ref
            .read(slotLinksProvider.notifier)
            .record(after.caps.model, slot, widget.recipe.id, slotSettingsHash(after.caps.model, after.slots[slot - 1])));
      }
      _progress.value = 1;
      if (mounted) setState(() { _result = r; _phase = _Phase.done; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _phase = _Phase.failed; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(cameraServiceProvider);
    if (st is! CameraReady && _phase == _Phase.choose) {
      return KataSheet(eyebrow: 'Writing', title: widget.recipe.name, children: [
        IssueCard(title: 'Camera not connected', rows: const [IssueRow('Connect on the Camera tab first.', '')]),
        const SizedBox(height: 12),
        KataPillButton(label: 'Close', kind: KataButtonKind.secondary, display: false, height: 50, onPressed: () => Navigator.of(context).pop()),
      ]);
    }
    return switch (_phase) {
      _Phase.choose => _choose(context, st as CameraReady),
      _Phase.writing => _writing(context),
      _Phase.done => _done(context),
      _Phase.failed => _failed(context),
    };
  }

  // ------------------------------------------------------------ choose

  Widget _choose(BuildContext context, CameraReady st) {
    final p = context.kata;
    final lib = ref.read(recipeRepositoryProvider);
    final sel = _slot;
    final target = sel == null ? null : st.slots[sel - 1];
    final targetName = target == null ? '' : (target.name.isEmpty ? (FilmSim.labels[target.filmSim] ?? '') : target.name);
    return KataSheet(eyebrow: 'Writing', title: widget.recipe.name, children: [
      const EyebrowDivider('Choose slot'),
      const SizedBox(height: 14),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 120),
        itemCount: st.slots.length,
        itemBuilder: (_, i) {
          final s = st.slots[i];
          final holds = s.name.isEmpty ? (FilmSim.labels[s.filmSim] ?? '') : s.name;
          return SlotCard(slot: i + 1, state: SlotCardState.filled, selected: sel == i + 1, title: holds, line1: 'HOLDS', line2: holds, onTap: () => setState(() => _slot = i + 1));
        },
      ),
      if (sel != null) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: p.red)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(shape: BoxShape.circle, color: p.red)),
            const SizedBox(width: 11),
            Expanded(
              child: Text.rich(TextSpan(
                style: KataType.bodyStyle(size: 11.5, color: p.dim, height: 1.5),
                children: [
                  TextSpan(text: 'C$sel will be overwritten. Save what\'s in it first? '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () async {
                        final ofr = OfrMapper.fromPreset(target!, sensors: OfrMapper.sensorsForModel(st.caps.model), sourceAttribution: 'Read from ${st.caps.model}');
                        await lib.addImported(ofr.name == null ? ofr.copyWith(name: '$targetName C$sel') : ofr, source: RecipeSource.camera);
                        if (context.mounted) KataToast.show(context, 'Saved to Mine');
                      },
                      child: Text('Save as kata', style: KataType.bodyStyle(size: 11.5, color: p.fg, height: 1.5).copyWith(decoration: TextDecoration.underline, decorationColor: p.fg)),
                    ),
                  ),
                ],
              )),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      KataPillButton(
        label: sel == null ? 'Choose a slot' : 'Write to C$sel',
        leading: Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: sel == null ? p.muted : p.bg, width: 2))),
        onPressed: sel == null || st.busy ? null : () => _write(st),
      ),
    ]);
  }

  // ------------------------------------------------------------ writing

  Widget _writing(BuildContext context) {
    final p = context.kata;
    return Container(
      color: p.bg,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: AnimatedBuilder(
        animation: _progress,
        builder: (_, _) {
          final total = 22;
          final done = (_progress.value * total).round();
          return Column(mainAxisSize: MainAxisSize.min, children: [
            DotMatrixProgress(progress: _progress.value, animated: true),
            const SizedBox(height: 34),
            Text('WRITING $done/$total', style: KataType.displayStyle(size: 26, color: p.fg, letterSpacing: 0)),
            const SizedBox(height: 10),
            Text('SETTINGS → C$_slot · KEEP THE CABLE IN', style: KataType.monoStyle(size: 12, color: p.muted, height: 1.5)),
            const SizedBox(height: 34),
            Container(height: 2, color: p.surface, child: Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: _progress.value, child: Container(color: p.fg)))),
            const SizedBox(height: 34),
            Text('Cancel', style: KataType.bodyStyle(size: 11, color: p.muted.withValues(alpha: 0.5), height: 1).copyWith(decoration: TextDecoration.underline, decorationColor: p.muted.withValues(alpha: 0.5))),
          ]);
        },
      ),
    );
  }

  // ------------------------------------------------------------ done / failed

  Widget _done(BuildContext context) {
    final p = context.kata;
    final r = _result!;
    final total = r.written.length + r.skipped.length;
    final skippedRows = [for (final w in r.warnings) IssueRow(w.split(':').first, w.contains(':') ? w.substring(w.indexOf(':') + 1).trim() : '')];
    return Container(
      color: p.bg,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 22),
          child: Column(children: [
            Container(width: 96, height: 96, decoration: BoxDecoration(shape: BoxShape.circle, color: r.ok ? p.fg : p.surface), alignment: Alignment.center,
                child: Text(r.ok ? '✓' : '!', style: TextStyle(fontFamily: KataType.body, fontSize: 34, fontWeight: FontWeight.w600, color: r.ok ? p.bg : p.fg, height: 1))),
            const SizedBox(height: 22),
            Text((r.ok ? 'WRITTEN TO C${r.slot}' : 'WRITTEN WITH ISSUES'), style: KataType.displayStyle(size: 26, color: p.fg, letterSpacing: 0)),
            const SizedBox(height: 8),
            Text('${widget.recipe.name} · ${r.written.length} of $total settings', style: KataType.bodyStyle(size: 12.5, color: p.muted, height: 1.55)),
          ]),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hairline)), borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KataBanner(child: Text.rich(TextSpan(children: [
              const TextSpan(text: 'Turn the mode dial off '),
              TextSpan(text: 'C${r.slot}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const TextSpan(text: " and back to load it. The camera won't show the change until you do."),
            ]))),
            if (skippedRows.isNotEmpty) ...[const SizedBox(height: 14), IssueCard(title: '${skippedRows.length} SETTING${skippedRows.length == 1 ? '' : 'S'} SKIPPED', rows: skippedRows)],
            if (_notes.isNotEmpty) ...[const SizedBox(height: 14), IssueCard(title: '${_notes.length} NOTE${_notes.length == 1 ? '' : 'S'}', rows: [for (final n in _notes) IssueRow(n, '')])],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: KataPillButton(label: 'Write another', kind: KataButtonKind.secondary, display: false, height: 52, onPressed: () => setState(() { _phase = _Phase.choose; _slot = null; _result = null; }))),
              const SizedBox(width: 10),
              Expanded(child: KataPillButton(label: 'Done', height: 52, onPressed: () => Navigator.of(context).pop(true))),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _failed(BuildContext context) => KataSheet(eyebrow: 'Writing', title: widget.recipe.name, children: [
        IssueCard(title: 'Write failed', rows: [IssueRow(_error ?? 'Unknown error', 'Nothing was written')]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: KataPillButton(label: 'Close', kind: KataButtonKind.secondary, display: false, height: 52, onPressed: () => Navigator.of(context).pop(false))),
          const SizedBox(width: 10),
          Expanded(child: KataPillButton(label: 'Retry', height: 52, onPressed: () => setState(() { _phase = _Phase.choose; _error = null; }))),
        ]),
      ]);
}

Future<bool?> showWriteSheet(BuildContext context, Recipe recipe) =>
    showKataSheet<bool>(context, dismissible: true, builder: (_) => WriteSheet(recipe: recipe));
