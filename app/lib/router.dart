import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';

import 'core/auth/auth_repository.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/camera/camera_screen.dart';
import 'features/debug/kit_screen.dart';
import 'features/debug/probe_screen.dart';
import 'features/library/library_screen.dart';
import 'features/library/recipe_detail_screen.dart';
import 'features/mine/mine_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/shell/shell_scaffold.dart';

final initialLocationProvider = Provider<String>((_) => '/library');

/// Shown while the session is being restored from secure storage.
class BootScreen extends StatelessWidget {
  const BootScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Scaffold(
      body: Center(
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.hairline)),
          alignment: Alignment.center,
          child: Text('型', style: KataType.displayStyle(size: 22, weight: FontWeight.w400, color: p.fg, letterSpacing: 0)),
        ),
      ),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier<AsyncValue<Session?>>(ref.read(sessionProvider));
  ref.listen(sessionProvider, (_, v) => session.value = v);
  return GoRouter(
    initialLocation: ref.read(initialLocationProvider),
    refreshListenable: session,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final s = session.value;
      if (s.isLoading) return loc == '/boot' ? null : '/boot?from=${Uri.encodeComponent(state.uri.toString())}';
      final signedIn = s.valueOrNull != null;
      if (!signedIn) return loc == '/signin' ? null : '/signin';
      if (loc == '/signin') return '/library';
      if (loc == '/boot') {
        final from = state.uri.queryParameters['from'];
        return (from == null || from.startsWith('/boot') || from.startsWith('/signin')) ? '/library' : from;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/boot', pageBuilder: (_, s) => _page(s, const BootScreen())),
      GoRoute(path: '/signin', pageBuilder: (_, s) => _page(s, const SignInScreen())),
      GoRoute(path: '/recipe/:id', pageBuilder: (_, s) => _page(s, RecipeDetailScreen(id: s.pathParameters['id']!))),
      GoRoute(path: '/probe', pageBuilder: (_, s) => _page(s, const ProbeScreen())),
      GoRoute(path: '/kit', pageBuilder: (_, s) => _page(s, const KitScreen())),
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, s, shell) => _page(s, ShellScaffold(shell: shell)),
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

/// Every route gets the kata_ui fade + rise transition.
Page<T> _page<T>(GoRouterState s, Widget child) => CustomTransitionPage<T>(
  key: s.pageKey,
  name: s.name ?? s.path,
  child: child,
  transitionDuration: KataMotion.page,
  reverseTransitionDuration: KataMotion.pageOut,
  transitionsBuilder: KataPageTransition.transitionsBuilder,
);
