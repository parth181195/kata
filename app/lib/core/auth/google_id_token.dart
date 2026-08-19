import 'package:google_sign_in/google_sign_in.dart';

/// Web OAuth client id; pass with --dart-define=KATA_GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
const kGoogleWebClientId = String.fromEnvironment('KATA_GOOGLE_WEB_CLIENT_ID');

class AuthCancelled implements Exception {}

class AuthNotConfigured implements Exception {}

/// Yields a Google ID token for our API to verify. Fake in tests.
abstract class GoogleIdTokenProvider {
  Future<String> signIn(); // throws AuthCancelled / AuthNotConfigured
  Future<void> signOut();
}

class GoogleSignInIdTokenProvider implements GoogleIdTokenProvider {
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    if (kGoogleWebClientId.isEmpty) throw AuthNotConfigured();
    await GoogleSignIn.instance.initialize(serverClientId: kGoogleWebClientId);
    _ready = true;
  }

  @override
  Future<String> signIn() async {
    await _init();
    try {
      final account = await GoogleSignIn.instance.authenticate(scopeHint: const ['email', 'profile']);
      final idToken = account.authentication.idToken;
      if (idToken == null) throw AuthCancelled();
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw AuthCancelled();
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    if (!_ready) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
