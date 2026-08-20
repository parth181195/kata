import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../core/auth/auth_repository.dart';
import '../core/fuji/camera_service.dart';
import '../core/net/api_client.dart';
import '../data/recipe.dart';
import '../data/recipe_repository.dart';
import '../data/recipe_specs.dart';
import '../features/editor/ofr_fields.dart';
import '../features/editor/recipe_editor_screen.dart' show kBlankOfr;
import 'desktop_camera.dart';
import 'desktop_import.dart';

/// Design 1e: every field visible at once. Left rail carries identity, live compatibility
/// against the connected body, and the Kata Code; the right pane is the full field set.
class DesktopEditor extends ConsumerStatefulWidget {
  const DesktopEditor({super.key, this.id, this.from, this.seed, this.onDone});

  /// Existing recipe to edit (draft or published).
  final String? id;

  /// Duplicate this recipe's settings into a new draft.
  final String? from;

  /// Start from these settings (e.g. read out of a camera slot).
  final OfrRecipe? seed;
  final VoidCallback? onDone;

  @override
  ConsumerState<DesktopEditor> createState() => _DesktopEditorState();
}

class _DesktopEditorState extends ConsumerState<DesktopEditor> {
  late OfrRecipe _r;
  late final TextEditingController _name, _attr, _url;
  Recipe? _editing;
  bool _busy = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(recipeRepositoryProvider);
    _editing = widget.id == null ? null : repo.byId(widget.id!);
    final from = widget.from == null ? null : repo.byId(widget.from!);
    final base = _editing?.ofr ??
        widget.seed ??
        from?.ofr.copyWith(clearHash: true, name: '${from.name} (copy)') ??
        kBlankOfr;
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

  OfrRecipe get _current => _r.copyWith(
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
        sourceAttribution: _attr.text.trim().isEmpty ? null : _attr.text.trim(),
        sourceUrl: _url.text.trim().isEmpty ? null : _url.text.trim(),
      );

  List<OfrIssue> get _issues => OfrValidator.validate(_current);
  bool get _hasErrors => OfrValidator.hasErrors(_issues);
  bool get _isPublished => _editing?.source == RecipeSource.published;

  void _leave() {
    _dirty = false;
    widget.onDone?.call();
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showKataDialog(context, title: 'Discard changes?', body: 'Nothing has been saved yet.', confirmLabel: 'Discard', destructive: true);
    return ok == true;
  }

  Future<void> _saveDraft() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(recipeRepositoryProvider);
      if (_editing != null && _editing!.isDraft) {
        await repo.updateDraft(_editing!.id, _current);
      } else {
        await repo.addImported(_current);
      }
      if (!mounted) return;
      KataToast.show(context, 'Saved to Mine');
      _leave();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final ofr = _current;
    if (ofr.name == null) return KataToast.show(context, 'Give it a name first');
    if (ofr.sensors.isEmpty) return KataToast.show(context, 'Pick at least one sensor generation');
    final (title, body, label) = _isPublished
        ? ('Save changes?', 'Edits go back into the review queue — the verified badge comes off until a curator re-checks it.', 'Save')
        : ('Publish "${ofr.name}"?', 'It goes live in the community library right away under your name and lands in the review queue for a verified badge.', 'Publish');
    final ok = await showKataDialog(context, title: title, body: body, confirmLabel: label);
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(recipeRepositoryProvider);
      if (_isPublished) {
        await repo.updatePublished(_editing!.id, ofr);
        if (mounted) KataToast.show(context, 'Saved — back in review');
      } else {
        await repo.publish(ofr, draftId: _editing?.isDraft == true ? _editing!.id : null);
        if (mounted) KataToast.show(context, 'Published');
      }
      if (mounted) _leave();
    } on RecipeConflict catch (e) {
      final existing = ref.read(recipeRepositoryProvider).byId(e.existingId);
      if (mounted) KataToast.show(context, 'Already in the library${existing == null ? '' : ' as "${existing.name}"'} — names don\'t count, change a setting');
    } on RecipeInvalid catch (e) {
      if (mounted) KataToast.show(context, 'Rejected: ${e.issues.first}');
    } on ApiException catch (e) {
      if (mounted) KataToast.show(context, e.isNetwork ? 'No connection — saved nothing' : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Queue what's on screen straight onto a slot, then the standard review + write.
  Future<void> _writeTo(int slot) async {
    ref.read(writeQueueProvider.notifier).update((q) => {...q, slot: Recipe(id: 'editor-draft', ofr: _current, source: RecipeSource.camera)});
    await showWriteReview(context, ref);
  }

  Future<void> _readFrom(int slot) async {
    final st = ref.read(cameraServiceProvider);
    if (st is! CameraReady || slot > st.slots.length) return;
    final ofr = OfrMapper.fromPreset(st.slots[slot - 1], sensors: OfrMapper.sensorsForModel(st.caps.model));
    setState(() {
      // keep the identity the user typed; take the settings
      _r = ofr.copyWith(name: _r.name, sourceAttribution: _r.sourceAttribution, sourceUrl: _r.sourceUrl, sensors: _r.sensors.isEmpty ? ofr.sensors : _r.sensors, clearHash: true);
      _dirty = true;
    });
    if (mounted) KataToast.show(context, 'Loaded C$slot');
  }

  Future<void> _pasteCode() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    try {
      final out = parseImportText(text);
      if (out == null) throw const FormatException('clipboard is empty');
      setState(() {
        _r = out.recipe.copyWith(clearHash: true);
        _name.text = out.recipe.name ?? _name.text;
        _dirty = true;
      });
      if (mounted) KataToast.show(context, 'Loaded from the clipboard');
    } catch (_) {
      if (mounted) KataToast.show(context, 'No Kata Code or OFR JSON on the clipboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final signedIn = ref.watch(sessionProvider).valueOrNull != null;
    final cam = ref.watch(cameraServiceProvider);
    final ready = cam is CameraReady ? cam : null;
    final r = _r;
    final code = KataCode.encode(_current, credit: _attr.text.trim().isEmpty ? null : _attr.text.trim());

    return Column(children: [
      // ---- header
      Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hairline))),
        child: Row(children: [
          Expanded(
            child: Text((_name.text.trim().isEmpty ? (_editing == null ? 'New kata' : 'Edit kata') : _name.text.trim()).toUpperCase(),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 22, color: p.fg)),
          ),
          const SizedBox(width: 12),
          if (_editing != null)
            KataStatusPill(_isPublished && _editing!.verified ? KataStatus.connected : KataStatus.disconnected,
                label: _isPublished ? (_editing!.verified ? 'VERIFIED' : 'IN REVIEW') : 'DRAFT'),
          const SizedBox(width: 12),
          if (ready != null)
            KataPillButton(
              label: 'Write to a slot',
              kind: KataButtonKind.secondary,
              display: false,
              height: 34,
              expand: false,
              onPressed: _hasErrors
                  ? null
                  : () async {
                      final slot = await showKataMenu<int>(context,
                          title: 'Write to which slot?',
                          items: [for (var i = 1; i <= ready.caps.slotCount; i++) KataMenuItem(i, 'C$i', icon: Icons.save_alt)]);
                      if (slot != null && context.mounted) await _writeTo(slot);
                    },
            ),
          const SizedBox(width: 8),
          KataPillButton(label: 'Close', kind: KataButtonKind.secondary, display: false, height: 34, expand: false, onPressed: () async {
            if (await _confirmDiscard()) _leave();
          }),
        ]),
      ),
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ---- left rail: identity, compatibility, live code
          Container(
            width: 340,
            decoration: BoxDecoration(border: Border(right: BorderSide(color: p.hairline))),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 24), children: [
              KataSectionHeader('Identity'),
              const SizedBox(height: 10),
              KataTextField(label: 'Name', controller: _name, hint: 'e.g. Kodachrome 64', onChanged: (_) => setState(() => _dirty = true)),
              const SizedBox(height: 6),
              Text(
                _name.text.trim().length > 25
                    ? 'Cameras keep at most 25 characters — on the body this shows as "${_name.text.trim().substring(0, 25)}". The full name lives in Kata.'
                    : 'Bodies that store preset names keep 25 characters; the X-S20 stores none.',
                style: KataType.bodyStyle(size: 10.5, color: _name.text.trim().length > 25 ? p.dim : p.muted, height: 1.4),
              ),
              const SizedBox(height: 10),
              KataTextField(label: 'Credit', controller: _attr, hint: 'Attribution (optional)', onChanged: (_) => setState(() => _dirty = true)),
              const SizedBox(height: 10),
              KataTextField(label: 'Source URL', controller: _url, hint: 'https:// (optional)', onChanged: (_) => setState(() => _dirty = true)),
              const SizedBox(height: 12),
              OfrFields.sensorChips(r, _set),
              const SizedBox(height: 22),
              KataSectionHeader('Compatibility'),
              const SizedBox(height: 10),
              _compatibility(p, ready),
              const SizedBox(height: 22),
              KataSectionHeader('Kata Code · live'),
              const SizedBox(height: 10),
              KataCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SelectableText(code, style: KataType.monoStyle(size: 10, color: p.dim, height: 1.5)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: Text('${code.length} BYTES · LIVE', maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 8, color: p.muted, letterSpacing: 0.12)),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (context.mounted) KataToast.show(context, 'Kata Code copied');
                      },
                      child: Text('COPY', style: KataType.monoStyle(size: 8.5, weight: FontWeight.w500, color: p.fg, letterSpacing: 0.14)),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
          // ---- right pane: every field
          Expanded(
            child: Column(children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hairline))),
                child: Row(children: [
                  Text('SETTINGS', style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.18)),
                  const Spacer(),
                  KataPillButton(label: 'Paste code', kind: KataButtonKind.secondary, display: false, height: 30, expand: false, onPressed: _pasteCode),
                  const SizedBox(width: 8),
                  if (ready != null)
                    KataPillButton(
                      label: 'Read from a slot',
                      kind: KataButtonKind.secondary,
                      display: false,
                      height: 30,
                      expand: false,
                      onPressed: () async {
                        final slot = await showKataMenu<int>(context,
                            title: 'Read which slot?', items: [for (var i = 1; i <= ready.caps.slotCount; i++) KataMenuItem(i, 'C$i', icon: Icons.download)]);
                        if (slot != null && context.mounted) await _readFrom(slot);
                      },
                    ),
                  const SizedBox(width: 8),
                  KataPillButton(
                    label: 'Reset',
                    kind: KataButtonKind.secondary,
                    display: false,
                    height: 30,
                    expand: false,
                    onPressed: () => setState(() {
                      _r = kBlankOfr;
                      _dirty = true;
                    }),
                  ),
                ]),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(24, 18, 24, 24), children: [
                  KataSectionHeader('Look'),
                  const SizedBox(height: 10),
                  ...OfrFields.look(r, _set),
                  const SizedBox(height: 22),
                  KataSectionHeader('White balance'),
                  const SizedBox(height: 10),
                  ...OfrFields.whiteBalance(r, _set),
                  const SizedBox(height: 22),
                  KataSectionHeader('Tone'),
                  const SizedBox(height: 10),
                  ...OfrFields.tone(r, _set),
                  const SizedBox(height: 22),
                  KataSectionHeader('Summary'),
                  const SizedBox(height: 10),
                  Text(RecipeSpecs.summary(_current), style: KataType.monoStyle(size: 11.5, color: p.dim, height: 1.5)),
                  if (_issues.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    IssueCard(
                      title: '${_issues.length} FIELD${_issues.length == 1 ? '' : 'S'} NEED${_issues.length == 1 ? 'S' : ''} ATTENTION',
                      rows: [for (final i in _issues) IssueRow(i.field, i.message)],
                    ),
                  ],
                ]),
              ),
              // ---- actions
              Container(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
                child: Row(children: [
                  if (!_isPublished) ...[
                    KataPillButton(label: 'Save draft', kind: KataButtonKind.secondary, display: false, height: 44, expand: false, onPressed: _busy ? null : _saveDraft),
                    const SizedBox(width: 10),
                  ],
                  const Spacer(),
                  if (!signedIn) Padding(padding: const EdgeInsets.only(right: 12), child: Text('SIGN IN TO PUBLISH', style: KataType.monoStyle(size: 9, color: p.muted, letterSpacing: 0.14))),
                  KataPillButton(
                    label: _isPublished ? 'Save changes' : 'Publish',
                    height: 44,
                    expand: false,
                    loading: _busy,
                    onPressed: (_hasErrors || !signedIn || _busy) ? null : _publish,
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }

  /// Real compatibility, not guesswork: what the *connected* body would actually store.
  Widget _compatibility(KataPalette p, CameraReady? ready) {
    if (ready == null) {
      return KataCard(
        dashed: true,
        child: Text('Plug a camera in to see exactly which of these fields it stores.', style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.5)),
      );
    }
    final mapped = OfrMapper.toPreset(_current);
    final plan = PresetWriter.plan(mapped.value, ready.caps);
    final skipped = plan.where((w) => !ready.caps.supports(w.code) && ready.caps.supportedProps.isNotEmpty).toList();
    final rows = <(bool, String)>[
      (true, '${ready.caps.model} — ${plan.length - skipped.length} of ${plan.length} fields'),
      for (final w in skipped) (false, '${FujiProp.name(w.code)} not stored on this body'),
      for (final n in mapped.notes) (false, n),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (ok, text) in rows.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ok ? '✓' : '!', style: KataType.monoStyle(size: 10, weight: FontWeight.w600, color: ok ? p.fg : p.dim)),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.4))),
            ]),
          ),
      ],
    );
  }
}
