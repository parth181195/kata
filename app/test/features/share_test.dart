import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/features/share/card_renderer.dart';
import 'package:kata/features/share/card_templates.dart';
import 'package:kata/features/share/share_composer_sheet.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

void main() {
  testWidgets('detail ⋮ → Share card: composer with preview, template switch, payload peek, copy', (t) async {
    await pumpKata(t, initialLocation: '/recipe/a');
    await t.tap(find.byIcon(Icons.more_vert).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Share card').first);
    await t.pumpAndSettle();
    expect(find.byType(ShareComposerSheet), findsOneWidget);
    expect(find.text('S1 · RECIPE CARD'), findsOneWidget);
    await t.ensureVisible(find.text('S4 CODE'));
    await t.pumpAndSettle();
    await t.tap(find.text('S4 CODE'));
    await t.pumpAndSettle();
    expect(find.text('S4 · KATA CODE'), findsOneWidget);
    expect(find.text('HOW TO USE'), findsOneWidget);
    await t.ensureVisible(find.text('{ }'));
    await t.pumpAndSettle();
    await t.tap(find.text('{ }'));
    await t.pumpAndSettle();
    final payload = t.widget<Text>(find.byKey(const ValueKey('payload'))).data!;
    expect(payload, startsWith('kata1:CC,DR400'));
    expect(KataCode.decode(payload).recipe.name, 'Kodachrome 64');
    // invert toggles palette without breaking layout
    await t.ensureVisible(find.text('Invert card'));
    await t.pumpAndSettle();
    await t.tap(find.text('Invert card'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('S1 card renders to a PNG', (t) async {
    await t.runAsync(() async {
      final key = GlobalKey();
      final r = FakeRecipeApi.fromSeed(seedJson).recipes.first;
      await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: OffscreenCardHost(boundaryKey: key, spec: ShareSpec(recipe: r, template: ShareTemplate.card, ratio: ShareRatio.r4x5, credit: 'Fuji X Weekly'), scale: 0.5)))));
      await t.pump();
      final png = await CardRenderer(key).toPng(pixelRatio: 2, settle: false);
      expect(png.length, greaterThan(8 * 1024));
      expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });
  });
}
