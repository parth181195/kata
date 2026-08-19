import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kata_ui/kata_ui.dart';

import 'router.dart';

class KataApp extends ConsumerWidget {
  const KataApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Kata',
        debugShowCheckedModeBanner: false,
        theme: KataTheme.light(),
        darkTheme: KataTheme.dark(),
        themeMode: ThemeMode.system,
        routerConfig: ref.watch(routerProvider),
      );
}
