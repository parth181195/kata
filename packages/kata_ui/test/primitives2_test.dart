import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata_ui/kata_ui.dart';

Widget wrap(Widget w) => MaterialApp(theme: KataTheme.dark(), home: Scaffold(body: SingleChildScrollView(child: w)));

void main() {
  testWidgets('text field, segmented, tabs, chips variants', (t) async {
    var seg = 0, tab = 0, removed = 0;
    await t.pumpWidget(wrap(StatefulBuilder(builder: (c, set) => Column(children: [
      const KataTextField(label: 'Kata name', hint: 'Untitled kata'),
      const KataTextField(label: 'Clarity', error: 'Out of range −5…+5', unit: 'K'),
      KataSegmented(labels: const ['All', 'Mine', 'Saved'], index: seg, onChanged: (i) => set(() => seg = i), counts: const [null, 3, null]),
      KataTabs(labels: const ['Colour', 'B&W'], index: tab, onChanged: (i) => set(() => tab = i)),
      KataChip(label: 'Acros', onRemove: () => removed++),
      const KataChip(label: 'Film sim', leadingPlus: true),
      const KataChip(label: 'Mine', count: 3),
      const KataChip(label: 'Disabled', enabled: false),
    ]))));
    expect(find.text('KATA NAME'), findsOneWidget);
    expect(find.text('OUT OF RANGE −5…+5'), findsOneWidget);
    await t.tap(find.text('MINE').first);
    await t.pump();
    expect(seg, 1);
    await t.tap(find.text('B&W'));
    await t.pump();
    expect(tab, 1);
    await t.tap(find.text('×'));
    expect(removed, 1);
    expect(find.text('3'), findsNWidgets(2));
  });
  testWidgets('rows, banner, empty state, skeleton, dialog', (t) async {
    // looping placeholders (skeleton pulse) never settle — run this one under reduce-motion
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    bool? result;
    await t.pumpWidget(wrap(Builder(builder: (c) => Column(children: [
      const KataSectionHeader('Settings'),
      const KataListRow(title: 'Default write slot', value: 'Ask each time'),
      const KataBanner(child: Text('Turn the dial off C3 and back.')),
      const KataEmptyState(glyph: '0', title: 'Nothing saved yet', body: 'Favourite a kata.', actionLabel: 'Browse library'),
      const KataSkeletonCard(),
      TextButton(onPressed: () async => result = await showKataDialog(c, title: 'Overwrite C3?', body: 'Acros Push is in this slot.', confirmLabel: 'Overwrite', destructive: true), child: const Text('open')),
    ]))));
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('ASK EACH TIME'), findsOneWidget);
    expect(find.text('NOTHING SAVED YET'), findsOneWidget);
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text('OVERWRITE C3?'), findsOneWidget);
    await t.tap(find.text('Overwrite'));
    await t.pumpAndSettle();
    expect(result, isTrue);
  });
}
