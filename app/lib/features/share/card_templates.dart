import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../../data/recipe.dart';
import '../../data/recipe_specs.dart';
import 'kata_code_qr.dart';

/// A share is always a pair: the photograph on one page, the recipe on the
/// other, never both on one. A template is the style the pair is drawn in.
enum ShareTemplate { card, sheet, story }

/// Which page of the pair.
enum SharePage { photo, recipe }

extension ShareTemplateX on ShareTemplate {
  String get code => switch (this) { ShareTemplate.card => 'S1', ShareTemplate.sheet => 'S2', ShareTemplate.story => 'S3' };
  String get label => switch (this) { ShareTemplate.card => 'CARD', ShareTemplate.sheet => 'SHEET', ShareTemplate.story => 'STORY' };

  /// The small tag at the top right of both pages — what ties them as a set.
  String get tag => switch (this) { ShareTemplate.card => 'S1 · RECIPE CARD', ShareTemplate.sheet => 'S2 · CONTACT SHEET', ShareTemplate.story => 'S3 · STORY' };
}

extension SharePageX on SharePage {
  String get label => switch (this) { SharePage.photo => 'PHOTO', SharePage.recipe => 'RECIPE' };
}

enum ShareRatio { r4x5, r1x1, r9x16 }

extension ShareRatioX on ShareRatio {
  String get label => switch (this) { ShareRatio.r4x5 => '4:5', ShareRatio.r1x1 => '1:1', ShareRatio.r9x16 => '9:16' };
  double get aspect => switch (this) { ShareRatio.r4x5 => 4 / 5, ShareRatio.r1x1 => 1, ShareRatio.r9x16 => 9 / 16 };
}

/// Everything a template needs. Cards are laid out at a logical width of [kCardWidth] and
/// rendered at [kCardPixelRatio]×.
class ShareSpec {
  const ShareSpec({
    required this.recipe,
    required this.template,
    this.page = SharePage.recipe,
    required this.ratio,
    this.inverted = false,
    this.outline = false,
    this.roundCorners = true,
    this.embedCode = true,
    required this.credit,
    this.imageFor = _network,
    this.photos = const [],
  });
  final Recipe recipe;

  /// The user's own photograph for page 1 (index 0); absent, the recipe's
  /// own sample stands in. Bytes are already decodable — RAW previews are
  /// extracted upstream.
  final List<Uint8List?> photos;

  /// How a sample-frame URL becomes an image. The network by default; a test
  /// hands in a provider it controls, so the export's wait for the photo can be
  /// exercised without one.
  final ImageProvider Function(String url) imageFor;
  static ImageProvider _network(String url) => CachedNetworkImageProvider(url);
  final ShareTemplate template;
  final SharePage page;
  final ShareRatio ratio;
  final bool inverted;

  /// A thin rule just inside the card's edge — a black card on a dark feed
  /// has no edge of its own without one.
  final bool outline;

  /// Round the photograph's corners (the default), or keep them square.
  final bool roundCorners;
  final bool embedCode;
  final String credit;
  String get payload => KataCode.encode(recipe.ofr, credit: credit);
  int get settingsCount => recipe.ofr.settingsJson().length;
}

const kCardWidth = 390.0;

/// The file a page is saved or shared as: `kata-<five digits>-<date>-<page>.png`.
///
/// Five digits from the recipe id — the id itself when it is numeric, else a
/// stable hash of it — so two recipes saved the same day never collide, and
/// the photo and the recipe page of one pair sit beside each other as -1 and -2.
String shareFileName(Recipe r, SharePage page, {DateTime? now}) {
  final d = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return 'kata-${recipeCode5(r.id)}-${d.year}${two(d.month)}${two(d.day)}-${page == SharePage.photo ? 1 : 2}.png';
}

/// Five digits for a recipe id: the last five of a numeric id, a hash otherwise.
String recipeCode5(String id) {
  if (RegExp(r'^\d+$').hasMatch(id)) return id.padLeft(5, '0').substring(id.length > 5 ? id.length - 5 : 0);
  // FNV-1a over the UTF-8 bytes — the same five digits on every platform
  var h = 0x811C9DC5;
  for (final b in id.codeUnits) {
    h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF;
  }
  return (h % 100000).toString().padLeft(5, '0');
}

/// Export scale. 4× puts the card at 1560px wide — about what WhatsApp and Instagram
/// downscale to, so the QR arrives with whole pixels per module instead of mush.
const kCardPixelRatio = 4.0;

/// Pixels per QR module in the exported PNG, below which a recompressed
/// screenshot stops scanning reliably.
const kMinQrPxPerModule = 5.0;

/// The side of the QR on the templates that give it a fixed slot.
///
/// Sized from the payload, not from taste. A Kata Code carries the settings plus
/// the name, the attribution and the source URL, and none of those three are
/// bounded — a Japanese name with a Japanese attribution percent-encodes to about
/// 384 bytes, which is a 77-module code and needs 115px to stay scannable. The
/// old slots were 104–124 and that recipe came out unscannable on two of the four
/// templates. 128 covers a 120-character name *and* a 120-character attribution
/// *and* a long URL; share_qr_test.dart measures the rendered code and fails if a
/// payload ever outgrows it again.
const kQrSlot = 128.0;

/// Palette for a card: white card / black ink by default; inverted flips.
class _Ink {
  _Ink(bool inv) : bg = inv ? Colors.black : Colors.white, fg = inv ? Colors.white : Colors.black, mid = inv ? KataColors.grey300 : KataColors.grey700, mute = KataColors.grey500, rule = inv ? KataColors.grey700 : KataColors.grey300, frame = inv ? const Color(0xFF141414) : const Color(0xFFF2F2F2);
  final Color bg, fg, mid, mute, rule, frame;
}

/// Builds the card for [spec] at [kCardWidth] × (width / aspect).
class ShareCard extends StatelessWidget {
  const ShareCard(this.spec, {super.key});
  final ShareSpec spec;

  @override
  Widget build(BuildContext context) {
    final ink = _Ink(spec.inverted);
    final h = kCardWidth / spec.ratio.aspect;
    final body = switch ((spec.template, spec.page)) {
      (ShareTemplate.card, SharePage.photo) => _S1Photo(spec, ink),
      (ShareTemplate.card, SharePage.recipe) => _S1Recipe(spec, ink),
      (ShareTemplate.sheet, SharePage.photo) => _S2Photo(spec, ink),
      (ShareTemplate.sheet, SharePage.recipe) => _S2Recipe(spec, ink),
      (ShareTemplate.story, SharePage.photo) => _S3Photo(spec, ink),
      (ShareTemplate.story, SharePage.recipe) => _S3Recipe(spec, ink),
    };
    // cards are white by default (light palette), inverted = dark palette — so kata_ui widgets inside pick the right greys
    return Theme(
      data: spec.inverted ? KataTheme.dark() : KataTheme.light(),
      child: Container(
        width: kCardWidth,
        height: h,
        color: ink.bg,
        // the outline is drawn over the content, inset by its own width, so
        // nothing on the card moves when it is turned on
        foregroundDecoration: spec.outline ? BoxDecoration(border: Border.all(color: ink.rule, width: 1.5)) : null,
        child: DefaultTextStyle(style: TextStyle(color: ink.fg), child: body),
      ),
    );
  }
}

// ---------------------------------------------------------------- pieces

/// The header both pages share: the wordmark, and the template's tag.
Widget _header(_Ink ink, ShareSpec spec) => _wordmark(ink, right: spec.template.tag);

/// The name line both pages share: the name, `FILM SIM · SENSOR` under it,
/// the swatch bars and the film's short mark to the right.
Widget _nameLine(_Ink ink, Recipe r, {double size = 22, int maxLines = 2, String? sub}) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(r.name.toUpperCase(), maxLines: maxLines, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: size, color: ink.fg, letterSpacing: 0, height: 1.02)),
      const SizedBox(height: 5),
      Text((sub ?? '${r.ofr.filmSimulation} · ${r.ofr.sensors.isEmpty ? 'ANY SENSOR' : r.ofr.sensors.join('/')}').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 8.5, weight: FontWeight.w500, color: ink.mute, height: 1).copyWith(letterSpacing: 8.5 * 0.16)),
    ]),
  ),
  const SizedBox(width: 12),
  SwatchBars(values: RecipeSpecs.swatch(r.ofr), abbr: RecipeSpecs.filmAbbr(r.ofr)),
]);

Widget _wordmark(_Ink ink, {String? right}) => Row(children: [
  Text('KATA 型', style: KataType.displayStyle(size: 14, weight: FontWeight.w900, color: ink.fg, letterSpacing: 0.05)),
  const Spacer(),
  if (right != null) Text(right, style: KataType.bodyStyle(size: 8.5, weight: FontWeight.w500, color: ink.mute, height: 1).copyWith(letterSpacing: 8.5 * 0.16)),
]);

Widget _frame(_Ink ink, ShareSpec spec, {double? height, int index = 0, double radius = 4}) {
  final r = spec.recipe;
  final url = r.imageUrls.length > index ? r.imageUrls[index] : null;
  // the user's photo for this frame, else the recipe's own sample
  final own = index < spec.photos.length ? spec.photos[index] : null;
  return ClipRRect(
    borderRadius: BorderRadius.circular(spec.roundCorners ? radius : 0),
    child: Container(
      height: height,
      color: ink.frame,
      child: own != null
          // decoded no larger than the export needs (1560px wide at 4×): a
          // 24MP photo at full size is a texture the GPU has no reason to hold
          ? Image(image: ResizeImage(MemoryImage(own), width: 2600, height: 2600, policy: ResizeImagePolicy.fit), fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true)
          : url == null
              ? CustomPaint(painter: _Dots(ink.rule), child: Center(child: Text('SAMPLE FRAME', style: KataType.monoStyle(size: 8, color: ink.mute, letterSpacing: 0.12))))
              : Image(image: spec.imageFor(url), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
    ),
  );
}

Widget _kv(_Ink ink, String k, String v, {double vs = 11}) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
  Text(k.toUpperCase(), style: KataType.bodyStyle(size: 7.5, weight: FontWeight.w500, color: ink.mute, height: 1).copyWith(letterSpacing: 7.5 * 0.16)),
  const SizedBox(height: 3),
  Text(v, style: KataType.monoStyle(size: vs, color: ink.fg, height: 1)),
]);

Widget _qrBlock(ShareSpec spec, _Ink ink, double size) => spec.embedCode
    ? KataCodeQr(payload: spec.payload, size: size, inverted: spec.inverted)
    : SizedBox(width: size, height: size, child: Center(child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: ink.mute))));

class _Dots extends CustomPainter {
  _Dots(this.c);
  final Color c;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = c;
    for (var y = 6.0; y < s.height; y += 12) {
      for (var x = 6.0; x < s.width; x += 12) {
        canvas.drawCircle(Offset(x, y), 0.8, p);
      }
    }
  }

  @override
  bool shouldRepaint(_Dots o) => o.c != c;
}

// ---------------------------------------------------------------- S1 recipe card

/// Page 1: the photograph, the name under it.
class _S1Photo extends StatelessWidget {
  const _S1Photo(this.spec, this.ink);
  final ShareSpec spec;
  final _Ink ink;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _header(ink, spec),
          const SizedBox(height: 14),
          Expanded(child: _frame(ink, spec)),
          const SizedBox(height: 14),
          _nameLine(ink, spec.recipe),
        ]),
      );
}

/// Page 2: every setting, the credit and the code. No picture — the pair
/// carries it on page 1.
class _S1Recipe extends StatelessWidget {
  const _S1Recipe(this.spec, this.ink);
  final ShareSpec spec;
  final _Ink ink;
  @override
  Widget build(BuildContext context) {
    final r = spec.recipe;
    final items = RecipeSpecs.items(r.ofr, rulers: false);
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(ink, spec),
        const SizedBox(height: 14),
        _nameLine(ink, r),
        const SizedBox(height: 11),
        Container(height: 1, decoration: BoxDecoration(border: Border(top: BorderSide(color: ink.rule, style: BorderStyle.solid)))),
        const SizedBox(height: 10),
        // Every setting, in as many rows as it takes. A fixed childAspectRatio
        // with a fixed take(12) dropped the last row off every colour recipe —
        // Clarity, silently. So the grid takes the height its rows need, and
        // the air between it and the code is what yields.
        _SettingsGrid(items: items, ink: ink),
        const Spacer(),
        Container(height: 1, color: ink.fg),
        const SizedBox(height: 10),
        SizedBox(
          height: kQrSlot,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(spec.credit, maxLines: 2, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 10, weight: FontWeight.w600, color: ink.fg, height: 1.2)),
                const SizedBox(height: 4),
                Text('SCAN TO IMPORT · ${spec.settingsCount} SETTINGS', style: KataType.monoStyle(size: 8, color: ink.mute, letterSpacing: 0.1)),
              ]),
            ),
            const SizedBox(width: 12),
            _qrBlock(spec, ink, kQrSlot),
          ]),
        ),
      ]),
    );
  }
}

/// The settings, two columns, every row the height its type needs. Not a
/// GridView: a grid divides the height it is given, and a card is not a place
/// where the height is negotiable — the rows are, and the picture above them.
class _SettingsGrid extends StatelessWidget {
  const _SettingsGrid({required this.items, required this.ink});
  final List<SpecItem> items;
  final _Ink ink;

  static const _rowH = 12.5, _gapX = 18.0;

  @override
  Widget build(BuildContext context) {
    final rows = (items.length / 2).ceil();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < rows; i++)
        SizedBox(
          height: _rowH,
          child: Row(children: [
            for (var c = 0; c < 2; c++) ...[
              if (c > 0) const SizedBox(width: _gapX),
              Expanded(
                child: i * 2 + c < items.length
                    ? Row(children: [
                        Expanded(child: Text(items[i * 2 + c].label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 9, color: ink.mid, height: 1))),
                        Text(items[i * 2 + c].value, style: KataType.monoStyle(size: 9.5, color: ink.fg, height: 1)),
                      ])
                    : const SizedBox.shrink(),
              ),
            ],
          ]),
        ),
    ]);
  }
}

// ---------------------------------------------------------------- S2 contact sheet

List<String> _tags(Recipe r) => ['#FUJI${(r.ofr.sensors.firstOrNull ?? 'X').replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}', '#${r.ofr.filmSimulation.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}', '#KATA'];

/// Page 1: the photograph square, the name and the tags.
class _S2Photo extends StatelessWidget {
  const _S2Photo(this.spec, this.ink);
  final ShareSpec spec;
  final _Ink ink;
  @override
  Widget build(BuildContext context) {
    final r = spec.recipe;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(ink, spec),
        const SizedBox(height: 12),
        Expanded(child: _frame(ink, spec)),
        const SizedBox(height: 12),
        _nameLine(ink, r, size: 18, maxLines: 1),
        const SizedBox(height: 6),
        Text(_tags(r).join(' ').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 8.5, color: ink.mute, letterSpacing: 0.08)),
      ]),
    );
  }
}

/// Page 2: the name, the settings that matter, the code large.
class _S2Recipe extends StatelessWidget {
  const _S2Recipe(this.spec, this.ink);
  final ShareSpec spec;
  final _Ink ink;
  @override
  Widget build(BuildContext context) {
    final r = spec.recipe;
    final compact = RecipeSpecs.compact(r.ofr);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(ink, spec),
        const SizedBox(height: 12),
        _nameLine(ink, r, size: 18, maxLines: 1),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, children: [for (final it in compact.take(6)) _kv(ink, it.label, it.value, vs: 10)]),
        const SizedBox(height: 8),
        Text(_tags(r).join(' ').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 8.5, color: ink.mute, letterSpacing: 0.08)),
        const SizedBox(height: 10),
        // the code takes whatever height is left and never pushes the credit off the card
        Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _qrBlock(spec, ink, 260)))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text(spec.credit, maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 10, weight: FontWeight.w600, color: ink.fg, height: 1))),
          const SizedBox(width: 8),
          Text('SCAN TO IMPORT · ${spec.settingsCount} SETTINGS', style: KataType.monoStyle(size: 8, color: ink.mute, letterSpacing: 0.1)),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- S3 story 9:16

/// Page 1: the photograph tall, the name large beneath it.
class _S3Photo extends StatelessWidget {
  const _S3Photo(this.spec, this.ink);
  final ShareSpec spec;
  final _Ink ink;
  @override
  Widget build(BuildContext context) {
    final r = spec.recipe;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(builder: (context, box) {
        // drawn for 9:16; on a square the frame yields and the name goes to one line
        final tight = box.maxHeight < 560;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _header(ink, spec),
          SizedBox(height: tight ? 10 : 16),
          Expanded(child: _frame(ink, spec, radius: 8)),
          SizedBox(height: tight ? 14 : 22),
          _nameLine(ink, r, size: tight ? 26 : 34, maxLines: tight ? 1 : 2, sub: RecipeSpecs.summary(r.ofr)),
        ]);
      }),
    );
  }
}

/// Page 2: the name, four settings, the code large, how to use it.
class _S3Recipe extends StatelessWidget {
  const _S3Recipe(this.spec, this.ink);
  final ShareSpec spec;
  final _Ink ink;
  @override
  Widget build(BuildContext context) {
    final r = spec.recipe;
    final items = RecipeSpecs.compact(r.ofr).take(4).toList();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(builder: (context, box) {
        final tight = box.maxHeight < 560;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _header(ink, spec),
          SizedBox(height: tight ? 10 : 16),
          _nameLine(ink, r, size: tight ? 26 : 34, maxLines: tight ? 1 : 2, sub: RecipeSpecs.summary(r.ofr)),
          SizedBox(height: tight ? 12 : 18),
          Row(children: [for (final it in items) ...[Expanded(child: _kv(ink, it.label, it.value, vs: 13))]]),
          SizedBox(height: tight ? 12 : 22),
          Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: _qrBlock(spec, ink, 260)))),
          SizedBox(height: tight ? 12 : 22),
          Text('SCAN TO LOAD INTO YOUR OWN C-SLOT', maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 12, color: ink.fg, letterSpacing: 0.02, height: 1.25)),
          const SizedBox(height: 8),
          Text(spec.credit, maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 10, weight: FontWeight.w600, color: ink.mute, height: 1)),
        ]);
      }),
    );
  }
}
