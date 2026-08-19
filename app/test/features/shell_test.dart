import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('signed out → sign-in; Continue (Google) → library; profile shows user; sign out → sign-in', (t) async {
    await pumpKata(t, signedIn: false);
    expect(find.text('KATA'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(find.text('KATA 型'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('nav-3')));
    await t.pumpAndSettle();
    expect(find.text('PARTH JANSARI'), findsOneWidget);
    expect(find.text('parth@example.com'), findsOneWidget);
    await t.tap(find.text('Sign out'));
    await t.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('cancelled Google picker stays on sign-in', (t) async {
    await pumpKata(t, signedIn: false, google: FakeGoogle(cancel: true));
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('signed out: long-press the mark opens the probe screen (debug route allowed)', (t) async {
    await pumpKata(t, signedIn: false);
    await t.longPress(find.text('型'));
    await t.pumpAndSettle();
    expect(find.text('Kata · probe'), findsOneWidget);
    expect(find.text('Ping API'), findsOneWidget);
  });

  testWidgets('bottom nav switches branches; profile → kit', (t) async {
    await pumpKata(t);
    await t.tap(find.byKey(const ValueKey('nav-1')));
    await t.pumpAndSettle();
    expect(find.text('CAMERA'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('nav-3')));
    await t.pumpAndSettle();
    expect(find.text('PROFILE'), findsOneWidget);
    await t.tap(find.text('Component kit'));
    await t.pumpAndSettle();
    expect(find.text('KATA 型 KIT'), findsOneWidget);
  });
}
