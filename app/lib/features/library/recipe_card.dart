import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../data/recipe.dart';
import '../../data/recipe_specs.dart';

String attributionLine(Recipe r) {
  final who = r.ofr.sourceAttribution ?? (r.source == RecipeSource.camera ? 'From camera' : 'Imported');
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
              Positioned.fill(child: FrameSlot(radius: 0, placeholder: 'sample frame · ${r.name}', image: r.imageUrls.isEmpty ? null : NetworkImage(r.imageUrls.first))),
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
          SizedBox(width: 78, height: 78, child: FrameSlot(placeholder: 'frame', image: r.imageUrls.isEmpty ? null : NetworkImage(r.imageUrls.first))),
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
