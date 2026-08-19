import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How library cards are laid out: hero = big first card + rows (design default), list = rows only, grid = 2-up photo tiles.
enum LibraryLayout { hero, list, grid }

extension LibraryLayoutX on LibraryLayout {
  String get label => switch (this) { LibraryLayout.hero => 'HERO', LibraryLayout.list => 'LIST', LibraryLayout.grid => 'GRID' };
  LibraryLayout get next => LibraryLayout.values[(index + 1) % LibraryLayout.values.length];
}

/// Persisted UI settings (SharedPreferences). Override [sharedPrefsProvider] in tests.
final sharedPrefsProvider = FutureProvider<SharedPreferences>((_) => SharedPreferences.getInstance());

class LibraryLayoutNotifier extends Notifier<LibraryLayout> {
  static const _key = 'kata.libraryLayout';
  @override
  LibraryLayout build() {
    ref.listen(sharedPrefsProvider, (_, p) {
      final v = p.valueOrNull?.getString(_key);
      final l = LibraryLayout.values.where((x) => x.name == v).firstOrNull;
      if (l != null && l != state) state = l;
    }, fireImmediately: true);
    return LibraryLayout.hero;
  }

  Future<void> set(LibraryLayout l) async {
    state = l;
    final p = await ref.read(sharedPrefsProvider.future);
    await p.setString(_key, l.name);
  }

  Future<void> cycle() => set(state.next);
}

final libraryLayoutProvider = NotifierProvider<LibraryLayoutNotifier, LibraryLayout>(LibraryLayoutNotifier.new);
