import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/testing.dart';
import 'package:kata/core/fuji/camera_service.dart';

import '../helpers.dart';

void main() {
  testWidgets('write flow: choose C3 → overwrite warning → writing → done with dial card', (t) async {
    final host = FakeUsbHost(FakeFujiBody());
    final c = await pumpKata(t, initialLocation: '/camera', overrides: fakeCameraOverrides(host));
    unawaited(c.read(cameraServiceProvider.notifier).connect());
    await t.pumpAndSettle();

    // go to a recipe detail
    await t.tap(find.byKey(const ValueKey('nav-0')));
    await t.pumpAndSettle();
    await t.tap(find.text('KODACHROME 64'));
    await t.pumpAndSettle();
    expect(find.text('X-S20 · C1–C4'), findsOneWidget);
    await t.tap(find.text('WRITE TO CAMERA'));
    await t.pumpAndSettle();
    expect(find.text('CHOOSE SLOT'), findsOneWidget);
    expect(find.text('CHOOSE A SLOT'), findsOneWidget);

    await t.tap(find.text('C3'));
    await t.pumpAndSettle();
    expect(find.textContaining('C3 will be overwritten'), findsOneWidget);
    await t.tap(find.text('WRITE TO C3'));
    await t.pump();
    expect(find.textContaining('WRITING'), findsWidgets);
    await t.pumpAndSettle(const Duration(seconds: 4));
    expect(find.text('WRITTEN TO C3'), findsOneWidget);
    expect(find.textContaining('Turn the mode dial off'), findsOneWidget);
    expect(host.body.slots[3]![0xD192], Uint8List.fromList([11, 0]));

    await t.tap(find.text('DONE'));
    await t.pumpAndSettle();
    await t.pump(const Duration(seconds: 5));
    unawaited(c.read(cameraServiceProvider.notifier).disconnect());
    await t.pumpAndSettle();
  });
}
