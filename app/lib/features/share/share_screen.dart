import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../data/recipe.dart';
import '../../data/recipe_repository.dart';
import 'photo_import.dart';
import 'photo_meta.dart';
import 'share_composer_sheet.dart';

/// The kata a photograph was most likely shot on: its film simulation, from
/// the camera's EXIF, against the library. A guess the user can always
/// overrule — the picker comes up either way.
Recipe? matchKata(Iterable<Recipe> all, PhotoMeta meta) {
  final sim = meta.filmMode?.toUpperCase();
  if (sim == null) return null;
  final hits = all.where((r) => r.ofr.filmSimulation.toUpperCase() == sim).toList();
  if (hits.isEmpty) return null;
  // prefer the user's own katas over the library's
  return hits.firstWhere((r) => r.isDraft || r.source == RecipeSource.published, orElse: () => hits.first);
}

/// Confirm the guessed kata or pick another. A page of its own on a phone
/// (nothing about it slides, so no handle); a dialog on a desktop window.
Future<Recipe?> pickKata(BuildContext context, {required List<Recipe> all, required List<Recipe> mine, Recipe? guess, String? filmMode}) {
  final body = KataPicker(all: all, mine: mine, guess: guess, filmMode: filmMode);
  if (MediaQuery.sizeOf(context).width >= 820) {
    return showKataSheet<Recipe>(context, maxWidth: 560, builder: (_) => body);
  }
  return Navigator.of(context).push<Recipe>(MaterialPageRoute(builder: (_) => Scaffold(body: SafeArea(child: body))));
}

/// The picker's body: the guess pinned on top with a one-tap Use, a search
/// field, then Mine and the Library. Pops with the chosen kata.
class KataPicker extends StatefulWidget {
  const KataPicker({super.key, required this.all, required this.mine, this.guess, this.filmMode});
  final List<Recipe> all, mine;
  final Recipe? guess;
  final String? filmMode;
  @override
  State<KataPicker> createState() => _KataPickerState();
}

class _KataPickerState extends State<KataPicker> {
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
    final guess = widget.guess;
    final q = _query.trim().toLowerCase();
    bool hit(Recipe r) => r.id != guess?.id && (q.isEmpty || r.name.toLowerCase().contains(q) || r.ofr.filmSimulation.toLowerCase().contains(q));
    final mine = widget.mine.where(hit).toList();
    final rest = widget.all.where((r) => !widget.mine.any((m) => m.id == r.id)).where(hit).toList();
    final note = guess != null
        ? 'Matched from the photo\u2019s film simulation (${widget.filmMode}). Use it, or pick another.'
        : (widget.filmMode != null ? 'The photo says ${widget.filmMode}, but nothing in the library matches. Pick a kata.' : 'The photo carries no film simulation. Pick a kata.');
    Widget row(Recipe r) => KataListRow(key: ValueKey('pick-${r.id}'), title: r.name, value: r.ofr.filmSimulation.toUpperCase(), onTap: () => Navigator.of(context).pop(r));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            KataIconCircle(size: 36, onPressed: () => Navigator.of(context).pop(), child: Icon(Icons.arrow_back, size: 18, color: p.fg)),
            const SizedBox(width: 12),
            Expanded(child: Text(guess != null ? 'SHOT ON ${guess.name.toUpperCase()}?' : 'WHICH KATA?', maxLines: 2, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 22, color: p.fg))),
          ]),
          const SizedBox(height: 6),
          Text(note, style: KataType.bodyStyle(size: 12, color: p.muted, height: 1.4)),
          const SizedBox(height: 12),
          if (guess != null) ...[
            KataPillButton(label: 'Use ${guess.name}', height: 44, onPressed: () => Navigator.of(context).pop(guess)),
            const SizedBox(height: 12),
          ],
          KataSearchField(hint: 'Search katas, film sims', controller: _search, onChanged: (v) => setState(() => _query = v)),
        ]),
      ),
      Flexible(
        child: (mine.isEmpty && rest.isEmpty)
            ? Padding(padding: const EdgeInsets.all(24), child: Center(child: KataEmptyState(glyph: '0', title: 'No katas match')))
            : ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
                if (mine.isNotEmpty) ...[
                  KataSectionHeader('Mine'),
                  for (final r in mine) row(r),
                  const SizedBox(height: 14),
                ],
                if (rest.isNotEmpty) ...[
                  KataSectionHeader(guess != null ? 'Or pick' : 'Library'),
                  for (final r in rest) row(r),
                ],
              ]),
      ),
    ]);
  }
}

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

  /// Start from the photograph: read what the camera wrote, guess the kata,
  /// let the user confirm or pick another, then open the composer with the
  /// photo already on the card.
  Future<void> _fromPhoto({bool gallery = true}) async {
    final res = gallery
        ? await FilePicker.platform.pickFiles(dialogTitle: 'Choose a photo', type: FileType.image, withData: true)
        : await FilePicker.platform.pickFiles(dialogTitle: 'Choose a photo', type: FileType.custom, allowedExtensions: sharePhotoExtensions, withData: true);
    final raw = res?.files.firstOrNull?.bytes;
    if (raw == null || !mounted) return;
    final usable = await prepareSharePhoto(raw);
    if (!mounted) return;
    if (usable == null) {
      KataToast.show(context, "Couldn't read an image out of that file");
      return;
    }
    final meta = await readPhotoMeta(usable);
    if (!mounted) return;
    final repo = ref.read(recipeRepositoryProvider);
    final guess = matchKata(repo.all, meta);
    final picked = await pickKata(context, all: repo.all.toList(), mine: repo.mine.toList(), guess: guess, filmMode: meta.filmMode);
    if (picked == null || !mounted) return;
    await showShareComposer(context, picked, photos: [usable]);
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
              // the other way in: the photograph first, the kata read off it
              Row(children: [
                Expanded(child: KataPillButton(label: 'From a photo', height: 40, onPressed: () => _fromPhoto())),
                const SizedBox(width: 8),
                KataPillButton(label: 'RAW file', kind: KataButtonKind.secondary, display: false, expand: false, height: 40, onPressed: () => _fromPhoto(gallery: false)),
              ]),
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
