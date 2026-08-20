import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/features/shell/shell_scaffold.dart';

import '../helpers.dart';

/// Android back from a tab should walk back to the library before leaving the app.
Future<bool> _pressBack(WidgetTester t) async {
  // PopScope is generic, so byType can't match it
  final scope = t.widgetList(find.byWidgetPredicate((w) => w is PopScope)).first as dynamic;
  final canPop = scope.canPop as bool;
  if (!canPop) (scope.onPopInvokedWithResult as void Function(bool, dynamic)?)?.call(false, null);
  await t.pumpAndSettle();
  return canPop; // true = the app would actually close
}

void main() {
  testWidgets('back from Camera goes to the library first, then closes the app', (t) async {
    await pumpKata(t, initialLocation: '/camera');
    expect(find.byType(ShellScaffold), findsOneWidget);

    // first back: stays in the app, lands on the library
    expect(await _pressBack(t), isFalse, reason: 'a back press on Camera must not exit');
    expect(find.text('Search recipes, film sims, authors'), findsOneWidget, reason: 'we are on the library');

    // second back: nothing left to go back to, so the app may close
    expect(await _pressBack(t), isTrue);
  });

  testWidgets('back from Mine also returns to the library', (t) async {
    await pumpKata(t, initialLocation: '/mine');
    expect(await _pressBack(t), isFalse);
    expect(find.text('Search recipes, film sims, authors'), findsOneWidget);
  });

  testWidgets('the library itself does not trap back', (t) async {
    await pumpKata(t, initialLocation: '/library');
    expect(await _pressBack(t), isTrue);
  });
}
