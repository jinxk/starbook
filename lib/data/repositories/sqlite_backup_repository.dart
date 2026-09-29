import 'dart:convert';

import 'package:fpdart/fpdart.dart'
    show Either, Left, Right, Unit, left, right, unit;
import 'package:sqflite/sqflite.dart';

import '../../domain/failure.dart';
import '../../domain/repositories.dart';
import '../db/store_db.dart';
import '../pack/pack_parser.dart';

// Every table but voices, whose clips live in files.
const _tables = [
  'packs',
  'child',
  'weeks',
  'awards',
  'trophies',
  'finished',
  'habit_ticks',
  'settings',
];

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
      for (final table in _tables)
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
        for (final table in _tables) {
          await txn.delete(table);
          for (final row in rows[table]!) {
            await txn.insert(table, row);
          }
        }
      });
    } catch (_) {
      return left(_damaged);
    }
    await _packs.start(const []);
    await _voices.start(const []);
    return right(unit);
  }

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
        for (final table in _tables)
          table: [
            for (final row in (json[table] as List?) ?? const [])
              Map<String, Object?>.from(row as Map),
          ],
      };
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
