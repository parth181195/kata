import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kata/data/local_library.dart';
import 'package:kata/data/recipe.dart';
import 'package:ofr/ofr.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.json);
  final String json;
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
}

const seed = '''{"recipes":[
 {"id":"a","verified":true,"ofr":{"v":1,"name":"Kodachrome 64","sensors":["X-Trans IV"],"source_attribution":"Fuji X Weekly","film_simulation":"Classic Chrome","dynamic_range":"DR400","d_range_priority":"Off","grain_roughness":"Weak","grain_size":"Small","color_chrome_effect":"Weak","color_chrome_fx_blue":"Off","white_balance":"Daylight","white_balance_red":2,"white_balance_blue":-5,"highlight":-1,"shadow":0.5,"color":2,"sharpness":-2,"high_iso_nr":-4,"clarity":0}},
 {"id":"b","verified":false,"ofr":{"v":1,"name":"Mono","sensors":["X-Trans V"],"film_simulation":"Acros STD","d_range_priority":"Off","grain_roughness":"Off","white_balance":"Auto","white_balance_red":0,"white_balance_blue":0,"sharpness":0,"high_iso_nr":0,"clarity":0}}
]}''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalLibrary lib;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    lib = LocalLibrary(await SharedPreferences.getInstance(), bundle: _Bundle(seed));
    await lib.load();
  });

  test('loads seed, computes hashes, filters', () {
    expect(lib.all.length, 2);
    expect(lib.byId('a')!.hash, 'ac98f45967554208ac8fd9b485c3b6598beb99f9fd17b941843fff4c0c3ec176');
    expect(lib.where(const LibraryFilter(query: 'koda')).map((r) => r.id), ['a']);
    expect(lib.where(const LibraryFilter(mono: true)).map((r) => r.id), ['b']);
    expect(lib.where(const LibraryFilter(verifiedOnly: true)).map((r) => r.id), ['a']);
    expect(lib.where(const LibraryFilter(sensor: 'X-Trans V')).map((r) => r.id), ['b']);
    expect(lib.where(const LibraryFilter(sort: LibrarySort.az)).first.id, 'a');
  });

  test('favourites and imported persist across instances', () async {
    await lib.toggleFavourite('a');
    final added = await lib.addImported(const OfrRecipe(name: 'Imp', filmSimulation: 'Velvia', dRangePriority: 'Off', grainRoughness: 'Off',
        whiteBalance: 'Auto', whiteBalanceRed: 0, whiteBalanceBlue: 0, sharpness: 0, highIsoNr: 0, clarity: 0));
    final lib2 = LocalLibrary(await SharedPreferences.getInstance(), bundle: _Bundle(seed));
    await lib2.load();
    expect(lib2.favourites, {'a'});
    expect(lib2.mine.map((r) => r.id), [added.id]);
    expect(lib2.byId(added.id)!.source, RecipeSource.imported);
    expect(lib2.all.length, 3);
    await lib2.remove(added.id);
    expect(lib2.mine, isEmpty);
  });
}
