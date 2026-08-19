import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata_ui/kata_ui.dart';

Widget wrap(Widget w) => MaterialApp(theme: KataTheme.dark(), home: Scaffold(body: Center(child: w)));

void main() {
  test('SwatchBars.fromTones is deterministic and in range', () {
    final a = SwatchBars.fromTones(highlight: -1, shadow: 0.5, color: 2, sharpness: -2, clarity: 0);
    final b = SwatchBars.fromTones(highlight: -1, shadow: 0.5, color: 2, sharpness: -2, clarity: 0);
    expect(a.heights, b.heights);
    expect(a.heights.length, 5);
    for (final h in a.heights) {
      expect(h, inInclusiveRange(0.25, 1.0));
    }
    for (final g in a.greys) {
      expect(g, inInclusiveRange(0, 3));
    }
    expect(a.heights, isNot(SwatchBars.fromTones(highlight: 2, shadow: 2, color: -4, sharpness: 4, clarity: 5).heights));
  });
  testWidgets('spec grid renders labels, values, rulers', (t) async {
    await t.pumpWidget(wrap(const SpecGrid([
      SpecItem('Film Sim', 'Classic Chrome', display: true),
      SpecItem('Dynamic Range', 'DR400'),
      SpecItem('Highlight', '+1', rulerT: 0.56),
    ])));
    expect(find.text('FILM SIM'), findsOneWidget);
    expect(find.text('CLASSIC CHROME'), findsOneWidget);
    expect(find.text('DR400'), findsOneWidget);
    expect(find.byType(Ruler), findsOneWidget);
  });
  testWidgets('slot cards, checklist, dot matrix, frame, bottom nav', (t) async {
    var tapped = -1;
    await t.pumpWidget(wrap(SingleChildScrollView(
        child: Column(children: [
      const SlotCard(slot: 1, state: SlotCardState.filled, title: 'Kodachrome 64', line1: 'CLASSIC CHROME', line2: 'DR400 · 5800K'),
      const SlotCard(slot: 2, state: SlotCardState.onDial, title: 'Nostalgic Neg'),
      const SlotCard(slot: 4, state: SlotCardState.empty),
      const ChecklistStep(n: 1, title: 'Plug in USB-C', active: true),
      const DotMatrixProgress(progress: 0.8),
      const SizedBox(width: 80, height: 80, child: FrameSlot(placeholder: 'frame')),
      KataBottomNav(index: 0, onTap: (i) => tapped = i),
    ]))));
    expect(find.text('C1'), findsOneWidget);
    expect(find.text('ON DIAL'), findsOneWidget);
    expect(find.text('EMPTY'), findsOneWidget);
    expect(find.text('Plug in USB-C'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nav-2')));
    expect(tapped, 2);
  });
}
