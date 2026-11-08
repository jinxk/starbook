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

typedef _File = ({
  String phone,
  Map<String, int> has,
  List<Map<String, Object?>> events,
});

/// The phone's own marks of what the child has seen, which name awards and
/// weeks by row id. A merge numbers the rows again, so they are read before
/// it and written back by event and week start after it.
class _Marks {
  _Marks._(this._weeks, this._awards, this._settings);

  final Map<int, String> _weeks;
  final Map<int, String> _awards;
  final Map<String, String> _settings;

  static Future<_Marks> read(Transaction txn) async => _Marks._(
    {
      for (final r in await txn.query('weeks'))
        r['id']! as int: r['week_start']! as String,
    },
    {
      for (final r in await txn.query('awards'))
        r['id']! as int: r['event']! as String,
    },
    {
      for (final r in await txn.query(
        'settings',
        where: "key IN ('seenAward', 'allDoneMoment', 'seenWeek', 'seenDays')",
      ))
        r['key']! as String: r['value']! as String,
    },
  );

  Future<void> write(Transaction txn) async {
    final weeks = {
      for (final r in await txn.query('weeks'))
        r['week_start']! as String: r['id']! as int,
    };
    final awards = {
      for (final r in await txn.query('awards'))
        r['event']! as String: r['id']! as int,
    };
    int? week(String old) => weeks[_weeks[int.tryParse(old)]];
    Future<void> put(String key, Object? value) => value == null
        ? txn.delete('settings', where: 'key = ?', whereArgs: [key])
        : txn.insert('settings', {
            'key': key,
            'value': '$value',
          }, conflictAlgorithm: ConflictAlgorithm.replace);

    if (_settings['seenAward'] case final seen?) {
      // The awards not seen yet stay unseen; the other phone's awards before
      // the first of them count as seen.
      final unseen = [
        for (final MapEntry(:key, :value) in _awards.entries)
          if (key > int.parse(seen) && awards[value] != null) awards[value]!,
      ];
      final newest = awards.values.fold(0, (a, b) => a > b ? a : b);
      await put(
        'seenAward',
        unseen.isEmpty ? newest : unseen.reduce((a, b) => a < b ? a : b) - 1,
      );
    }
    if (_settings['allDoneMoment'] case final id?) {
      await put('allDoneMoment', awards[_awards[int.tryParse(id)]]);
    }
    if (_settings['seenWeek'] case final id?) {
      await put('seenWeek', week(id));
    }
    if (_settings['seenDays'] case final marks?) {
      await put(
        'seenDays',
        jsonEncode([
          for (final mark in (jsonDecode(marks) as List).cast<String>())
            if (week(mark.split('/').first) case final id?)
              '$id/${mark.split('/').skip(1).join('/')}',
        ]),
      );
    }
  }
}

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
  SqliteFamilyRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Database _db;
  final DateTime Function() _now;

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
      final code = makeFamilyCode(Random.secure());
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
      final body = jsonEncode({
        'starbookFamily': _version,
        'phone': await phoneId(txn),
        'made': _now().toIso8601String(),
        'has': await heldNumbers(txn),
        'events': await eventsBeyond(txn, held),
      });
      final zip = Archive()..add(ArchiveFile.string(_entry, body));
      return right(ZipEncoder(password: code).encodeBytes(zip));
    }),
  );

  @override
  Future<Either<Failure, Unit>> sent() => guard(() async {
    await _put(_db, 'familySent', '${_now().millisecondsSinceEpoch}');
    return right(unit);
  });

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
    // An entry that opens without the words was not made by [send].
    try {
      ZipDecoder().decodeBytes(bytes).find(_entry)?.readBytes();
      return left(unreadable);
    } catch (_) {}
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
    final _File file;
    try {
      file = _read(text);
    } catch (_) {
      return left(unreadable);
    }
    try {
      await _db.transaction((txn) async {
        // A file this phone sent, opened here again.
        if (file.phone == await phoneId(txn)) throw const FormatException();
        final marks = await _Marks.read(txn);
        await merge(txn, file.events);
        await _check(txn);
        await marks.write(txn);
        await _put(txn, 'familyHas', jsonEncode(file.has));
        await _put(txn, 'familyReceived', '${_now().millisecondsSinceEpoch}');
      });
    } catch (_) {
      return left(unreadable);
    }
    return right(unit);
  }

  _File _read(String text) {
    final json = jsonDecode(text) as Map;
    if (json['starbookFamily'] != _version) throw const FormatException();
    final phone = json['phone'] as String;
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
    return (phone: phone, has: has, events: events);
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
