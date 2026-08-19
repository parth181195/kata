import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../data/recipe.dart';
import '../../data/recipe_specs.dart';

/// Cached (disk + memory) Bunny CDN image, or null when the recipe has no photos.
ImageProvider? recipeImage(String? url) => url == null ? null : CachedNetworkImageProvider(url);

String attributionLine(Recipe r) {
  final who = r.ofr.sourceAttribution ?? switch (r.source) { RecipeSource.camera => 'From camera', RecipeSource.published => 'Yours', RecipeSource.imported => 'Draft', RecipeSource.seed => 'Community' };
  final sensors = r.ofr.sensors.isEmpty ? '' : ' · ${r.ofr.sensors.map((s) => s.replaceFirst('X-Trans ', 'X-Trans ')).join('/')}';
  return '$who$sensors';
}

/// Library card. `hero` = full-bleed variant with 168px frame + 3-value footer; otherwise compact 78px thumb row.
class RecipeCard extends StatelessWidget {
  const RecipeCard({super.key, required this.recipe, required this.favourite, required this.onTap, required this.onFavourite, this.hero = false, this.dimmed = false});
  final Recipe recipe;
  final bool favourite;
  final VoidCallback onTap;
  final VoidCallback onFavourite;
  final bool hero;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final r = recipe;
    final sw = RecipeSpecs.swatch(r.ofr);
    final heart = KataIconCircle(
      size: 34,
      filled: favourite,
      onPressed: onFavourite,
      child: Text(favourite ? '♥' : '♡', style: KataType.bodyStyle(size: 14, color: favourite ? p.bg : p.muted, height: 1)),
    );
    final nameRow = Row(children: [
      Flexible(child: Text(r.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: hero ? 19 : 18, color: p.fg, letterSpacing: 0))),
      if (r.verified) ...[const SizedBox(width: 7), const VerifiedBadge()],
    ]);
    final summary = Text(RecipeSpecs.summary(r.ofr), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 11.5, color: p.dim, height: 1.35));
    final attribution = Text(attributionLine(r), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 11, color: p.muted, height: 1.3));

    Widget card;
    if (hero) {
      card = KataCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 168,
            child: Stack(children: [
              Positioned.fill(child: FrameSlot(radius: 0, placeholder: 'sample frame · ${r.name}', image: recipeImage(r.imageUrls.firstOrNull))),
              Positioned(top: 10, right: 10, child: heart),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SwatchBars(heights: sw.heights, greys: sw.greys, abbr: RecipeSpecs.filmAbbr(r.ofr)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [nameRow, const SizedBox(height: 4), summary, const SizedBox(height: 4), attribution])),
              ]),
              const SizedBox(height: 11),
              const DottedDivider(),
              const SizedBox(height: 10),
              SpecGrid(RecipeSpecs.compact(r.ofr), valueSize: 14, rowGap: 0),
            ]),
          ),
        ]),
      );
    } else {
      card = KataCard(
        padding: const EdgeInsets.all(13),
        onTap: onTap,
        child: Row(children: [
          SizedBox(width: 78, height: 78, child: FrameSlot(placeholder: 'frame', image: recipeImage(r.imageUrls.firstOrNull))),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              nameRow,
              const SizedBox(height: 4),
              summary,
              const SizedBox(height: 4),
              attribution,
              const SizedBox(height: 4),
              SwatchBars(heights: sw.heights, greys: sw.greys, size: 16),
            ]),
          ),
          const SizedBox(width: 10),
          heart,
        ]),
      );
    }
    return dimmed ? Opacity(opacity: 0.5, child: card) : card;
  }
}

/// 2-up grid tile: photo (or dot grid), name, film sim · DR, heart. Square-ish; used by the GRID library layout.
class RecipeGridTile extends StatelessWidget {
  const RecipeGridTile({super.key, required this.recipe, required this.favourite, required this.onTap, required this.onFavourite});
  final Recipe recipe;
  final bool favourite;
  final VoidCallback onTap;
  final VoidCallback onFavourite;
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final r = recipe;
    return KataCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(fit: StackFit.expand, children: [
            FrameSlot(radius: 0, placeholder: 'frame', image: recipeImage(r.imageUrls.firstOrNull)),
            Positioned(
              top: 8,
              right: 8,
              child: KataIconCircle(
                size: 30,
                filled: favourite,
                onPressed: onFavourite,
                child: Text(favourite ? '♥' : '♡', style: KataType.bodyStyle(size: 12, color: favourite ? p.bg : Colors.white, height: 1)),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(r.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 13.5, color: p.fg, letterSpacing: 0))),
              if (r.verified) ...[const SizedBox(width: 5), const VerifiedBadge(size: 13)],
            ]),
            const SizedBox(height: 3),
            Text(RecipeSpecs.summary(r.ofr), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 9.5, color: p.dim, height: 1.3)),
          ]),
        ),
      ]),
    );
  }
}
