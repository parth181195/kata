import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/testing.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:kata/core/fuji/camera_service.dart';
import 'package:kata/data/recipe_repository.dart';
import 'package:kata/data/recipe.dart';

import '../helpers.dart';

void main() {
  _supportedCameras();
  testWidgets('no camera shows the checklist; plugging one in connects by itself → slot grid; slot panel saves to Mine', (t) async {
    final host = FakeUsbHost(FakeFujiBody(), present: false);
    final c = await pumpKata(t, initialLocation: '/camera', overrides: fakeCameraOverrides(host));
    expect(find.text('Camera off, plug in USB-C'), findsOneWidget);
    expect(find.text('CONNECT'), findsOneWidget);
    expect(find.text('DISCONNECTED'), findsOneWidget);

    // plug it in: the host's attach event connects without a tap
    host.present = true;
    host.ctrl.add(const UsbEvent(attached: true, deviceName: '/dev/bus/usb/001/002', vid: 0x04CB));
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
    expect(find.text('X-S20'), findsOneWidget);
    expect(find.text('CONNECTED'), findsOneWidget);
    expect(find.text('C1'), findsOneWidget);
    expect(find.text('C4'), findsOneWidget);
    expect(find.text('READ ALL ↻'), findsOneWidget);

    await t.tap(find.text('C2'));
    await t.pumpAndSettle();
    expect(find.text("C2 — WHAT'S IN THE CAMERA"), findsOneWidget);
    // Save opens the publish sheet: name it, then keep it locally
    await t.tap(find.text('Save as kata'));
    await t.pumpAndSettle();
    expect(find.textContaining('SAVE C2 FROM THE CAMERA'), findsOneWidget);
    await t.tap(find.text('Save to Mine'));
    // the save writes to the local db: testWidgets' fake async can't complete that on its
    // own, so interleave real event-loop turns before settling
    for (var i = 0; i < 6; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pumpAndSettle();
    }
    final mine = c.read(recipeRepositoryProvider).mine;
    expect(mine.length, 1);
    expect(mine.first.source, RecipeSource.camera);
    expect(find.text('Saved to Mine'), findsOneWidget);

    // flush the snackbar timer and stop the heartbeat
    await t.pump(const Duration(seconds: 5));
    await c.read(cameraServiceProvider.notifier).disconnect();
    await t.pumpAndSettle();
  });

  testWidgets('no device → NO CAMERA pill + Connect stays', (t) async {
    final host = FakeUsbHost(FakeFujiBody(), present: false);
    await pumpKata(t, initialLocation: '/camera', overrides: fakeCameraOverrides(host));
    await t.tap(find.text('CONNECT'));
    await t.pumpAndSettle();
    expect(find.text('NO CAMERA'), findsOneWidget);
    expect(find.text('CONNECT'), findsOneWidget);
  });
}

void _supportedCameras() {
  testWidgets('supported cameras screen lists tiers; connected body is highlighted', (t) async {
    final host = FakeUsbHost(FakeFujiBody());
    await pumpKata(t, initialLocation: '/cameras', overrides: fakeCameraOverrides(host));
    expect(find.text('CAMERAS'), findsOneWidget);
    expect(find.text('X-S20'), findsWidgets); // row (+ the caption text inside the art placeholder)
    expect(find.text('TESTED'), findsOneWidget);
    expect(find.text('WRITES RECIPES'), findsOneWidget);
    expect(find.text('WRITES'), findsWidgets);
    expect(find.text('CONNECTED NOW'), findsNothing);
    await t.scrollUntilVisible(find.text('CONNECTS, READ ONLY'), 400, scrollable: find.byType(Scrollable).first);
    expect(find.text('READ'), findsWidgets);
  });

  testWidgets('camera tab links to the supported list', (t) async {
    final host = FakeUsbHost(FakeFujiBody(), present: false);
    await pumpKata(t, initialLocation: '/camera', overrides: fakeCameraOverrides(host));
    await t.tap(find.text('Which cameras work?'));
    await t.pumpAndSettle();
    expect(find.text('CAMERAS'), findsOneWidget);
  });
}
