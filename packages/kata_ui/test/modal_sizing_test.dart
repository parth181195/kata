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

  _rowTests();
  _stepperTests();
  _rulerScaleTests();

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

/// Rows you choose from: the tick belongs at the end of the line, not floating in the middle.
void _rowTests() {
  testWidgets('a selected row shows its tick at the end of the line', (t) async {
    t.view.physicalSize = const Size(1200, 400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
      theme: KataTheme.dark(),
      home: const Scaffold(
        body: Column(children: [
          KataListRow(title: 'X-S20', sub: 'X-Trans V · C1–C4', selected: true, contentInset: 18),
          KataListRow(title: 'X-T4', sub: 'X-Trans IV · C1–C7'),
        ]),
      ),
    ));
    await t.pumpAndSettle();
    final tick = t.getRect(find.text('✓'));
    final row = t.getRect(find.widgetWithText(KataListRow, 'X-S20'));
    expect(tick.right, closeTo(row.right - 18, 4), reason: 'at the end of the line, inside the inset');
    expect(find.text('✓'), findsOneWidget, reason: 'only the selected row gets one');

    // the row inverts: white ground, black text
    final p = KataTheme.dark().extension<KataPalette>()!;
    final title = t.widget<Text>(find.text('X-S20'));
    expect(title.style?.color, p.bg, reason: 'text is knocked out of the white ground');
    final grounds = t.widgetList<DecoratedBox>(find.descendant(of: find.widgetWithText(KataListRow, 'X-S20'), matching: find.byType(DecoratedBox)));
    expect(grounds.any((d) => (d.decoration as BoxDecoration).color == p.fg), isTrue, reason: 'and the ground is white');
  });
}

/// The stepper's ruler: it has to *show* the value and let you drag it.
void _stepperTests() {
  testWidgets('the ruler marker tracks the value and can be dragged', (t) async {
    num value = 0;
    t.view.physicalSize = const Size(800, 400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
      theme: KataTheme.dark(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (_, setState) => Column(
            crossAxisAlignment: CrossAxisAlignment.start, // the layout that used to collapse it
            children: [
              KataStepper(label: 'Shadow', value: value, min: -9, max: 9, onChanged: (v) => setState(() => value = v)),
            ],
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    // the bar fills its row rather than collapsing to nothing
    final bar = find.byWidgetPredicate((w) => w is CustomPaint && w.size.width > 200);
    expect(bar, findsWidgets, reason: 'a zero-width ruler pins the marker at the left forever');

    // dragging to the far right sets the maximum
    final rect = t.getRect(bar.first);
    await t.tapAt(Offset(rect.right - 2, rect.center.dy));
    await t.pumpAndSettle();
    expect(value, 9);

    await t.tapAt(Offset(rect.left + 2, rect.center.dy));
    await t.pumpAndSettle();
    expect(value, -9);

    await t.dragFrom(Offset(rect.left + 2, rect.center.dy), Offset(rect.width / 2, 0));
    await t.pumpAndSettle();
    expect(value, 0, reason: 'dragging to the middle of a ±9 range lands on zero');
  });
}

/// A scale is only useful if its zero sits where zero actually is.
void _rulerScaleTests() {
  testWidgets('the 0 label lands on its tick, not in the middle of the row', (t) async {
    t.view.physicalSize = const Size(600, 300);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
      theme: KataTheme.dark(),
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(20),
          // -2…+4: zero is a third along, not half
          child: SpecCell(SpecItem('Highlight', '+0.5', rulerT: 0.416, rulerMin: '-2', rulerMax: '+4')),
        ),
      ),
    ));
    await t.pumpAndSettle();

    final row = t.getRect(find.text('-2'));
    final end = t.getRect(find.text('+4'));
    final zero = t.getRect(find.text('0'));
    final span = end.right - row.left;
    final at = (zero.center.dx - row.left) / span;
    expect(at, closeTo(1 / 3, 0.06), reason: 'zero sits a third along a -2…+4 scale');
  });
}
