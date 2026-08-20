import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';

import '../data/recipe.dart';
import '../data/recipe_repository.dart';
import '../data/recipe_specs.dart';
import '../features/library/image_viewer.dart';
import '../features/library/credit_line.dart';
import '../features/library/recipe_card.dart' show recipeImage;
import '../features/history/version_history_sheet.dart';
import '../features/ofr_io/export_sheet.dart';
import '../features/share/share_composer_sheet.dart';
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

/// One frame at a time, filling the pane — a wall of scrolling thumbnails is a contact
/// sheet, not a look at somebody's photograph. Arrows, dots, keyboard, and click to zoom.
class _Carousel extends StatefulWidget {
  const _Carousel({required this.photos, required this.credit});
  final List<String> photos;
  final String credit;
  @override
  State<_Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<_Carousel> {
  final _page = PageController();
  final _focus = FocusNode();
  int _i = 0;

  @override
  void dispose() {
    _page.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_i + delta).clamp(0, widget.photos.length - 1);
    if (next == _i) return;
    _page.animateToPage(next, duration: KataMotion.page, curve: KataMotion.curve);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    if (widget.photos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('NO SAMPLE FRAMES YET', style: KataType.monoStyle(size: 10, color: p.muted, letterSpacing: 0.18)),
        ),
      );
    }
    final many = widget.photos.length > 1;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (_, e) {
        if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
        if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
          _go(1);
          return KeyEventResult.handled;
        }
        if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _go(-1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(children: [
        Expanded(
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: PageView.builder(
                controller: _page,
                onPageChanged: (i) => setState(() => _i = i),
                itemCount: widget.photos.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => showImageViewer(context, urls: widget.photos, initialIndex: i, credit: widget.credit),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FrameSlot(radius: 0, image: recipeImage(widget.photos[i]), fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            if (many) ...[
              Positioned(left: 34, top: 0, bottom: 12, child: Center(child: _Arrow(back: true, enabled: _i > 0, onTap: () => _go(-1)))),
              Positioned(right: 34, top: 0, bottom: 12, child: Center(child: _Arrow(back: false, enabled: _i < widget.photos.length - 1, onTap: () => _go(1)))),
            ],
          ]),
        ),
        if (many)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < widget.photos.length; i++) ...[
                InkWell(
                  onTap: () => _page.animateToPage(i, duration: KataMotion.page, curve: KataMotion.curve),
                  child: Container(
                    width: i == _i ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(color: i == _i ? p.fg : p.hairline, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const SizedBox(width: 8),
              Text('${_i + 1} / ${widget.photos.length}', style: KataType.monoStyle(size: 9.5, color: p.muted, letterSpacing: 0.14)),
            ]),
          ),
      ]),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.back, required this.enabled, required this.onTap});
  final bool back;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Opacity(
      opacity: enabled ? 1 : 0.25,
      child: Material(
        color: p.bg.withValues(alpha: 0.72),
        shape: CircleBorder(side: BorderSide(color: p.hairline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(back ? Icons.arrow_back : Icons.arrow_forward, size: 16, color: p.fg),
          ),
        ),
      ),
    );
  }
}

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
            Expanded(flex: 3, child: _Carousel(photos: photos, credit: r.ofr.sourceAttribution ?? '')),
            // ---- every setting, no scrolling between halves
            Container(
              width: 420,
              decoration: BoxDecoration(border: Border(left: BorderSide(color: p.hairline))),
              child: ListView(padding: const EdgeInsets.fromLTRB(22, 22, 22, 28), children: [
                CreditLine(recipe: r, size: 13),
                const SizedBox(height: 6),
                Text(r.ofr.sensors.join(' · '), style: KataType.monoStyle(size: 10, color: p.muted, letterSpacing: 0.12)),
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
