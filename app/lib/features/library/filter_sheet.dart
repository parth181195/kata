import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../../data/recipe.dart';
import '../../data/recipe_repository.dart';

/// Everything the chip row doesn't have space for. A bottom sheet on a phone and a centred
/// panel on desktop (showKataSheet decides), with a live count so you can see what a choice
/// costs before you commit to it.
Future<void> showFilterSheet(BuildContext context) => showKataSheet<void>(context, builder: (_) => const _FilterSheet());

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    final repo = ref.watch(recipeRepositoryProvider);
    final f = ref.watch(libraryFilterProvider);
    void set(LibraryFilter Function(LibraryFilter) fn) => ref.read(libraryFilterProvider.notifier).update(fn);
    final matches = repo.loaded ? repo.where(f).length : 0;

    Widget group(String label, List<Widget> chips) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KataSectionHeader(label),
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 7, children: chips),
          const SizedBox(height: 18),
        ]);

    /// A chip that sets one value, or clears it when it is already the one set.
    Widget one(String label, String? value, String? current, void Function(String?) apply) =>
        KataChip(label: label, selected: current == value, onTap: () => apply(current == value ? null : value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('FILTERS', style: KataType.displayStyle(size: 20, color: p.fg))),
          if (!f.isEmpty)
            TextButton(
              onPressed: () => set((x) => x.cleared()),
              child: Text('Clear all', style: KataType.bodyStyle(size: 12.5, color: p.muted)),
            ),
        ]),
        const SizedBox(height: 4),
        Text('$matches kata${matches == 1 ? '' : 's'} match right now', style: KataType.monoStyle(size: 10, color: p.muted, letterSpacing: 0.12)),
        const SizedBox(height: 18),

        group('Sensor', [
          for (final s in OfrEnums.sensors.take(7))
            KataChip(
              label: s,
              selected: f.sensors.contains(s),
              onTap: () => set((x) {
                final next = {...x.sensors};
                next.contains(s) ? next.remove(s) : next.add(s);
                return x.copyWith(sensors: next);
              }),
            ),
        ]),

        group('Look', [
          for (final fam in FilmFamily.all)
            KataChip(
              label: fam.label,
              selected: f.families.contains(fam.id),
              onTap: () => set((x) {
                final next = {...x.families};
                next.contains(fam.id) ? next.remove(fam.id) : next.add(fam.id);
                return x.copyWith(families: next);
              }),
            ),
        ]),

        group('Dynamic range', [
          for (final dr in OfrEnums.dynamicRanges) one(dr, dr, f.dynamicRange, (v) => set((x) => v == null ? x.copyWith(clearDynamicRange: true) : x.copyWith(dynamicRange: v))),
        ]),

        group('Grain', [
          for (final g in OfrEnums.grainRoughness) one(g, g, f.grain, (v) => set((x) => v == null ? x.copyWith(clearGrain: true) : x.copyWith(grain: v))),
        ]),

        group('White balance', [
          for (final wb in OfrEnums.wbModes.take(8)) one(wb, wb, f.whiteBalance, (v) => set((x) => v == null ? x.copyWith(clearWhiteBalance: true) : x.copyWith(whiteBalance: v))),
        ]),

        group('Only show', [
          KataChip(label: 'Verified', dot: true, selected: f.verifiedOnly, onTap: () => set((x) => x.copyWith(verifiedOnly: !x.verifiedOnly))),
          KataChip(label: 'With sample photos', selected: f.withPhotos, onTap: () => set((x) => x.copyWith(withPhotos: !x.withPhotos))),
          KataChip(label: 'B&W', selected: f.mono == true, onTap: () => set((x) => x.mono == true ? x.copyWith(clearMono: true) : x.copyWith(mono: true))),
        ]),

        KataPillButton(
          label: matches == 0 ? 'Nothing matches — loosen something' : 'Show $matches kata${matches == 1 ? '' : 's'}',
          height: 52,
          onPressed: matches == 0 ? null : () => Navigator.of(context).pop(),
        ),
      ]),
    );
  }
}
