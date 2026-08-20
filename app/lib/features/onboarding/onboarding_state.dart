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
    p.sensor == null ? base : base.copyWith(sensor: p.sensor);

/// Answers as the user builds them up, before they are saved.
class OnboardingAnswers {
  const OnboardingAnswers({this.body, this.sensor, this.families = const {}});
  final String? body;
  final String? sensor;
  final Set<String> families;

  OnboardingAnswers copyWith({String? body, String? sensor, Set<String>? families, bool clearBody = false}) => OnboardingAnswers(
        body: clearBody ? null : (body ?? this.body),
        sensor: clearBody ? null : (sensor ?? this.sensor),
        families: families ?? this.families,
      );

  UserPreferences toPreferences() => UserPreferences(
        sensor: sensor,
        body: body,
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
