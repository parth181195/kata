import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../core/auth/auth_repository.dart';
import '../data/recipe_repository.dart';
import '../features/onboarding/onboarding_state.dart';

/// Desktop gets the same two questions as one card — there is no reason to page through
/// steps on a large screen. Skippable, and re-runnable from Settings.
class DesktopOnboarding extends ConsumerStatefulWidget {
  const DesktopOnboarding({super.key, this.onDone});
  final VoidCallback? onDone;
  @override
  ConsumerState<DesktopOnboarding> createState() => _DesktopOnboardingState();
}

class _DesktopOnboardingState extends ConsumerState<DesktopOnboarding> {
  final _search = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _save({required bool skipped}) async {
    setState(() => _busy = true);
    final a = ref.read(onboardingAnswersProvider);
    await ref.read(sessionProvider.notifier).savePreferences(
          skipped ? UserPreferences(onboardedAt: DateTime.now()) : a.toPreferences(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    final a = ref.watch(onboardingAnswersProvider);
    final counts = familyCounts(ref.watch(recipeRepositoryProvider));
    final bodies = onboardingBodies(_search.text).take(40).toList();
    // Full screen, not a card: this is the whole window's job right now. The panel's
    // rhythm is kept — heading, search, list, chips, actions — just at window scale.
    // Its own Scaffold: this is a route in its own right, and Text outside Material renders
    // with Flutter's yellow-underlined error style.
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 44),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('SET KATA UP', style: KataType.displayStyle(size: 32, color: p.fg)),
          const SizedBox(height: 8),
          Text('Two questions, so the library opens on katas that suit your camera. Change or clear any of it later — nothing is hidden from you.',
              style: KataType.bodyStyle(size: 13, color: p.muted, height: 1.5)),
          const SizedBox(height: 24),
          KataSectionHeader('Which body do you shoot?'),
          const SizedBox(height: 10),
          KataSearchField(hint: 'Search bodies', controller: _search, onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          SizedBox(
            height: 320,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: bodies.length,
              itemBuilder: (_, i) {
                final b = bodies[i];
                return KataListRow(
                  contentInset: 18, // the label sits inside the highlight, not on its edge
                  title: b.model,
                  sub: '${b.generation} · C1–C${b.slots}${b.usbWrite == UsbWrite.full ? '' : ' · writing unverified'}',
                  value: a.body == b.model ? '✓' : null,
                  onTap: () => ref.read(onboardingAnswersProvider.notifier).state = a.copyWith(body: b.model, sensor: b.generation),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          KataSectionHeader('What are you after?'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in FilmFamily.all)
              KataChip(
                label: '${f.label} ${counts[f.id] ?? 0}',
                selected: a.families.contains(f.id),
                onTap: () {
                  final next = {...a.families};
                  next.contains(f.id) ? next.remove(f.id) : next.add(f.id);
                  ref.read(onboardingAnswersProvider.notifier).state = a.copyWith(families: next);
                },
              ),
          ]),
          const SizedBox(height: 26),
          Row(children: [
            KataPillButton(label: 'Skip', kind: KataButtonKind.secondary, display: false, height: 46, expand: false, onPressed: _busy ? null : () => _save(skipped: true)),
            const Spacer(),
            Text(
              a.sensor == null ? 'The library will show everything' : 'The library will open on ${a.sensor}',
              style: KataType.monoStyle(size: 9.5, color: p.muted, letterSpacing: 0.12),
            ),
            const SizedBox(width: 12),
            KataPillButton(label: 'Start', height: 46, expand: false, loading: _busy, onPressed: _busy ? null : () => _save(skipped: false)),
          ]),
          ]),
        ),
      ),
    );
  }
}
