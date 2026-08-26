import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/compose/voice.dart';

void main() {
  test('every voice names three distinct roles', () {
    expect(kVoices.length, VoiceId.values.length);
    for (final v in kVoices.values) {
      expect({v.display, v.text, v.data}.length, 3, reason: '${v.id} reuses a family across roles');
    }
  });

  test('bias weights, never forces: a mono shot leans serif but nothing is excluded', () {
    const allowed = {VoiceId.postOffice, VoiceId.bureau, VoiceId.deco, VoiceId.civic};
    final mono = voiceWeights(filmSim: 'ACROS', iso: 400, allowed: allowed);
    final vivid = voiceWeights(filmSim: 'VELVIA', iso: 200, allowed: allowed);

    for (final w in [mono, vivid]) {
      expect(w.keys.toSet(), allowed);
      for (final v in w.values) {
        expect(v, greaterThan(0), reason: 'a bias must never zero an allowed voice');
      }
    }
    // deco is the serif voice; it must be likelier on the monochrome shot
    expect(mono[VoiceId.deco]! / mono.values.reduce((a, b) => a + b),
        greaterThan(vivid[VoiceId.deco]! / vivid.values.reduce((a, b) => a + b)));
  });

  test('only allowed voices are weighted', () {
    final w = voiceWeights(filmSim: null, iso: null, allowed: {VoiceId.civic});
    expect(w.keys.single, VoiceId.civic);
  });
}
