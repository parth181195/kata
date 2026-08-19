import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kata/core/auth/auth_repository.dart';
import 'package:kata/core/net/api_client.dart';
import 'package:kata/core/net/token_store.dart';

import '../../helpers.dart';

void main() {
  test('sign in stores tokens + user; restore works offline; sign out clears', () async {
    final http = authAdapter();
    final store = MemoryTokenStore();
    final api = ApiClient(tokens: store, base: 'https://t', adapter: http);
    final google = FakeGoogle();
    final repo = AuthRepository(api: api, tokens: store, google: google);

    expect(await repo.restore(), isNull);
    final s = await repo.signInWithGoogle();
    expect(s.user.email, 'parth@example.com');
    expect(await store.read(TokenKeys.access), 'A1');
    expect(jsonDecode((await store.read(TokenKeys.user))!)['email'], 'parth@example.com');
    final sent = http.requests.firstWhere((r) => r.path == '/auth/google');
    expect(sent.data, {'idToken': 'fake-google-id-token-1'});

    final repo2 = AuthRepository(api: api, tokens: store, google: google);
    expect((await repo2.restore())!.user.displayName, 'Parth Jansari');

    await repo2.signOut();
    expect(http.requests.where((r) => r.path == '/auth/logout').single.data, {'refreshToken': 'R1'});
    expect(await store.read(TokenKeys.access), isNull);
    expect(google.signOuts, 1);
  });
}
