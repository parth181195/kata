import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: Text(id, style: KataType.monoStyle(color: context.kata.fg)))));
}
