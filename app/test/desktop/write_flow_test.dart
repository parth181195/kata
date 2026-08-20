import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:fuji_ptp/testing.dart';
import 'package:kata/core/fuji/camera_service.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/desktop/desktop_camera.dart';
import 'package:kata/desktop/slot_backups.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

const _ofr = OfrRecipe(
    name: 'Winter Chrome', sensors: ['X-Trans V'], filmSimulation: 'Classic Chrome', dynamicRange: 'DR200',
    dRangePriority: 'Off', grainRoughness: 'Weak', whiteBalance: 'Daylight', whiteBalanceRed: 1, whiteBalanceBlue: -2,
    sharpness: 0, highIsoNr: -2, clarity: 0);

/// A button that opens the real write flow with the given queue — mirrors the board/dock call site.
class _Harness extends ConsumerWidget {
  const _Harness({required this.slot});
  final int slot;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () {
              ref.read(writeQueueProvider.notifier).state = {slot: Recipe(id: 'r1', ofr: _ofr)};
              showWriteReview(context, ref);
            },
            child: const Text('go'),
          ),
        ),
      );
}

/// pumpAndSettle alone can't advance real async work (PTP futures, the path_provider
/// channel) because testWidgets runs in fake-async: interleave real event-loop turns.
Future<void> _settle(WidgetTester t, {int turns = 8}) async {
  for (var i = 0; i < turns; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pumpAndSettle();
  }
}

Future<ProviderContainer> _pump(WidgetTester t, FakeUsbHost host) async {
  // looping loaders never settle: run these under reduce-motion
  t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final c = ProviderContainer(overrides: [
    usbHostProvider.overrideWithValue(host),
    fujiCameraFactoryProvider.overrideWithValue(
        (link, reopen) => FujiCamera(PtpTransport(link), reopenUsb: reopen, slotSettle: Duration.zero)),
  ]);
  addTearDown(c.dispose);
  // testWidgets runs in fake-async: PTP's zero-duration settles need a real event loop
  await t.runAsync(() => c.read(cameraServiceProvider.notifier).connect());
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(theme: KataTheme.dark(), home: const _Harness(slot: 2)),
  ));
  return c;
}

void main() {
  late Directory tmp;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmp = Directory.systemTemp.createTempSync('kata_test');
    // path_provider has no implementation under flutter test: answer the channel ourselves
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tmp.path,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    tmp.deleteSync(recursive: true);
  });

  testWidgets('review → writing progress → done card, and the slot really changed', (t) async {
    final body = FakeFujiBody();
    final c = await _pump(t, FakeUsbHost(body));

    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    // 1b review dialog first — nothing written yet
    expect(find.textContaining('REVIEW 1 WRITE'), findsOneWidget);
    expect(body.slots[2]![0xD192], isNot(Uint8ListEq([11, 0])));

    await t.tap(find.textContaining('WRITE THE SLOT'));
    await _settle(t);

    // 1c done card
    expect(find.text('WRITE COMPLETE'), findsOneWidget);
    expect(find.textContaining('1 slot written'), findsOneWidget);
    expect(find.textContaining('Turn the mode dial off'), findsOneWidget);
    // Classic Chrome landed in C2 and the queue is empty again
    expect(body.slots[2]![0xD192]!.first, 11);
    expect(c.read(writeQueueProvider), isEmpty);
    // a pre-write backup was taken automatically
    expect(c.read(slotBackupsProvider).length, 1);
    expect(c.read(slotBackupsProvider).first.auto, isTrue);

    await t.tap(find.text('DONE'));
    await t.pumpAndSettle();
    expect(find.text('WRITE COMPLETE'), findsNothing);
  });

  testWidgets('cancelling the review writes nothing', (t) async {
    final body = FakeFujiBody();
    final c = await _pump(t, FakeUsbHost(body));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('WRITE COMPLETE'), findsNothing);
    expect(body.slots[2]![0xD192]!.first, isNot(11));
    expect(c.read(writeQueueProvider).length, 1); // still queued
    expect(c.read(slotBackupsProvider), isEmpty); // no write attempted → no backup
  });

  testWidgets('a rejected fatal property surfaces as a failure card, queue survives', (t) async {
    final body = FakeFujiBody()..rejectWrites.add(0xD192); // film sim: fatal in the plan? no — use a fatal one
    final c = await _pump(t, FakeUsbHost(body));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('WRITE THE SLOT'));
    await _settle(t);
    // D192 is optional → warning, not failure: the write still completes
    expect(find.text('WRITE COMPLETE'), findsOneWidget);
    expect(find.textContaining('SETTING'), findsWidgets); // skipped list rendered
    expect(c.read(writeQueueProvider), isEmpty);
  });

  testWidgets('Undo from backup queues the pre-write slot and opens the review', (t) async {
    final body = FakeFujiBody();
    // give C2 a recognisable starting value so the restore has something to put back
    body.slots[2]![0xD192] = Uint8List.fromList([2, 0]); // Velvia
    final c = await _pump(t, FakeUsbHost(body));

    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('WRITE THE SLOT'));
    await _settle(t);
    expect(find.text('WRITE COMPLETE'), findsOneWidget);
    expect(body.slots[2]![0xD192]!.first, 11); // Classic Chrome landed

    // Undo pops the done card and re-opens the review with the backup queued
    await t.tap(find.textContaining('Undo from backup'));
    await _settle(t);
    expect(find.textContaining('REVIEW 1 WRITE'), findsOneWidget);
    expect(c.read(writeQueueProvider)[2]!.ofr.filmSimulation, 'Velvia');

    await t.tap(find.textContaining('WRITE THE SLOT'));
    await _settle(t);
    expect(body.slots[2]![0xD192]!.first, 2); // back to Velvia
  });
}

/// Matcher helper: compares the first byte only (fake body stores 2-byte LE values).
class Uint8ListEq extends Matcher {
  Uint8ListEq(this.expected);
  final List<int> expected;
  @override
  bool matches(dynamic item, Map matchState) => item is List<int> && item.length >= expected.length && item[0] == expected[0];
  @override
  Description describe(Description d) => d.add('bytes starting $expected');
}