import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:fuji_ptp/testing.dart';
import 'package:kata/core/fuji/camera_service.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/data/local_db.dart';
import 'package:kata/data/recipe_repository.dart';
import 'package:kata/desktop/slot_identity.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

const _ofr = OfrRecipe(
    name: 'Beach Chrome', sensors: ['X-Trans V'], filmSimulation: 'Classic Chrome', dynamicRange: 'DR200',
    dRangePriority: 'Off', grainRoughness: 'Weak', whiteBalance: 'Daylight', whiteBalanceRed: 1, whiteBalanceBlue: -2,
    highlight: 0, shadow: 0, color: 0, sharpness: 0, highIsoNr: -2, clarity: 0);

/// Reads identity for C2 through a real ConsumerWidget (identifySlot needs a WidgetRef).
class _Probe extends ConsumerWidget {
  const _Probe({required this.model, required this.onIdentity});
  final String model;
  final void Function(SlotIdentity) onIdentity;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(cameraServiceProvider);
    if (st is CameraReady) onIdentity(identifySlot(ref, model, 2, st.slots[1]));
    return const SizedBox.shrink();
  }
}

void main() {
  late Directory tmp;
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmp = Directory.systemTemp.createTempSync('kata_edit');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (call) async => tmp.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    tmp.deleteSync(recursive: true);
  });

  testWidgets('write → unplug → edit on camera → reconnect ⇒ slot reads as edited, origin kept', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final body = FakeFujiBody();
    final host = FakeUsbHost(body);
    final api = FakeRecipeApi([Recipe(id: 'lib-1', ofr: _ofr.copyWith(hash: OfrHasher.compute(_ofr)))]);
    final db = KataDb.memory();
    addTearDown(db.close);
    final repo = RecipeRepository(db: db, api: api);
    await repo.load();
    await repo.sync();

    final c = ProviderContainer(overrides: [
      usbHostProvider.overrideWithValue(host),
      recipeRepositoryProvider.overrideWith((_) => repo),
      fujiCameraFactoryProvider.overrideWithValue(
          (link, reopen) => FujiCamera(PtpTransport(link), reopenUsb: reopen, slotSettle: Duration.zero)),
    ]);
    addTearDown(c.dispose);
    await t.runAsync(() => c.read(cameraServiceProvider.notifier).connect());

    SlotIdentity? seen;
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: KataTheme.dark(), home: _Probe(model: 'X-S20', onIdentity: (i) => seen = i)),
    ));

    // 1. Kata writes Beach Chrome into C2 and remembers it
    final saved = repo.byId('lib-1')!;
    await t.runAsync(() async {
      await c.read(cameraServiceProvider.notifier).writeRecipe(2, OfrMapper.toPreset(saved.ofr).value);
      final st = c.read(cameraServiceProvider) as CameraReady;
      await c.read(slotLinksProvider.notifier).record('X-S20', 2, saved.id, slotSettingsHash('X-S20', st.slots[1]));
    });
    await t.pumpAndSettle();
    expect(seen!.match, SlotMatch.exact);
    expect(seen!.recipe!.name, 'Beach Chrome');

    // 2. Unplug, shoot, and dial Shadow up on the body itself (D19E), then plug back in
    await t.runAsync(() => c.read(cameraServiceProvider.notifier).disconnect());
    body.slots[2]![0xD19E] = Uint8List.fromList([20, 0]); // shadow +2.0
    await t.runAsync(() => c.read(cameraServiceProvider.notifier).connect());
    await t.pumpAndSettle();

    // 3. Kata says so instead of silently showing a generic tile — and remembers where it came from
    expect(seen!.match, SlotMatch.editedOnCamera);
    expect(seen!.recipe, isNull);
    expect(seen!.origin!.name, 'Beach Chrome');
    expect(seen!.display!.name, 'Beach Chrome');

    // 4. The camera's version is publishable, with the change carried over
    final fromCam = OfrMapper.fromPreset((c.read(cameraServiceProvider) as CameraReady).slots[1], sensors: const ['X-Trans V']);
    expect(fromCam.shadow, 2);
    final published = await repo.publish(fromCam.copyWith(name: 'Beach Chrome v2', clearHash: true));
    expect(published.name, 'Beach Chrome v2');
    expect(api.published.single.ofr.shadow, 2);

    // 5. Re-linking the slot to the new kata makes it identify exactly again
    await t.runAsync(() async {
      final st = c.read(cameraServiceProvider) as CameraReady;
      await c.read(slotLinksProvider.notifier).record('X-S20', 2, published.id, slotSettingsHash('X-S20', st.slots[1]));
    });
    await t.pumpAndSettle();
    expect(seen!.match, SlotMatch.exact);
    expect(seen!.recipe!.name, 'Beach Chrome v2');
  });

  testWidgets('editing back to the original settings re-identifies the slot on its own', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final body = FakeFujiBody();
    final api = FakeRecipeApi([Recipe(id: 'lib-1', ofr: _ofr.copyWith(hash: OfrHasher.compute(_ofr)))]);
    final db = KataDb.memory();
    addTearDown(db.close);
    final repo = RecipeRepository(db: db, api: api);
    await repo.load();
    await repo.sync();
    final c = ProviderContainer(overrides: [
      usbHostProvider.overrideWithValue(FakeUsbHost(body)),
      recipeRepositoryProvider.overrideWith((_) => repo),
      fujiCameraFactoryProvider.overrideWithValue(
          (link, reopen) => FujiCamera(PtpTransport(link), reopenUsb: reopen, slotSettle: Duration.zero)),
    ]);
    addTearDown(c.dispose);
    await t.runAsync(() => c.read(cameraServiceProvider.notifier).connect());
    SlotIdentity? seen;
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: KataTheme.dark(), home: _Probe(model: 'X-S20', onIdentity: (i) => seen = i)),
    ));
    await t.runAsync(() async {
      await c.read(cameraServiceProvider.notifier).writeRecipe(2, OfrMapper.toPreset(repo.byId('lib-1')!.ofr).value);
      final st = c.read(cameraServiceProvider) as CameraReady;
      await c.read(slotLinksProvider.notifier).record('X-S20', 2, 'lib-1', slotSettingsHash('X-S20', st.slots[1]));
      // tweak on camera, then undo the tweak
      body.slots[2]![0xD19E] = Uint8List.fromList([20, 0]);
      await c.read(cameraServiceProvider.notifier).refreshSlots();
    });
    await t.pumpAndSettle();
    expect(seen!.match, SlotMatch.editedOnCamera);

    await t.runAsync(() async {
      body.slots[2]![0xD19E] = Uint8List.fromList([0, 0]);
      await c.read(cameraServiceProvider.notifier).refreshSlots();
    });
    await t.pumpAndSettle();
    expect(seen!.match, SlotMatch.exact, reason: 'settings match the library recipe again');
  });
}
