import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata_ui/kata_ui.dart';

Widget wrap(Widget w) => MaterialApp(theme: KataTheme.dark(), home: Scaffold(body: Center(child: w)));

void main() {
  testWidgets('pill buttons render labels and fire', (t) async {
    var hits = 0;
    await t.pumpWidget(wrap(Column(children: [
      KataPillButton(label: 'Write to camera', onPressed: () => hits++),
      const KataPillButton(label: 'Secondary', kind: KataButtonKind.secondary, onPressed: null),
      KataPillButton(label: 'Overwrite', kind: KataButtonKind.danger, onPressed: () => hits++),
    ])));
    expect(find.text('WRITE TO CAMERA'), findsOneWidget);
    await t.tap(find.text('WRITE TO CAMERA'));
    expect(hits, 1);
  });
  testWidgets('status pill + badge + chip + search', (t) async {
    await t.pumpWidget(wrap(const Column(children: [
      KataStatusPill(KataStatus.connected),
      KataStatusPill(KataStatus.disconnected, label: 'NO CAMERA'),
      VerifiedBadge(),
      KataChip(label: 'VERIFIED', selected: true, dot: true),
      KataSearchField(hint: 'Search recipes'),
    ])));
    expect(find.text('CONNECTED'), findsOneWidget);
    expect(find.text('NO CAMERA'), findsOneWidget);
    expect(find.text('✓'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('Search recipes'), findsOneWidget);
  });
  testWidgets('sheet, card, issue card, toast', (t) async {
    await t.pumpWidget(wrap(Builder(builder: (c) => Column(children: [
      const KataSheet(eyebrow: 'WRITING', title: 'Kodachrome 64', children: [Text('body')]),
      const KataCard(child: Text('card')),
      const IssueCard(title: '1 SETTING SKIPPED', rows: [IssueRow('Kelvin 5800K', 'WB ISN\'T COLOR TEMP')]),
      TextButton(onPressed: () => KataToast.show(c, 'Saved to Mine', action: 'UNDO', onAction: () {}), child: const Text('toast')),
    ]))));
    expect(find.text('KODACHROME 64'), findsOneWidget);
    expect(find.text('1 SETTING SKIPPED'), findsOneWidget);
    await t.tap(find.text('toast'));
    await t.pump();
    expect(find.text('Saved to Mine'), findsOneWidget);
  });
}
