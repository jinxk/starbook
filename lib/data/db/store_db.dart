import 'package:fpdart/fpdart.dart' show Either, left, right;
import 'package:sqflite/sqflite.dart';

import '../../domain/failure.dart';

// Entry 0 is schema version 1. A later change appends a list; shipped lists
// are never edited.
const _migrations = <List<String>>[
  [
    'CREATE TABLE packs ('
        'id TEXT PRIMARY KEY, '
        'revision INTEGER NOT NULL, '
        'title TEXT NOT NULL, '
        'json TEXT NOT NULL, '
        'installed_at INTEGER NOT NULL)',
    'CREATE TABLE child ('
        'id INTEGER PRIMARY KEY CHECK (id = 1), '
        'name TEXT, '
        'picture TEXT)',
    'CREATE TABLE weeks ('
        'id INTEGER PRIMARY KEY, '
        'week_start TEXT NOT NULL UNIQUE, '
        'sheet_ref TEXT NOT NULL, '
        'sheet_json TEXT NOT NULL, '
        'special_reward TEXT)',
    'CREATE TABLE awards ('
        'id INTEGER PRIMARY KEY, '
        'week_id INTEGER NOT NULL, '
        'weekday TEXT NOT NULL, '
        'task_id TEXT NOT NULL, '
        'award_ref TEXT NOT NULL, '
        'stars INTEGER NOT NULL, '
        'sticker TEXT, '
        'given_at INTEGER NOT NULL, '
        'undone_at INTEGER)',
    'CREATE UNIQUE INDEX awards_live ON awards (week_id, weekday, task_id) '
        'WHERE undone_at IS NULL',
    'CREATE TABLE trophies ('
        'milestone_ref TEXT PRIMARY KEY, '
        'earned_at INTEGER NOT NULL)',
    'CREATE TABLE finished ('
        'kind TEXT NOT NULL, '
        'ref TEXT NOT NULL, '
        'finished_at INTEGER NOT NULL)',
    'CREATE TABLE voices ('
        'id TEXT PRIMARY KEY, '
        'revision INTEGER NOT NULL, '
        'title TEXT NOT NULL, '
        'language TEXT NOT NULL, '
        'manifest_json TEXT NOT NULL, '
        'folder TEXT NOT NULL, '
        'installed_at INTEGER NOT NULL)',
    'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  ],
  [
    'CREATE TABLE habit_ticks ('
        'day TEXT NOT NULL, '
        'habit_id TEXT NOT NULL, '
        'PRIMARY KEY (day, habit_id))',
  ],
];

/// The schema version of a store that is up to date.
int get storeVersion => _migrations.length;

Future<Either<Failure, T>> guard<T>(
  Future<Either<Failure, T>> Function() body,
) async {
  try {
    return await body();
  } catch (e) {
    return left(Failure('$e'));
  }
}

Future<Either<Failure, Database>> openStore(
  DatabaseFactory factory,
  String path,
) => guard(
  () async => right(
    await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _migrations.length,
        // sqflite calls onUpgrade(0, n) for a new file, so there is no onCreate.
        onUpgrade: (db, from, to) async {
          for (final statements in _migrations.sublist(from, to)) {
            for (final sql in statements) {
              await db.execute(sql);
            }
          }
        },
      ),
    ),
  ),
);
