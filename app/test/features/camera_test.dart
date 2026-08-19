import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/testing.dart';
import 'package:kata/core/fuji/camera_service.dart';
import 'package:kata/data/local_library.dart';
import 'package:kata/data/recipe.dart';

import '../helpers.dart';

void main() {
  testWidgets('disconnected shows checklist and Connect; connect → slot grid; slot panel saves to Mine', (t) async {
    final host = FakeUsbHost(FakeFujiBody());
    final c = await pumpKata(t, initialLocation: '/camera', overrides: fakeCameraOverrides(host));
    expect(find.text('Camera off, plug in USB-C'), findsOneWidget);
    expect(find.text('CONNECT'), findsOneWidget);
    expect(find.text('DISCONNECTED'), findsOneWidget);

    await t.tap(find.text('CONNECT'));
    await t.pumpAndSettle();
    expect(find.text('X-S20'), findsOneWidget);
    expect(find.text('CONNECTED'), findsOneWidget);
    expect(find.text('C1'), findsOneWidget);
    expect(find.text('C4'), findsOneWidget);
    expect(find.text('READ ALL ↻'), findsOneWidget);

    await t.tap(find.text('C2'));
    await t.pumpAndSettle();
    expect(find.text("C2 — WHAT'S IN THE CAMERA"), findsOneWidget);
    await t.tap(find.text('Save as kata'));
    await t.pumpAndSettle();
    final mine = c.read(localLibraryProvider).lib.mine;
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
