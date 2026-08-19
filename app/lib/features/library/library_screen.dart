import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../../data/recipe.dart';
import '../../data/recipe_repository.dart';
import 'recipe_card.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setFilter(LibraryFilter Function(LibraryFilter) f) => ref.read(libraryFilterProvider.notifier).update(f);

  Future<void> _pickFilmSim() async {
    final current = ref.read(libraryFilterProvider).filmSim;
    final picked = await showKataSheet<String?>(context, builder: (c) => KataSheet(
      eyebrow: 'Filter',
      title: 'Film simulation',
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in OfrEnums.filmSims) KataChip(label: s, selected: s == current, onTap: () => Navigator.of(c).pop(s)),
        ]),
        const SizedBox(height: 16),
        KataPillButton(label: 'Clear', kind: KataButtonKind.secondary, display: false, height: 50, onPressed: () => Navigator.of(c).pop('')),
      ],
    ));
    if (picked == null) return;
    _setFilter((f) => picked.isEmpty ? f.copyWith(clearFilmSim: true) : f.copyWith(filmSim: picked));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final filter = ref.watch(libraryFilterProvider);
    final lib = ref.watch(recipeRepositoryProvider);
    final recipes = ref.watch(filteredRecipesProvider);
    final sortLabel = switch (filter.sort) { LibrarySort.newest => 'NEWEST', LibrarySort.popular => 'POPULAR', LibrarySort.az => 'A → Z' };

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('KATA 型', style: KataType.displayStyle(size: 24, weight: FontWeight.w900, color: p.fg, letterSpacing: 0.05))),
                Material(
                  color: Colors.transparent,
                  shape: StadiumBorder(side: BorderSide(color: p.hairline)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _setFilter((f) => f.copyWith(sort: LibrarySort.values[(f.sort.index + 1) % LibrarySort.values.length])),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(sortLabel, style: KataType.monoStyle(size: 10.5, weight: FontWeight.w500, color: p.dim)),
                        const SizedBox(width: 8),
                        Text('▾', style: KataType.bodyStyle(size: 10, color: p.muted, height: 1)),
                      ]),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              KataSearchField(hint: 'Search recipes, film sims, authors', controller: _search, onChanged: (q) => _setFilter((f) => f.copyWith(query: q))),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  KataChip(label: 'Verified', dot: true, selected: filter.verifiedOnly, onTap: () => _setFilter((f) => f.copyWith(verifiedOnly: !f.verifiedOnly))),
                  const SizedBox(width: 7),
                  KataChip(label: 'X-Trans V', selected: filter.sensor == 'X-Trans V', onTap: () => _setFilter((f) => f.sensor == 'X-Trans V' ? f.copyWith(clearSensor: true) : f.copyWith(sensor: 'X-Trans V'))),
                  const SizedBox(width: 7),
                  KataChip(label: 'B&W', selected: filter.mono == true, onTap: () => _setFilter((f) => f.mono == true ? f.copyWith(clearMono: true) : f.copyWith(mono: true))),
                  const SizedBox(width: 7),
                  KataChip(label: filter.filmSim ?? 'Film sim', selected: filter.filmSim != null, onTap: _pickFilmSim, onRemove: filter.filmSim == null ? null : () => _setFilter((f) => f.copyWith(clearFilmSim: true))),
                ]),
              ),
            ]),
          ),
          if (lib.loaded && lib.offline)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: KataCard(
                radius: 14,
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.dim, width: 1.5))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(lib.offlineIsNetwork ? 'Offline — showing cached library' : 'Library unreachable — showing cached copy', maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 12, color: p.dim, height: 1.2))),
                  const SizedBox(width: 8),
                  KataPillButton(label: 'RETRY', kind: KataButtonKind.secondary, height: 32, expand: false, display: false, loading: lib.syncing, onPressed: () => lib.sync()),
                ]),
              ),
            ),
          Expanded(
            // loading: db not read yet, or first-ever sync still running with nothing cached
            child: !lib.loaded || (lib.syncing && lib.all.isEmpty)
                ? ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), children: [
                    if (lib.loaded) ...[
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        KataDotsLoader(color: p.muted, dot: 4, gap: 4),
                        const SizedBox(width: 10),
                        Text('SYNCING LIBRARY', style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.14)),
                      ]),
                      const SizedBox(height: 14),
                    ],
                    const KataSkeletonCard(),
                    const SizedBox(height: 12),
                    const KataSkeletonCard(),
                    const SizedBox(height: 12),
                    const KataSkeletonCard(),
                  ])
                : recipes.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: KataCard(
                          dashed: true,
                          child: lib.all.isEmpty && lib.offline
                              ? KataEmptyState(
                                  glyph: '!',
                                  title: 'Nothing cached yet',
                                  body: lib.offlineIsNetwork ? 'Connect to the internet once to load the library.' : 'The library server is unreachable right now.',
                                  actionLabel: 'Retry',
                                  onAction: () => lib.sync(),
                                )
                              : KataEmptyState(
                                  glyph: '0',
                                  title: filter.query.isEmpty ? 'No katas match' : 'No katas for “${filter.query}”',
                                  body: 'Try a film sim (Classic Neg) or clear the Verified filter.',
                                  actionLabel: 'Clear filters',
                                  onAction: () {
                                    _search.clear();
                                    ref.read(libraryFilterProvider.notifier).state = const LibraryFilter();
                                  },
                                ),
                        ),
                      )
                    : RefreshIndicator(
                        color: p.fg,
                        backgroundColor: p.surface,
                        strokeWidth: 2,
                        onRefresh: lib.sync,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          itemCount: recipes.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final r = recipes[i];
                            final card = RecipeCard(
                              recipe: r,
                              hero: i == 0,
                              favourite: lib.favourites.contains(r.id),
                              onTap: () => context.push('/recipe/${r.id}'),
                              onFavourite: () => lib.toggleFavourite(r.id),
                            );
                            // stagger the first screenful on entry; later cards just appear while scrolling
                            return i < 6 ? KataFadeIn(key: ValueKey('fade-${r.id}'), delay: Duration(milliseconds: 40 * i), child: card) : card;
                          },
                        ),
                      ),
          ),
        ]),
      ),
    );
  }
}
