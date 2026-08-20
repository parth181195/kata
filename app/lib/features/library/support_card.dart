import 'package:flutter/material.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/recipe.dart';

/// Kata's seeded library is Ritchie Roesch's work: he writes, shoots and tests the recipes on
/// Fuji X Weekly and gives them away. This says so where people actually read it — on the
/// kata they're about to use — and points at the App Patron subscription that funds it.
class SupportCard extends StatelessWidget {
  const SupportCard({super.key, required this.recipe});
  final Recipe recipe;

  /// Support links belong to whoever the recipe credits — only Fuji X Weekly for now.
  static const _patron = 'https://fujixweekly.com/2021/10/22/why-should-you-become-a-fuji-x-weekly-app-patron/';
  static bool isFxw(Recipe r) => (r.ofr.sourceAttribution ?? '').toLowerCase().contains('fuji x weekly');

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    if (!isFxw(recipe)) return const SizedBox.shrink();
    return KataCard(
      dashed: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('THIS RECIPE IS FUJI X WEEKLY\'S', style: KataType.monoStyle(size: 9, weight: FontWeight.w500, color: p.muted, letterSpacing: 0.16)),
        const SizedBox(height: 8),
        Text(
          'Ritchie Roesch works these out on real cameras and gives them away free — Kata would have nothing to seed without that. '
          'If you shoot with his recipes, becoming a Fuji X Weekly App Patron is the way to keep them coming.',
          style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.55),
        ),
        const SizedBox(height: 12),
        KataPillButton(
          label: 'Support Fuji X Weekly ↗',
          kind: KataButtonKind.secondary,
          display: false,
          height: 42,
          onPressed: () async {
            final ok = await launchUrl(Uri.parse(_patron), mode: LaunchMode.externalApplication);
            if (!ok && context.mounted) KataToast.show(context, "Couldn't open fujixweekly.com");
          },
        ),
      ]),
    );
  }
}
