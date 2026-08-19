import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/local_library.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/camera/camera_screen.dart';
import 'features/debug/kit_screen.dart';
import 'features/debug/probe_screen.dart';
import 'features/library/library_screen.dart';
import 'features/library/recipe_detail_screen.dart';
import 'features/mine/mine_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/shell/shell_scaffold.dart';

const _kSignedIn = 'kata.signedIn';

/// Plan 2: a persisted flag; Plan 3 replaces it with real Google sign-in.
final signedInProvider = StateNotifierProvider<SignedInNotifier, bool>((ref) => SignedInNotifier(ref));

class SignedInNotifier extends StateNotifier<bool> {
  SignedInNotifier(this.ref) : super(ref.read(prefsProvider).getBool(_kSignedIn) ?? false);
  final Ref ref;
  Future<void> set(bool v) async {
    state = v;
    await ref.read(prefsProvider).setBool(_kSignedIn, v);
  }
}

final initialLocationProvider = Provider<String>((_) => '/library');

final routerProvider = Provider<GoRouter>((ref) {
  final signedIn = ValueNotifier(ref.read(signedInProvider));
  ref.listen(signedInProvider, (_, v) => signedIn.value = v);
  return GoRouter(
    initialLocation: ref.read(initialLocationProvider),
    refreshListenable: signedIn,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!signedIn.value && loc != '/signin') return '/signin';
      if (signedIn.value && loc == '/signin') return '/library';
      return null;
    },
    routes: [
      GoRoute(path: '/signin', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/recipe/:id', builder: (_, s) => RecipeDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/probe', builder: (_, _) => const ProbeScreen()),
      GoRoute(path: '/kit', builder: (_, _) => const KitScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/library', builder: (_, _) => const LibraryScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/camera', builder: (_, _) => const CameraScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/mine', builder: (_, _) => const MineScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
    ],
  );
});
