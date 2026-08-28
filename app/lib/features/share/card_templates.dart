import 'dart:math' as math;

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

  /// The shape of the photograph's frame — the card's ratio is the user's,
  /// the frame's is the template's, so between them every orientation is
  /// covered: landscape on the card, square on the sheet, portrait on the story.
  double get frameAspect => switch (this) { ShareTemplate.card => 3 / 2, ShareTemplate.sheet => 1, ShareTemplate.story => 4 / 5 };
}

extension SharePageX on SharePage {
  String get label => switch (this) { SharePage.photo => 'PHOTO', SharePage.recipe => 'RECIPE' };
}

/// Everything a template needs. Cards are laid out at a logical width of
/// [kCardWidth] and rendered at [kCardPixelRatio]×; their height is whatever
/// the pair's taller page needs — both pages are always the same height.
class ShareSpec {
  const ShareSpec({
    required this.recipe,
    required this.template,
    this.page = SharePage.recipe,
    this.inverted = false,
    this.outline = false,
    this.roundCorners = true,
    this.embedCode = true,
    required this.credit,
    this.imageFor = _network,
    this.photos = const [],
    this.photoOffset = Offset.zero,
    this.photoZoom = 1,
    this.photoSize,
    this.camera,
  });

  /// The camera the photograph was made on, from its EXIF — the header's
  /// right-hand line when known.
  final String? camera;

  /// Where the photograph sits in its frame: a shift in card pixels from
  /// centred, and a zoom ≥ 1 on top of the cover fit. Clamped at draw time so
  /// the frame is always full — the preview and the export share the clamp.
  final Offset photoOffset;
  final double photoZoom;

  /// The photograph's pixel size, when known; what the clamp needs.
  final Size? photoSize;
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

  /// The credit as it reads on the card: whose recipe it originally is.
  String get creditLine => credit.isEmpty || credit == 'Kata' ? 'Kata' : 'Original recipe by $credit';

  /// What travels with the pictures on the share sheet: not the code (that
  /// is on the card), but a caption in the shape Fujifilm's own accounts use
  /// — the camera, the film simulation, and the tags they repost from.
  String get caption => shareCaption(recipe, camera: camera, credit: credit);
}

const kCardWidth = 390.0;

/// The card's outer corner, and the photograph's, when Corners is Round.
const kCardRadius = 20.0;
const kFrameRadius = 12.0;

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

/// The caption for a shared pair, the way Fujifilm's own accounts write
/// theirs: what it was captured with, the film simulation, then the tags the
/// official accounts repost from — #fujifilm_xseries (global) and #myfujifilm
/// (US) — with the recipe's own tag and Kata's at the end.
String shareCaption(Recipe r, {String? camera, String? credit}) {
  String tag(String v) => '#${v.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}';
  final sim = r.ofr.filmSimulation;
  final lines = <String>[
    'Captured with ${camera == null || camera.isEmpty ? 'FUJIFILM' : camera.toUpperCase().startsWith('FUJIFILM') ? camera : 'FUJIFILM $camera'} · ${r.name}',
    'Film Simulation: $sim',
    if (credit != null && credit.isNotEmpty && credit != 'Kata') 'Recipe: $credit',
    '',
    ['#FUJIFILM', '#FujifilmXSeries', '#XSeries', '#fujifilm_xseries', '#myfujifilm', '#FilmSimulation', tag(sim), tag(r.name), '#Kata'].join(' '),
  ];
  return lines.join('\n');
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

/// The sheet's code, beneath its settings: smaller than the card's slot so
/// the settings get the room, and no larger than [kQrSheetMax] when page 1
/// leaves it more.
const kQrSheet = 140.0;
const kQrSheetMax = 200.0;

/// How large a code grows when page 1 leaves it the room.
const kQrMax = 240.0;

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
    final photo = switch (spec.template) {
      ShareTemplate.card => _S1Photo(spec, ink),
      ShareTemplate.sheet => _S2Photo(spec, ink),
      ShareTemplate.story => _S3Photo(spec, ink),
    };
    final recipe = switch (spec.template) {
      ShareTemplate.card => _S1Recipe(spec, ink),
      ShareTemplate.sheet => _S2Recipe(spec, ink),
      ShareTemplate.story => _S3Recipe(spec, ink),
    };
    // Both pages are laid out side by side under one IntrinsicHeight, so the
    // pair is as tall as the taller page needs and no taller: page 1's frame
    // grows to take any difference, page 2's code does. The clip shows the
    // page asked for. (Nothing in here may be a LayoutBuilder — intrinsic
    // sizing asks every child for its height, and a LayoutBuilder has none.)
    // A viewport rather than an Align: it gives the row its unbounded width
    // and hugs the height; it never scrolls, it is just parked on the page.
    final body = SingleChildScrollView(
      key: ValueKey(spec.page),
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      controller: ScrollController(initialScrollOffset: spec.page == SharePage.photo ? 0 : kCardWidth),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: kCardWidth, child: photo),
          SizedBox(width: kCardWidth, child: recipe),
        ]),
      ),
    );
    // cards are white by default (light palette), inverted = dark palette — so kata_ui widgets inside pick the right greys
    return Theme(
      data: spec.inverted ? KataTheme.dark() : KataTheme.light(),
      // the card's own corners follow the Corners option too: rounded, the
      // PNG keeps transparent corners; square, it is the full rectangle
      child: ClipRRect(
        borderRadius: BorderRadius.circular(spec.roundCorners ? kCardRadius : 0),
        child: Container(
          width: kCardWidth,
          color: ink.bg,
          // the outline is drawn over the content, inset by its own width, so
          // nothing on the card moves when it is turned on
          foregroundDecoration: spec.outline
              ? BoxDecoration(border: Border.all(color: ink.rule, width: 1.5), borderRadius: BorderRadius.circular(spec.roundCorners ? kCardRadius : 0))
              : null,
          child: DefaultTextStyle(style: TextStyle(color: ink.fg), child: body),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- pieces

/// The header both pages share: the wordmark, and the camera when known.
Widget _header(_Ink ink, ShareSpec spec) => _wordmark(ink, right: spec.camera?.toUpperCase());

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

Widget _frame(_Ink ink, ShareSpec spec, {double? height, int index = 0, double radius = kFrameRadius, double? aspect, double width = kCardWidth}) {
  final r = spec.recipe;
  final url = r.imageUrls.length > index ? r.imageUrls[index] : null;
  // the user's photo for this frame, else the recipe's own sample
  final own = index < spec.photos.length ? spec.photos[index] : null;
  final box = ClipRRect(
    borderRadius: BorderRadius.circular(spec.roundCorners ? radius : 0),
    child: Container(
      height: height,
      color: ink.frame,
      child: own != null
          ? _placed(spec, Image(image: ResizeImage(MemoryImage(own), width: 2600, height: 2600, policy: ResizeImagePolicy.fit), fit: BoxFit.cover, width: double.infinity, height: double.infinity, gaplessPlayback: true))
          : url == null
              ? CustomPaint(painter: _Dots(ink.rule), child: Center(child: Text('SAMPLE FRAME', style: KataType.monoStyle(size: 8, color: ink.mute, letterSpacing: 0.12))))
              : _placed(spec, Image(image: spec.imageFor(url), fit: BoxFit.cover, width: double.infinity, height: double.infinity), own: false),
    ),
  );
  // a shaped frame runs the full width; its height is at least the aspect's,
  // and grows when the other page of the pair is taller
  return aspect == null ? box : ConstrainedBox(constraints: BoxConstraints(minHeight: width / aspect), child: box);
}

/// The photograph shifted and zoomed as the spec says, no further than the
/// frame stays covered — you cannot drag past the photo's own edge. A layout
/// delegate rather than a LayoutBuilder: the pair's height is found by
/// intrinsic sizing, which a LayoutBuilder refuses. Decoded no larger than the
/// export needs (1560px wide at 4×): a 24MP photo at full size is a texture
/// the GPU has no reason to hold.
Widget _placed(ShareSpec spec, Widget image, {bool own = true}) => CustomSingleChildLayout(
  delegate: _Place(own ? spec.photoSize : null, own ? spec.photoZoom.clamp(1.0, 6.0) : 1.0, own ? spec.photoOffset : Offset.zero),
  child: Transform.scale(scale: own ? spec.photoZoom.clamp(1.0, 6.0) : 1.0, child: image),
);

class _Place extends SingleChildLayoutDelegate {
  const _Place(this.img, this.zoom, this.offset);
  final Size? img;
  final double zoom;
  final Offset offset;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => BoxConstraints.tight(c.biggest);
  @override
  Offset getPositionForChild(Size size, Size childSize) => clampPlacement(offset, img, zoom, size);
  @override
  bool shouldRelayout(_Place o) => o.img != img || o.zoom != zoom || o.offset != offset;
}

/// The shift that keeps a photo of [img] pixels, cover-fitted and zoomed by
/// [zoom] into a [frame], covering the frame: the edge of the photo never
/// comes inside the edge of the frame.
Offset clampPlacement(Offset offset, Size? img, double zoom, Size frame) {
  if (img == null || img.width <= 0 || img.height <= 0 || !frame.width.isFinite || !frame.height.isFinite) return Offset.zero;
  final scale = math.max(frame.width / img.width, frame.height / img.height) * zoom;
  final mx = (img.width * scale - frame.width) / 2, my = (img.height * scale - frame.height) / 2;
  return Offset(offset.dx.clamp(-mx, mx), offset.dy.clamp(-my, my));
}

/// The code at [min] as far as sizing goes, scaled up into the room it gets —
/// square, top-right, no larger than [kQrMax]. Vector, so still crisp.
Widget _qrGrowing(ShareSpec spec, _Ink ink, double min) => Align(
  alignment: Alignment.topRight,
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: kQrMax, maxHeight: kQrMax),
    child: AspectRatio(aspectRatio: 1, child: FittedBox(fit: BoxFit.contain, child: _qrBlock(spec, ink, min))),
  ),
);

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

/// Page 1: the photograph landscape, the name under it.
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
          Expanded(child: _frame(ink, spec, aspect: spec.template.frameAspect, width: kCardWidth - 44)),
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
        // Clarity, silently. So the grid takes the height its rows need.
        _SettingsGrid(items: items, ink: ink),
        const SizedBox(height: 10),
        Container(height: 1, color: ink.fg),
        const SizedBox(height: 10),
        // the code's row takes whatever height page 1 leaves, and the code
        // grows into it — never below kQrSlot, never past kQrMax
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kQrSlot),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(spec.creditLine, maxLines: 2, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 10, weight: FontWeight.w600, color: ink.fg, height: 1.2)),
                  const SizedBox(height: 4),
                  Text('SCAN IN KATA TO IMPORT', style: KataType.monoStyle(size: 8, color: ink.mute, letterSpacing: 0.1)),
                ]),
              ),
              const SizedBox(width: 12),
              _qrGrowing(spec, ink, kQrSlot),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// The settings, two columns, every row the height its type needs. Not a
/// GridView: a grid divides the height it is given, and a card is not a place
/// where the height is negotiable — the rows are, and the picture above them.
class _SettingsGrid extends StatelessWidget {
  const _SettingsGrid({required this.items, required this.ink, this.columns = 2});
  final List<SpecItem> items;
  final _Ink ink;
  final int columns;

  static const _rowH = 12.5;

  @override
  Widget build(BuildContext context) {
    final rows = (items.length / columns).ceil();
    final gapX = columns > 2 ? 12.0 : 18.0;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < rows; i++)
        SizedBox(
          height: _rowH,
          child: Row(children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) SizedBox(width: gapX),
              Expanded(
                child: i * columns + c < items.length
                    ? Row(children: [
                        Expanded(child: Text(items[i * columns + c].label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 9, color: ink.mid, height: 1))),
                        const SizedBox(width: 4),
                        // a long value in a narrow column shrinks a little rather than spilling
                        Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: Text(items[i * columns + c].value, style: KataType.monoStyle(size: 9.5, color: ink.fg, height: 1)))),
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
        Expanded(child: _frame(ink, spec, aspect: spec.template.frameAspect, width: kCardWidth - 40)),
        const SizedBox(height: 12),
        _nameLine(ink, r, size: 18, maxLines: 1),
        const SizedBox(height: 6),
        Text(_tags(r).join(' ').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 8.5, color: ink.mute, letterSpacing: 0.08)),
      ]),
    );
  }
}

/// Page 2: the name, then every setting in three columns, the code beneath
/// them — smaller than the card's, so the settings get the room.
class _S2Recipe extends StatelessWidget {
  const _S2Recipe(this.spec, this.ink);
  final ShareSpec spec;
  final _Ink ink;
  @override
  Widget build(BuildContext context) {
    final r = spec.recipe;
    final items = RecipeSpecs.items(r.ofr, rulers: false);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(ink, spec),
        const SizedBox(height: 12),
        _nameLine(ink, r, size: 18, maxLines: 1),
        const SizedBox(height: 6),
        Text(_tags(r).join(' ').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 8.5, color: ink.mute, letterSpacing: 0.08)),
        const SizedBox(height: 10),
        Container(height: 1, decoration: BoxDecoration(border: Border(top: BorderSide(color: ink.rule)))),
        const SizedBox(height: 10),
        _SettingsGrid(items: items, ink: ink, columns: 3),
        const SizedBox(height: 10),
        Container(height: 1, color: ink.fg),
        const SizedBox(height: 10),
        // the code takes what page 1 leaves, centred — never below kQrSheet,
        // never past kQrSheetMax
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kQrSheet, maxHeight: kQrSheetMax),
              child: AspectRatio(aspectRatio: 1, child: FittedBox(fit: BoxFit.contain, child: _qrBlock(spec, ink, kQrSheet))),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text(spec.creditLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 10, weight: FontWeight.w600, color: ink.fg, height: 1))),
          const SizedBox(width: 8),
          Text('SCAN IN KATA TO IMPORT', style: KataType.monoStyle(size: 8, color: ink.mute, letterSpacing: 0.1)),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- S3 story 9:16

/// Page 1: the photograph portrait, the name large beneath it.
class _S3Photo extends StatelessWidget {
  const _S3Photo(this.spec, this.ink);
  final ShareSpec spec;
  final _Ink ink;
  @override
  Widget build(BuildContext context) {
    final r = spec.recipe;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(ink, spec),
        const SizedBox(height: 16),
        Expanded(child: _frame(ink, spec, aspect: spec.template.frameAspect, width: kCardWidth - 48)),
        const SizedBox(height: 22),
        _nameLine(ink, r, size: 34, sub: RecipeSpecs.summary(r.ofr)),
      ]),
    );
  }
}

/// Page 2: the name, every setting, the code large.
class _S3Recipe extends StatelessWidget {
  const _S3Recipe(this.spec, this.ink);
  final ShareSpec spec;
  final _Ink ink;
  @override
  Widget build(BuildContext context) {
    final r = spec.recipe;
    final items = RecipeSpecs.items(r.ofr, rulers: false);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(ink, spec),
        const SizedBox(height: 16),
        _nameLine(ink, r, size: 34, sub: RecipeSpecs.summary(r.ofr)),
        const SizedBox(height: 16),
        Container(height: 1, decoration: BoxDecoration(border: Border(top: BorderSide(color: ink.rule)))),
        const SizedBox(height: 10),
        _SettingsGrid(items: items, ink: ink),
        const SizedBox(height: 10),
        Container(height: 1, color: ink.fg),
        const SizedBox(height: 16),
        // the code takes what page 1 leaves, centred
        Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(minHeight: kQrSlot, maxHeight: kQrMax), child: AspectRatio(aspectRatio: 1, child: FittedBox(fit: BoxFit.contain, child: _qrBlock(spec, ink, kQrSlot)))))),
        const SizedBox(height: 22),
        Text('SCAN TO LOAD INTO YOUR OWN C-SLOT', maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 12, color: ink.fg, letterSpacing: 0.02, height: 1.25)),
        const SizedBox(height: 8),
        Text(spec.creditLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 10, weight: FontWeight.w600, color: ink.mute, height: 1)),
      ]),
    );
  }
}
