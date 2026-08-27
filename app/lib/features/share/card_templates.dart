import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../../data/recipe.dart';
import '../../data/recipe_specs.dart';
import 'kata_code_qr.dart';

enum ShareTemplate { card, sheet, story, code }

extension ShareTemplateX on ShareTemplate {
  String get code => switch (this) { ShareTemplate.card => 'S1', ShareTemplate.sheet => 'S2', ShareTemplate.story => 'S3', ShareTemplate.code => 'S4' };
  String get label => switch (this) { ShareTemplate.card => 'CARD', ShareTemplate.sheet => 'SHEET', ShareTemplate.story => 'STORY', ShareTemplate.code => 'CODE' };
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
    required this.ratio,
    this.inverted = false,
    this.embedCode = true,
    required this.credit,
    this.imageFor = _network,
  });
  final Recipe recipe;

  /// How a sample-frame URL becomes an image. The network by default; a test
  /// hands in a provider it controls, so the export's wait for the photo can be
  /// exercised without one.
  final ImageProvider Function(String url) imageFor;
  static ImageProvider _network(String url) => CachedNetworkImageProvider(url);
  final ShareTemplate template;
  final ShareRatio ratio;
  final bool inverted;
  final bool embedCode;
  final String credit;
  String get payload => KataCode.encode(recipe.ofr, credit: credit);
  int get settingsCount => recipe.ofr.settingsJson().length;
}

const kCardWidth = 390.0;

/// The file the card is saved or shared as.
///
/// A name is not guaranteed to survive `[^A-Za-z0-9]` — '夏の海辺' and '...' both
/// reduce to nothing, and every such recipe used to save as the same `--s1.png`,
/// quietly overwriting the last one in someone's Downloads. So the name is used
/// when it leaves something, the film simulation when it doesn't, and the id is
/// appended in that case to keep two of them apart.
String shareFileName(Recipe r, ShareTemplate template) {
  String slug(String? v) => (v ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '').toLowerCase();
  var stem = slug(r.ofr.name);
  if (stem.isEmpty) {
    final sim = slug(r.ofr.filmSimulation);
    final tail = slug(r.id);
    stem = [if (sim.isNotEmpty) sim, if (tail.isNotEmpty) tail.substring(0, tail.length < 6 ? tail.length : 6)].join('-');
  }
  if (stem.isEmpty) stem = 'kata';
  return '$stem-${template.code.toLowerCase()}.png';
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
    final body = switch (spec.template) {
      ShareTemplate.card => _S1(spec, ink),
      ShareTemplate.sheet => _S2(spec, ink),
      ShareTemplate.story => _S3(spec, ink),
      ShareTemplate.code => _S4(spec, ink),
    };
    // cards are white by default (light palette), inverted = dark palette — so kata_ui widgets inside pick the right greys
    return Theme(
      data: spec.inverted ? KataTheme.dark() : KataTheme.light(),
      child: Container(width: kCardWidth, height: h, color: ink.bg, child: DefaultTextStyle(style: TextStyle(color: ink.fg), child: body)),
    );
  }
}

// ---------------------------------------------------------------- pieces

Widget _wordmark(_Ink ink, {String? right}) => Row(children: [
  Text('KATA 型', style: KataType.displayStyle(size: 14, weight: FontWeight.w900, color: ink.fg, letterSpacing: 0.05)),
  const Spacer(),
  if (right != null) Text(right, style: KataType.bodyStyle(size: 8.5, weight: FontWeight.w500, color: ink.mute, height: 1).copyWith(letterSpacing: 8.5 * 0.16)),
]);

Widget _frame(_Ink ink, ShareSpec spec, {double? height, int index = 0, double radius = 4}) {
  final r = spec.recipe;
  final url = r.imageUrls.length > index ? r.imageUrls[index] : null;
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Container(
      height: height,
      color: ink.frame,
      child: url == null
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
class _S1 extends StatelessWidget {
  const _S1(this.spec, this.ink);
  final ShareSpec spec;
  final _Ink ink;
  @override
  Widget build(BuildContext context) {
    final r = spec.recipe;
    final items = RecipeSpecs.items(r.ofr, rulers: false);
    // On a 390px square the fixed rows — name, swatch, every setting, credit,
    // code — come to ~403px with a two-line name, so the frame can never have
    // meaningful height: with a one-line name it got 18px, a sliver of photo
    // above a name that had lost its last word. The square card is a settings
    // card. It has no frame, and the name is whole.
    final square = spec.ratio == ShareRatio.r1x1;
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _wordmark(ink, right: 'S1 · RECIPE CARD'),
        const SizedBox(height: 14),
        if (!square) ...[
          Expanded(child: _frame(ink, spec)),
          const SizedBox(height: 14),
        ],
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 22, color: ink.fg, letterSpacing: 0, height: 1.02)),
              const SizedBox(height: 5),
              Text('${r.ofr.filmSimulation} · ${r.ofr.sensors.isEmpty ? 'ANY SENSOR' : r.ofr.sensors.join('/')}'.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 8.5, weight: FontWeight.w500, color: ink.mute, height: 1).copyWith(letterSpacing: 8.5 * 0.16)),
            ]),
          ),
          const SizedBox(width: 12),
          SwatchBars(values: RecipeSpecs.swatch(r.ofr), abbr: RecipeSpecs.filmAbbr(r.ofr)),
        ]),
        const SizedBox(height: 11),
        Container(height: 1, decoration: BoxDecoration(border: Border(top: BorderSide(color: ink.rule, style: BorderStyle.solid)))),
        const SizedBox(height: 10),
        // Every setting, in as many rows as it takes. A fixed childAspectRatio
        // with a fixed take(12) dropped the last row off every colour recipe —
        // Clarity, silently. And sizing the rows from whatever height was left
        // clipped the type on a square card instead, where the frame:grid flex
        // split drawn for 4:5 leaves the grid 43px for seven rows. So the grid
        // takes the height its rows need, and the frame above is what yields.
        _SettingsGrid(items: items, ink: ink),
        Container(height: 1, color: ink.fg),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(spec.credit, style: KataType.bodyStyle(size: 10, weight: FontWeight.w600, color: ink.fg, height: 1)),
              const SizedBox(height: 4),
              Text('SCAN TO IMPORT · ${spec.settingsCount} SETTINGS', style: KataType.monoStyle(size: 8, color: ink.mute, letterSpacing: 0.1)),
            ]),
          ),
          _qrBlock(spec, ink, kQrSlot),
        ]),
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
class _S2 extends StatelessWidget {
  const _S2(this.spec, this.ink);
  final ShareSpec spec;
  final _Ink ink;
  @override
  Widget build(BuildContext context) {
    final r = spec.recipe;
    final compact = RecipeSpecs.compact(r.ofr);
    final tags = ['#FUJI${(r.ofr.sensors.firstOrNull ?? 'X').replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}', '#${r.ofr.filmSimulation.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}', '#KATA'];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _wordmark(ink, right: 'S2 · CONTACT SHEET'),
        const SizedBox(height: 12),
        Expanded(
          flex: 3,
          child: Row(children: [
            Expanded(flex: 3, child: _frame(ink, spec, index: 0)),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: Column(children: [Expanded(child: _frame(ink, spec, index: 1)), const SizedBox(height: 6), Expanded(child: _frame(ink, spec, index: 2))])),
          ]),
        ),
        const SizedBox(height: 12),
        Flexible(
          flex: 2,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 18, color: ink.fg, letterSpacing: 0)),
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 6, children: [for (final it in compact.take(6)) _kv(ink, it.label, it.value, vs: 10)]),
              const SizedBox(height: 8),
              Text(tags.join(' ').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 8.5, color: ink.mute, letterSpacing: 0.08)),
            ]),
          ),
          const SizedBox(width: 10),
          _qrBlock(spec, ink, kQrSlot),
        ]),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- S3 story 9:16
class _S3 extends StatelessWidget {
  const _S3(this.spec, this.ink);
  final ShareSpec spec;
  final _Ink ink;
  @override
  Widget build(BuildContext context) {
    final r = spec.recipe;
    final items = RecipeSpecs.compact(r.ofr).take(4).toList();
    // The story is drawn for 9:16, but the ratio chips let it be posted square,
    // and on a square card the fixed rows below the frame add up to more than
    // the card is tall: it overflowed by ~20px in release, silently clipped.
    // So the frame yields first, and if that isn't enough the title does — a
    // story with no picture is still a story; one with its code cut off isn't.
    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(builder: (context, box) {
        final tight = box.maxHeight < 560;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _wordmark(ink, right: 'S3 · STORY'),
          SizedBox(height: tight ? 10 : 16),
          Expanded(flex: 5, child: _frame(ink, spec, radius: 8)),
          SizedBox(height: tight ? 14 : 22),
          Text(r.name.toUpperCase(), maxLines: tight ? 1 : 2, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: tight ? 26 : 34, color: ink.fg, letterSpacing: 0, height: 1)),
          const SizedBox(height: 8),
          Text(RecipeSpecs.summary(r.ofr).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.monoStyle(size: 10.5, color: ink.mid, letterSpacing: 0.08)),
          SizedBox(height: tight ? 12 : 18),
          Row(children: [for (final it in items) ...[Expanded(child: _kv(ink, it.label, it.value, vs: 13))]]),
          SizedBox(height: tight ? 14 : 22),
          Row(children: [
            _qrBlock(spec, ink, kQrSlot),
            const SizedBox(width: 14),
            Expanded(child: Text('SCAN TO LOAD INTO\nYOUR OWN C-SLOT', style: KataType.displayStyle(size: 12, color: ink.fg, letterSpacing: 0.02, height: 1.25))),
          ]),
          const SizedBox(height: 8),
          Text(spec.credit, maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 10, weight: FontWeight.w600, color: ink.mute, height: 1)),
        ]);
      }),
    );
  }
}

// ---------------------------------------------------------------- S4 code
class _S4 extends StatelessWidget {
  const _S4(this.spec, this.ink);
  final ShareSpec spec;
  final _Ink ink;
  @override
  Widget build(BuildContext context) {
    final r = spec.recipe;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _wordmark(ink, right: 'S4 · KATA CODE'),
        const SizedBox(height: 18),
        Text(r.name.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 24, color: ink.fg, letterSpacing: 0, height: 1.02)),
        const SizedBox(height: 6),
        Text('${r.ofr.filmSimulation} · ${RecipeSpecs.summary(r.ofr)} · ${spec.settingsCount} SETTINGS'.toUpperCase(), maxLines: 2, style: KataType.monoStyle(size: 9.5, color: ink.mid, letterSpacing: 0.06, height: 1.4)),
        const SizedBox(height: 4),
        Text(spec.credit, style: KataType.bodyStyle(size: 10, weight: FontWeight.w600, color: ink.fg, height: 1)),
        const SizedBox(height: 12),
        // the code takes whatever height is left (≥ 120) and never pushes the footer off the card
        Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: KataCodeQr(payload: spec.payload, size: 260, inverted: spec.inverted)))),
        const SizedBox(height: 12),
        Text('HOW TO USE', style: KataType.bodyStyle(size: 8, weight: FontWeight.w500, color: ink.mute, height: 1).copyWith(letterSpacing: 8 * 0.16)),
        const SizedBox(height: 6),
        Text('Open Kata → Scan → the recipe lands in your library, then write it to a C-slot over USB-C.', style: KataType.bodyStyle(size: 11, color: ink.fg, height: 1.45)),
      ]),
    );
  }
}
