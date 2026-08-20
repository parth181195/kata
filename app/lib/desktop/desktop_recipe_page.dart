import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';

import '../data/recipe.dart';
import '../data/recipe_repository.dart';
import '../data/recipe_specs.dart';
import '../features/library/image_viewer.dart';
import '../features/library/recipe_card.dart' show recipeImage;
import '../features/history/version_history_sheet.dart';
import '../features/ofr_io/export_sheet.dart';
import '../features/share/share_composer_sheet.dart';
import 'desktop_library.dart' show attributionLineOf;
import 'desktop_shell.dart';

/// The whole kata on one screen: big photography, every one of the 22 fields at once, and
/// the actions. The side pane is for skimming; this is for reading — and for looking at
/// somebody's photos at a size that does them justice.
Future<void> showRecipeFullScreen(BuildContext context, Recipe recipe) => Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        transitionDuration: KataMotion.page,
        reverseTransitionDuration: KataMotion.page,
        pageBuilder: (_, a, _) => FadeTransition(opacity: a, child: _RecipePage(recipe: recipe)),
      ),
    );

class _RecipePage extends ConsumerWidget {
  const _RecipePage({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    final repo = ref.watch(recipeRepositoryProvider);
    final r = repo.byId(recipe.id) ?? recipe;
    final fav = repo.favourites.contains(r.id);
    final mine = r.isDraft || repo.mine.any((x) => x.id == r.id);
    final photos = r.imageUrls;
    return Scaffold(
      backgroundColor: p.bg,
      body: Column(children: [
        // ---- top bar
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hairline))),
          child: Row(children: [
            KataIconCircle(size: 36, onPressed: () => Navigator.of(context).maybePop(), child: Icon(Icons.arrow_back, size: 16, color: p.dim)),
            const SizedBox(width: 14),
            if (r.verified) ...[const VerifiedBadge(size: 15), const SizedBox(width: 8)],
            Expanded(
              child: Text(r.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 19, color: p.fg, letterSpacing: 0)),
            ),
            const SizedBox(width: 12),
            KataPillButton(
              label: fav ? '♥ Saved' : '♡ Save',
              kind: KataButtonKind.secondary,
              display: false,
              height: 34,
              expand: false,
              onPressed: () => repo.toggleFavourite(r.id),
            ),
            const SizedBox(width: 8),
            KataPillButton(label: 'Share card', kind: KataButtonKind.secondary, display: false, height: 34, expand: false, onPressed: () => showShareComposer(context, r)),
            const SizedBox(width: 8),
            if (!r.isDraft && mine)
              KataPillButton(label: 'History', kind: KataButtonKind.secondary, display: false, height: 34, expand: false, onPressed: () => showVersionHistoryDialog(context, r)),
            if (!r.isDraft && mine) const SizedBox(width: 8),
            KataPillButton(
              label: mine ? 'Edit' : 'Duplicate & edit',
              height: 34,
              expand: false,
              onPressed: () {
                final shell = DesktopShell.of(context);
                Navigator.of(context).pop();
                shell?.openEditor(id: mine ? r.id : null, from: mine ? null : r.id);
              },
            ),
            const SizedBox(width: 8),
            KataIconCircle(size: 34, onPressed: () => showExportSheet(context, r), child: Icon(Icons.file_download_outlined, size: 15, color: p.dim)),
          ]),
        ),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // ---- photography, as big as the window allows
            Expanded(
              flex: 3,
              child: photos.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text('NO SAMPLE FRAMES YET', style: KataType.monoStyle(size: 10, color: p.muted, letterSpacing: 0.18)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: photos.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => showImageViewer(context, urls: photos, initialIndex: i, credit: attributionLineOf(r)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(aspectRatio: 3 / 2, child: FrameSlot(radius: 0, image: recipeImage(photos[i]))),
                        ),
                      ),
                    ),
            ),
            // ---- every setting, no scrolling between halves
            Container(
              width: 420,
              decoration: BoxDecoration(border: Border(left: BorderSide(color: p.hairline))),
              child: ListView(padding: const EdgeInsets.fromLTRB(22, 22, 22, 28), children: [
                Text(attributionLineOf(r), style: KataType.bodyStyle(size: 12, color: p.muted, height: 1.5)),
                if (r.ofr.sourceUrl != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => showExportSheet(context, r),
                    child: Text(r.ofr.sourceUrl!, maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 10, color: p.dim)),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  for (final s in r.ofr.sensors) KataChip(label: s, selected: false, onTap: null),
                ]),
                const SizedBox(height: 18),
                const DottedDivider(),
                const SizedBox(height: 16),
                KataSectionHeader('Q-menu order'),
                const SizedBox(height: 12),
                SpecGrid(RecipeSpecs.items(r.ofr), columns: 2, valueSize: 13.5, rowGap: 16),
                const SizedBox(height: 20),
                KataCard(
                  dashed: true,
                  child: Text('Drag this kata onto a camera slot from the library, or open it in the editor to change anything before writing.',
                      style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.5)),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
