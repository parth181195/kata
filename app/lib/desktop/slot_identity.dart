import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:ofr/ofr.dart';
import 'package:path_provider/path_provider.dart';

import '../data/recipe.dart';
import '../data/recipe_repository.dart';

/// Settings-only hash of what a slot holds, computed through the same mapper both directions.
String slotSettingsHash(String model, CameraPreset preset) =>
    OfrHasher.compute(OfrMapper.fromPreset(preset, sensors: OfrMapper.sensorsForModel(model)), scheme: HashScheme.v1SettingsOnly);

/// settingsHash → recipeId for the whole library. Every OFR is roundtripped through the
/// mapper (toPreset → fromPreset) before hashing so representation quirks cancel out:
/// a camera read-back then matches its source recipe by construction — including slots
/// written from the phone, where no local write log exists.
final settingsIndexProvider = Provider<Map<String, String>>((ref) {
  final repo = ref.watch(recipeRepositoryProvider);
  final map = <String, String>{};
  for (final r in repo.all) {
    try {
      final rt = OfrMapper.fromPreset(OfrMapper.toPreset(r.ofr).value, sensors: r.ofr.sensors);
      map[OfrHasher.compute(rt, scheme: HashScheme.v1SettingsOnly)] = r.id;
    } catch (_) {/* unmappable recipe: not identifiable */}
  }
  return map;
});

/// Exact record of what we wrote where — wins over the hash index when both apply
/// (two recipes can share identical settings).
class SlotLink {
  const SlotLink({required this.recipeId, required this.hash, required this.at});
  final String recipeId;
  final String hash;
  final DateTime at;
  Map<String, dynamic> toJson() => {'recipeId': recipeId, 'hash': hash, 'at': at.toIso8601String()};
  static SlotLink fromJson(Map<String, dynamic> j) => SlotLink(
      recipeId: j['recipeId'] as String,
      hash: j['hash'] as String,
      at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0));
}

final slotLinksProvider = StateNotifierProvider<SlotLinkStore, Map<String, SlotLink>>((_) => SlotLinkStore());

class SlotLinkStore extends StateNotifier<Map<String, SlotLink>> {
  SlotLinkStore() : super(const {}) {
    _load();
  }

  Future<File> _file() async => File('${(await getApplicationSupportDirectory()).path}/slot_links.json');

  Future<void> _load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      state = m.map((k, v) => MapEntry(k, SlotLink.fromJson(v as Map<String, dynamic>)));
    } catch (_) {}
  }

  Future<void> record(String model, int slot, String recipeId, String hash) async {
    state = {...state, '$model|$slot': SlotLink(recipeId: recipeId, hash: hash, at: DateTime.now())};
    final f = await _file();
    await f.writeAsString(jsonEncode(state.map((k, v) => MapEntry(k, v.toJson()))));
  }
}

/// Which library recipe lives in this slot, if we can tell. Write log first (exact),
/// then the settings index (covers writes from other devices). Null = unknown/custom.
Recipe? identifySlot(WidgetRef ref, String model, int slot, CameraPreset preset) {
  final repo = ref.watch(recipeRepositoryProvider);
  final h = slotSettingsHash(model, preset);
  final link = ref.watch(slotLinksProvider)['$model|$slot'];
  if (link != null && link.hash == h) {
    final r = repo.byId(link.recipeId);
    if (r != null) return r;
  }
  final id = ref.watch(settingsIndexProvider)[h];
  return id == null ? null : repo.byId(id);
}
