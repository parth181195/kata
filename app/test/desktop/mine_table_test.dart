import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:fuji_ptp/testing.dart';
import 'package:kata/core/fuji/camera_service.dart';
import 'package:kata/data/local_db.dart';
import 'package:kata/data/recipe_repository.dart';
import 'package:kata/desktop/desktop_camera.dart';
import 'package:kata/desktop/desktop_library.dart';
import 'package:kata/desktop/desktop_mine.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../helpers.dart';

const _a = OfrRecipe(
    name: 'Beach Chrome', sensors: ['X-Trans V'], filmSimulation: 'Classic Chrome', dynamicRange: 'DR200',
    dRangePriority: 'Off', grainRoughness: 'Weak', whiteBalance: 'Daylight', whiteBalanceRed: 1, whiteBalanceBlue: -2,
    highlight: 0, shadow: 0, color: 0, sharpness: 0, highIsoNr: -2, clarity: 0);
const _b = OfrRecipe(
    name: 'Night Mono', sensors: ['X-Trans V'], filmSimulation: 'Acros Red', dynamicRange: 'DR400',
    dRangePriority: 'Off', grainRoughness: 'Strong', grainSize: 'Large', whiteBalance: 'Auto',
    whiteBalanceRed: 0, whiteBalanceBlue: 0, highlight: 1, shadow: 2, sharpness: 1, highIsoNr: -2, clarity: -1);

Future<(ProviderContainer, RecipeRepository)> _pump(WidgetTester t, {bool camera = true}) async {
  t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
  t.view.physicalSize = const Size(1500, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  final db = KataDb.memory();
  addTearDown(db.close);
  final repo = RecipeRepository(db: db, api: FakeRecipeApi([]));
  await repo.load();
  await repo.addImported(_a);
  await repo.publish(_b);

  final c = ProviderContainer(overrides: [
    recipeRepositoryProvider.overrideWith((_) => repo),
    if (camera) usbHostProvider.overrideWithValue(FakeUsbHost(FakeFujiBody())),
    if (camera)
      fujiCameraFactoryProvider.overrideWithValue((link, reopen) => FujiCamera(PtpTransport(link), reopenUsb: reopen, slotSettle: Duration.zero)),
  ]);
  addTearDown(c.dispose);
  if (camera) await t.runAsync(() => c.read(cameraServiceProvider.notifier).connect());
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(theme: KataTheme.dark(), home: const Scaffold(body: DesktopMine())),
  ));
  await t.pumpAndSettle();
  return (c, repo);
}

void main() {
  late Directory tmp;
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    tmp = Directory.systemTemp.createTempSync('kata_mine');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (_) async => tmp.path);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    tmp.deleteSync(recursive: true);
  });

  _libraryToolbar();

  testWidgets('lists my katas with state, and the tabs filter drafts vs published', (t) async {
    await _pump(t);
    expect(find.text('MINE · 2 KATAS'), findsOneWidget);
    expect(find.text('Beach Chrome'), findsOneWidget);
    expect(find.text('Night Mono'), findsOneWidget);
    expect(find.textContaining('NONE SELECTED · 2 OF 2 SHOWN'), findsOneWidget);

    await t.tap(find.text('DRAFTS 1'));
    await t.pumpAndSettle();
    expect(find.text('Beach Chrome'), findsOneWidget);
    expect(find.text('Night Mono'), findsNothing);

    await t.tap(find.text('PUBLISHED 1'));
    await t.pumpAndSettle();
    expect(find.text('Night Mono'), findsOneWidget);
    expect(find.text('Beach Chrome'), findsNothing);
  });

  testWidgets('selecting rows enables Write selection, which queues onto free slots', (t) async {
    final (c, _) = await _pump(t);
    // Write selection is dead until something is picked
    final before = t.widget<KataPillButton>(find.widgetWithText(KataPillButton, 'WRITE SELECTION'));
    expect(before.onPressed, isNull);

    await t.tap(find.text('Beach Chrome'));
    await t.pumpAndSettle();
    expect(find.textContaining('1 SELECTED'), findsOneWidget);
    await t.tap(find.text('Night Mono'));
    await t.pumpAndSettle();
    expect(find.textContaining('2 SELECTED'), findsOneWidget);

    final after = t.widget<KataPillButton>(find.widgetWithText(KataPillButton, 'WRITE SELECTION'));
    expect(after.onPressed, isNotNull);
    await t.tap(find.text('WRITE SELECTION'));
    await t.pumpAndSettle();

    // both landed in the queue on distinct slots, and the review dialog is up
    final queue = c.read(writeQueueProvider);
    expect(queue.length, 2);
    expect(queue.keys.toSet().length, 2);
    expect(find.textContaining('REVIEW 2 WRITES'), findsOneWidget);
  });

  testWidgets('without a camera the write column and bulk write stay unavailable', (t) async {
    await _pump(t, camera: false);
    expect(find.text('WRITE'), findsNothing);
    final btn = t.widget<KataPillButton>(find.widgetWithText(KataPillButton, 'WRITE SELECTION'));
    expect(btn.onPressed, isNull);
    expect(find.text('Read from camera'), findsNothing);
  });
}

/// The desktop library's toolbar: search must survive however many chips get added.
void _libraryToolbar() {
  testWidgets('desktop library keeps a usable search box beside its filters', (t) async {
    t.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    t.view.physicalSize = const Size(1500, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    final db = KataDb.memory();
    addTearDown(db.close);
    final repo = RecipeRepository(db: db, api: FakeRecipeApi([]));
    await repo.load();
    final c = ProviderContainer(overrides: [recipeRepositoryProvider.overrideWith((_) => repo)]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: KataTheme.dark(), home: const Scaffold(body: DesktopLibrary())),
    ));
    await t.pumpAndSettle();

    final search = find.byType(KataSearchField);
    expect(search, findsOneWidget);
    expect(t.getRect(search).width, greaterThan(400), reason: 'chips must not squeeze search out of the row');
    expect(find.text('FILTERS'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('NEWEST'), findsOneWidget, reason: 'sort is reachable on desktop too');
  });
}
