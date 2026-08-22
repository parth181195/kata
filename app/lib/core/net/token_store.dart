import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
