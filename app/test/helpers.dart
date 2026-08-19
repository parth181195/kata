import 'dart:convert';

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:fuji_ptp/testing.dart';
import 'package:kata/core/fuji/camera_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/app.dart';
import 'package:kata/core/auth/auth_repository.dart';
import 'package:kata/core/auth/google_id_token.dart';
import 'package:kata/core/net/api_client.dart';
import 'package:kata/core/net/token_store.dart';
import 'package:kata/data/local_db.dart';
import 'package:kata/data/recipe.dart';
import 'package:kata/data/recipe_api.dart';
import 'package:kata/data/recipe_repository.dart';
import 'package:kata/router.dart';
import 'core/net/api_client_test.dart' show FakeAdapter;

/// In-memory [RecipeApi]: serves [recipes] in pages of [pageSize]; flip [failNetwork] to simulate offline.
class FakeRecipeApi implements RecipeApi {
  FakeRecipeApi(this.recipes, {this.pageSize = 50});
  factory FakeRecipeApi.fromSeed(String json) => FakeRecipeApi([
    for (final j in (jsonDecode(json) as Map<String, dynamic>)['recipes'] as List) Recipe.fromJson(j as Map<String, dynamic>),
  ]);
  List<Recipe> recipes;
  int pageSize;
  bool failNetwork = false;
  int calls = 0;

  @override
  Future<RecipePage> list({String? cursor, int limit = 50}) async {
    calls++;
    if (failNetwork) throw ApiException('offline', isNetwork: true);
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, recipes.length);
    return RecipePage(items: recipes.sublist(start, end), nextCursor: end < recipes.length ? '$end' : null);
  }

  @override
  Future<Recipe> get(String id) async {
    if (failNetwork) throw ApiException('offline', isNetwork: true);
    return recipes.firstWhere((r) => r.id == id, orElse: () => throw ApiException('not found', status: 404));
  }
}

const seedJson = '''{"recipes":[
 {"id":"a","verified":true,"ofr":{"v":1,"name":"Kodachrome 64","sensors":["X-Trans IV"],"source_url":"https://fujixweekly.com/x","source_attribution":"Fuji X Weekly","film_simulation":"Classic Chrome","dynamic_range":"DR400","d_range_priority":"Off","grain_roughness":"Weak","grain_size":"Small","color_chrome_effect":"Weak","color_chrome_fx_blue":"Off","white_balance":"Daylight","white_balance_red":2,"white_balance_blue":-5,"highlight":-1,"shadow":0.5,"color":2,"sharpness":-2,"high_iso_nr":-4,"clarity":0}},
 {"id":"b","verified":false,"ofr":{"v":1,"name":"Mono Push","sensors":["X-Trans V"],"source_attribution":"Kata sample","film_simulation":"Acros Red","dynamic_range":"DR200","d_range_priority":"Off","grain_roughness":"Strong","grain_size":"Large","white_balance":"Auto","white_balance_red":2,"white_balance_blue":-3,"highlight":2,"shadow":3,"sharpness":2,"high_iso_nr":-2,"clarity":-2,"monochromatic_color_warm_cool":2,"monochromatic_color_magenta_green":-1}},
 {"id":"c","verified":true,"ofr":{"v":1,"name":"Slide Film","sensors":["GFX"],"source_attribution":"Kata sample","film_simulation":"Velvia","dynamic_range":"DR400","d_range_priority":"Off","grain_roughness":"Off","color_chrome_effect":"Strong","color_chrome_fx_blue":"Strong","white_balance":"Daylight","white_balance_red":0,"white_balance_blue":0,"highlight":-0.5,"shadow":-1,"color":4,"sharpness":0,"high_iso_nr":-4,"clarity":0}}
]}''';

class FakeGoogle implements GoogleIdTokenProvider {
  FakeGoogle({this.token = 'fake-google-id-token-1', this.cancel = false});
  String token;
  bool cancel;
  int signOuts = 0;
  @override
  Future<String> signIn() async {
    if (cancel) throw AuthCancelled();
    return token;
  }

  @override
  Future<void> signOut() async => signOuts++;
}

const testUser = {'id': 'u1', 'email': 'parth@example.com', 'displayName': 'Parth Jansari', 'photoUrl': null, 'role': 'user'};

/// Fake HTTP that answers the auth endpoints; add more scripts per test via [http.on].
FakeAdapter authAdapter() {
  final http = FakeAdapter();
  http.on((o) => o.path == '/auth/google', (_) => FakeAdapter.json(200, {'accessToken': 'A1', 'refreshToken': 'R1', 'expiresIn': 900, 'user': testUser}));
  http.on((o) => o.path == '/auth/logout', (_) => FakeAdapter.json(204, {}));
  http.on((o) => o.path == '/me', (_) => FakeAdapter.json(200, testUser));
  return http;
}

/// Pumps the full app with an in-memory db + fake API seeded from [seedJson]. Returns the container for reading providers.
Future<ProviderContainer> pumpKata(WidgetTester t, {String initialLocation = '/library', bool signedIn = true, List<Override> overrides = const [], FakeAdapter? http, FakeGoogle? google, FakeRecipeApi? api}) async {
  final db = KataDb.memory();
  addTearDown(db.close);
  final repo = RecipeRepository(db: db, api: api ?? FakeRecipeApi.fromSeed(seedJson));
  await repo.load();
  await repo.sync();
  final tokens = MemoryTokenStore();
  if (signedIn) {
    await tokens.write(TokenKeys.access, 'A1');
    await tokens.write(TokenKeys.refresh, 'R1');
    await tokens.write(TokenKeys.user, jsonEncode(testUser));
  }
  final adapter = http ?? authAdapter();
  final g = google ?? FakeGoogle();
  final container = ProviderContainer(overrides: [
    kataDbProvider.overrideWithValue(db),
    recipeRepositoryProvider.overrideWith((_) => repo),
    initialLocationProvider.overrideWithValue(initialLocation),
    tokenStoreProvider.overrideWithValue(tokens),
    apiClientProvider.overrideWith((ref) => ApiClient(tokens: tokens, base: 'https://t', adapter: adapter, onSessionLost: () => ref.read(sessionLostProvider.notifier).state++)),
    googleIdTokenProvider.overrideWithValue(g),
    ...overrides,
  ]);
  t.view.physicalSize = const Size(412 * 3, 915 * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(UncontrolledProviderScope(container: container, child: const KataApp()));
  await t.pumpAndSettle();
  return container;
}

class FakeUsbHost implements UsbHost {
  FakeUsbHost(this.body, {this.present = true, this.grant = true});
  final FakeFujiBody body;
  bool present;
  bool grant;
  bool opened = false;
  final ctrl = StreamController<UsbEvent>.broadcast();

  @override
  Future<List<UsbDeviceInfo>> listDevices() async => present
      ? [
          UsbDeviceInfo(
              name: '/dev/bus/usb/001/002', vid: 0x04CB, pid: 0x02F7, product: 'USB PTP Camera', manufacturer: 'FUJIFILM',
              hasPermission: grant, interfaces: [UsbInterfaceInfo(0, 6, 1, 1, 0x81, 0x01)])
        ]
      : [];
  @override
  Future<bool> requestPermission(String name) async => grant;
  @override
  Future<Map> open(String name, {int? interfaceId}) async {
    opened = true;
    return {'interfaceId': 0, 'epIn': 0x81, 'epOut': 1, 'maxPacketIn': 512, 'maxPacketOut': 512};
  }

  @override
  Future<void> close() async => opened = false;
  @override
  Stream<UsbEvent> get events => ctrl.stream;
  @override
  UsbLink get link => body;
}

/// Overrides that wire a fake camera body into CameraService.
List<Override> fakeCameraOverrides(FakeUsbHost host) => [
      usbHostProvider.overrideWithValue(host),
      fujiCameraFactoryProvider.overrideWithValue((link, reopen) => FujiCamera(PtpTransport(link), reopenUsb: reopen, slotSettle: Duration.zero)),
    ];
