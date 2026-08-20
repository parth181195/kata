import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';

import '../data/recipe.dart';
import '../data/recipe_repository.dart';
import '../data/recipe_specs.dart';
import '../features/library/recipe_card.dart' show recipeImage;
import '../features/ofr_io/export_sheet.dart';
import '../features/share/share_composer_sheet.dart';
import 'desktop_shell.dart';
import 'slot_dock.dart';

final desktopSelectedRecipeProvider = StateProvider<String?>((_) => null);

/// Design 1g: card grid left, persistent detail pane right. `savedOnly`/`mineOnly` reuse it for the rail.
class DesktopLibrary extends ConsumerStatefulWidget {
  const DesktopLibrary({super.key, this.savedOnly = false, this.mineOnly = false});
  final bool savedOnly;
  final bool mineOnly;
  @override
  ConsumerState<DesktopLibrary> createState() => _DesktopLibraryState();
}

class _DesktopLibraryState extends ConsumerState<DesktopLibrary> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final repo = ref.watch(recipeRepositoryProvider);
    final filter = ref.watch(libraryFilterProvider);
    var recipes = repo.loaded ? repo.where(filter) : const <Recipe>[];
    if (widget.savedOnly) recipes = recipes.where((r) => repo.favourites.contains(r.id)).toList();
    if (widget.mineOnly) recipes = repo.mine.toList();
    final selId = ref.watch(desktopSelectedRecipeProvider);
    final selected = recipes.where((r) => r.id == selId).firstOrNull ?? recipes.firstOrNull;

    return Column(children: [
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(children: [
              Expanded(child: KataSearchField(hint: 'Search recipes, film sims, authors', controller: _search, onChanged: (q) => ref.read(libraryFilterProvider.notifier).update((f) => f.copyWith(query: q)))),
              const SizedBox(width: 10),
              KataChip(label: 'Verified', dot: true, selected: filter.verifiedOnly, onTap: () => ref.read(libraryFilterProvider.notifier).update((f) => f.copyWith(verifiedOnly: !f.verifiedOnly))),
              const SizedBox(width: 7),
              KataChip(label: 'B&W', selected: filter.mono == true, onTap: () => ref.read(libraryFilterProvider.notifier).update((f) => f.mono == true ? f.copyWith(clearMono: true) : f.copyWith(mono: true))),
            ]),
          ),
          Expanded(
            child: !repo.loaded
                ? const Center(child: KataDotsLoader())
                : recipes.isEmpty
                    ? Center(child: KataEmptyState(glyph: '0', title: widget.savedOnly ? 'Nothing saved yet' : 'No katas match'))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 230, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.92),
                        itemCount: recipes.length,
                        itemBuilder: (_, i) {
                          final r = recipes[i];
                          final on = selected?.id == r.id;
                          // cards are draggable onto the camera slot board (1a)
                          return Draggable<Recipe>(
                            data: r,
                            feedback: Material(
                              color: Colors.transparent,
                              child: Container(
                                width: 190,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: p.fg, width: 1.5)),
                                child: Text(r.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 13, color: p.fg, letterSpacing: 0)),
                              ),
                            ),
                            child: _card(p, r, on),
                          );
                        },
                      ),
          ),
        ]),
      ),
      Container(
        width: 380,
        decoration: BoxDecoration(border: Border(left: BorderSide(color: p.hairline))),
        child: selected == null ? Center(child: Text('PICK A KATA', style: KataType.monoStyle(size: 10, color: p.muted, letterSpacing: 0.16))) : _DetailPane(recipe: selected),
      ),
        ]),
      ),
      const SlotDock(),
    ]);
  }

  Widget _card(KataPalette p, Recipe r, bool on) => Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: on ? p.fg : p.hairline, width: on ? 1.5 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ref.read(desktopSelectedRecipeProvider.notifier).state = r.id,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                FrameSlot(radius: 0, placeholder: 'frame', image: recipeImage(r.imageUrls.firstOrNull)),
                if (r.verified)
                  Positioned(top: 8, right: 8, child: Container(width: 16, height: 16, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: const Center(child: Text('✓', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.black, height: 1))))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 12.5, color: p.fg, letterSpacing: 0)),
                const SizedBox(height: 3),
                Text('${r.ofr.filmSimulation} · ${RecipeSpecs.dr(r.ofr)}'.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 8.5, color: p.muted)),
              ]),
            ),
          ]),
        ),
      );
}

class _DetailPane extends ConsumerWidget {
  const _DetailPane({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    final repo = ref.watch(recipeRepositoryProvider);
    final r = recipe;
    final fav = repo.favourites.contains(r.id);
    // "mine" = a local draft or something I published: those I edit in place, the rest I fork.
    final mine = r.isDraft || repo.mine.any((x) => x.id == r.id);
    final items = RecipeSpecs.items(r.ofr, rulers: false);
    return ListView(padding: const EdgeInsets.all(18), children: [
      Row(children: [
        if (r.verified) ...[const VerifiedBadge(size: 16), const SizedBox(width: 8)],
        Expanded(child: Text(r.name.toUpperCase(), style: KataType.displayStyle(size: 20, color: p.fg, letterSpacing: 0, height: 1.05))),
      ]),
      const SizedBox(height: 6),
      Text(attributionLineOf(r), style: KataType.bodyStyle(size: 11.5, color: p.muted)),
      const SizedBox(height: 12),
      if (r.imageUrls.isNotEmpty)
        ClipRRect(borderRadius: BorderRadius.circular(10), child: AspectRatio(aspectRatio: 3 / 2, child: FrameSlot(radius: 0, image: recipeImage(r.imageUrls.first)))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: KataPillButton(label: fav ? '♥ Saved' : '♡ Save', kind: KataButtonKind.secondary, display: false, height: 40, onPressed: () => repo.toggleFavourite(r.id))),
        const SizedBox(width: 8),
        Expanded(child: KataPillButton(label: 'Share card', kind: KataButtonKind.secondary, display: false, height: 40, onPressed: () => showShareComposer(context, r))),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: KataPillButton(
            label: mine ? 'Edit' : 'Duplicate & edit',
            kind: KataButtonKind.secondary,
            display: false,
            height: 40,
            onPressed: () => DesktopShell.of(context)?.openEditor(id: mine ? r.id : null, from: mine ? null : r.id),
          ),
        ),
        const SizedBox(width: 8),
        KataIconCircle(size: 40, onPressed: () => showExportSheet(context, r), child: Icon(Icons.file_download_outlined, size: 16, color: p.dim)),
      ]),
      const SizedBox(height: 14),
      const DottedDivider(),
      const SizedBox(height: 12),
      SpecGrid(items, columns: 2, valueSize: 13, rowGap: 14),
      const SizedBox(height: 16),
      KataCard(
        dashed: true,
        child: Text('Drag any card onto a slot in the dock below (or on the Camera board) to queue a write.', style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.5)),
      ),
    ]);
  }
}

String attributionLineOf(Recipe r) {
  final who = r.ofr.sourceAttribution ?? (r.source == RecipeSource.published ? 'Yours' : 'Community');
  final sensors = r.ofr.sensors.join(' / ');
  return sensors.isEmpty ? who : '$who · $sensors';
}
