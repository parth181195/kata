import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/recipe.dart';

/// "Credits: Fuji X Weekly" — with the name itself as the link to the original post.
///
/// Nearly every seeded kata came out of someone's blog write-up. The credit is the honest
/// place to send people there, rather than a separate button that reads like an advert.
class CreditLine extends StatelessWidget {
  const CreditLine({super.key, required this.recipe, this.size = 12});
  final Recipe recipe;
  final double size;

  String get _who =>
      recipe.ofr.sourceAttribution ??
      switch (recipe.source) {
        RecipeSource.camera => 'Read from a camera',
        RecipeSource.published => 'You',
        RecipeSource.imported => 'Imported',
        RecipeSource.seed => 'The community',
      };

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(recipe.ofr.sourceUrl!);
    final ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) KataToast.show(context, "Couldn't open the source post");
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final url = recipe.ofr.sourceUrl;
    final label = Text(
      _who,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: KataType.bodyStyle(
        size: size,
        weight: FontWeight.w600,
        color: url == null ? p.dim : p.fg,
        height: 1.3,
      ).copyWith(decoration: url == null ? null : TextDecoration.underline, decorationColor: p.hairline),
    );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('CREDITS ', style: KataType.monoStyle(size: size - 3, color: p.muted, letterSpacing: 0.16)),
      Flexible(
        child: url == null
            ? label
            : Tooltip(
                message: Uri.tryParse(url)?.host ?? url,
                child: InkWell(onTap: () => _open(context), child: label),
              ),
      ),
      if (url != null) Text(' ↗', style: KataType.bodyStyle(size: size - 1, color: p.muted, height: 1.3)),
    ]);
  }
}
