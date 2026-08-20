import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../data/recipe.dart';
import '../../data/recipe_specs.dart';

/// Cached (disk + memory) Bunny CDN image, or null when the recipe has no photos.
ImageProvider? recipeImage(String? url) => url == null ? null : CachedNetworkImageProvider(url);

/// Short credit for card corners: "FXW\nIV/V".
String _creditAbbr(Recipe r) {
  final who = r.ofr.sourceAttribution ?? '';
  final abbr = who.isEmpty
      ? (r.source == RecipeSource.published ? 'YOU' : '—')
      : who.split(RegExp(r'\s+')).map((w) => w[0]).take(3).join().toUpperCase();
  final sensors = r.ofr.sensors.map((x) => x.replaceFirst('X-Trans ', '')).join('/');
  return sensors.isEmpty ? abbr : '$abbr\n$sensors';
}

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
      // design 6a: full-bleed 3:2 photo, VERIFIED pill + heart on the photo, footer = swatch | name/spec | credit
      card = KataCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(
            aspectRatio: 3 / 2,
            child: Stack(fit: StackFit.expand, children: [
              FrameSlot(radius: 0, placeholder: 'sample frame · ${r.name}', image: recipeImage(r.imageUrls.firstOrNull)),
              if (r.verified)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 5, height: 5, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                      const SizedBox(width: 6),
                      Text('VERIFIED', style: KataType.monoStyle(size: 9, weight: FontWeight.w500, color: Colors.white, height: 1)),
                    ]),
                  ),
                ),
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: favourite ? Colors.white : Colors.black.withValues(alpha: 0.55),
                  shape: CircleBorder(side: BorderSide(color: favourite ? Colors.transparent : Colors.white.withValues(alpha: 0.3))),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onFavourite,
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: Center(child: Text(favourite ? '♥' : '♡', style: KataType.bodyStyle(size: 14, color: favourite ? Colors.black : Colors.white, height: 1))),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
            child: Row(children: [
              SwatchBars(heights: sw.heights, greys: sw.greys, abbr: RecipeSpecs.filmAbbr(r.ofr), size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 19, color: p.fg, letterSpacing: 0, height: 1.05)),
                  const SizedBox(height: 4),
                  Text(RecipeSpecs.summary(r.ofr).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 11, color: p.dim, height: 1.35)),
                ]),
              ),
              const SizedBox(width: 8),
              Text(_creditAbbr(r), textAlign: TextAlign.right, style: KataType.monoStyle(size: 10, color: p.muted, height: 1.4)),
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

/// 2-up grid tile per design 6b: the photo is the whole tile; name, 2-line spec and a mini swatch
/// sit on a bottom gradient; ✓ (verified) or ♥ (favourite) floats top-right.
class RecipeGridTile extends StatelessWidget {
  const RecipeGridTile({super.key, required this.recipe, required this.favourite, required this.onTap, required this.onFavourite});
  final Recipe recipe;
  final bool favourite;
  final VoidCallback onTap;
  final VoidCallback onFavourite;
  @override
  Widget build(BuildContext context) {
    final r = recipe;
    final sw = RecipeSpecs.swatch(r.ofr);
    const greys = [Colors.white, Color(0xFFD9D9D9), Color(0xFF8A8A8A), Color(0xFF2E2E2E)];
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(fit: StackFit.expand, children: [
          FrameSlot(radius: 0, placeholder: 'frame', image: recipeImage(r.imageUrls.firstOrNull)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.22, 0.45, 1],
                colors: [Color(0x59000000), Color(0x59000000), Color(0x00000000), Color(0xE0000000)],
              ),
            ),
          ),
          Positioned(
            top: 9,
            right: 9,
            child: GestureDetector(
              onTap: onFavourite,
              child: favourite
                  ? Container(width: 26, height: 26, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: const Center(child: Text('♥', style: TextStyle(fontSize: 12, color: Colors.black, height: 1))))
                  : r.verified
                      ? Container(width: 16, height: 16, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: Center(child: Text('✓', style: KataType.bodyStyle(size: 9, weight: FontWeight.w600, color: Colors.black, height: 1))))
                      : Container(width: 26, height: 26, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.4), border: Border.all(color: Colors.white30)), child: const Center(child: Text('♡', style: TextStyle(fontSize: 12, color: Colors.white, height: 1)))),
            ),
          ),
          Positioned(
            left: 11,
            right: 11,
            bottom: 11,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 15, color: Colors.white, letterSpacing: 0, height: 1.05)),
              const SizedBox(height: 5),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Text('${r.ofr.filmSimulation}\n${RecipeSpecs.dr(r.ofr)} · ${RecipeSpecs.wb(r.ofr)}'.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 9, color: const Color(0xFFD9D9D9), height: 1.35)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 22,
                  height: 16,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 1.5),
                      Expanded(child: FractionallySizedBox(heightFactor: sw.heights[i].clamp(0.05, 1), child: ColoredBox(color: greys[sw.greys[i] % 4]))),
                    ],
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
