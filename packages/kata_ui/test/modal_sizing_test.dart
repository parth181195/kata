import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata_ui/kata_ui.dart';

/// Dialog's own render box spans the overlay; the panel is the Material it wraps.
Finder _panel() => find.descendant(of: find.byType(Dialog), matching: find.byType(Material)).first;

Future<void> _pump(WidgetTester t, Size size, void Function(BuildContext) onTap) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(
    theme: KataTheme.dark(),
    home: Scaffold(body: Builder(builder: (c) => Center(child: TextButton(onPressed: () => onTap(c), child: const Text('open'))))),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('a confirm dialog stays a modal on a wide window, not a banner', (t) async {
    await _pump(t, const Size(2000, 1200), (c) => showKataDialog(c, title: 'Publish?', body: 'It goes live right away.', confirmLabel: 'Publish'));
    expect(find.text('PUBLISH?'), findsOneWidget);
    final box = t.getRect(_panel());
    expect(box.width, lessThanOrEqualTo(KataLayout.dialogWidth + 1), reason: 'capped, not full-bleed');
    expect(box.center.dx, closeTo(1000, 1), reason: 'and centred');
  });

  testWidgets('the same dialog still uses the width it has on a phone', (t) async {
    await _pump(t, const Size(412, 892), (c) => showKataDialog(c, title: 'Publish?', body: 'It goes live right away.', confirmLabel: 'Publish'));
    final box = t.getRect(_panel());
    expect(box.width, greaterThan(300), reason: 'phones get the near-full width they always had');
    expect(box.width, lessThanOrEqualTo(412 - 56), reason: 'minus the 28px inset on each side');
  });

  testWidgets('a sheet is a bottom sheet on a phone', (t) async {
    await _pump(t, const Size(412, 892), (c) => showKataSheet<void>(c, builder: (_) => const SizedBox(height: 200, child: Center(child: Text('body')))));
    expect(find.text('body'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('and a centred panel on a desktop window', (t) async {
    await _pump(t, const Size(1600, 1000), (c) => showKataSheet<void>(c, builder: (_) => const SizedBox(height: 200, child: Center(child: Text('body')))));
    expect(find.text('body'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    final box = t.getRect(_panel());
    expect(box.width, lessThanOrEqualTo(KataLayout.sheetWidth + 1));
    expect(box.center.dx, closeTo(800, 1));
    expect(box.center.dy, closeTo(500, 60), reason: 'centred vertically, not stuck to the bottom edge');
  });

  testWidgets('a sheet still returns its value from either presentation', (t) async {
    String? got;
    await _pump(t, const Size(1600, 1000), (c) async {
      got = await showKataSheet<String>(c, builder: (s) => TextButton(onPressed: () => Navigator.of(s).pop('done'), child: const Text('finish')));
    });
    await t.tap(find.text('finish'));
    await t.pumpAndSettle();
    expect(got, 'done');
  });
}
