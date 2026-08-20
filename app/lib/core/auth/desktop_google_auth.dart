// Desktop Google sign-in: OAuth "installed app" loopback flow with PKCE.
// Opens the system browser, catches the redirect on 127.0.0.1:<random>, exchanges the
// code for tokens, and hands the resulting ID token to the normal /auth/google flow.
//
// For installed apps Google issues a client "secret" that is not confidential and is
// expected to ship with the binary (https://developers.google.com/identity/protocols/oauth2/native-app).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';

import 'google_id_token.dart';

const kGoogleDesktopClientId = String.fromEnvironment('KATA_GOOGLE_DESKTOP_CLIENT_ID');
const kGoogleDesktopClientSecret = String.fromEnvironment('KATA_GOOGLE_DESKTOP_CLIENT_SECRET');

class DesktopGoogleIdTokenProvider implements GoogleIdTokenProvider {
  DesktopGoogleIdTokenProvider({this.clientId = kGoogleDesktopClientId, this.clientSecret = kGoogleDesktopClientSecret, this.timeout = const Duration(minutes: 5)});
  final String clientId;
  final String clientSecret;
  final Duration timeout;

  @override
  Future<String> signIn() async {
    if (clientId.isEmpty) throw AuthNotConfigured();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final redirect = 'http://127.0.0.1:${server.port}';
      final verifier = _randomUrlSafe(64);
      final challenge = base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');
      final state = _randomUrlSafe(24);
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirect,
        'response_type': 'code',
        'scope': 'openid email profile',
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'state': state,
        'prompt': 'select_account',
      });
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open the browser');
      }
      final req = await server.first.timeout(timeout, onTimeout: () => throw AuthCancelled());
      final params = req.uri.queryParameters;
      final ok = params['code'] != null && params['state'] == state;
      req.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(ok
            ? '<html><body style="background:#000;color:#fff;font-family:sans-serif;display:grid;place-items:center;height:100vh"><div style="text-align:center"><div style="font-size:40px">型</div><h2>Signed in</h2><p>You can close this tab and go back to Kata.</p></div></body></html>'
            : '<html><body style="background:#000;color:#fff;font-family:sans-serif;display:grid;place-items:center;height:100vh"><h2>Sign-in was cancelled</h2></body></html>');
      await req.response.close();
      if (!ok) throw AuthCancelled();
      // exchange the code
      final client = HttpClient();
      try {
        final tokenReq = await client.postUrl(Uri.parse('https://oauth2.googleapis.com/token'));
        tokenReq.headers.contentType = ContentType('application', 'x-www-form-urlencoded');
        tokenReq.write(Uri(queryParameters: {
          'client_id': clientId,
          if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
          'code': params['code']!,
          'code_verifier': verifier,
          'grant_type': 'authorization_code',
          'redirect_uri': redirect,
        }).query);
        final res = await tokenReq.close();
        final body = await res.transform(utf8.decoder).join();
        if (res.statusCode != 200) throw StateError('Token exchange failed (${res.statusCode}): ${body.length > 200 ? body.substring(0, 200) : body}');
        final idToken = (jsonDecode(body) as Map<String, dynamic>)['id_token'] as String?;
        if (idToken == null) throw StateError('Google returned no ID token');
        return idToken;
      } finally {
        client.close();
      }
    } finally {
      await server.close(force: true);
    }
  }

  @override
  Future<void> signOut() async {
    // nothing to clear locally; the browser session belongs to the user
  }

  static String _randomUrlSafe(int len) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rnd = Random.secure();
    return List.generate(len, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
