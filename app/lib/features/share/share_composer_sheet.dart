import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../core/auth/auth_repository.dart';
import '../../data/recipe.dart';
import '../../core/compose/export.dart';
import 'card_renderer.dart';
import 'card_templates.dart';

/// Design 3a: preview · template row S1–S4 · options (invert, embed code, ratio) · `{ }` payload peek · Share card.
Future<void> showShareComposer(BuildContext context, Recipe recipe) =>
    showKataSheet<void>(context, maxWidth: 980, builder: (_) => ShareComposerSheet(recipe: recipe));

class ShareComposerSheet extends ConsumerStatefulWidget {
  const ShareComposerSheet({super.key, required this.recipe});
  final Recipe recipe;
  @override
  ConsumerState<ShareComposerSheet> createState() => _ShareComposerSheetState();
}

class _ShareComposerSheetState extends ConsumerState<ShareComposerSheet> {
  final _boundary = GlobalKey();
  ShareTemplate _template = ShareTemplate.card;
  ShareRatio _ratio = ShareRatio.r4x5;
  bool _inverted = false;
  bool _embed = true;
  bool _showPayload = false;
  bool _busy = false;

  String get _credit {
    final r = widget.recipe;
    if (r.ofr.sourceAttribution != null && r.ofr.sourceAttribution!.isNotEmpty) return r.ofr.sourceAttribution!;
    final me = ref.read(sessionProvider).valueOrNull?.user;
    return r.source == RecipeSource.published && me != null ? me.displayName : 'Kata';
  }

  ShareSpec get _spec => ShareSpec(recipe: widget.recipe, template: _template, ratio: _ratio, inverted: _inverted, embedCode: _embed, credit: _credit);

  void _pickTemplate(ShareTemplate t) => setState(() {
    _template = t;
    // sensible default ratio per template
    _ratio = switch (t) { ShareTemplate.card => ShareRatio.r4x5, ShareTemplate.sheet => ShareRatio.r1x1, ShareTemplate.story => ShareRatio.r9x16, ShareTemplate.code => ShareRatio.r1x1 };
  });

  Future<void> _share() async {
    setState(() => _busy = true);
    final name = shareFileName(widget.recipe, _template);
    Uint8List png;
    try {
      png = await CardRenderer(_boundary).toPng(pixelRatio: kCardPixelRatio);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        KataToast.show(context, 'Could not render the card');
      }
      return;
    }
    try {
      if (mounted) await deliverPng(context, png, name: name, subject: '${widget.recipe.name} — Kata recipe card', text: _spec.payload);
    } catch (e) {
      if (mounted) KataToast.show(context, 'Card made, but sharing failed — try Save instead');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _spec.payload));
    if (mounted) KataToast.show(context, 'Kata Code copied');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final spec = _spec;
    final previewW = MediaQuery.sizeOf(context).width - 40;
    final scale = (previewW / kCardWidth).clamp(0.3, 1.0);
    // keep the preview from eating the whole sheet on tall ratios
    final maxH = MediaQuery.sizeOf(context).height * 0.42;
    final natural = (kCardWidth / spec.ratio.aspect) * scale;
    final previewScale = natural > maxH ? scale * (maxH / natural) : scale;

    Widget segmented<T>(List<T> values, T current, String Function(T) label, ValueChanged<T> onPick) => Row(children: [
      for (final v in values) ...[
        KataChip(label: label(v), selected: v == current, onTap: () => onPick(v)),
        const SizedBox(width: 7),
      ],
    ]);

    final wide = MediaQuery.sizeOf(context).width >= 820;
    final preview = Center(
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: p.hairline)),
        clipBehavior: Clip.antiAlias,
        child: OffscreenCardHost(boundaryKey: _boundary, spec: spec, scale: wide ? scale.clamp(0.3, 1.0) : previewScale),
      ),
    );

    return KataSheet(
      eyebrow: 'Share card',
      title: widget.recipe.name,
      // on a desktop window the card sits beside its options instead of above them
      leading: wide ? preview : null,
      children: [
        if (!wide) ...[preview, const SizedBox(height: 16)],
        KataSectionHeader('Template'),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: segmented<ShareTemplate>(ShareTemplate.values, _template, (t) => '${t.code} ${t.label}', _pickTemplate),
        ),
        const SizedBox(height: 14),
        KataSectionHeader('Card options'),
        const SizedBox(height: 4),
        // named choices rather than a switch: "WHITE | BLACK" needs no interpreting
        KataListRow(
          title: 'Card',
          trailing: KataChoice<bool>(
            values: const [false, true],
            selected: _inverted,
            label: (v) => v ? 'Black' : 'White',
            onChanged: (v) => setState(() => _inverted = v),
          ),
        ),
        KataListRow(
          title: 'Kata Code',
          trailing: KataChoice<bool>(
            values: const [true, false],
            selected: _embed,
            label: (v) => v ? 'Shown' : 'Hidden',
            onChanged: (v) => setState(() => _embed = v),
          ),
        ),
        KataListRow(title: 'Credit', value: _credit),
        const SizedBox(height: 10),
        Row(children: [
          Text('RATIO', style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16)),
          const SizedBox(width: 12),
          segmented<ShareRatio>(ShareRatio.values, _ratio, (r) => r.label, (r) => setState(() => _ratio = r)),
          const Spacer(),
          KataIconCircle(size: 36, onPressed: () => setState(() => _showPayload = !_showPayload), child: Text('{ }', style: KataType.monoStyle(size: 11, color: p.dim, height: 1))),
        ]),
        if (_showPayload) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _copyCode,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.hairline)),
              child: Text(spec.payload, key: const ValueKey('payload'), style: KataType.monoStyle(size: 10.5, color: p.dim, height: 1.6)),
            ),
          ),
          const SizedBox(height: 4),
          Text('${spec.payload.length} BYTES · TAP TO COPY', style: KataType.monoStyle(size: 8.5, color: p.muted, letterSpacing: 0.14)),
        ],
        const SizedBox(height: 16),
        KataPillButton(label: 'Share card', loading: _busy, onPressed: _busy ? null : _share),
        const SizedBox(height: 8),
        KataPillButton(label: 'Copy Kata Code', kind: KataButtonKind.secondary, display: false, height: 48, onPressed: _copyCode),
      ],
    );
  }
}

