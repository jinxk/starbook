import 'dart:convert';

import 'package:fpdart/fpdart.dart'
    show Either, Left, Right, Unit, left, right, unit;
import 'package:sqflite/sqflite.dart';

import '../../domain/failure.dart';
import '../../domain/pack/pack.dart';
import '../../domain/repositories.dart';
import '../db/store_db.dart';
import '../pack/pack_parser.dart';

class SqlitePackRepository implements PackRepository {
  SqlitePackRepository(this._db, {this._now = DateTime.now});

  final Database _db;
  final DateTime Function() _now;
  List<Pack> _installed = const [];

  @override
  List<Pack> get installed => _installed;

  @override
  Future<Either<Failure, Unit>> start(List<String> defaultPacks) =>
      guard(() async {
        final defaults = <(Pack, String)>[];
        for (final text in defaultPacks) {
          switch (parsePack(text)) {
            case Left(:final value):
              return left(value);
            case Right(:final value):
              defaults.add((value, text));
          }
        }
        await _db.transaction((txn) async {
          final stored = await _setting(txn, 'defaultsOffered');
          final offered = <String>{
            if (stored != null) ...(jsonDecode(stored) as List).cast<String>(),
          };
          for (final (pack, text) in defaults) {
            final revision = await _revision(txn, pack.id);
            final write = revision == null
                ? !offered.contains(pack.id)
                : pack.revision > revision;
            if (write) await _write(txn, pack, text);
          }
          await txn.insert('settings', {
            'key': 'defaultsOffered',
            'value': jsonEncode(
              {...offered, for (final (pack, _) in defaults) pack.id}.toList()
                ..sort(),
            ),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        });
        await _reload();
        return right(unit);
      });

  @override
  Future<Either<Failure, InstallResult>> install(
    String json, {
    bool confirmed = false,
  }) => guard(() async {
    switch (parsePack(json)) {
      case Left(:final value):
        return left(value);
      case Right(:final value):
        final revision = await _revision(_db, value.id);
        if (revision != null && value.revision <= revision && !confirmed) {
          return right(InstallResult.needsConfirm);
        }
        await _write(_db, value, json);
        await _reload();
        return right(InstallResult.installed);
    }
  });

  @override
  Future<Either<Failure, Unit>> remove(String id) => guard(() async {
    await _db.delete('packs', where: 'id = ?', whereArgs: [id]);
    await _reload();
    return right(unit);
  });

  @override
  Either<Failure, Pack> check(String json) {
    try {
      return parsePack(json);
    } catch (_) {
      return left(const Failure('the file could not be read'));
    }
  }

  Future<int?> _revision(DatabaseExecutor e, String id) async {
    final rows = await e.query(
      'packs',
      columns: ['revision'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : rows.single['revision'] as int;
  }

  Future<String?> _setting(DatabaseExecutor e, String key) async {
    final rows = await e.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  /// A replace keeps the stored install time, so the pack keeps its place.
  Future<void> _write(DatabaseExecutor e, Pack pack, String text) async {
    final had = await e.query(
      'packs',
      columns: ['installed_at'],
      where: 'id = ?',
      whereArgs: [pack.id],
    );
    await e.insert('packs', {
      'id': pack.id,
      'revision': pack.revision,
      'title': pack.title,
      'json': text.startsWith('\uFEFF') ? text.substring(1) : text,
      'installed_at': had.isEmpty
          ? _now().millisecondsSinceEpoch
          : had.single['installed_at'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _reload() async {
    final rows = await _db.query('packs', orderBy: 'installed_at, id');
    _installed = [
      for (final r in rows)
        if (parsePack(r['json'] as String) case Right(:final value)) value,
    ];
  }
}
