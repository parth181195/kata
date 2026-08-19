import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'ofr_recipe.dart';

enum HashScheme {
  /// Current README: settings + `sensors`.
  v1Sensors,

  /// Open PR #1: settings only.
  v1SettingsOnly,
}

class OfrHasher {
  /// Sorted keys (top level), compact, UTF-8; doubles that are whole numbers serialize as ints.
  static String canonicalJson(Map<String, dynamic> payload) {
    final sorted = Map<String, dynamic>.fromEntries(
      payload.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return json.encode(_canon(sorted));
  }

  static dynamic _canon(dynamic v) {
    if (v is double && v == v.roundToDouble()) return v.toInt();
    if (v is Map) return {for (final e in v.entries) e.key.toString(): _canon(e.value)};
    if (v is List) return v.map(_canon).toList();
    return v;
  }

  static String compute(OfrRecipe r, {HashScheme scheme = HashScheme.v1Sensors}) {
    final payload = r.settingsJson();
    if (scheme == HashScheme.v1Sensors) payload['sensors'] = r.sensors;
    final bytes = utf8.encode(canonicalJson(payload));
    return sha256.convert(bytes).toString();
  }
}
