import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/api_client.dart';
import '../net/token_store.dart';
import 'desktop_google_auth.dart';
import 'google_id_token.dart';

/// What the first-run questions produced: the body they shoot, its sensor generation, and
/// the looks they asked for. Empty until onboarding runs; safe to ignore everywhere.
class UserPreferences {
  const UserPreferences({this.bodies = const [], this.sensors = const [], this.filmSimFamilies = const [], this.onboardedAt});

  /// Every body the user shoots — plenty of people own two.
  final List<String> bodies;

  /// The sensor generations those bodies use; what the library filter is seeded with.
  final List<String> sensors;
  final List<String> filmSimFamilies;
  final DateTime? onboardedAt;

  bool get onboarded => onboardedAt != null;

  /// For one-line summaries ("X-S20 · X-T4").
  String get bodiesLabel => bodies.join(' · ');

  Map<String, dynamic> toJson() => {
        if (bodies.isNotEmpty) 'bodies': bodies,
        if (sensors.isNotEmpty) 'sensors': sensors,
        if (filmSimFamilies.isNotEmpty) 'filmSimFamilies': filmSimFamilies,
        if (onboardedAt != null) 'onboardedAt': onboardedAt!.toUtc().toIso8601String(),
      };

  static const empty = UserPreferences();

  factory UserPreferences.fromJson(Map<String, dynamic>? j) {
    if (j == null) return empty;
    List<String> list(String plural, String singular) {
      final many = (j[plural] as List?)?.cast<String>();
      if (many != null && many.isNotEmpty) return many;
      final one = j[singular] as String?; // accounts set up before multi-body
      return one == null ? const [] : [one];
    }

    return UserPreferences(
      bodies: list('bodies', 'body'),
      sensors: list('sensors', 'sensor'),
      filmSimFamilies: ((j['filmSimFamilies'] as List?) ?? const []).cast<String>(),
      onboardedAt: DateTime.tryParse((j['onboardedAt'] ?? '') as String),
    );
  }
}

class AppUser {
  const AppUser({required this.id, required this.email, required this.displayName, this.photoUrl, required this.role, this.preferences = UserPreferences.empty});
  final String id, email, displayName, role;
  final String? photoUrl;
  final UserPreferences preferences;
  bool get isAdmin => role == 'admin';
  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'displayName': displayName, 'photoUrl': photoUrl, 'role': role, 'preferences': preferences.toJson()};
  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
      id: j['id'] as String,
      email: j['email'] as String,
      displayName: (j['displayName'] ?? '') as String,
      photoUrl: j['photoUrl'] as String?,
      role: (j['role'] ?? 'user') as String,
      preferences: UserPreferences.fromJson(j['preferences'] as Map<String, dynamic>?));

  AppUser copyWith({UserPreferences? preferences}) =>
      AppUser(id: id, email: email, displayName: displayName, photoUrl: photoUrl, role: role, preferences: preferences ?? this.preferences);
}

class Session {
  const Session({required this.user});
  final AppUser user;
}

class AuthRepository {
  AuthRepository({required this.api, required this.tokens, required this.google});
  final ApiClient api;
  final TokenStore tokens;
  final GoogleIdTokenProvider google;

  /// Session from the token store, without network. Null if signed out.
  Future<Session?> restore() async {
    final access = await tokens.read(TokenKeys.access);
    final userJson = await tokens.read(TokenKeys.user);
    if (access == null || userJson == null) return null;
    return Session(user: AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>));
  }

  /// Re-fetch /me (refreshing the token if needed). Returns null if the session is gone.
  Future<Session?> refreshUser() async {
    try {
      final me = await api.getJson('/me');
      final user = AppUser.fromJson(me);
      await tokens.write(TokenKeys.user, jsonEncode(user.toJson()));
      return Session(user: user);
    } on ApiException catch (e) {
      if (e.status == 401) return null;
      return restore();
    }
  }

  Future<Session> signInWithGoogle() async {
    final idToken = await google.signIn();
    final r = await api.postJson('/auth/google', {'idToken': idToken}, auth: false);
    final user = AppUser.fromJson((r['user'] as Map).cast<String, dynamic>());
    await tokens.write(TokenKeys.access, r['accessToken'] as String);
    await tokens.write(TokenKeys.refresh, r['refreshToken'] as String);
    await tokens.write(TokenKeys.user, jsonEncode(user.toJson()));
    return Session(user: user);
  }

  /// Save the first-run answers (or any later edit). Merged server-side, so partial is fine.
  Future<AppUser> savePreferences(UserPreferences prefs) async {
    final r = await api.patchJson('/me', {'preferences': prefs.toJson()});
    final user = AppUser.fromJson(r);
    await tokens.write(TokenKeys.user, jsonEncode(user.toJson()));
    return user;
  }

  Future<void> signOut() async {
    final refresh = await tokens.read(TokenKeys.refresh);
    if (refresh != null) {
      try {
        await api.postJson('/auth/logout', {'refreshToken': refresh}, auth: false);
      } catch (_) {}
    }
    await tokens.clear();
    await google.signOut();
  }
}

/// Android uses the platform Google Sign-In; desktop uses the loopback OAuth flow.
final googleIdTokenProvider = Provider<GoogleIdTokenProvider>((_) {
  if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
    return DesktopGoogleIdTokenProvider();
  }
  return GoogleSignInIdTokenProvider();
});
final authRepositoryProvider = Provider<AuthRepository>(
    (ref) => AuthRepository(api: ref.watch(apiClientProvider), tokens: ref.watch(tokenStoreProvider), google: ref.watch(googleIdTokenProvider)));

class SessionNotifier extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    // interceptor bumps this when refresh fails → drop the session
    ref.listen(sessionLostProvider, (prev, next) {
      if (prev != null && next != prev) state = const AsyncData(null);
    });
    final repo = ref.read(authRepositoryProvider);
    final restored = await repo.restore();
    if (restored != null) {
      // background refresh of the profile; ignore failures
      Future<void>.microtask(() async {
        final fresh = await repo.refreshUser();
        if (fresh == null) {
          state = const AsyncData(null);
        } else if (fresh.user != restored.user) {
          state = AsyncData(fresh);
        }
      });
    }
    return restored;
  }

  Future<void> signIn() async {
    final s = await ref.read(authRepositoryProvider).signInWithGoogle();
    state = AsyncData(s);
  }

  /// Persist the first-run answers and reflect them in the session immediately.
  Future<void> savePreferences(UserPreferences prefs) async {
    final current = state.valueOrNull;
    // optimistic: onboarding must finish even on a bad connection, and the server merges
    if (current != null) state = AsyncData(Session(user: current.user.copyWith(preferences: prefs)));
    try {
      final user = await ref.read(authRepositoryProvider).savePreferences(prefs);
      state = AsyncData(Session(user: user));
    } catch (_) {
      // keep the optimistic value; the next /me refresh reconciles it
    }
  }

  Future<void> signOut() async {
    if (state.isLoading) return;
    state = const AsyncLoading(); // router shows the boot loader while /auth/logout runs
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);
