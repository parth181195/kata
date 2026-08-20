import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../../core/prefs/settings.dart';
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
    final layout = ref.watch(libraryLayoutProvider);
    final sortLabel = switch (filter.sort) { LibrarySort.newest => 'NEWEST', LibrarySort.popular => 'POPULAR', LibrarySort.az => 'A → Z' };

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('KATA 型', style: KataType.displayStyle(size: 24, weight: FontWeight.w900, color: p.fg, letterSpacing: 0.05))),
                _LayoutToggle(layout: layout, onChanged: (l) => ref.read(libraryLayoutProvider.notifier).set(l)),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  shape: StadiumBorder(side: BorderSide(color: p.hairline)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () async {
                      final pos = Offset(MediaQuery.sizeOf(context).width - 20, MediaQuery.paddingOf(context).top + 56);
                      final pick = await showKataMenu<LibrarySort>(context, position: pos, items: [
                        for (final (s, label) in [(LibrarySort.newest, 'Newest first'), (LibrarySort.popular, 'Most saved'), (LibrarySort.az, 'A → Z')])
                          KataMenuItem(s, label, selected: filter.sort == s),
                      ]);
                      if (pick != null) _setFilter((f) => f.copyWith(sort: pick));
                    },
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
              KataSearchField(hint: 'Search recipes, film sims, authors', height: KataSearchField.touch, controller: _search, onChanged: (q) => _setFilter((f) => f.copyWith(query: q))),
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
                        child: layout == LibraryLayout.grid
                            ? GridView.builder(
                                key: const ValueKey('library-grid'),
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.82),
                                itemCount: recipes.length,
                                itemBuilder: (_, i) {
                                  final r = recipes[i];
                                  final tile = RecipeGridTile(recipe: r, favourite: lib.favourites.contains(r.id), onTap: () => context.push('/recipe/${r.id}'), onFavourite: () => lib.toggleFavourite(r.id));
                                  return i < 6 ? KataFadeIn(key: ValueKey('fade-${r.id}'), delay: Duration(milliseconds: 40 * i), child: tile) : tile;
                                },
                              )
                            : ListView.separated(
                                key: const ValueKey('library-list'),
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                                itemCount: recipes.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (_, i) {
                                  final r = recipes[i];
                                  final card = RecipeCard(
                                    recipe: r,
                                    hero: layout == LibraryLayout.hero, // 6a: every card full-bleed
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

/// Two-segment icon pill per design 6a: hero rect · 2×2 grid; active segment is filled white.
class _LayoutToggle extends StatelessWidget {
  const _LayoutToggle({required this.layout, required this.onChanged});
  final LibraryLayout layout;
  final ValueChanged<LibraryLayout> onChanged;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    Widget seg(LibraryLayout l, Widget glyph) {
      final on = layout == l;
      return Material(
        key: ValueKey('layout-${l.name}'),
        color: on ? p.fg : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(l),
          child: SizedBox(width: 30, height: 28, child: Center(child: glyph)),
        ),
      );
    }

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(border: Border.all(color: p.hairline), borderRadius: BorderRadius.circular(18)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg(LibraryLayout.hero, Container(width: 13, height: 10, decoration: BoxDecoration(border: Border.all(color: layout == LibraryLayout.hero ? p.bg : p.muted, width: 1.5), borderRadius: BorderRadius.circular(2)))),
        const SizedBox(width: 2),
        seg(
          LibraryLayout.grid,
          SizedBox(
            width: 12,
            height: 12,
            child: GridView.count(crossAxisCount: 2, mainAxisSpacing: 2, crossAxisSpacing: 2, physics: const NeverScrollableScrollPhysics(), children: [
              for (var i = 0; i < 4; i++) ColoredBox(color: layout == LibraryLayout.grid ? p.bg : p.muted),
            ]),
          ),
        ),
      ]),
    );
  }
}
