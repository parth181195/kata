import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/fuji/camera_service.dart';
import '../../data/recipe.dart';
import '../../data/recipe_repository.dart';
import '../../data/recipe_specs.dart';
import '../../core/fuji/slot_identity.dart';

/// Take what is *actually* in a camera slot right now and turn it into a kata: save it
/// locally, publish it as a new recipe, or — when the slot drifted from something you
/// published — push the camera's version as the next version of that recipe.
///
/// This is the "I refined it while shooting" path: write → shoot → tweak on the body →
/// come back and keep the better version.
Future<void> showPublishFromCamera(BuildContext context, WidgetRef ref, {required int slot}) async {
  final st = ref.read(cameraServiceProvider);
  if (st is! CameraReady || slot > st.slots.length) return;
  final ident = identifySlot(ref, st.caps.model, slot, st.slots[slot - 1]);
  final body = _PublishDialog(slot: slot, model: st.caps.model, preset: st.slots[slot - 1], identity: ident);
  // The sheet pops with the message to show: a toast raised from a route that is being
  // dismissed never reaches the screen, so the caller (still mounted) shows it.
  // showKataSheet is a bottom sheet on a phone and a centred panel on desktop
  final done = await showKataSheet<String>(context, builder: (_) => body);
  if (!context.mounted || done == null) return;
  KataToast.show(context, done);
}

class _PublishDialog extends ConsumerStatefulWidget {
  const _PublishDialog({required this.slot, required this.model, required this.preset, required this.identity});
  final int slot;
  final String model;
  final CameraPreset preset;
  final SlotIdentity identity;
  @override
  ConsumerState<_PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends ConsumerState<_PublishDialog> {
  late final OfrRecipe _fromCamera = OfrMapper.fromPreset(
    widget.preset,
    sensors: OfrMapper.sensorsForModel(widget.model),
    sourceAttribution: 'Refined on ${widget.model}',
  );
  late final TextEditingController _name = TextEditingController(text: _initialName);
  bool _busy = false;
  String? _error;

  Recipe? get _origin => widget.identity.origin;

  String get _initialName {
    final o = _origin;
    if (o != null) return _bump(o.name);
    if (widget.preset.name.isNotEmpty) return widget.preset.name;
    return '${OfrEnums.codeToFilmSim[widget.preset.filmSim] ?? 'Kata'} C${widget.slot}';
  }

  /// "Beach Chrome" -> "Beach Chrome v2" -> "Beach Chrome v3"
  static String _bump(String name) {
    final m = RegExp(r'^(.*?)\s+v(\d+)$').firstMatch(name);
    return m == null ? '$name v2' : '${m.group(1)} v${int.parse(m.group(2)!) + 1}';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  OfrRecipe get _recipe => _fromCamera.copyWith(name: _name.text.trim(), clearHash: true);

  /// Field-level changes the camera made to the recipe we wrote.
  List<(String, String, String)> get _changes {
    final o = _origin?.ofr;
    if (o == null) return const [];
    final rows = <(String, String, String)>[];
    String show(dynamic v) => v == null ? '—' : (v is num && v > 0 ? '+$v' : '$v');
    void cmp(String label, dynamic a, dynamic b) {
      if ('$a' == '$b') return;
      rows.add((label, show(a), show(b)));
    }

    final n = _fromCamera;
    cmp('Film sim', o.filmSimulation, n.filmSimulation);
    cmp('Dynamic range', o.dynamicRange, n.dynamicRange);
    cmp('White balance', o.whiteBalance, n.whiteBalance);
    cmp('Kelvin', o.wbKelvin, n.wbKelvin);
    cmp('WB shift R', o.whiteBalanceRed, n.whiteBalanceRed);
    cmp('WB shift B', o.whiteBalanceBlue, n.whiteBalanceBlue);
    cmp('Highlight', o.highlight, n.highlight);
    cmp('Shadow', o.shadow, n.shadow);
    cmp('Color', o.color, n.color);
    cmp('Sharpness', o.sharpness, n.sharpness);
    cmp('High ISO NR', o.highIsoNr, n.highIsoNr);
    cmp('Clarity', o.clarity, n.clarity);
    cmp('Grain', '${o.grainRoughness}/${o.grainSize}', '${n.grainRoughness}/${n.grainSize}');
    cmp('CC effect', o.colorChromeEffect, n.colorChromeEffect);
    cmp('CC blue', o.colorChromeFxBlue, n.colorChromeFxBlue);
    return rows;
  }

  /// After saving, this slot *is* the new recipe — keep the tile honest.
  Future<void> _relink(Recipe saved) => ref
      .read(slotLinksProvider.notifier)
      .record(widget.model, widget.slot, saved.id, slotSettingsHash(widget.model, widget.preset));

  Future<void> _run(Future<Recipe> Function() action, String toast) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await action();
      await _relink(saved);
      if (!mounted) return;
      // Pop with the message: the caller shows it, because a toast raised from a route that
      // is being dismissed never reaches the screen.
      Navigator.of(context).pop(toast);
    } on RecipeConflict catch (e) {
      final existing = ref.read(recipeRepositoryProvider).byId(e.existingId);
      setState(() {
        _busy = false;
        _error = 'These exact settings are already in the library${existing == null ? '' : ' as "${existing.name}"'}. Names don\'t count — change a setting or keep it local.';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final repo = ref.watch(recipeRepositoryProvider);
    final me = ref.watch(sessionProvider).valueOrNull?.user;
    final origin = _origin;
    // "Update the original" only makes sense for a published recipe I own.
    final canUpdate = origin != null && !origin.isDraft && me != null && origin.authorId == me.id;
    final issues = OfrValidator.validate(_recipe);
    final blocking = _busy || _name.text.trim().isEmpty || OfrValidator.hasErrors(issues);
    final changes = _changes;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(origin == null ? 'SAVE C${widget.slot} FROM THE CAMERA' : 'C${widget.slot} CHANGED WHILE YOU SHOT', style: KataType.displayStyle(size: 19, color: p.fg)),
        const SizedBox(height: 6),
        Text(
          origin == null
              ? 'These are the settings sitting in the slot right now — including anything you dialled in on the body.'
              : 'You wrote "${origin.name}" here, then edited it on the camera. Keep the camera\'s version.',
          style: KataType.bodyStyle(size: 12, color: p.muted, height: 1.45),
        ),
        const SizedBox(height: 16),
        KataTextField(label: 'Name', controller: _name, hint: 'What do you call it?', onChanged: (_) => setState(() {})),
        if (_name.text.trim().length > 25) ...[
          const SizedBox(height: 6),
          Text('Cameras keep at most 25 characters — the ${widget.model} stores none at all. Longer names live in Kata.', style: KataType.bodyStyle(size: 10.5, color: p.muted, height: 1.4)),
        ],
        const SizedBox(height: 16),
        if (changes.isNotEmpty) ...[
          Text('${changes.length} CHANGE${changes.length == 1 ? '' : 'S'} FROM "${origin!.name.toUpperCase()}"', style: KataType.monoStyle(size: 9, weight: FontWeight.w500, color: p.fg, letterSpacing: 0.16)),
          const SizedBox(height: 8),
          for (final (label, was, now) in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Expanded(flex: 3, child: Text(label.toUpperCase(), style: KataType.monoStyle(size: 9, color: p.muted, letterSpacing: 0.1))),
                Expanded(flex: 2, child: Text(was, style: KataType.monoStyle(size: 9.5, color: p.dim))),
                Text('→', style: KataType.monoStyle(size: 9.5, color: p.muted)),
                Expanded(flex: 2, child: Padding(padding: const EdgeInsets.only(left: 8), child: Text(now, style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.fg)))),
              ]),
            ),
          const SizedBox(height: 14),
          const DottedDivider(),
          const SizedBox(height: 14),
        ],
        SpecGrid(RecipeSpecs.items(_recipe, rulers: false).take(8).toList(), valueSize: 13, rowGap: 14, colGap: 10),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          IssueCard(title: '${issues.length} NOTE${issues.length == 1 ? '' : 'S'}', rows: [for (final i in issues) IssueRow(i.field, i.message)]),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          IssueCard(title: "COULDN'T SAVE", rows: [IssueRow('server', _error!)]),
        ],
        const SizedBox(height: 18),
        if (_busy)
          Center(child: KataDotsLoader(dot: 5, color: p.fg))
        else ...[
          Row(children: [
            Expanded(child: KataPillButton(label: 'Cancel', kind: KataButtonKind.secondary, display: false, height: 46, onPressed: () => Navigator.of(context).pop())),
            const SizedBox(width: 10),
            Expanded(
              child: KataPillButton(
                label: 'Save to Mine',
                kind: KataButtonKind.secondary,
                display: false,
                height: 46,
                onPressed: blocking ? null : () => _run(() => repo.addImported(_recipe, source: RecipeSource.camera), 'Saved to Mine'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (canUpdate)
            KataPillButton(
              label: 'Update "${origin.name}"',
              height: 46,
              onPressed: blocking ? null : () => _run(() => repo.updatePublished(origin.id, _recipe), 'Updated — new version, back in the review queue'),
            ),
          if (canUpdate) const SizedBox(height: 10),
          KataPillButton(
            label: canUpdate ? 'Publish as a new kata' : 'Publish',
            kind: canUpdate ? KataButtonKind.secondary : KataButtonKind.primary,
            display: !canUpdate,
            height: 46,
            onPressed: blocking ? null : () => _run(() => repo.publish(_recipe), 'Published'),
          ),
          const SizedBox(height: 8),
          Text(
            canUpdate
                ? 'Updating keeps the same page and history — the old version stays revertable. Publishing makes a separate kata.'
                : 'Published katas are public straight away; the ✓ badge follows a review.',
            style: KataType.bodyStyle(size: 10.5, color: p.muted, height: 1.4),
          ),
        ],
      ]),
    );
  }
}
