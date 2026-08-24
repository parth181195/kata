import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Small key/value secret store for tokens and the cached user.
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
  Future<void> clear();
}

class TokenKeys {
  static const access = 'kata.access';
  static const refresh = 'kata.refresh';
  static const user = 'kata.user';
}

/// Debug desktop builds skip the keychain: every rebuild carries a fresh
/// ad-hoc signature, so the keychain re-prompts for the login password on
/// each new binary. A plain file is fine for a developer's own tokens;
/// release builds keep the real keychain.
class DebugFileTokenStore implements TokenStore {
  Map<String, String>? _cache;
  Future<File> _file() async => File('${(await getApplicationSupportDirectory()).path}/kata_dev_tokens.json');

  Future<Map<String, String>> _load() async {
    if (_cache != null) return _cache!;
    try {
      final f = await _file();
      _cache = f.existsSync() ? (jsonDecode(f.readAsStringSync()) as Map).cast<String, String>() : <String, String>{};
    } catch (_) {
      _cache = <String, String>{};
    }
    return _cache!;
  }

  Future<void> _save() async => (await _file()).writeAsString(jsonEncode(_cache));

  @override
  Future<String?> read(String key) async => (await _load())[key];

  @override
  Future<void> write(String key, String? value) async {
    final m = await _load();
    if (value == null) {
      m.remove(key);
    } else {
      m[key] = value;
    }
    await _save();
  }

  @override
  Future<void> clear() async {
    _cache = <String, String>{};
    await _save();
  }
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              // The data-protection keychain needs a keychain-access-groups entitlement,
              // which needs a real signing certificate; the legacy keychain doesn't.
              mOptions: MacOsOptions(useDataProtectionKeyChain: false),
            );
  final FlutterSecureStorage _s;
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String? value) => value == null ? _s.delete(key: key) : _s.write(key: key, value: value);
  @override
  Future<void> clear() => _s.deleteAll();
}

class MemoryTokenStore implements TokenStore {
  final Map<String, String> _m = {};
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      _m.remove(key);
    } else {
      _m[key] = value;
    }
  }

  @override
  Future<void> clear() async => _m.clear();
}
