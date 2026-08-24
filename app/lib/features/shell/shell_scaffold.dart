import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../core/fuji/camera_service.dart';
import '../../data/recipe_repository.dart';

/// Tab shell. Also: re-syncs the library when the app comes back to the foreground (after 2+ min),
/// and reports the connected camera body to the account (model / firmware / slots) once per connection.
class ShellScaffold extends ConsumerStatefulWidget {
  const ShellScaffold({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold> with WidgetsBindingObserver {
  static const _resyncAfter = Duration(minutes: 2);
  String? _reportedCamera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final repo = ref.read(recipeRepositoryProvider);
    final last = repo.lastSyncedAt;
    if (last == null || DateTime.now().difference(last) > _resyncAfter) repo.sync();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(cameraServiceProvider, (_, st) {
      if (st is! CameraReady) return;
      final key = '${st.caps.model}|${st.caps.firmware}';
      if (_reportedCamera == key) return;
      _reportedCamera = key;
      ref.read(recipeRepositoryProvider).reportCamera(model: st.caps.model, firmware: st.caps.firmware, pid: st.caps.pid, slots: st.caps.slotCount, props: st.caps.supportedProps.length);
    });
    final onHome = widget.shell.currentIndex == 0;
    return PopScope(
      // Back from any other tab lands on the library first — only a back press *there*
      // leaves the app. Matches how every other tabbed Android app behaves.
      canPop: onHome,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || onHome) return;
        widget.shell.goBranch(0);
      },
      child: Scaffold(
        body: widget.shell,
        bottomNavigationBar: SafeArea(
          top: false,
          child: KataBottomNav(
            index: widget.shell.currentIndex,
            labels: const ['Library', 'Camera', 'Waku', 'Mine', 'Profile'],
            iconKinds: const [0, 1, 4, 2, 3],
            onTap: (i) => widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex),
          ),
        ),
      ),
    );
  }
}
