import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';

import '../../data/recipe_repository.dart';
import '../ofr_io/import_sheet.dart';

/// The three ways a kata comes in — scan a code, start one fresh, import an
/// OFR — behind the + on Mine and the + on the Library alike.
Future<void> showAddKataSheet(BuildContext context, RecipeRepository lib) => showKataSheet(
      context,
      builder: (c) => KataSheet(eyebrow: 'Mine', title: 'Add a kata', children: [
        KataListRow(title: 'Scan a Kata Code', sub: 'From a card, a screen or a print — works offline', value: 'Camera', onTap: () {
          Navigator.of(c).pop();
          context.push('/scan');
        }),
        KataListRow(title: 'New kata', sub: 'Start from camera defaults', value: 'Editor', onTap: () {
          Navigator.of(c).pop();
          context.push('/new');
        }),
        KataListRow(title: 'Import OFR', sub: 'Paste JSON or pick a .ofr.json file', value: 'Import', onTap: () async {
          Navigator.of(c).pop();
          final id = await showImportSheet(context);
          if (id != null && context.mounted) KataToast.show(context, 'Saved to Mine', action: 'Undo', onAction: () => lib.remove(id));
        }),
      ]),
    );

/// The + itself: filled, 56 on a floating corner, smaller in a header.
Widget addKataButton(BuildContext context, RecipeRepository lib, {double size = 56}) => KataIconCircle(
      size: size,
      filled: true,
      onPressed: () => showAddKataSheet(context, lib),
      child: Text('+', style: KataType.bodyStyle(size: size > 40 ? 24 : 20, color: context.kata.bg, height: 1)),
    );
