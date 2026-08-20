import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kata/desktop/desktop_import.dart';
import 'package:ofr/ofr.dart';

const _r = OfrRecipe(
    name: 'Beach Chrome', sensors: ['X-Trans V'], filmSimulation: 'Classic Chrome', dynamicRange: 'DR200',
    dRangePriority: 'Off', grainRoughness: 'Weak', whiteBalance: 'Daylight', whiteBalanceRed: 1, whiteBalanceBlue: -2,
    sharpness: 0, highIsoNr: -2, clarity: 0);

void main() {
  test('parses a Kata Code', () {
    final out = parseImportText(KataCode.encode(_r, credit: 'parth'))!;
    expect(out.kind, ImportKind.kataCode);
    expect(out.recipe.filmSimulation, 'Classic Chrome');
  });

  test('parses OFR JSON and flags a stale hash', () {
    final j = _r.toJson()..['hash'] = 'deadbeef';
    final out = parseImportText(jsonEncode(j))!;
    expect(out.kind, ImportKind.ofrJson);
    expect(out.warnings.single, contains('recomputed'));
  });

  test('empty text yields nothing; garbage throws', () {
    expect(parseImportText('   '), isNull);
    expect(() => parseImportText('not a recipe'), throwsA(isA<FormatException>()));
  });

  test('an image with no code reports it clearly', () {
    expect(
      () => parseImportFile('/tmp/card.png', Uint8List.fromList(List.filled(64, 0))),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('No Kata Code'))),
    );
  });

  test('a .ofr.json file parses through the file path', () {
    final out = parseImportFile('/tmp/beach.ofr.json', Uint8List.fromList(utf8.encode(jsonEncode(_r.toJson()))))!;
    expect(out.kind, ImportKind.ofrJson);
    expect(out.sourceLabel, 'beach.ofr.json');
  });
}
