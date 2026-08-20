import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuji_ptp/fuji_ptp.dart';
import 'package:ofr/ofr.dart';

import '../../core/auth/auth_repository.dart';
import '../../data/recipe.dart';
import '../../data/recipe_repository.dart';

/// Set from Settings to run the questions again without pretending the answers are gone.
final redoOnboardingProvider = StateProvider<bool>((_) => false);

/// True when the signed-in user has never answered the first-run questions — or asked to
/// answer them again.
final needsOnboardingProvider = Provider<bool>((ref) {
  final s = ref.watch(sessionProvider).valueOrNull;
  if (s == null) return false;
  return !s.user.preferences.onboarded || ref.watch(redoOnboardingProvider);
});

/// The library filter a set of preferences implies. Only the sensor is applied: a film-sim
/// family is a *shortcut* the user taps, not something we silently narrow the library by.
LibraryFilter filterFor(UserPreferences p, LibraryFilter base) =>
    p.sensors.isEmpty ? base : base.copyWith(sensors: p.sensors.toSet());

/// Answers as the user builds them up, before they are saved.
class OnboardingAnswers {
  const OnboardingAnswers({this.bodies = const {}, this.families = const {}});

  /// Model names; the sensor list is derived, since two bodies can share a generation.
  final Set<String> bodies;
  final Set<String> families;

  Set<String> get sensors => {
        for (final m in bodies)
          if (KnownBody.forModel(m) case final b?) b.generation,
      };

  /// What the library will open on, in a form a person can read.
  String? get sensorSummary => sensors.isEmpty ? null : (sensors.toList()..sort()).join(' · ');

  OnboardingAnswers toggleBody(String model) =>
      OnboardingAnswers(bodies: bodies.contains(model) ? ({...bodies}..remove(model)) : {...bodies, model}, families: families);

  OnboardingAnswers copyWith({Set<String>? bodies, Set<String>? families}) =>
      OnboardingAnswers(bodies: bodies ?? this.bodies, families: families ?? this.families);

  UserPreferences toPreferences() => UserPreferences(
        bodies: bodies.toList()..sort(),
        sensors: sensors.toList()..sort(),
        filmSimFamilies: families.toList()..sort(),
        onboardedAt: DateTime.now(),
      );
}

final onboardingAnswersProvider = StateProvider<OnboardingAnswers>((_) => const OnboardingAnswers());

/// Bodies to offer, grouped so the ones Kata can actually write to come first.
List<KnownBody> onboardingBodies(String query) {
  final q = query.trim().toLowerCase();
  final all = [...KnownBody.all]..sort((a, b) {
    final t = a.usbWrite.index.compareTo(b.usbWrite.index);
    return t != 0 ? t : a.model.compareTo(b.model);
  });
  if (q.isEmpty) return all;
  return all.where((b) => b.model.toLowerCase().contains(q)).toList();
}

/// How many katas in the synced library each family covers — an empty-looking choice is
/// worse than no choice, so the picker shows real numbers.
Map<String, int> familyCounts(RecipeRepository repo) {
  final out = {for (final f in FilmFamily.all) f.id: 0};
  for (final r in repo.all) {
    for (final f in FilmFamily.all) {
      if (f.matches(r.ofr)) out[f.id] = out[f.id]! + 1;
    }
  }
  return out;
}
