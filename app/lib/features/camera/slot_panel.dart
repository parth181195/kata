import 'package:flutter/material.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../data/recipe_specs.dart';

/// "C2 — WHAT'S IN THE CAMERA": the selected slot's main values + Save as kata / Overwrite with…
class SlotPanel extends StatelessWidget {
  const SlotPanel({super.key, required this.slot, required this.preset, required this.model, required this.onSave, required this.onOverwrite, this.busy = false});
  final int slot;
  final CameraPreset preset;
  final String model;
  final VoidCallback onSave;
  final VoidCallback onOverwrite;
  final bool busy;

  static const _mainLabels = {'Film Sim', 'Dynamic Range', 'White Balance', 'Highlight', 'Shadow', 'Grain'};

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final ofr = OfrMapper.fromPreset(preset, sensors: OfrMapper.sensorsForModel(model));
    final items = RecipeSpecs.items(ofr, rulers: false).where((i) => _mainLabels.contains(i.label)).toList();
    final title = preset.name.isEmpty ? (FilmSim.labels[preset.filmSim] ?? 'Slot $slot') : preset.name;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('C$slot — WHAT\'S IN THE CAMERA', style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16)),
      const SizedBox(height: 10),
      KataCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(width: 34, height: 5, decoration: BoxDecoration(color: p.hairline, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 12),
            Expanded(child: Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 16, color: p.fg, letterSpacing: 0))),
          ]),
          const SizedBox(height: 14),
          SpecGrid(items, valueSize: 13, rowGap: 14, colGap: 10),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: KataPillButton(label: 'Save as kata', display: false, height: 44, onPressed: busy ? null : onSave)),
            const SizedBox(width: 10),
            Expanded(child: KataPillButton(label: 'Overwrite with…', kind: KataButtonKind.secondary, display: false, height: 44, onPressed: busy ? null : onOverwrite)),
          ]),
        ]),
      ),
    ]);
  }
}
