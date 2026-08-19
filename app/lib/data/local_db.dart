import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'local_db.g.dart';

/// Recipes mirrored from the API (`Recipe.toJson()` in [body]).
class CachedRecipes extends Table {
  TextColumn get id => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Recipes the user imported or read off a camera (device-local until Stage 2 sync).
class MineRecipes extends Table {
  TextColumn get id => text()();
  TextColumn get body => text()();
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class Favourites extends Table {
  TextColumn get recipeId => text()();
  @override
  Set<Column> get primaryKey => {recipeId};
}

class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [CachedRecipes, MineRecipes, Favourites, Meta])
class KataDb extends _$KataDb {
  KataDb(super.e);
  KataDb.memory() : super(NativeDatabase.memory());

  /// File-backed database in the app documents dir.
  static KataDb open() => KataDb(
    LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      return NativeDatabase.createInBackground(File(p.join(dir.path, 'kata.sqlite')));
    }),
  );

  @override
  int get schemaVersion => 1;

  Future<String?> getMeta(String key) async => (await (select(meta)..where((m) => m.key.equals(key))).getSingleOrNull())?.value;
  Future<void> setMeta(String key, String value) => into(meta).insertOnConflictUpdate(MetaCompanion.insert(key: key, value: value));
}
