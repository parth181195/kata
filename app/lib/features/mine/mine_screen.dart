import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../data/local_library.dart';
import '../../data/recipe.dart';
import '../library/recipe_card.dart';
import '../ofr_io/import_sheet.dart';

class MineScreen extends ConsumerStatefulWidget {
  const MineScreen({super.key});
  @override
  ConsumerState<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends ConsumerState<MineScreen> {
  int _seg = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final lib = ref.watch(localLibraryProvider);
    final favs = lib.lib.all.where((r) => lib.lib.favourites.contains(r.id)).toList();
    final mine = lib.lib.mine.where((r) => r.source == RecipeSource.imported).toList();
    final cam = lib.lib.mine.where((r) => r.source == RecipeSource.camera).toList();
    final list = [favs, mine, cam][_seg];
    final emptyCopy = [
      ('Nothing saved yet', 'Favourite a kata or read one back from your camera.', 'Browse library'),
      ('No recipes of yours yet', 'Import an OFR file or paste JSON to start a collection.', 'Import'),
      ('Nothing from the camera', 'Connect on the Camera tab and tap “Save as kata” on a slot.', 'Camera'),
    ][_seg];

    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MINE', style: KataType.displayStyle(size: 24, color: p.fg)),
                const SizedBox(height: 12),
                KataSegmented(labels: const ['Favourites', 'My recipes', 'From camera'], index: _seg, onChanged: (i) => setState(() => _seg = i), counts: [favs.length, mine.length, cam.length]),
              ]),
            ),
            Expanded(
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: KataCard(
                        dashed: true,
                        child: KataEmptyState(
                          glyph: '0',
                          title: emptyCopy.$1,
                          body: emptyCopy.$2,
                          actionLabel: emptyCopy.$3,
                          onAction: () => switch (_seg) {
                            0 => context.go('/library'),
                            1 => showImportSheet(context),
                            _ => context.go('/camera'),
                          },
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final r = list[i];
                        final card = RecipeCard(
                          recipe: r,
                          favourite: lib.lib.favourites.contains(r.id),
                          onTap: () => context.push('/recipe/${r.id}'),
                          onFavourite: () => lib.toggleFavourite(r.id),
                        );
                        if (r.source == RecipeSource.seed) return card;
                        return Dismissible(
                          key: ValueKey(r.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: p.red)),
                            child: Text('DELETE', style: KataType.monoStyle(size: 10.5, weight: FontWeight.w500, color: p.red)),
                          ),
                          onDismissed: (_) => lib.remove(r.id),
                          child: card,
                        );
                      },
                    ),
            ),
          ]),
          Positioned(
            right: 20,
            bottom: 20,
            child: KataIconCircle(
              size: 56,
              filled: true,
              onPressed: () async {
                final id = await showImportSheet(context);
                if (id != null && context.mounted) KataToast.show(context, 'Saved to Mine', action: 'Undo', onAction: () => lib.remove(id));
              },
              child: Text('+', style: KataType.bodyStyle(size: 24, color: p.bg, height: 1)),
            ),
          ),
        ]),
      ),
    );
  }
}
