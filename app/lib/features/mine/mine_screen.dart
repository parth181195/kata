import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../data/recipe_repository.dart';
import '../../data/recipe.dart';
import '../library/recipe_card.dart';
import '../camera/write_sheet.dart';
import '../ofr_io/import_sheet.dart';
import '../share/share_composer_sheet.dart';

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
    final lib = ref.watch(recipeRepositoryProvider);
    // design 5a: MINE = published under your name · SAVED = favourites · DRAFTS = local (imported / camera / new)
    final mine = lib.published.toList();
    // hidden katas drop out of Saved too: `all` is the raw cache, not the browse feed
    final favs = lib.all.where((r) => lib.favourites.contains(r.id) && !r.hidden).toList();
    final drafts = lib.drafts.toList();
    final list = [mine, favs, drafts][_seg];
    final emptyCopy = [
      ('Nothing published yet', 'Publish a draft and it goes live under your name — and into the review queue for a badge.', 'New kata'),
      ('Nothing saved yet', 'Save any community kata and it shows up here, synced across devices.', 'Browse library'),
      ('No drafts', 'Start a kata from scratch, import an OFR file, scan a Kata Code, or read one back from your camera.', 'New kata'),
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
                KataSegmented(labels: const ['Mine', 'Saved', 'Drafts'], index: _seg, onChanged: (i) => setState(() => _seg = i), counts: [mine.length, favs.length, drafts.length]),
              ]),
            ),
            Expanded(
              child: !lib.loaded
                  ? ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), children: const [KataSkeletonCard(), SizedBox(height: 12), KataSkeletonCard()])
                  : list.isEmpty
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
                            1 => context.go('/library'),
                            _ => context.push('/new'),
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
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final r = list[i];
                        final card = GestureDetector(
                          onLongPress: () => _contextMenu(context, ref, r),
                          child: RecipeCard(
                            recipe: r,
                            favourite: lib.favourites.contains(r.id),
                            onTap: () => context.push('/recipe/${r.id}'),
                            onFavourite: () => lib.toggleFavourite(r.id),
                          ),
                        );
                        if (r.source == RecipeSource.seed) return card;
                        // status strip above my recipes: DRAFT · IN REVIEW · VERIFIED · HIDDEN
                        final status = r.source == RecipeSource.published
                            ? (r.hidden ? 'HIDDEN' : (r.verified ? 'VERIFIED' : 'IN REVIEW'))
                            : (r.source == RecipeSource.camera ? 'FROM CAMERA' : 'DRAFT');
                        final withStatus = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 6),
                            child: Row(children: [
                              KataStatusPill(
                                status == 'VERIFIED' ? KataStatus.connected : (status == 'HIDDEN' ? KataStatus.offline : KataStatus.disconnected),
                                label: status,
                              ),
                              const Spacer(),
                              if (r.source != RecipeSource.camera)
                                KataPillButton(label: r.source == RecipeSource.published ? 'Edit' : 'Edit · Publish', kind: KataButtonKind.secondary, display: false, height: 30, expand: false, onPressed: () => context.push('/edit/${r.id}')),
                            ]),
                          ),
                          card,
                        ]);
                        if (r.source == RecipeSource.published) return withStatus;
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
                          child: withStatus,
                        );
                      },
                    ),
                    ),
            ),
          ]),
          Positioned(
            right: 20,
            bottom: 20,
            child: KataIconCircle(
              size: 56,
              filled: true,
              onPressed: () => showKataSheet(context, builder: (c) => KataSheet(eyebrow: 'Mine', title: 'Add a kata', children: [
                KataListRow(title: 'Scan a Kata Code', sub: 'From a card, a screen or a print — works offline', value: 'Camera', onTap: () { Navigator.of(c).pop(); context.push('/scan'); }),
                KataListRow(title: 'New kata', sub: 'Start from camera defaults', value: 'Editor', onTap: () { Navigator.of(c).pop(); context.push('/new'); }),
                KataListRow(title: 'Import OFR', sub: 'Paste JSON or pick a .ofr.json file', value: 'Import', onTap: () async {
                  Navigator.of(c).pop();
                  final id = await showImportSheet(context);
                  if (id != null && context.mounted) KataToast.show(context, 'Saved to Mine', action: 'Undo', onAction: () => lib.remove(id));
                }),
              ])),
              child: Text('+', style: KataType.bodyStyle(size: 24, color: p.bg, height: 1)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 5a: long-press any kata for the same actions; the header names the object.
Future<void> _contextMenu(BuildContext context, WidgetRef ref, Recipe r) async {
  final lib = ref.read(recipeRepositoryProvider);
  final own = r.source == RecipeSource.published || r.isDraft;
  final pick = await showKataMenu<String>(context, title: r.name, items: [
    if (own) const KataMenuItem('edit', 'Edit kata', icon: Icons.edit_outlined),
    const KataMenuItem('write', 'Write to slot…', icon: Icons.usb_outlined),
    const KataMenuItem('dup', 'Duplicate', icon: Icons.copy_outlined),
    const KataMenuItem('share', 'Share card…', icon: Icons.ios_share_outlined),
    if (r.isDraft) const KataMenuItem('publish', 'Publish to library', icon: Icons.public_outlined),
    const KataMenuDivider('d'),
    if (own)
      KataMenuItem(r.isDraft ? 'delete' : 'unpublish', r.isDraft ? 'Delete' : 'Unpublish', icon: Icons.delete_outline, destructive: true)
    else
      const KataMenuItem('unsave', 'Remove from Saved', icon: Icons.bookmark_remove_outlined, destructive: true),
  ]);
  if (pick == null || !context.mounted) return;
  switch (pick) {
    case 'edit' || 'publish':
      context.push('/edit/${r.id}');
    case 'write':
      await showWriteSheet(context, r);
    case 'dup':
      context.push('/new?from=${r.id}');
    case 'share':
      await showShareComposer(context, r);
    case 'delete':
      await lib.remove(r.id);
    case 'unpublish':
      final ok = await showKataDialog(context, title: 'Unpublish “${r.name}”?', body: 'It disappears from the community library for everyone.', confirmLabel: 'Unpublish', destructive: true);
      if (ok == true) await lib.unpublish(r.id);
    case 'unsave':
      await lib.toggleFavourite(r.id);
  }
}
