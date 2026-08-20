import 'package:flutter/material.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:kata_ui/kata_ui.dart';

/// A refused setting, and which slot it was refused on.
typedef SlotSkip = ({int slot, SkipCause cause});

/// Turns write results into causes. [presets] is what we asked the camera for — the film
/// simulation and white balance decide whether a field could have applied at all.
List<SlotSkip> slotSkips(Map<int, WriteResult> results, Map<int, CameraPreset> presets) => [
      for (final e in results.entries)
        if (presets[e.key] != null)
          for (final c in explainSkips(e.value.skipped, preset: presets[e.key]!, reasons: e.value.skipReasons)) (slot: e.key, cause: c),
    ];

/// Everything worth saying about a write that isn't a skipped field: values the camera
/// stored differently, and bodies that don't keep slot names. These come back through
/// [WriteResult.mismatched] / warnings rather than [WriteResult.skipped], so they'd vanish
/// if the skip card were the only thing on screen.
List<String> writeNotes(Map<int, WriteResult> results, {bool showSlot = false}) => [
      for (final e in results.entries) ...[
        if (e.value.mismatched.isNotEmpty)
          '${showSlot ? 'C${e.key}: ' : ''}${e.value.mismatched.map(FujiProp.friendly).join(', ')} read back different — '
              'the camera stored its own value, so check ${e.value.mismatched.length == 1 ? 'it' : 'them'} on the body.',
        if (e.value.warnings.any((w) => w.contains('PresetName')))
          '${showSlot ? 'C${e.key}: ' : ''}This body doesn\'t keep slot names, so the kata name isn\'t shown on the camera. The settings are all there.',
      ],
    ];

/// "5 SETTINGS SKIPPED" with a reason under each group, because a bare list of property
/// names tells the photographer nothing about what to change on the camera.
class SkippedSettingsCard extends StatelessWidget {
  const SkippedSettingsCard({super.key, required this.causes, this.showSlot = false});
  final List<SlotSkip> causes;

  /// Prefix each reason with C1–C7 — only useful when several slots were written at once.
  final bool showSlot;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final fields = causes.fold<int>(0, (a, c) => a + c.cause.codes.length);
    return KataCard(
      outline: p.red,
      radius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: p.red)),
          const SizedBox(width: 9),
          Expanded(
            child: Text('$fields SETTING${fields == 1 ? '' : 'S'} SKIPPED',
                style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.dim, letterSpacing: 0.16)),
          ),
        ]),
        for (final c in causes) ...[
          const SizedBox(height: 11),
          const DottedDivider(),
          const SizedBox(height: 11),
          Text('${showSlot ? 'C${c.slot} · ' : ''}${c.cause.headline.toUpperCase()}',
              style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.fg, letterSpacing: 0.14)),
          const SizedBox(height: 5),
          Text(c.cause.fields.join(' · '), style: KataType.monoStyle(size: 9, color: p.muted, height: 1.45)),
          const SizedBox(height: 7),
          Text(c.cause.detail, style: KataType.bodyStyle(size: 11.5, color: p.dim, height: 1.5)),
          if (c.cause.fix.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(c.cause.fix, style: KataType.bodyStyle(size: 11.5, color: p.fg, height: 1.5)),
          ],
        ],
      ]),
    );
  }
}
