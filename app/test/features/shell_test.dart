import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  testWidgets('signed out → sign-in; Continue → library', (t) async {
    await pumpKata(t, signedIn: false);
    expect(find.text('KATA'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    await t.tap(find.text('Continue with Google'));
    await t.pumpAndSettle();
    expect(find.text('KATA 型'), findsOneWidget);
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
