import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:ofr/ofr.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/recipe.dart';
import '../../data/recipe_repository.dart';

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
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode(state.map((k, v) => MapEntry(k, v.toJson()))));
    } catch (_) {
      // best effort: the in-memory link still works this session, and identification falls
      // back to the settings hash. Never fail a write that already reached the camera.
    }
  }
}

/// How well a slot matches something we know.
enum SlotMatch {
  /// Settings are byte-for-byte a library recipe.
  exact,

  /// Kata wrote a known recipe here, but the settings have changed since — the user
  /// refined it on the camera while shooting.
  editedOnCamera,

  /// Nothing in the library matches and we never wrote here.
  unknown,
}

class SlotIdentity {
  const SlotIdentity({required this.match, this.recipe, this.origin});

  /// The library recipe this slot *is* (only when [match] is exact).
  final Recipe? recipe;

  /// What Kata last wrote here, when the slot has since been edited on the camera.
  final Recipe? origin;
  final SlotMatch match;

  /// What to render on the tile: the exact recipe, else the recipe it came from.
  Recipe? get display => recipe ?? origin;
  bool get edited => match == SlotMatch.editedOnCamera;
}

/// Which library recipe lives in this slot, if we can tell. Write log first (exact),
/// then the settings index (covers writes from other devices, e.g. the phone). A write-log
/// entry whose hash no longer matches means the slot was edited on the camera after we
/// wrote it — worth saying out loud rather than silently showing a generic tile.
SlotIdentity identifySlot(WidgetRef ref, String model, int slot, CameraPreset preset) {
  final repo = ref.watch(recipeRepositoryProvider);
  final h = slotSettingsHash(model, preset);
  final link = ref.watch(slotLinksProvider)['$model|$slot'];
  final linked = link == null ? null : repo.byId(link.recipeId);
  if (link != null && link.hash == h && linked != null) {
    return SlotIdentity(match: SlotMatch.exact, recipe: linked);
  }
  final id = ref.watch(settingsIndexProvider)[h];
  final byHash = id == null ? null : repo.byId(id);
  if (byHash != null) return SlotIdentity(match: SlotMatch.exact, recipe: byHash);
  if (linked != null) return SlotIdentity(match: SlotMatch.editedOnCamera, origin: linked);
  return const SlotIdentity(match: SlotMatch.unknown);
}
