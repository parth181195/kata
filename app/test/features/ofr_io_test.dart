import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/local_library.dart';

import '../helpers.dart';

const _badJson = '{"v":1,"film_simulation":"Classic Chrome","d_range_priority":"Off","grain_roughness":"Weak","white_balance":"Daylight","white_balance_red":0,"white_balance_blue":0,"sharpness":0,"high_iso_nr":0,"clarity":9}';
const _goodJson = '{"v":1,"name":"Portra Warm","film_simulation":"Pro Neg. Hi","dynamic_range":"DR400","d_range_priority":"Off","grain_roughness":"Off","white_balance":"Kelvin","wb_kelvin":6300,"white_balance_red":0,"white_balance_blue":0,"highlight":-1,"shadow":1,"color":1,"sharpness":0,"high_iso_nr":-4,"clarity":1}';

void main() {
  testWidgets('export sheet shows the OFR JSON', (t) async {
    await pumpKata(t);
    await t.tap(find.text('KODACHROME 64'));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.more_vert).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Export OFR'));
    await t.pumpAndSettle();
    expect(find.text('EXPORT · OPEN FUJI RECIPE'), findsOneWidget);
    expect(find.textContaining('"film_simulation": "Classic Chrome"'), findsOneWidget);
    expect(find.text('Copy JSON'), findsOneWidget);
  });

  testWidgets('import: invalid clarity blocks save; valid JSON saves to Mine', (t) async {
    final c = await pumpKata(t, initialLocation: '/mine');
    expect(find.text('NOTHING SAVED YET'), findsOneWidget);
    await t.tap(find.text('+'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), _badJson);
    await t.pumpAndSettle();
    expect(find.textContaining('clarity: 9'), findsOneWidget);
    expect(find.textContaining('RANGE -5…5'), findsOneWidget);
    final save = t.widget<InkWell>(find.ancestor(of: find.text('SAVE TO MINE'), matching: find.byType(InkWell)).first);
    expect(save.onTap, isNull);

    await t.enterText(find.byType(TextField), _goodJson);
    await t.pumpAndSettle();
    expect(find.text('PRO NEG. HI'), findsOneWidget);
    await t.tap(find.text('SAVE TO MINE'));
    await t.pumpAndSettle();
    expect(c.read(localLibraryProvider).lib.mine.length, 1);
    await t.tap(find.text('MY RECIPES'));
    await t.pumpAndSettle();
    expect(find.text('PORTRA WARM'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });
}
