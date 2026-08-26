import 'dart:io';

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

  test('every weight a voice names has a bundled font file', () {
    // google_fonts resolves Family + weight to an asset called
    // <Family>-<Variant>.ttf. The app bundles one file per family and turns
    // runtime fetching off, so a weight with no file does not fall back to a
    // near neighbour — it drops to the platform default, and in a test to the
    // box font, which is how a label card came to render YOUR NAME as two grey
    // rectangles.
    const variants = {400: 'Regular', 500: 'Medium', 600: 'SemiBold', 700: 'Bold', 800: 'ExtraBold', 900: 'Black'};
    final dir = Directory('assets/google_fonts');
    expect(dir.existsSync(), isTrue, reason: 'run this from app/');
    final have = dir.listSync().map((f) => f.uri.pathSegments.last).toSet();

    for (final v in kVoices.values) {
      for (final (family, weight) in [
        (v.display, v.displayWeight),
        (v.text, v.textWeight),
        (v.data, v.dataWeight),
      ]) {
        final file = '${family.replaceAll(' ', '')}-${variants[weight.value]}.ttf';
        expect(have, contains(file),
            reason: '${v.id.name} asks for $family ${variants[weight.value]}, and assets/google_fonts has no $file');
      }
    }
  });
}
