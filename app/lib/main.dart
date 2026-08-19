import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/debug/probe_screen.dart';

void main() => runApp(const ProviderScope(child: KataApp()));

class KataApp extends StatelessWidget {
  const KataApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Kata',
        theme: ThemeData(
            brightness: Brightness.dark, colorSchemeSeed: Colors.white, useMaterial3: true, scaffoldBackgroundColor: Colors.black),
        home: const ProbeScreen(),
      );
}
