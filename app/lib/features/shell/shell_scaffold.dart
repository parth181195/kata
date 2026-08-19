import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.shell});
  final StatefulNavigationShell shell;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: SafeArea(
          top: false,
          child: KataBottomNav(index: shell.currentIndex, onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex)),
        ),
      );
}
