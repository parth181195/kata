import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../data/recipe.dart';
import '../../data/recipe_repository.dart';
import 'share_composer_sheet.dart';

/// The Share tab: pick a kata, share its code card — with the card's photo
/// swappable for one of your own. Nothing more; the card is the product.
class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key});
  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final repo = ref.watch(recipeRepositoryProvider);
    final q = _query.trim().toLowerCase();
    final mine = repo.mine.toList();
    final rest = repo.all.where((r) => !mine.any((m) => m.id == r.id)).toList();
    bool hit(Recipe r) => q.isEmpty || r.name.toLowerCase().contains(q) || r.ofr.filmSimulation.toLowerCase().contains(q);
    final mineHits = mine.where(hit).toList();
    final restHits = rest.where(hit).toList();

    Widget row(Recipe r) => KataListRow(
          key: ValueKey('share-${r.id}'),
          title: r.name,
          value: r.ofr.filmSimulation.toUpperCase(),
          onTap: () => showShareComposer(context, r),
        );

    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('SHARE', style: KataType.displayStyle(size: 24, color: p.fg)),
              const SizedBox(height: 6),
              Text('Pick a kata. Its code card carries the recipe; put your own photo on it if you like.',
                  style: KataType.bodyStyle(size: 12, color: p.muted, height: 1.4)),
              const SizedBox(height: 12),
              KataSearchField(hint: 'Search katas, film sims', controller: _search, onChanged: (v) => setState(() => _query = v)),
            ]),
          ),
          Expanded(
            child: !repo.loaded
                ? const Center(child: KataDotsLoader())
                : (mineHits.isEmpty && restHits.isEmpty)
                    ? Center(child: KataEmptyState(glyph: '0', title: 'No katas match'))
                    : ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
                        if (mineHits.isNotEmpty) ...[
                          KataSectionHeader('Mine'),
                          for (final r in mineHits) row(r),
                          const SizedBox(height: 14),
                        ],
                        if (restHits.isNotEmpty) ...[
                          KataSectionHeader('Library'),
                          for (final r in restHits) row(r),
                        ],
                      ]),
          ),
        ]),
      ),
    );
  }
}
