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
  int _step = 0;
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
    // Full screen, two pages — the camera, then the looks. Each question gets the window
    // rather than sharing it, which is what the phone flow does for the same reason.
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(48, 28, 48, 0),
            child: Row(children: [
              for (var i = 0; i < 2; i++) ...[
                Container(width: i == _step ? 22 : 7, height: 7, decoration: BoxDecoration(color: i <= _step ? p.fg : p.hairline, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 6),
              ],
              const SizedBox(width: 8),
              Text('STEP ${_step + 1} OF 2', style: KataType.monoStyle(size: 9, color: p.muted, letterSpacing: 0.18)),
              const Spacer(),
              KataPillButton(label: 'Skip', kind: KataButtonKind.secondary, display: false, height: 34, expand: false, onPressed: _busy ? null : () => _save(skipped: true)),
            ]),
          ),
          Expanded(child: _step == 0 ? _bodyStep(p) : _looksStep(p)),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- 1. the camera
  Widget _bodyStep(KataPalette p) {
    final a = ref.watch(onboardingAnswersProvider);
    final bodies = onboardingBodies(_search.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(48, 26, 48, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WHICH BODIES DO YOU SHOOT?', style: KataType.displayStyle(size: 32, color: p.fg)),
          const SizedBox(height: 8),
          Text('Pick as many as you own — the library opens on katas made for those sensors. Change or clear it any time.', style: KataType.bodyStyle(size: 13.5, color: p.muted, height: 1.5)),
          const SizedBox(height: 18),
          KataSearchField(hint: 'Search bodies', controller: _search, onChanged: (_) => setState(() {})),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          itemCount: bodies.length,
          itemBuilder: (_, i) {
            final b = bodies[i];
            return KataListRow(
              contentInset: 18, // the label sits inside the highlight, not on its edge
              title: b.model,
              sub: '${b.generation} · C1–C${b.slots}${b.usbWrite == UsbWrite.full ? '' : ' · writing unverified'}',
              selected: a.bodies.contains(b.model),
              onTap: () => ref.read(onboardingAnswersProvider.notifier).state = a.toggleBody(b.model),
            );
          },
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(48, 14, 48, 20),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
        child: Row(children: [
          KataPillButton(
            label: 'Not listed',
            kind: KataButtonKind.secondary,
            display: false,
            height: 46,
            expand: false,
            onPressed: () {
              ref.read(onboardingAnswersProvider.notifier).state = a.copyWith(bodies: const {});
              setState(() => _step = 1);
            },
          ),
          const Spacer(),
          if (a.sensorSummary != null)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text('LIBRARY WILL OPEN ON ${a.sensorSummary!.toUpperCase()}', style: KataType.monoStyle(size: 9.5, color: p.muted, letterSpacing: 0.14)),
            ),
          KataPillButton(
            label: a.bodies.isEmpty ? 'Continue' : 'Continue · ${a.bodies.length}',
            height: 46,
            expand: false,
            onPressed: a.bodies.isEmpty ? null : () => setState(() => _step = 1),
          ),
        ]),
      ),
    ]);
  }

  // ---------------------------------------------------------------- 2. the looks
  Widget _looksStep(KataPalette p) {
    final a = ref.watch(onboardingAnswersProvider);
    final counts = familyCounts(ref.watch(recipeRepositoryProvider));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(48, 26, 48, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WHAT ARE YOU AFTER?', style: KataType.displayStyle(size: 32, color: p.fg)),
          const SizedBox(height: 8),
          Text('Pick as many as you like — they become one-tap chips on the library. Nothing is hidden from you either way.',
              style: KataType.bodyStyle(size: 13.5, color: p.muted, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 20),
      Expanded(
        child: GridView.extent(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          maxCrossAxisExtent: 320,
          childAspectRatio: 2.1,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final f in FilmFamily.all)
              _LookCard(
                family: f,
                count: counts[f.id] ?? 0,
                selected: a.families.contains(f.id),
                onTap: () {
                  final next = {...a.families};
                  next.contains(f.id) ? next.remove(f.id) : next.add(f.id);
                  ref.read(onboardingAnswersProvider.notifier).state = a.copyWith(families: next);
                },
              ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(48, 14, 48, 20),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.hairline))),
        child: Row(children: [
          KataPillButton(label: 'Back', kind: KataButtonKind.secondary, display: false, height: 46, expand: false, onPressed: () => setState(() => _step = 0)),
          const Spacer(),
          Text(
            a.sensorSummary == null ? 'The library will show everything' : 'The library will open on ${a.sensorSummary}',
            style: KataType.monoStyle(size: 9.5, color: p.muted, letterSpacing: 0.12),
          ),
          const SizedBox(width: 14),
          KataPillButton(label: 'Start', height: 46, expand: false, loading: _busy, onPressed: _busy ? null : () => _save(skipped: false)),
        ]),
      ),
    ]);
  }
}

/// One look, big enough to read: what it is, and how many katas you'd get.
class _LookCard extends StatelessWidget {
  const _LookCard({required this.family, required this.count, required this.selected, required this.onTap});
  final FilmFamily family;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Material(
      color: selected ? p.surface : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: selected ? p.fg : p.hairline, width: selected ? 1.5 : 1)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(family.label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: KataType.displayStyle(size: 15, color: p.fg, letterSpacing: 0))),
              if (selected)
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: p.fg),
                  child: Center(child: Text('✓', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: p.bg, height: 1))),
                ),
            ]),
            const SizedBox(height: 6),
            Expanded(child: Text(family.blurb, maxLines: 2, overflow: TextOverflow.ellipsis, style: KataType.bodyStyle(size: 11.5, color: p.muted, height: 1.4))),
            Text('$count KATAS', style: KataType.monoStyle(size: 9, color: p.dim, letterSpacing: 0.16)),
          ]),
        ),
      ),
    );
  }
}
