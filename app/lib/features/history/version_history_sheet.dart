import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../../core/net/api_client.dart';
import '../../data/recipe.dart';
import '../../data/recipe_api.dart';
import '../../data/recipe_repository.dart';

/// Every kept snapshot of a published kata, what changed between it and the current
/// settings, and a one-tap roll back. Reverting writes a *new* version server-side, so
/// nothing is ever destroyed — you can revert the revert.
Future<void> showVersionHistory(BuildContext context, Recipe recipe) =>
    showKataSheet<void>(context, builder: (_) => _VersionHistory(recipe: recipe));

/// Desktop presents the same content in a dialog.
Future<void> showVersionHistoryDialog(BuildContext context, Recipe recipe) => showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: c.kata.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: c.kata.hairline)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
          child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: _VersionHistory(recipe: recipe)),
        ),
      ),
    );

class _VersionHistory extends ConsumerStatefulWidget {
  const _VersionHistory({required this.recipe});
  final Recipe recipe;
  @override
  ConsumerState<_VersionHistory> createState() => _VersionHistoryState();
}

class _VersionHistoryState extends ConsumerState<_VersionHistory> {
  RecipeHistory? _history;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final h = await ref.read(recipeRepositoryProvider).versions(widget.recipe.id);
      if (mounted) setState(() => _history = h);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.isNetwork ? 'No connection' : e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _revert(RecipeVersion v) async {
    final ok = await showKataDialog(context,
        title: 'Roll back to v${v.version}?',
        body: 'Kata saves this as a new version, so the current settings stay in the history. Published katas go back into the review queue.',
        confirmLabel: 'Roll back');
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(recipeRepositoryProvider).revert(widget.recipe.id, v.version);
      if (!mounted) return;
      Navigator.of(context).pop();
      KataToast.show(context, 'Rolled back to v${v.version}');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        KataToast.show(context, e.isNetwork ? 'No connection — nothing changed' : e.message);
      }
    }
  }

  /// Fields that differ between a snapshot and what the recipe holds now.
  List<String> _diff(OfrRecipe old) {
    final now = widget.recipe.ofr;
    final out = <String>[];
    void cmp(String label, dynamic a, dynamic b) {
      if ('$a' != '$b') out.add(label);
    }

    cmp('film sim', old.filmSimulation, now.filmSimulation);
    cmp('DR', old.dynamicRange, now.dynamicRange);
    cmp('WB', '${old.whiteBalance}/${old.wbKelvin}/${old.whiteBalanceRed}/${old.whiteBalanceBlue}',
        '${now.whiteBalance}/${now.wbKelvin}/${now.whiteBalanceRed}/${now.whiteBalanceBlue}');
    cmp('highlight', old.highlight, now.highlight);
    cmp('shadow', old.shadow, now.shadow);
    cmp('color', old.color, now.color);
    cmp('sharpness', old.sharpness, now.sharpness);
    cmp('NR', old.highIsoNr, now.highIsoNr);
    cmp('clarity', old.clarity, now.clarity);
    cmp('grain', '${old.grainRoughness}/${old.grainSize}', '${now.grainRoughness}/${now.grainSize}');
    cmp('colour chrome', '${old.colorChromeEffect}/${old.colorChromeFxBlue}', '${now.colorChromeEffect}/${now.colorChromeFxBlue}');
    cmp('name', old.name, now.name);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final h = _history;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('VERSION HISTORY', style: KataType.displayStyle(size: 20, color: p.fg)),
      const SizedBox(height: 6),
      Text('Kata keeps the last ten versions of a published kata. Rolling back never destroys anything.',
          style: KataType.bodyStyle(size: 12, color: p.muted, height: 1.4)),
      const SizedBox(height: 16),
      if (_error != null)
        IssueCard(title: "COULDN'T LOAD HISTORY", rows: [IssueRow('server', _error!)])
      else if (h == null)
        Padding(padding: const EdgeInsets.symmetric(vertical: 26), child: Center(child: KataDotsLoader(dot: 5, color: p.fg)))
      else ...[
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: p.fg, borderRadius: BorderRadius.circular(5)),
            child: Text('V${h.current}', style: KataType.displayStyle(size: 10, color: p.bg, letterSpacing: 0)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${widget.recipe.name.toUpperCase()} · NOW',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 10, weight: FontWeight.w500, color: p.dim)),
          ),
        ]),
        if (h.items.isEmpty) ...[
          const SizedBox(height: 12),
          KataCard(dashed: true, child: Text('No earlier versions yet — this kata has never been edited.', style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.5))),
        ],
        for (final v in h.items) ...[
          const SizedBox(height: 10),
          Divider(height: 1, color: p.hairline),
          const SizedBox(height: 10),
          _row(p, v),
        ],
      ],
      const SizedBox(height: 18),
    ]);
  }

  Widget _row(KataPalette p, RecipeVersion v) {
    final changed = _diff(v.ofr);
    final d = v.createdAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('V${v.version}', style: KataType.displayStyle(size: 12, color: p.fg, letterSpacing: 0)),
            const SizedBox(width: 8),
            Text('${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}',
                style: KataType.monoStyle(size: 9, color: p.muted, letterSpacing: 0.1)),
          ]),
          const SizedBox(height: 3),
          Text(changed.isEmpty ? 'IDENTICAL TO NOW' : 'DIFFERS IN ${changed.join(', ').toUpperCase()}',
              maxLines: 2, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 8.5, color: p.dim, height: 1.4)),
        ]),
      ),
      const SizedBox(width: 10),
      KataPillButton(
        label: 'Roll back',
        kind: KataButtonKind.secondary,
        display: false,
        height: 30,
        expand: false,
        onPressed: _busy || changed.isEmpty ? null : () => _revert(v),
      ),
    ]);
  }
}
