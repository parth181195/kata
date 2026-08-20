import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../../data/recipe_specs.dart';

const _kodachrome = OfrRecipe(name: 'Kodachrome 64', filmSimulation: 'Classic Chrome', dynamicRange: 'DR400', dRangePriority: 'Off',
    grainRoughness: 'Weak', grainSize: 'Small', colorChromeEffect: 'Weak', colorChromeFxBlue: 'Off', whiteBalance: 'Daylight',
    whiteBalanceRed: 2, whiteBalanceBlue: -5, highlight: -1, shadow: 0.5, color: 2, sharpness: -2, highIsoNr: -4, clarity: 0);

/// Every kata_ui widget on one page, for visual QA against docs/design/Kata.dc.html.
class KitScreen extends StatelessWidget {
  const KitScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    Widget section(String t, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [EyebrowDivider(t), const SizedBox(height: 11), child]),
        );
    final sims = {'CC': (-1, 0.5, 2, -2, 0), 'ACR': (2, 3, 0, 2, -2), 'VEL': (-0.5, -1, 4, 0, 0), 'PNS': (0, 0, -1, 1, 0), 'NN': (1.5, 0, 1, -1, -2), 'ETR': (-2, -2, -2, -2, 0)};
    return Scaffold(
      appBar: AppBar(title: Text('KATA 型 KIT', style: KataType.displayStyle(size: 20, weight: FontWeight.w900, color: p.fg, letterSpacing: 0.05))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        section('Status · badges', Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: const [
          KataStatusPill(KataStatus.connected), KataStatusPill(KataStatus.disconnected), KataStatusPill(KataStatus.offline), KataStatusPill(KataStatus.noCamera),
          KataStatusPill(KataStatus.connected, label: 'X-S20 · C1–C4'), VerifiedBadge(),
        ])),
        section('Chips · search', Column(children: [
          const Wrap(spacing: 7, children: [KataChip(label: 'Verified', selected: true, dot: true), KataChip(label: 'X-Trans V'), KataChip(label: 'B&W'), KataChip(label: 'Film sim')]),
          const SizedBox(height: 10),
          const KataSearchField(hint: 'Search recipes, film sims, authors'),
        ])),
        section('Buttons', Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          KataPillButton(label: 'Write', expand: false, onPressed: () {}),
          KataPillButton(label: 'Secondary', kind: KataButtonKind.secondary, display: false, expand: false, onPressed: () {}),
          KataPillButton(label: 'Tonal', kind: KataButtonKind.tonal, display: false, expand: false, onPressed: () {}),
          KataPillButton(label: 'Overwrite', kind: KataButtonKind.danger, display: false, expand: false, onPressed: () {}),
          KataPillButton(label: 'Signing in…', display: false, expand: false, loading: true, onPressed: () {}),
          const Padding(padding: EdgeInsets.all(12), child: KataDotsLoader()),
          KataIconCircle(onPressed: () {}, child: const Text('♡')),
          KataIconCircle(filled: true, onPressed: () {}, child: const Text('+')),
          KataBigRound(label: 'Connect', sub: 'USB-C', size: 74, onPressed: () {}),
        ])),
        section('Swatch generator', Wrap(spacing: 14, children: [
          for (final e in sims.entries)
            Builder(builder: (_) {
              final s = SwatchBars.fromTones(highlight: e.value.$1, shadow: e.value.$2, color: e.value.$3, sharpness: e.value.$4, clarity: e.value.$5);
              return Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(border: Border.all(color: p.hairline)), child: SwatchBars(values: s, abbr: e.key, size: 32));
            }),
        ])),
        section('Spec grid', SpecGrid(RecipeSpecs.items(_kodachrome))),
        section('Slot cards', Row(children: [
          Expanded(child: SlotCard(slot: 1, state: SlotCardState.filled, title: 'Kodachrome 64', line1: 'Classic Chrome', line2: 'DR400 · 5800K', onRefresh: () {})),
          const SizedBox(width: 11),
          const Expanded(child: SlotCard(slot: 2, state: SlotCardState.onDial, title: 'Nostalgic Neg', line1: 'Nostalgic Neg', line2: 'DR200 · Auto')),
          const SizedBox(width: 11),
          const Expanded(child: SlotCard(slot: 4, state: SlotCardState.empty)),
        ])),
        section('Checklist', const Column(children: [
          ChecklistStep(n: 1, title: 'Plug in USB-C', sub: Text('A data cable, not charge-only. Camera off.'), active: true),
          SizedBox(height: 14), DottedDivider(), SizedBox(height: 14),
          ChecklistStep(n: 2, title: 'Set two camera menu items'),
        ])),
        section('Dot matrix · frame', Row(children: [
          const DotMatrixProgress(progress: 0.8),
          const SizedBox(width: 20),
          const SizedBox(width: 78, height: 78, child: FrameSlot(placeholder: 'frame')),
        ])),
        section('Issue card · toast', Column(children: [
          const IssueCard(title: '2 fields need attention', rows: [IssueRow('clarity: 9', 'range −5…+5'), IssueRow('grain: missing', 'will use Off')]),
          const SizedBox(height: 10),
          KataPillButton(label: 'Show toast', kind: KataButtonKind.secondary, display: false, onPressed: () => KataToast.show(context, 'Saved to Mine', action: 'Undo', onAction: () {})),
        ])),
        section('Sheet header', const KataSheet(eyebrow: 'Writing', title: 'Kodachrome 64', children: [Text('…')])),
      ]),
    );
  }
}
