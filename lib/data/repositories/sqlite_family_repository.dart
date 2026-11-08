import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fpdart/fpdart.dart' show Either, Right, Unit, left, right, unit;
import 'package:sqflite/sqflite.dart';

import '../../domain/failure.dart';
import '../../domain/family.dart';
import '../../domain/progress/progress.dart'
    show ownHabitPictures, ownHabitTextMax;
import '../../domain/repositories.dart';
import '../db/journal.dart';
import '../db/store_db.dart';
import '../pack/pack_validator.dart';

const _entry = 'starbook-family.json';
const _version = 1;

const wrongWords = Failure(
  'These words do not match. Check them and try again.',
);
const otherFamily = Failure(
  'This file is from a phone with other words. Pair the phones again.',
);
const notPaired = Failure('Pair this phone first, then open the file again.');
const unreadable = Failure(
  'This file could not be read. Ask the other phone to send it again.',
);

class SqliteFamilyRepository implements FamilyRepository {
  SqliteFamilyRepository(this._db, {DateTime Function()? now, Random? random})
    : _now = now ?? DateTime.now,
      _random = random ?? Random.secure();

  final Database _db;
  final DateTime Function() _now;
  final Random _random;

  Future<String?> _setting(DatabaseExecutor e, String key) async {
    final rows = await e.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.single['value']! as String;
  }

  Future<void> _put(DatabaseExecutor e, String key, String value) => e.insert(
    'settings',
    {'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  DateTime? _time(String? millis) => millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(int.parse(millis));

  @override
  Future<Either<Failure, FamilyState>> state() => guard(() async {
    final code = await _setting(_db, 'familyCode');
    return right((
      code: code?.split(' '),
      lastSent: _time(await _setting(_db, 'familySent')),
      lastReceived: _time(await _setting(_db, 'familyReceived')),
    ));
  });

  @override
  Future<Either<Failure, List<String>>> showCode() => guard(
    () => _db.transaction((txn) async {
      final had = await _setting(txn, 'familyCode');
      if (had != null) return right(had.split(' '));
      final code = makeFamilyCode(_random);
      await _put(txn, 'familyCode', code.join(' '));
      return right(code);
    }),
  );

  @override
  Future<Either<Failure, Unit>> pair(String typed) async {
    final code = readFamilyCode(typed);
    if (code == null) return left(wrongWords);
    return guard(
      () => _db.transaction((txn) async {
        if (await _setting(txn, 'familyCode') == code.join(' ')) {
          return right(unit);
        }
        // Another family: nothing is known about what its phones hold.
        await txn.delete(
          'settings',
          where: "key IN ('familyHas', 'familySent', 'familyReceived')",
        );
        await _put(txn, 'familyCode', code.join(' '));
        return right(unit);
      }),
    );
  }

  @override
  Future<Either<Failure, Uint8List>> send() => guard(
    () => _db.transaction((txn) async {
      final code = await _setting(txn, 'familyCode');
      if (code == null) return left(notPaired);
      final has = await _setting(txn, 'familyHas');
      final held = has == null
          ? const <String, int>{}
          : (jsonDecode(has) as Map).cast<String, int>();
      final now = _now();
      final body = jsonEncode({
        'starbookFamily': _version,
        'phone': await phoneId(txn),
        'made': now.toIso8601String(),
        'has': await heldNumbers(txn),
        'events': await eventsBeyond(txn, held),
      });
      final zip = Archive()..add(ArchiveFile.string(_entry, body));
      final bytes = ZipEncoder(password: code).encodeBytes(zip);
      await _put(txn, 'familySent', '${now.millisecondsSinceEpoch}');
      return right(bytes);
    }),
  );

  @override
  bool isFamilyFile(Uint8List bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes).find(_entry) != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Either<Failure, Unit>> receive(Uint8List bytes) async {
    final code = switch (await state()) {
      Right(:final value) => value.code?.join(' '),
      _ => null,
    };
    if (code == null) return left(notPaired);
    final String text;
    try {
      final file = ZipDecoder().decodeBytes(bytes, password: code).find(_entry);
      if (file == null) return left(unreadable);
      text = utf8.decode(file.readBytes()!);
    } on ArchiveException catch (e) {
      return left(
        e.message.contains('Wrong password') ? otherFamily : unreadable,
      );
    } catch (_) {
      return left(unreadable);
    }
    final ({Map<String, int> has, List<Map<String, Object?>> events}) file;
    try {
      file = _read(text);
    } catch (_) {
      return left(unreadable);
    }
    try {
      await _db.transaction((txn) async {
        await merge(txn, file.events);
        await _check(txn);
        await _put(txn, 'familyHas', jsonEncode(file.has));
        await _put(txn, 'familyReceived', '${_now().millisecondsSinceEpoch}');
      });
    } catch (_) {
      return left(unreadable);
    }
    return right(unit);
  }

  ({Map<String, int> has, List<Map<String, Object?>> events}) _read(
    String text,
  ) {
    final json = jsonDecode(text) as Map;
    if (json['starbookFamily'] != _version) throw const FormatException();
    final has = {
      for (final MapEntry(:key, :value) in (json['has'] as Map).entries)
        key as String: value as int,
    };
    final events = [
      for (final raw in json['events'] as List)
        Map<String, Object?>.from(raw as Map),
    ];
    for (final e in events) {
      final phone = e['phone'] as String;
      final id = e['id'] as String;
      final n = int.parse(id.substring(phone.length + 1));
      if (phone.isEmpty ||
          phone.contains(':') ||
          id != '$phone:$n' ||
          n < 1 ||
          e['at'] is! int ||
          !eventKinds.contains(e['kind'])) {
        throw const FormatException();
      }
      jsonDecode(e['data'] as String) as Map;
    }
    return (has: has, events: events);
  }

  /// Throws when the merged rows hold a week sheet or an own habit this app
  /// would not make.
  Future<void> _check(Transaction txn) async {
    for (final row in await txn.query('weeks')) {
      final sheet = jsonDecode(row['sheet_json']! as String);
      if (validateSheet(sheet).isNotEmpty) throw const FormatException();
    }
    for (final row in await txn.query('own_habits')) {
      final text = (row['text']! as String).trim();
      final days = row['days']! as int;
      if (text.isEmpty ||
          text.length > ownHabitTextMax ||
          days < 1 ||
          days > 127 ||
          !ownHabitPictures.contains(row['picture'])) {
        throw const FormatException();
      }
    }
  }
}
