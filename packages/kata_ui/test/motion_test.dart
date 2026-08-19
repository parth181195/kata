import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata_ui/kata_ui.dart';

Widget _wrap(Widget child) => MaterialApp(theme: KataTheme.dark(), home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('KataTapScale scales to 0.98 while pressed and back on release', (t) async {
    await t.pumpWidget(_wrap(const KataTapScale(child: ColoredBox(color: Colors.white, child: SizedBox(width: 100, height: 40)))));
    final g = await t.startGesture(t.getCenter(find.byType(KataTapScale)));
    await t.pump(KataMotion.tap);
    expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 0.98);
    await g.up();
    await t.pump(KataMotion.tap);
    expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('DotMatrixProgress animated walks to the target one dot per step', (t) async {
    await t.pumpWidget(_wrap(const DotMatrixProgress(progress: 1, animated: true)));
    int lit() {
      const p = KataPalette.darkPalette;
      return t.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).where((c) => (c.decoration as BoxDecoration).color == p.fg).length;
    }
    expect(lit(), 0);
    for (var i = 0; i < 12; i++) {
      await t.pump(KataMotion.dotStep);
    }
    expect(lit(), inInclusiveRange(10, 13));
    await t.pumpAndSettle(KataMotion.dotStep);
    expect(lit(), 24);
  });

  testWidgets('KataFadeIn goes from transparent to opaque over the page duration', (t) async {
    await t.pumpWidget(_wrap(const KataFadeIn(child: Text('hi'))));
    final op = find.byType(Opacity);
    expect(t.widget<Opacity>(op).opacity, 0);
    await t.pump(KataMotion.page);
    await t.pump();
    expect(t.widget<Opacity>(op).opacity, 1);
  });
}
