import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';

/// Placeholder until Task 9.
class MineScreen extends StatelessWidget {
  const MineScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Text('MINE', style: KataType.displayStyle(size: 24, color: p.fg)),
        ),
      ),
    );
  }
}
