import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../core/fuji/camera_service.dart';
import '../../data/local_library.dart';
import '../../data/recipe.dart';
import '../../data/recipe_specs.dart';
import '../camera/write_sheet.dart';
import '../ofr_io/export_sheet.dart';
import 'recipe_card.dart';

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    final lib = ref.watch(localLibraryProvider);
    final recipe = lib.lib.byId(id);
    if (recipe == null) {
      return Scaffold(body: SafeArea(child: Center(child: KataEmptyState(glyph: '?', title: 'Kata not found', actionLabel: 'Back', onAction: () => context.pop()))));
    }
    final cam = ref.watch(cameraServiceProvider);
    final ready = cam is CameraReady && !cam.busy;
    final fav = lib.lib.favourites.contains(recipe.id);
    final sw = RecipeSpecs.swatch(recipe.ofr);

    final statusPill = cam is CameraReady
        ? KataStatusPill(KataStatus.connected, label: '${cam.caps.model} · C1–C${cam.caps.slotCount}')
        : const KataStatusPill(KataStatus.noCamera);

    Widget circle(Widget child, {VoidCallback? onTap}) => Material(
          color: Colors.black.withValues(alpha: 0.4),
          shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.4))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: SizedBox(width: 36, height: 36, child: Center(child: child))),
        );

    void overflow() => showKataSheet(context, builder: (c) => KataSheet(eyebrow: 'Kata', title: recipe.name, children: [
          KataListRow(title: 'Export OFR', value: '.ofr.json', onTap: () { Navigator.of(c).pop(); showExportSheet(context, recipe); }),
          KataListRow(title: 'Copy source link', value: recipe.ofr.sourceUrl == null ? '—' : 'URL', enabled: recipe.ofr.sourceUrl != null, onTap: () async {
            await Clipboard.setData(ClipboardData(text: recipe.ofr.sourceUrl!));
            if (c.mounted) Navigator.of(c).pop();
            if (context.mounted) KataToast.show(context, 'Link copied');
          }),
          const KataListRow(title: 'Report', value: 'Stage 3', enabled: false),
          if (recipe.source != RecipeSource.seed)
            KataListRow(title: 'Remove from Mine', value: 'Delete', onTap: () async {
              Navigator.of(c).pop();
              await ref.read(localLibraryProvider).remove(recipe.id);
              if (context.mounted) context.pop();
            }),
        ]));

    return Scaffold(
      body: Column(children: [
        Expanded(
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: 300,
                child: Stack(fit: StackFit.expand, children: [
                  FrameSlot(radius: 0, placeholder: 'hero sample frame · shot with this kata', image: recipe.imageUrls.isEmpty ? null : NetworkImage(recipe.imageUrls.first)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, 0.12, 0.4, 1], colors: [Color(0x99000000), Color(0x99000000), Color(0x00000000), Color(0xD9000000)]),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        circle(Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white), onTap: () => context.pop()),
                        statusPill,
                        circle(Icon(Icons.more_vert, size: 16, color: Colors.white), onTap: overflow),
                      ]),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 14,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(recipe.name.toUpperCase(), maxLines: 2, style: KataType.displayStyle(size: 30, color: Colors.white, letterSpacing: 0, height: 1))),
                            if (recipe.verified) ...[const SizedBox(width: 8), const VerifiedBadge(size: 17)],
                          ]),
                          const SizedBox(height: 6),
                          Text(RecipeSpecs.summary(recipe.ofr).toUpperCase(), style: KataType.monoStyle(size: 11.5, color: KataColors.grey300, height: 1.4)),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      SwatchBars(heights: sw.heights, greys: sw.greys, abbr: RecipeSpecs.filmAbbr(recipe.ofr)),
                    ]),
                  ),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              sliver: SliverList.list(children: [
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: recipe.ofr.sourceUrl == null ? null : () async {
                        await Clipboard.setData(ClipboardData(text: recipe.ofr.sourceUrl!));
                        if (context.mounted) KataToast.show(context, 'Link copied');
                      },
                      child: Text(
                        recipe.ofr.sourceUrl == null ? attributionLine(recipe) : '${recipe.ofr.sourceAttribution ?? 'Source'} — ${Uri.tryParse(recipe.ofr.sourceUrl!)?.host ?? recipe.ofr.sourceUrl} ↗',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KataType.bodyStyle(size: 11.5, color: p.dim, height: 1.4).copyWith(decoration: recipe.ofr.sourceUrl == null ? null : TextDecoration.underline, decorationColor: p.dim),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  for (final s in recipe.ofr.sensors.take(2)) ...[
                    Container(height: 24, padding: const EdgeInsets.symmetric(horizontal: 10), alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: p.hairline)),
                        child: Text(s.replaceFirst('X-Trans ', 'X-T ').toUpperCase(), style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.dim))),
                    const SizedBox(width: 6),
                  ],
                ]),
                const SizedBox(height: 16),
                SizedBox(height: 72, child: Row(children: [for (var i = 0; i < 3; i++) ...[if (i > 0) const SizedBox(width: 6), const Expanded(child: FrameSlot(radius: 8, placeholder: 'frame'))]])),
                const SizedBox(height: 16),
                const EyebrowDivider('Q-menu order'),
                const SizedBox(height: 16),
                SpecGrid(RecipeSpecs.items(recipe.ofr)),
                const SizedBox(height: 16),
                if (!ready)
                  KataCard(
                    radius: 16,
                    padding: const EdgeInsets.all(13),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(shape: BoxShape.circle, color: p.fg)),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Connect on the Camera tab to enable writing. The kata stays saved either way.', style: KataType.bodyStyle(size: 11.5, color: p.dim, height: 1.5))),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
        Container(
          decoration: BoxDecoration(color: p.bg, border: Border(top: BorderSide(color: p.dark ? p.surface : p.hairline))),
          padding: const EdgeInsets.fromLTRB(20, 13, 20, 16),
          child: SafeArea(
            top: false,
            child: Row(children: [
              KataIconCircle(filled: fav, onPressed: () => lib.toggleFavourite(recipe.id), child: Text(fav ? '♥' : '♡', style: KataType.bodyStyle(size: 16, color: fav ? p.bg : p.dim, height: 1))),
              const SizedBox(width: 13),
              Expanded(
                child: KataPillButton(
                  label: 'Write to camera',
                  leading: Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ready ? p.bg : p.muted, width: 2))),
                  onPressed: ready ? () => showWriteSheet(context, recipe) : null,
                ),
              ),
              const SizedBox(width: 13),
              KataIconCircle(onPressed: overflow, child: Icon(Icons.more_vert, size: 18, color: p.dim)),
            ]),
          ),
        ),
      ]),
    );
  }
}
