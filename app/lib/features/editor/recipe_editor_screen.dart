import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/net/api_client.dart';
import '../../data/recipe.dart';
import '../../data/recipe_repository.dart';
import '../../data/recipe_specs.dart';

/// Blank starting point for "New kata": Provia, everything at camera defaults.
const kBlankOfr = OfrRecipe(
  filmSimulation: 'Provia',
  dynamicRange: 'DR100',
  dRangePriority: 'Off',
  grainRoughness: 'Off',
  whiteBalance: 'Auto',
  whiteBalanceRed: 0,
  whiteBalanceBlue: 0,
  highlight: 0,
  shadow: 0,
  color: 0,
  sharpness: 0,
  highIsoNr: 0,
  clarity: 0,
);

/// Create / edit a kata. `id == null` → new draft; a draft id → edit locally; a published id → edit on the server.
/// `from` = duplicate an existing recipe's settings into a new draft.
class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({super.key, this.id, this.from});
  final String? id;
  final String? from;
  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  late OfrRecipe _r;
  late final TextEditingController _name, _attr, _url;
  Recipe? _editing; // existing recipe being edited (draft or published)
  bool _busy = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(recipeRepositoryProvider);
    _editing = widget.id == null ? null : repo.byId(widget.id!);
    final from = widget.from == null ? null : repo.byId(widget.from!);
    final base = _editing?.ofr ?? from?.ofr.copyWith(clearHash: true, name: '${from.name} (copy)', sourceUrl: from.ofr.sourceUrl, sourceAttribution: from.ofr.sourceAttribution) ?? kBlankOfr;
    _r = base.copyWith(clearHash: true);
    _name = TextEditingController(text: _r.name ?? '');
    _attr = TextEditingController(text: _r.sourceAttribution ?? '');
    _url = TextEditingController(text: _r.sourceUrl ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _attr.dispose();
    _url.dispose();
    super.dispose();
  }

  void _set(OfrRecipe Function(OfrRecipe) f) => setState(() {
    _r = f(_r);
    _dirty = true;
  });

  /// Editor can be the root route (deep link / initialLocation) — fall back to Mine.
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/mine');
    }
  }

  OfrRecipe get _current => _r.copyWith(
    name: _name.text.trim().isEmpty ? null : _name.text.trim(),
    sourceAttribution: _attr.text.trim().isEmpty ? null : _attr.text.trim(),
    sourceUrl: _url.text.trim().isEmpty ? null : _url.text.trim(),
  );

  List<OfrIssue> get _issues => OfrValidator.validate(_current);
  bool get _hasErrors => _issues.any((i) => i.severity == OfrSeverity.error);
  bool get _isPublished => _editing?.source == RecipeSource.published;

  Future<void> _saveDraft() async {
    final repo = ref.read(recipeRepositoryProvider);
    setState(() => _busy = true);
    try {
      if (_editing != null && _editing!.isDraft) {
        await repo.updateDraft(_editing!.id, _current);
      } else {
        await repo.addImported(_current);
      }
      if (mounted) {
        KataToast.show(context, 'Saved to Mine');
        _leave();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final repo = ref.read(recipeRepositoryProvider);
    final ofr = _current;
    if (ofr.name == null) {
      KataToast.show(context, 'Give it a name first');
      return;
    }
    if (ofr.sensors.isEmpty) {
      KataToast.show(context, 'Pick at least one sensor generation');
      return;
    }
    final (title, body, label) = _isPublished
        ? ('Save changes?', 'Edits go back into the review queue — the verified badge comes off until a curator re-checks it.', 'Save')
        : ('Publish “${ofr.name}”?', 'It goes live in the community library right away under your name and lands in the review queue for a verified badge.', 'Publish');
    final ok = await showKataDialog(context, title: title, body: body, confirmLabel: label);
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (_isPublished) {
        await repo.updatePublished(_editing!.id, ofr);
        if (mounted) KataToast.show(context, 'Saved — back in review');
      } else {
        await repo.publish(ofr, draftId: _editing?.isDraft == true ? _editing!.id : null);
        if (mounted) KataToast.show(context, 'Published');
      }
      if (mounted) _leave();
    } on RecipeConflict catch (e) {
      if (!mounted) return;
      final pick = await showKataMenu<String>(context, title: 'Already in the library', items: const [
        KataMenuItem('open', 'Open the existing kata', icon: Icons.arrow_outward),
        KataMenuItem('draft', 'Keep mine as a draft', icon: Icons.bookmark_outline, trailing: 'Mine'),
        KataMenuItem('edit', 'Keep editing', icon: Icons.edit_outlined),
      ]);
      if (!mounted) return;
      switch (pick) {
        case 'open':
          context.replace('/recipe/${e.existingId}');
        case 'draft':
          await _saveDraft();
        default:
          KataToast.show(context, 'Names don’t count for duplicates — change a setting to publish');
      }
    } on RecipeInvalid catch (e) {
      if (mounted) KataToast.show(context, 'Rejected: ${e.issues.first}');
    } on ApiException catch (e) {
      if (mounted) KataToast.show(context, e.isNetwork ? 'No connection — saved nothing' : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final signedIn = ref.watch(sessionProvider).valueOrNull != null;
    final r = _r;
    final mono = OfrEnums.isMonoName(r.filmSimulation);
    final issues = _issues;
    final title = _editing == null ? 'New kata' : 'Edit kata';

    Widget section(String label, List<Widget> children) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KataSectionHeader(label),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
    Widget two(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);
    Widget gap() => const SizedBox(height: 10);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showKataDialog(context, title: 'Discard changes?', body: 'Nothing has been saved yet.', confirmLabel: 'Discard', destructive: true);
        if (leave == true && context.mounted) context.pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(children: [
                KataIconCircle(size: 40, onPressed: () => Navigator.of(context).maybePop(), child: Icon(Icons.arrow_back_ios_new, size: 14, color: p.dim)),
                const SizedBox(width: 14),
                Expanded(child: Text(title.toUpperCase(), style: KataType.displayStyle(size: 22, color: p.fg))),
                if (_isPublished) KataStatusPill(_editing!.verified ? KataStatus.connected : KataStatus.disconnected, label: _editing!.verified ? 'VERIFIED' : 'IN REVIEW'),
              ]),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                section('Identity', [
                  KataTextField(label: 'Name', controller: _name, hint: 'e.g. Kodachrome 64', onChanged: (_) => setState(() => _dirty = true)),
                  const SizedBox(height: 6),
                  Text(
                    _name.text.trim().length > 25
                        ? 'Cameras keep at most 25 characters — on the body this shows as “${_name.text.trim().substring(0, 25)}”. The full name lives in Kata.'
                        : 'The name lives in Kata and on share cards. Bodies that store preset names keep 25 characters; the X-S20 stores none.',
                    style: KataType.bodyStyle(size: 10.5, color: _name.text.trim().length > 25 ? p.dim : p.muted, height: 1.4),
                  ),
                  gap(),
                  KataTextField(label: 'Credit', controller: _attr, hint: 'Attribution (optional)', onChanged: (_) => setState(() => _dirty = true)),
                  gap(),
                  KataTextField(label: 'Source URL', controller: _url, hint: 'https:// (optional)', keyboardType: TextInputType.url, onChanged: (_) => setState(() => _dirty = true)),
                  gap(),
                  Wrap(spacing: 7, runSpacing: 7, children: [
                    for (final s in OfrEnums.sensors.take(7))
                      KataChip(
                        label: s,
                        selected: r.sensors.contains(s),
                        onTap: () => _set((x) => x.copyWith(sensors: x.sensors.contains(s) ? x.sensors.where((e) => e != s).toList() : [...x.sensors, s])),
                      ),
                  ]),
                ]),
                section('Look', [
                  KataPickerRow(
                    label: 'Film simulation',
                    value: r.filmSimulation,
                    options: OfrEnums.filmSims,
                    // switching colour↔mono drops the fields the other family forbids, so validation never traps you
                    onChanged: (v) => _set((x) => OfrEnums.isMonoName(v)
                        ? x.copyWith(filmSimulation: v, clearColor: true, clearColorChrome: true)
                        : x.copyWith(filmSimulation: v, clearMonochromatic: true, color: x.color ?? 0)),
                  ),
                  KataPickerRow(label: 'Dynamic range', value: r.dynamicRange, hint: 'Camera default', options: OfrEnums.dynamicRanges, onChanged: (v) => _set((x) => x.copyWith(dynamicRange: v))),
                  KataPickerRow(label: 'D range priority', value: r.dRangePriority, options: OfrEnums.dRangePriorities, onChanged: (v) => _set((x) => x.copyWith(dRangePriority: v))),
                  KataPickerRow(label: 'Grain', value: r.grainRoughness, options: OfrEnums.grainRoughness, onChanged: (v) => _set((x) => x.copyWith(grainRoughness: v, clearGrainSize: v == 'Off'))),
                  KataPickerRow(label: 'Grain size', value: r.grainSize, hint: '—', enabled: r.grainRoughness != 'Off', options: OfrEnums.grainSizes, onChanged: (v) => _set((x) => x.copyWith(grainSize: v))),
                  KataPickerRow(label: 'Color chrome effect', value: r.colorChromeEffect, hint: 'Off', options: OfrEnums.effects, onChanged: (v) => _set((x) => x.copyWith(colorChromeEffect: v))),
                  KataPickerRow(label: 'Color chrome FX blue', value: r.colorChromeFxBlue, hint: 'Off', options: OfrEnums.effects, onChanged: (v) => _set((x) => x.copyWith(colorChromeFxBlue: v))),
                ]),
                section('White balance', [
                  KataPickerRow(label: 'Mode', value: r.whiteBalance, options: OfrEnums.wbModes, onChanged: (v) => _set((x) => x.copyWith(whiteBalance: v, wbKelvin: v == 'Kelvin' ? (x.wbKelvin ?? 5500) : null, clearKelvin: v != 'Kelvin'))),
                  if (r.whiteBalance == 'Kelvin') ...[
                    gap(),
                    KataStepper(label: 'Kelvin', value: r.wbKelvin ?? 5500, min: 2500, max: 10000, step: 100, format: (v) => '${v.toInt()}K', onChanged: (v) => _set((x) => x.copyWith(wbKelvin: v.toInt()))),
                  ],
                  gap(),
                  two(
                    KataStepper(label: 'WB shift R', value: r.whiteBalanceRed, min: -9, max: 9, onChanged: (v) => _set((x) => x.copyWith(whiteBalanceRed: v.toInt()))),
                    KataStepper(label: 'WB shift B', value: r.whiteBalanceBlue, min: -9, max: 9, onChanged: (v) => _set((x) => x.copyWith(whiteBalanceBlue: v.toInt()))),
                  ),
                ]),
                section('Tone', [
                  two(
                    KataStepper(label: 'Highlight', value: r.highlight ?? 0, min: -2, max: 4, step: 0.5, onChanged: (v) => _set((x) => x.copyWith(highlight: v))),
                    KataStepper(label: 'Shadow', value: r.shadow ?? 0, min: -2, max: 4, step: 0.5, onChanged: (v) => _set((x) => x.copyWith(shadow: v))),
                  ),
                  gap(),
                  two(
                    KataStepper(label: 'Color', value: r.color ?? 0, min: -4, max: 4, enabled: !mono, onChanged: (v) => _set((x) => x.copyWith(color: v.toInt()))),
                    KataStepper(label: 'Sharpness', value: r.sharpness, min: -4, max: 4, onChanged: (v) => _set((x) => x.copyWith(sharpness: v.toInt()))),
                  ),
                  gap(),
                  two(
                    KataStepper(label: 'High ISO NR', value: r.highIsoNr, min: -4, max: 4, onChanged: (v) => _set((x) => x.copyWith(highIsoNr: v.toInt()))),
                    KataStepper(label: 'Clarity', value: r.clarity, min: -5, max: 5, onChanged: (v) => _set((x) => x.copyWith(clarity: v.toInt()))),
                  ),
                  if (mono) ...[
                    gap(),
                    two(
                      KataStepper(label: 'Warm / cool', value: r.monochromaticColorWarmCool ?? 0, min: -9, max: 9, onChanged: (v) => _set((x) => x.copyWith(monochromaticColorWarmCool: v.toInt()))),
                      KataStepper(label: 'Magenta / green', value: r.monochromaticColorMagentaGreen ?? 0, min: -9, max: 9, onChanged: (v) => _set((x) => x.copyWith(monochromaticColorMagentaGreen: v.toInt()))),
                    ),
                  ],
                ]),
                section('Summary', [
                  Text(RecipeSpecs.summary(_current), style: KataType.monoStyle(size: 12, color: p.dim, height: 1.4)),
                  if (issues.isNotEmpty) ...[
                    gap(),
                    IssueCard(
                      title: '${issues.length} FIELD${issues.length == 1 ? '' : 'S'} NEED${issues.length == 1 ? 'S' : ''} ATTENTION',
                      rows: [for (final i in issues) IssueRow(i.field, i.message)],
                    ),
                  ],
                ]),
              ]),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
              child: Row(children: [
                if (!_isPublished) ...[
                  Expanded(child: KataPillButton(label: 'Save draft', kind: KataButtonKind.secondary, display: false, height: 52, onPressed: _busy ? null : _saveDraft)),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: _isPublished ? 1 : 1,
                  child: KataPillButton(
                    label: _isPublished ? 'Save changes' : 'Publish',
                    height: 52,
                    loading: _busy,
                    onPressed: (_hasErrors || !signedIn) ? null : _publish,
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
