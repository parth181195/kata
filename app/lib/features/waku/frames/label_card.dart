import 'package:flutter/material.dart';

import '../../../core/compose/grain.dart';
import '../../../core/compose/layers.dart';
import '../../../core/compose/roll.dart';
import '../../../core/compose/treatment.dart';
import '../../../core/compose/voice.dart';
import 'barcode.dart';
import '../../share/kata_code_qr.dart';
import 'frame.dart';

/// A print on a board with a tombstone card beside it: maker, title, date,
/// medium — which here is the camera and the recipe — and an accession number
/// over a Code 39 barcode. It permits the least wear of anything in the set,
/// because a gallery keeps its walls clean.
///
/// The card goes under the print on an upright sheet and to its right on a
/// wide one, which is where a wall label actually goes: a museum hangs the
/// label where there is room beside the work, not always beneath it.
class LabelCardObject extends WakuObject {
  const LabelCardObject();

  /// The board. The ink prints on this, so it is what legibility is measured
  /// against; the grounds only vary the paper's warmth around it.
  static const _board = Color(0xFFEDE8DC);

  @override
  String get id => 'label';

  @override
  String get label => 'Label';

  @override
  Allowances get allowances => const Allowances(
        voices: {VoiceId.deco, VoiceId.bureau},
        inkFamily: 'archive',
        // a gallery keeps its walls clean
        treatment: TreatmentBounds(slip: 0.003, bleed: 0.3, pressure: 0.08, speckles: 8, wear: 0),
        inkOn: _board,
        grounds: [_board, Color(0xFFE6E1D3), Color(0xFFF1EDE3), Color(0xFFE3E0DA)],
      );

  @override
  List<ComposeLayer> build(ObjectContext ctx) {
    final s = ctx.size;
    final roll = ctx.roll;

    final m = s.width * 0.075;
    final inner = Rect.fromLTRB(m, m, s.width - m, s.height - m);
    final air = s.width * 0.045;

    // Beside the work on a wide sheet, beneath it on an upright one. Either
    // way the card is sized from its own width, so its type never scales with
    // the sheet — a wall label is the same object in every room.
    final beside = s.width / s.height > 1.15;
    final Rect print, card;
    if (beside) {
      final cardW = inner.width * 0.30;
      print = Rect.fromLTRB(inner.left, inner.top, inner.right - cardW - air, inner.bottom);
      final cardH = cardW * 0.78;
      card = Rect.fromLTWH(inner.right - cardW, inner.center.dy - cardH * 0.15, cardW, cardH);
    } else {
      final cardW = inner.width * 0.60;
      final cardH = cardW * 0.46;
      print = Rect.fromLTRB(inner.left, inner.top, inner.right, inner.bottom - cardH - air);
      card = Rect.fromLTWH(inner.left, inner.bottom - cardH, cardW, cardH);
    }

    final (clump, amount) = ctx.grain.onSheet(print.width);
    final accession = 'KATA ${roll.seed % 900 + 100}.${ctx.meta.dateTime?.year ?? DateTime.now().year}';
    final medium = [ctx.meta.model, ctx.kataName ?? ctx.meta.filmMode].whereType<String>().join(' · ');

    // rows inside the card, as fractions of its height
    Rect row(double top, double height, {double left = 0.06, double right = 0.94}) => Rect.fromLTRB(
          card.left + card.width * left,
          card.top + card.height * top,
          card.left + card.width * right,
          card.top + card.height * (top + height),
        );

    return [
      ComposeSurface(ColoredBox(color: roll.ground)),
      ComposeGrainSheet(GrainSpec.measured(clumpPx: clump, amount: amount, seed: roll.seed)),
      ComposeSurface(CustomPaint(painter: PressurePainter(roll.treatment, roll.seed))),
      ComposePhotoWindow(
        rect: print,
        shadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 5))],
      ),
      // the tombstone card itself: barely there, a shade of the ink on the wall
      ComposeSurface(Padding(
        padding: EdgeInsets.fromLTRB(card.left, card.top, s.width - card.right, s.height - card.bottom),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: roll.ink.withValues(alpha: 0.05),
            border: Border.all(color: roll.ink.withValues(alpha: 0.22), width: 0.7),
          ),
        ),
      )),
      ComposeTextSlot(
        id: 'maker',
        region: row(0.09, 0.17),
        style: roll.voice.textStyle(card.width * 0.062, roll.ink, tracking: 0.05),
        invitation: 'YOUR NAME',
        align: Alignment.centerLeft,
        maxChars: 28,
        fitRegion: true,
      ),
      // a museum sets the title apart from the maker; ours does it by size and
      // by keeping the case you typed, since 'Untitled' is not a shout
      ComposeTextSlot(
        id: 'title',
        region: row(0.28, 0.24),
        style: roll.voice.displayStyle(card.width * 0.105, roll.ink),
        invitation: 'Untitled',
        uppercase: false,
        align: Alignment.centerLeft,
        maxChars: 34,
        fitRegion: true,
      ),
      ComposeTextSlot(
        id: 'medium',
        region: row(0.54, 0.14),
        style: roll.voice.dataStyle(card.width * 0.048, roll.ink.withValues(alpha: 0.78)),
        invitation: 'camera · recipe',
        prefill: medium.isEmpty ? null : medium,
        uppercase: false,
        align: Alignment.centerLeft,
        maxChars: 44,
        fitRegion: true,
      ),
      // The accession number's code. Code 39 when the object is only itself; the
      // Kata Code when a recipe is attached, because a museum label carries one
      // code, not two — and this one is worth scanning.
      ComposeSurface(Padding(
        padding: EdgeInsets.fromLTRB(
          card.left + card.width * 0.06,
          card.top + card.height * 0.72,
          s.width - (card.left + card.width * (ctx.kataCode == null ? 0.52 : 0.26)),
          s.height - (card.top + card.height * 0.90),
        ),
        child: ctx.kataCode == null
            ? CustomPaint(painter: BarcodePainter(accession, roll.ink.withValues(alpha: 0.85)))
            : LayoutBuilder(
                builder: (c, b) => Align(
                  alignment: Alignment.centerLeft,
                  child: KataCodeQr(payload: ctx.kataCode!, size: b.biggest.shortestSide),
                ),
              ),
      )),
      ComposeTextSlot(
        id: 'accession',
        region: row(0.75, 0.12, left: 0.56),
        style: roll.voice.dataStyle(card.width * 0.042, roll.ink.withValues(alpha: 0.72)),
        invitation: 'KATA 000',
        prefill: accession,
        align: Alignment.centerRight,
        maxChars: 18,
        fitRegion: true,
      ),
      ComposeSurface(CustomPaint(painter: SpecklePainter(roll.treatment, roll.seed))),
      ComposeGrainSheet(GrainSpec.measured(clumpPx: clump, amount: amount * 0.33, seed: roll.seed), overInk: true),
    ];
  }
}
