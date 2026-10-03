import 'dart:convert';

import 'package:fpdart/fpdart.dart'
    show Either, Left, Right, Unit, left, right, unit;
import 'package:sqflite/sqflite.dart';

import '../../domain/failure.dart';
import '../../domain/pack/pack.dart' show Weekday;
import '../../domain/repositories.dart';
import '../db/store_db.dart';
import '../pack/pack_parser.dart';

// Every table but voices, whose clips live in files, with each column's type;
// a ? allows null.
const _columns = <String, Map<String, String>>{
  'packs': {
    'id': 'String',
    'revision': 'int',
    'title': 'String',
    'json': 'String',
    'installed_at': 'int',
  },
  'child': {'id': 'int', 'name': 'String?', 'picture': 'String?'},
  'weeks': {
    'id': 'int',
    'week_start': 'String',
    'sheet_ref': 'String',
    'sheet_json': 'String',
    'special_reward': 'String?',
  },
  'awards': {
    'id': 'int',
    'week_id': 'int',
    'weekday': 'String',
    'task_id': 'String',
    'award_ref': 'String',
    'stars': 'int',
    'sticker': 'String?',
    'given_at': 'int',
    'undone_at': 'int?',
  },
  'trophies': {'milestone_ref': 'String', 'earned_at': 'int'},
  'finished': {'kind': 'String', 'ref': 'String', 'finished_at': 'int'},
  'habit_ticks': {'day': 'String', 'habit_id': 'String'},
  'settings': {'key': 'String', 'value': 'String'},
};

const _notBackup = Failure('the file is not a Starbook backup');
const _newer = Failure('the backup is from a newer Starbook');
const _damaged = Failure('the backup is damaged');

typedef _Backup = ({
  BackupInfo info,
  Map<String, List<Map<String, Object?>>> rows,
});

class SqliteBackupRepository implements BackupRepository {
  SqliteBackupRepository(
    this._db,
    this._packs,
    this._voices, {
    this._now = DateTime.now,
  });

  final Database _db;
  final PackRepository _packs;
  final VoiceRepository _voices;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, String>> export() => guard(() async {
    final backup = <String, Object?>{
      'starbookBackup': storeVersion,
      'made': _now().toIso8601String(),
      for (final table in _columns.keys)
        table: await _db.query(table, orderBy: 'rowid'),
    };
    return right(jsonEncode(backup));
  });

  @override
  Either<Failure, BackupInfo> check(String json) =>
      _read(json).map((backup) => backup.info);

  @override
  Future<Either<Failure, Unit>> restore(String json) async {
    final Map<String, List<Map<String, Object?>>> rows;
    switch (_read(json)) {
      case Left(:final value):
        return left(value);
      case Right(:final value):
        rows = value.rows;
    }
    try {
      await _db.transaction((txn) async {
        for (final table in _columns.keys) {
          await txn.delete(table);
          for (final row in rows[table]!) {
            await txn.insert(table, row);
          }
        }
      });
    } catch (_) {
      return left(_damaged);
    }
    final packs = await _packs.start(const []);
    if (packs case Left(:final value)) return left(value);
    final voices = await _voices.start(const []);
    if (voices case Left(:final value)) return left(value);
    return right(unit);
  }

  bool _typed(Map<String, String> columns, Map<String, Object?> row) =>
      row.keys.every(columns.containsKey) &&
      columns.entries.every((c) {
        final value = row[c.key];
        if (value == null) return c.value.endsWith('?');
        return switch (value) {
          int() => c.value.startsWith('int'),
          String() => c.value.startsWith('String'),
          _ => false,
        };
      });

  Either<Failure, _Backup> _read(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return left(_notBackup);
    }
    if (json is! Map) return left(_notBackup);
    final version = json['starbookBackup'];
    if (version is! int || version < 1) return left(_notBackup);
    if (version > storeVersion) return left(_newer);
    try {
      final rows = {
        for (final table in _columns.keys)
          table: [
            for (final row in json[table] as List)
              Map<String, Object?>.from(row as Map),
          ],
      };
      for (final MapEntry(key: table, value: columns) in _columns.entries) {
        if (rows[table]!.any((row) => !_typed(columns, row))) {
          return left(_damaged);
        }
      }
      for (final row in rows['awards']!) {
        Weekday.values.byName(row['weekday'] as String);
      }
      for (final row in rows['weeks']!) {
        DateTime.parse(row['week_start'] as String);
      }
      for (final row in rows['packs']!) {
        final pack = parsePack(row['json'] as String);
        if (pack case Right(:final value) when value.id == row['id']) continue;
        return left(_damaged);
      }
      for (final row in rows['weeks']!) {
        parseSheet(row['sheet_json'] as String);
      }
      return right((
        info: (
          made: DateTime.parse(json['made'] as String),
          child: rows['child']!.firstOrNull?['name'] as String?,
          stars: rows['awards']!
              .where((r) => r['undone_at'] == null)
              .fold(0, (sum, r) => sum + ((r['stars'] as int?) ?? 0)),
          packs: rows['packs']!.length,
        ),
        rows: rows,
      ));
    } catch (_) {
      return left(_damaged);
    }
  }
}
