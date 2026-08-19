import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: Text('KATA 型', style: KataType.displayStyle(size: 24, weight: FontWeight.w900, color: context.kata.fg, letterSpacing: 0.05)))));
}
