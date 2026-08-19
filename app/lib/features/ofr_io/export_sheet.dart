import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../data/recipe.dart';

Future<void> showExportSheet(BuildContext context, Recipe recipe) =>
    showKataSheet(context, builder: (_) => KataSheet(eyebrow: 'Export · Open Fuji Recipe', title: recipe.name, children: const [Text('Task 9')]));
