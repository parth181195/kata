import 'dart:math' as math;
import 'dart:ui';

import 'ink.dart';
import 'treatment.dart';
import 'voice.dart';

/// The axes a shuffle may move. Each can be pinned independently, which is what
/// keeps this a tool rather than a slot machine: you converge on something
/// instead of gambling for it.
enum RollAxis { object, voice, ink, treatment }

/// What an object permits the roll to touch. Identity and slots are authored;
/// only this varies (docs/design/waku-spec.md §3).
class Allowances {
  const Allowances({
    required this.voices,
    required this.inkFamily,
    required this.treatment,
    this.grounds = const [],
    this.inkOn = const Color(0xFFF4EFE3),
  });

  final Set<VoiceId> voices;

  /// A key into [kInkFamilies].
  final String inkFamily;
  final TreatmentBounds treatment;

  /// The grounds this object may be mounted on — the card under a stamp, the
  /// light table under a negative. Decorative; the roll picks one.
  final List<Color> grounds;

  /// The surface the ink is *printed on*, which is what legibility is measured
  /// against. A stamp's ink lands on its cream paper, not on the mount behind
  /// it — contrasting against the mount is how you get pale ink on pale paper.
  final Color inkOn;
}

/// One seeded draw. Reproducible from (seed, allowances, palette, shot).
class Roll {
  const Roll({required this.seed, required this.voiceId, required this.voice, required this.ink, required this.ground, required this.treatment});

  final int seed;
  final VoiceId voiceId;
  final Voice voice;
  final Color ink, ground;
  final Treatment treatment;

  static Roll draw({
    required int seed,
    required Allowances allowances,
    required List<Color> palette,
    String? filmSim,
    int? iso,
    Roll? pinnedFrom,
    Set<RollAxis> pins = const {},
  }) {
    // A stream per axis, all derived from the one seed: pinning one axis must
    // not shift what the others would have drawn.
    final voiceRnd = math.Random(seed * 31 + 1);
    final groundRnd = math.Random(seed * 31 + 3);

    VoiceId voiceId;
    if (pins.contains(RollAxis.voice) && pinnedFrom != null) {
      voiceId = pinnedFrom.voiceId;
    } else {
      final weights = voiceWeights(filmSim: filmSim, iso: iso, allowed: allowances.voices);
      final total = weights.values.fold(0.0, (a, b) => a + b);
      var pick = voiceRnd.nextDouble() * total;
      voiceId = weights.keys.first;
      for (final e in weights.entries) {
        pick -= e.value;
        if (pick <= 0) {
          voiceId = e.key;
          break;
        }
      }
    }

    // ink and mount are one decision: pinning the colour holds both
    final pinInk = pins.contains(RollAxis.ink) && pinnedFrom != null;
    final ground = allowances.grounds.isEmpty
        ? const Color(0xFF1A1714)
        : (pinInk ? pinnedFrom.ground : allowances.grounds[groundRnd.nextInt(allowances.grounds.length)]);
    final ink = pinInk
        ? pinnedFrom.ink
        : pickInk(family: kInkFamilies[allowances.inkFamily]!, palette: palette, ground: allowances.inkOn, seed: seed * 31 + 5);

    final treatment = pins.contains(RollAxis.treatment) && pinnedFrom != null
        ? pinnedFrom.treatment
        : Treatment.draw(allowances.treatment, seed * 31 + 7);

    return Roll(seed: seed, voiceId: voiceId, voice: kVoices[voiceId]!, ink: ink, ground: ground, treatment: treatment);
  }
}
