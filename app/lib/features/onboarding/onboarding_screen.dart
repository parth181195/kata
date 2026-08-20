import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:go_router/go_router.dart';
import 'package:kata_ui/kata_ui.dart';
import 'package:ofr/ofr.dart';

import '../../core/auth/auth_repository.dart';
import '../../data/recipe_repository.dart';
import 'onboarding_state.dart';

/// Two questions after the first sign-in: which body, and which looks. The answers seed the
/// library filter so a new user lands on katas that fit their camera instead of all 340.
///
/// Skippable at every step, and re-runnable from Settings — this must never be a gate.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _search = TextEditingController();
  int _step = 0;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  OnboardingAnswers get _a => ref.read(onboardingAnswersProvider);

  Future<void> _finish({required bool skipped}) async {
    setState(() => _busy = true);
    final prefs = skipped ? UserPreferences(onboardedAt: DateTime.now()) : _a.toPreferences();
    // Remember the answers even if the network is down: the point is not to ask twice.
    await ref.read(sessionProvider.notifier).savePreferences(prefs);
    if (!mounted) return;
    setState(() => _busy = false);
    context.go('/library');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.kata;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // ---- progress + skip
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              for (var i = 0; i < 3; i++) ...[
                Container(width: i == _step ? 18 : 6, height: 6, decoration: BoxDecoration(color: i <= _step ? p.fg : p.hairline, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 5),
              ],
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : () => _finish(skipped: true),
                child: Text('Skip', style: KataType.bodyStyle(size: 12.5, color: p.muted)),
              ),
            ]),
          ),
          Expanded(child: switch (_step) { 0 => _body(p), 1 => _looks(p), _ => _done(p) }),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- 1. the camera
  Widget _body(KataPalette p) {
    final answers = ref.watch(onboardingAnswersProvider);
    final bodies = onboardingBodies(_search.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WHICH BODIES DO YOU SHOOT?', style: KataType.displayStyle(size: 26, color: p.fg, height: 1.1)),
          const SizedBox(height: 8),
          Text('Pick as many as you own — the library opens on katas made for those sensors. Change or clear it any time.', style: KataType.bodyStyle(size: 13, color: p.muted, height: 1.5)),
          const SizedBox(height: 14),
          KataSearchField(hint: 'Search bodies', height: KataSearchField.touch, controller: _search, onChanged: (_) => setState(() {})),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(
        child: ListView.builder(
          itemCount: bodies.length,
          itemBuilder: (_, i) {
            final b = bodies[i];
            final on = answers.bodies.contains(b.model);
            return KataListRow(
              inkRadius: 0,
              contentInset: 20,
              title: b.model,
              sub: '${b.generation} · C1–C${b.slots}${b.usbWrite == UsbWrite.full ? '' : ' · writing unverified'}',
              selected: on,
              onTap: () => ref.read(onboardingAnswersProvider.notifier).state = answers.toggleBody(b.model),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(children: [
          Expanded(
            child: KataPillButton(
              label: 'Not listed',
              kind: KataButtonKind.secondary,
              display: false,
              height: 50,
              onPressed: () {
                ref.read(onboardingAnswersProvider.notifier).state = answers.copyWith(bodies: const {});
                setState(() => _step = 1);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: KataPillButton(
              label: answers.bodies.isEmpty ? 'Continue' : 'Continue · ${answers.bodies.length}',
              height: 50,
              onPressed: answers.bodies.isEmpty ? null : () => setState(() => _step = 1),
            ),
          ),
        ]),
      ),
    ]);
  }

  // ---------------------------------------------------------------- 2. the looks
  Widget _looks(KataPalette p) {
    final answers = ref.watch(onboardingAnswersProvider);
    final counts = familyCounts(ref.watch(recipeRepositoryProvider));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WHAT ARE YOU AFTER?', style: KataType.displayStyle(size: 26, color: p.fg, height: 1.1)),
          const SizedBox(height: 8),
          Text('Pick as many as you like. These become one-tap shortcuts on the library — nothing is hidden from you.', style: KataType.bodyStyle(size: 13, color: p.muted, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 14),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            for (final f in FilmFamily.all)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: KataListRow(
                  title: f.label,
                  sub: '${f.blurb} · ${counts[f.id] ?? 0} katas',
                  selected: answers.families.contains(f.id),
                  onTap: () {
                    final next = {...answers.families};
                    next.contains(f.id) ? next.remove(f.id) : next.add(f.id);
                    ref.read(onboardingAnswersProvider.notifier).state = answers.copyWith(families: next);
                  },
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(children: [
          Expanded(child: KataPillButton(label: 'Back', kind: KataButtonKind.secondary, display: false, height: 50, onPressed: () => setState(() => _step = 0))),
          const SizedBox(width: 10),
          Expanded(child: KataPillButton(label: 'Continue', height: 50, onPressed: () => setState(() => _step = 2))),
        ]),
      ),
    ]);
  }

  // ---------------------------------------------------------------- 3. what it did
  Widget _done(KataPalette p) {
    final a = ref.watch(onboardingAnswersProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("YOU'RE SET", style: KataType.displayStyle(size: 26, color: p.fg, height: 1.1)),
        const SizedBox(height: 10),
        Text(
          a.sensorSummary == null
              ? 'The library will show everything. Filter by sensor whenever you want — the chips are at the top.'
              : 'Your library opens on ${a.sensorSummary}. The chips are right at the top, so clear them any time to see everything.',
          style: KataType.bodyStyle(size: 13.5, color: p.muted, height: 1.5),
        ),
        const SizedBox(height: 18),
        KataCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (a.bodies.isNotEmpty) ...[
              Text(a.bodies.length == 1 ? 'CAMERA' : 'CAMERAS', style: KataType.monoStyle(size: 9, color: p.muted, letterSpacing: 0.18)),
              const SizedBox(height: 4),
              Text((a.bodies.toList()..sort()).join(' · '), style: KataType.displayStyle(size: 16, color: p.fg, letterSpacing: 0)),
              const SizedBox(height: 12),
            ],
            Text('LOOKS', style: KataType.monoStyle(size: 9, color: p.muted, letterSpacing: 0.18)),
            const SizedBox(height: 6),
            Text(
              a.families.isEmpty ? 'Everything' : a.families.map((id) => FilmFamily.byId(id)?.label ?? id).join(' · '),
              style: KataType.bodyStyle(size: 13, color: p.dim, height: 1.4),
            ),
          ]),
        ),
        const Spacer(),
        KataPillButton(label: 'Browse the library', height: 52, loading: _busy, onPressed: _busy ? null : () => _finish(skipped: false)),
        const SizedBox(height: 8),
        Center(child: TextButton(onPressed: () => setState(() => _step = 0), child: Text('Change answers', style: KataType.bodyStyle(size: 12, color: p.muted)))),
      ]),
    );
  }
}
