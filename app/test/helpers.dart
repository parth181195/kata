import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/app.dart';
import 'package:kata/data/local_library.dart';
import 'package:kata/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SeedBundle extends CachingAssetBundle {
  SeedBundle(this.json);
  final String json;
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
}

const seedJson = '''{"recipes":[
 {"id":"a","verified":true,"ofr":{"v":1,"name":"Kodachrome 64","sensors":["X-Trans IV"],"source_url":"https://fujixweekly.com/x","source_attribution":"Fuji X Weekly","film_simulation":"Classic Chrome","dynamic_range":"DR400","d_range_priority":"Off","grain_roughness":"Weak","grain_size":"Small","color_chrome_effect":"Weak","color_chrome_fx_blue":"Off","white_balance":"Daylight","white_balance_red":2,"white_balance_blue":-5,"highlight":-1,"shadow":0.5,"color":2,"sharpness":-2,"high_iso_nr":-4,"clarity":0}},
 {"id":"b","verified":false,"ofr":{"v":1,"name":"Mono Push","sensors":["X-Trans V"],"source_attribution":"Kata sample","film_simulation":"Acros Red","dynamic_range":"DR200","d_range_priority":"Off","grain_roughness":"Strong","grain_size":"Large","white_balance":"Auto","white_balance_red":2,"white_balance_blue":-3,"highlight":2,"shadow":3,"sharpness":2,"high_iso_nr":-2,"clarity":-2,"monochromatic_color_warm_cool":2,"monochromatic_color_magenta_green":-1}},
 {"id":"c","verified":true,"ofr":{"v":1,"name":"Slide Film","sensors":["GFX"],"source_attribution":"Kata sample","film_simulation":"Velvia","dynamic_range":"DR400","d_range_priority":"Off","grain_roughness":"Off","color_chrome_effect":"Strong","color_chrome_fx_blue":"Strong","white_balance":"Daylight","white_balance_red":0,"white_balance_blue":0,"highlight":-0.5,"shadow":-1,"color":4,"sharpness":0,"high_iso_nr":-4,"clarity":0}}
]}''';

/// Pumps the full app with fake prefs + seed bundle. Returns the container for reading providers.
Future<ProviderContainer> pumpKata(WidgetTester t, {String initialLocation = '/library', bool signedIn = true, List<Override> overrides = const []}) async {
  SharedPreferences.setMockInitialValues({'kata.signedIn': signedIn});
  final prefs = await SharedPreferences.getInstance();
  final lib = LocalLibraryNotifier(LocalLibrary(prefs, bundle: SeedBundle(seedJson)));
  await lib.load();
  final container = ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(prefs),
    localLibraryProvider.overrideWith((_) => lib),
    initialLocationProvider.overrideWithValue(initialLocation),
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
