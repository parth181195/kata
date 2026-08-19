import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/recipe.dart';

String exportJson(Recipe recipe) {
  final ofr = recipe.ofr.hash == null ? recipe.ofr.copyWith(hash: recipe.hash) : recipe.ofr;
  return const JsonEncoder.withIndent('  ').convert(ofr.toJson());
}

String _slug(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');

Future<void> showExportSheet(BuildContext context, Recipe recipe) => showKataSheet(context, builder: (c) {
      final p = c.kata;
      final json = exportJson(recipe);
      final name = '${_slug(recipe.name)}.ofr.json';
      Future<void> saveFile() => Share.shareXFiles([XFile.fromData(utf8.encode(json), name: name, mimeType: 'application/json')], subject: recipe.name);
      return KataSheet(eyebrow: 'Export · Open Fuji Recipe', title: recipe.name, children: [
        KataCard(
          radius: 16,
          fill: p.code,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(child: Text(json, style: KataType.monoStyle(size: 10, color: p.muted, height: 1.7))),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: KataPillButton(
              label: 'Copy JSON',
              kind: KataButtonKind.secondary,
              display: false,
              height: 50,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: json));
                if (c.mounted) KataToast.show(c, 'JSON copied');
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: KataPillButton(label: 'Save .ofr.json', kind: KataButtonKind.secondary, display: false, height: 50, onPressed: saveFile)),
        ]),
        const SizedBox(height: 18),
        Text('SHARE VIA', style: KataType.monoStyle(size: 9.5, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16)),
        const SizedBox(height: 12),
        Row(children: [
          _shareIcon(c, 'Text', () => Share.share(json, subject: recipe.name)),
          const SizedBox(width: 16),
          _shareIcon(c, 'File', saveFile),
        ]),
      ]);
    });

Widget _shareIcon(BuildContext c, String label, VoidCallback onTap) => Column(mainAxisSize: MainAxisSize.min, children: [
      KataIconCircle(size: 48, onPressed: onTap, child: Text(label.substring(0, 1), style: KataType.bodyStyle(size: 14, color: c.kata.dim, height: 1))),
      const SizedBox(height: 7),
      Text(label, style: KataType.bodyStyle(size: 9.5, color: c.kata.muted, height: 1)),
    ]);
