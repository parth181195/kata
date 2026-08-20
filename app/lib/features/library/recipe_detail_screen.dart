import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/fuji/camera_service.dart';
import '../../core/net/api_client.dart';
import '../../data/recipe_repository.dart';
import '../../data/recipe.dart';
import '../../data/recipe_specs.dart';
import '../camera/write_sheet.dart';
import '../ofr_io/export_sheet.dart';
import '../history/version_history_sheet.dart';
import '../share/share_composer_sheet.dart';
import 'image_viewer.dart';
import 'credit_line.dart';
import 'support_card.dart';
import 'recipe_card.dart';

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.kata;
    final lib = ref.watch(recipeRepositoryProvider);
    final recipe = lib.byId(id);
    if (recipe == null) {
      return Scaffold(body: SafeArea(child: Center(child: KataEmptyState(glyph: '?', title: 'Kata not found', actionLabel: 'Back', onAction: () => context.pop()))));
    }
    final cam = ref.watch(cameraServiceProvider);
    final ready = cam is CameraReady && !cam.busy;
    final fav = lib.favourites.contains(recipe.id);
    final sw = RecipeSpecs.swatch(recipe.ofr);

    final statusPill = cam is CameraReady
        ? KataStatusPill(KataStatus.connected, label: '${cam.caps.model} · C1–C${cam.caps.slotCount}')
        : const KataStatusPill(KataStatus.noCamera);

    Widget circle(Widget child, {VoidCallback? onTap}) => Material(
          color: Colors.black.withValues(alpha: 0.6),
          shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.55))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: SizedBox(width: 36, height: 36, child: Center(child: child))),
        );

    final me = ref.read(sessionProvider).valueOrNull?.user;
    final isOwn = recipe.source == RecipeSource.published || recipe.isDraft || (recipe.authorId != null && recipe.authorId == me?.id);
    final isDraft = recipe.isDraft;

    Future<void> exportAs(String what) async {
      switch (what) {
        case 'json':
          await showExportSheet(context, recipe);
        case 'png':
          await showShareComposer(context, recipe);
        case 'code':
          await Clipboard.setData(ClipboardData(text: KataCode.encode(recipe.ofr)));
          if (context.mounted) KataToast.show(context, 'Kata Code copied');
        case 'text':
          await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(recipe.ofr.toJson())));
          if (context.mounted) KataToast.show(context, 'OFR JSON copied');
      }
    }

    // 5b: primary actions (edit, write) are never only in the overflow; destructive last, red.
    Future<void> overflow() async {
      const exportSub = [
        KataMenuItem('json', '.ofr.json'),
        KataMenuItem('png', 'PNG card'),
        KataMenuItem('code', 'Kata Code'),
        KataMenuItem('text', 'Plain text'),
      ];
      final items = isOwn
          ? <KataMenuItem<String>>[
              const KataMenuItem('edit', 'Edit kata', icon: Icons.edit_outlined),
              KataMenuItem('write', 'Write to slot…', icon: Icons.usb_outlined, enabled: ready),
              const KataMenuItem('dup', 'Duplicate', icon: Icons.copy_outlined),
              const KataMenuItem('share', 'Share card…', icon: Icons.ios_share_outlined),
              const KataMenuDivider('d1'),
              const KataMenuItem('export', 'Export as', icon: Icons.file_download_outlined, submenu: exportSub),
              KataMenuItem('history', 'Version history', icon: Icons.history, enabled: !isDraft),
              if (isDraft) const KataMenuItem('publish', 'Publish to library', icon: Icons.public_outlined),
              const KataMenuDivider('d2'),
              if (isDraft)
                const KataMenuItem('delete', 'Delete', icon: Icons.delete_outline, destructive: true)
              else
                const KataMenuItem('unpublish', 'Unpublish', icon: Icons.undo_outlined, destructive: true),
            ]
          : <KataMenuItem<String>>[
              const KataMenuItem('dup', 'Duplicate to edit', icon: Icons.edit_outlined, trailing: 'Copy in Mine'),
              KataMenuItem('save', fav ? 'Remove from Saved' : 'Save to Mine', icon: fav ? Icons.bookmark : Icons.bookmark_outline),
              const KataMenuItem('share', 'Share card…', icon: Icons.ios_share_outlined),
              const KataMenuItem('code', 'Copy as text', icon: Icons.data_object, trailing: 'kata1:'),
              const KataMenuItem('export', 'Export as', icon: Icons.file_download_outlined, submenu: exportSub),
              KataMenuItem('source', 'View source post', icon: Icons.open_in_new, enabled: recipe.ofr.sourceUrl != null),
              const KataMenuDivider('d1'),
              const KataMenuItem('report', 'Report recipe', icon: Icons.flag_outlined, destructive: true),
            ];
      final pos = Offset(MediaQuery.sizeOf(context).width - 20, MediaQuery.paddingOf(context).top + 60);
      final pick = await showKataMenu<String>(context, title: recipe.name, position: pos, items: items);
      if (pick == null || !context.mounted) return;
      switch (pick) {
        case 'edit':
          context.push('/edit/${recipe.id}');
        case 'write':
          await showWriteSheet(context, recipe);
        case 'history':
          await showVersionHistory(context, recipe);
        case 'dup':
          context.push('/new?from=${recipe.id}');
        case 'share':
          await showShareComposer(context, recipe);
        case 'save':
          await ref.read(recipeRepositoryProvider).toggleFavourite(recipe.id);
          if (context.mounted) KataToast.show(context, fav ? 'Removed from Saved' : 'Saved');
        case 'code' || 'json' || 'png' || 'text':
          await exportAs(pick);
        case 'source':
          await launchUrl(Uri.parse(recipe.ofr.sourceUrl!), mode: LaunchMode.externalApplication);
        case 'publish':
          context.push('/edit/${recipe.id}');
        case 'delete':
          await ref.read(recipeRepositoryProvider).remove(recipe.id);
          if (context.mounted) context.pop();
        case 'unpublish':
          final ok = await showKataDialog(context, title: 'Unpublish “${recipe.name}”?', body: 'It disappears from the community library for everyone.', confirmLabel: 'Unpublish', destructive: true);
          if (ok == true && context.mounted) {
            try {
              await ref.read(recipeRepositoryProvider).unpublish(recipe.id);
              if (context.mounted) {
                KataToast.show(context, 'Unpublished');
                context.pop();
              }
            } on ApiException catch (e) {
              if (context.mounted) KataToast.show(context, e.isNetwork ? 'No connection' : e.message);
            }
          }
        case 'report':
          await _report(context, ref, recipe);
      }
    }


    return Scaffold(
      body: Column(children: [
        Expanded(
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: 300,
                // where the photograph stops: a dark frame otherwise bleeds into the page and
                // you can't tell the picture from the background
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hairline))),
                child: Stack(fit: StackFit.expand, children: [
                  FrameSlot(radius: 0, placeholder: 'hero sample frame · shot with this kata', image: recipeImage(recipe.imageUrls.firstOrNull)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, 0.12, 0.4, 1], colors: [Color(0x99000000), Color(0x99000000), Color(0x00000000), Color(0xD9000000)]),
                    ),
                  ),
                  // tap the hero to open the viewer (photos only)
                  if (recipe.imageUrls.isNotEmpty)
                    Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => showImageViewer(context, urls: recipe.imageUrls, credit: attributionLine(recipe)))),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          circle(Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white), onTap: () => context.pop()),
                          DecoratedBox(
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(15)),
                            child: statusPill,
                          ),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            if (isOwn) ...[
                              circle(const Icon(Icons.edit_outlined, size: 15, color: Colors.white), onTap: () => context.push('/edit/${recipe.id}')),
                              const SizedBox(width: 8),
                            ],
                            circle(const Icon(Icons.more_vert, size: 16, color: Colors.white), onTap: overflow),
                          ]),
                        ]),
                      ),
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
                  // tapping the credit opens the write-up it came from, rather than
                  // copying a link and leaving you to paste it somewhere
                  Expanded(child: CreditLine(recipe: recipe, size: 11.5)),
                  const SizedBox(width: 10),
                  for (final s in recipe.ofr.sensors.take(2)) ...[
                    Container(height: 24, padding: const EdgeInsets.symmetric(horizontal: 10), alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: p.hairline)),
                        child: Text(s.replaceFirst('X-Trans ', 'X-T ').toUpperCase(), style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.dim))),
                    const SizedBox(width: 6),
                  ],
                ]),
                // Extra frames beyond the hero — only the ones that exist. Tiles keep the width
                // they would have in a full row of three, so one or two photos don't stretch.
                if (recipe.imageUrls.length > 1) ...[
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, box) {
                      final extras = recipe.imageUrls.skip(1).take(3).toList();
                      final tile = (box.maxWidth - 12) / 3;
                      return SizedBox(
                        height: 72,
                        child: Row(children: [
                          for (var i = 0; i < extras.length; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            SizedBox(
                              width: tile,
                              child: GestureDetector(
                                onTap: () => showImageViewer(context, urls: recipe.imageUrls, initialIndex: 1 + i, credit: attributionLine(recipe)),
                                child: FrameSlot(radius: 8, image: recipeImage(extras[i])),
                              ),
                            ),
                          ],
                        ]),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                const EyebrowDivider('Q-menu order'),
                const SizedBox(height: 16),
                SpecGrid(RecipeSpecs.items(recipe.ofr)),
                if (SupportCard.isFxw(recipe)) ...[
                  const SizedBox(height: 16),
                  SupportCard(recipe: recipe),
                ],
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
              // share, not a second ⋮: the one in the top bar already opens the menu, and its
              // sheet anchored up there anyway
              KataIconCircle(
                onPressed: () => showShareComposer(context, recipe),
                child: Icon(Icons.ios_share_outlined, size: 19, color: p.dim),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

const _reportReasons = ['Wrong attribution or missing credit', 'Settings are wrong / not what the source says', 'Duplicate of another kata', 'Spam or not a recipe', 'Something else'];

Future<void> _report(BuildContext context, WidgetRef ref, Recipe recipe) async {
  final reason = await showKataPicker(context, eyebrow: 'Report', title: recipe.name, options: _reportReasons);
  if (reason == null || !context.mounted) return;
  try {
    await ref.read(recipeRepositoryProvider).report(recipe.id, reason);
    if (context.mounted) KataToast.show(context, 'Thanks — sent to the curators');
  } on ApiException catch (e) {
    if (context.mounted) KataToast.show(context, e.isNetwork ? 'No connection — try again later' : e.message);
  }
}
