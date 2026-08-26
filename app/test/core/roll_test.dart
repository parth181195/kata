import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/ink.dart';
import 'package:kata/core/compose/roll.dart';
import 'package:kata/core/compose/treatment.dart';
import 'package:kata/core/compose/voice.dart';

const _allowances = Allowances(
  voices: {VoiceId.postOffice, VoiceId.civic},
  inkFamily: 'postmark',
  treatment: TreatmentBounds(),
  grounds: [Color(0xFF7E2418), Color(0xFF1F3D34)],
);

const _palette = [Color(0xFF8A2B1C), Color(0xFF3C4A5A), Color(0xFFE8DFC9)];

Roll _roll(int seed, {Roll? from, Set<RollAxis> pins = const {}}) => Roll.draw(
      seed: seed,
      allowances: _allowances,
      palette: _palette,
      filmSim: 'CLASSIC CHROME',
      iso: 400,
      pinnedFrom: from,
      pins: pins,
    );

void main() {
  test('the same seed is the same output', () {
    final a = _roll(7), b = _roll(7);
    expect(a.voiceId, b.voiceId);
    expect(a.ink, b.ink);
    expect(a.ground, b.ground);
    expect(a.treatment.slip, b.treatment.slip);
  });

  test('a roll never leaves the allowances', () {
    for (var seed = 0; seed < 400; seed++) {
      final r = _roll(seed);
      expect(_allowances.voices.contains(r.voiceId), isTrue, reason: 'seed $seed drew a forbidden voice');
      expect(_allowances.grounds.contains(r.ground), isTrue, reason: 'seed $seed drew a forbidden ground');
      expect(contrastRatio(r.ink, _allowances.inkOn), greaterThanOrEqualTo(3.0),
          reason: 'seed $seed is unreadable on the surface it prints on');
    }
  });

  test('seeds actually vary the draw', () {
    final voices = {for (var s = 0; s < 40; s++) _roll(s).voiceId};
    expect(voices.length, greaterThan(1));
  });

  test('a pinned axis holds while the others move', () {
    final first = _roll(1);
    var movedTreatment = false, movedInk = false;
    for (var seed = 2; seed < 40; seed++) {
      final next = _roll(seed, from: first, pins: {RollAxis.voice});
      expect(next.voiceId, first.voiceId, reason: 'the pinned voice changed at seed $seed');
      if (next.ink != first.ink) movedInk = true;
      if (next.treatment.slip != first.treatment.slip) movedTreatment = true;
    }
    expect(movedInk, isTrue, reason: 'pinning the voice froze the ink too');
    expect(movedTreatment, isTrue, reason: 'pinning the voice froze the treatment too');
  });

  test('pinning the ink holds the ground with it — they are one decision', () {
    final first = _roll(1);
    for (var seed = 2; seed < 20; seed++) {
      final next = _roll(seed, from: first, pins: {RollAxis.ink});
      expect(next.ink, first.ink);
      expect(next.ground, first.ground);
    }
  });
}
