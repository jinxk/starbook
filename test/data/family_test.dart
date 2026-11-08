import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:starbook/data/db/store_db.dart';
import 'package:starbook/data/repositories/sqlite_backup_repository.dart';
import 'package:starbook/data/repositories/sqlite_family_repository.dart';
import 'package:starbook/data/repositories/sqlite_pack_repository.dart';
import 'package:starbook/data/repositories/sqlite_progress_repository.dart';
import 'package:starbook/data/repositories/sqlite_voice_repository.dart';
import 'package:starbook/domain/family.dart';
import 'package:starbook/domain/pack/pack.dart';
import 'package:starbook/domain/progress/progress.dart';

import 'store_test.dart' show builtRows, ok, packJson, seenFrom;

typedef Phone = ({
  Database db,
  SqliteProgressRepository progress,
  SqliteFamilyRepository family,
  SqliteBackupRepository backup,
  int week,
});

void main() {
  late Directory dir;
  final m = mondayOf(DateTime.now());
  var now = DateTime(m.year, m.month, m.day, 8);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('starbook_family');
    now = DateTime(m.year, m.month, m.day, 8);
  });

  tearDown(() => dir.delete(recursive: true));

  Future<Phone> phone(String name) async {
    final db = ok(
      await openStore(
        databaseFactoryFfi,
        '${dir.path}${Platform.pathSeparator}$name.db',
      ),
    );
    addTearDown(db.close);
    final packs = SqlitePackRepository(db);
    ok(await packs.start(const []));
    await packs.install(packJson());
    final progress = SqliteProgressRepository(db, packs, now: () => now);
    return (
      db: db,
      progress: progress,
      family: SqliteFamilyRepository(db, now: () => now),
      backup: SqliteBackupRepository(
        db,
        packs,
        SqliteVoiceRepository(db, dir.path),
      ),
      week: ok(await progress.currentWeek())!.id,
    );
  }

  void at(int minute) => now = DateTime(m.year, m.month, m.day, 8, minute);

  test('two paired phones that send each other a file show the same week: '
      'an award or tick given on both counts once, the earlier award and the '
      'latest edit count, a file opened twice changes nothing, and a backup '
      'made after it restores', () async {
    final a = await phone('a');
    final b = await phone('b');
    final code = ok(await a.family.showCode());
    expect(ok(await a.family.showCode()), code);
    ok(await b.family.pair('  ${code.join('   ').toUpperCase()} '));

    Future<void> give(Phone p, String task, String award) async => ok(
      await p.progress.give(
        weekId: p.week,
        weekday: Weekday.monday,
        taskId: task,
        awardRef: 'test.pack/$award',
      ),
    );
    at(1);
    await give(a, 't1', 'star');
    at(2);
    await give(b, 't1', 'sticker');
    at(3);
    await give(b, 't2', 'star');
    at(4);
    ok(await a.progress.tickHabit(a.week, 'teeth'));
    at(5);
    ok(await b.progress.tickHabit(b.week, 'teeth'));
    at(6);
    ok(await b.progress.editTask(b.week, 't1', 'Write C'));
    at(7);
    ok(await a.progress.editTask(a.week, 't1', 'Write B'));
    at(8);
    ok(await a.progress.setChild(const Child(name: 'Asha', picture: 'lion')));
    ok(await b.progress.addOwnHabit('I swam', 'water', {Weekday.monday}));

    at(10);
    final fromA = ok(await a.family.send());
    ok(await a.family.sent());
    expect(a.family.isFamilyFile(fromA), isTrue);
    ok(await b.family.receive(fromA));
    at(12);
    ok(await a.family.receive(ok(await b.family.send())));

    expect(await seenFrom(a.db), await seenFrom(b.db));
    Future<List<Object?>> live(Database db) async => [
      for (final r in await db.query(
        'awards',
        where: 'undone_at IS NULL',
        orderBy: 'task_id',
      ))
        (r['task_id'], r['award_ref']),
    ];
    expect(await live(a.db), [
      ('t1', 'test.pack/star'),
      ('t2', 'test.pack/star'),
    ]);
    expect(await live(b.db), await live(a.db));
    expect(await a.db.query('habit_ticks'), hasLength(1));
    final weekA = (await a.db.query('weeks')).single['sheet_json']! as String;
    expect(weekA, contains('Write B'));
    expect(weekA, isNot(contains('Write C')));
    expect((await b.db.query('weeks')).single['sheet_json'], weekA);
    expect((await b.db.query('child')).single['name'], 'Asha');
    expect(await a.db.query('own_habits'), hasLength(1));

    final state = ok(await a.family.state());
    expect(state.code, code);
    expect(state.lastSent, DateTime(m.year, m.month, m.day, 8, 10));
    expect(state.lastReceived, DateTime(m.year, m.month, m.day, 8, 12));

    final rowsA = await builtRows(a.db);
    final fromB = ok(await b.family.send());
    ok(await a.family.receive(fromB));
    ok(await a.family.receive(fromB));
    expect(await builtRows(a.db), rowsA);

    // A phone that has heard back sends only what the other phone lacks.
    at(20);
    ok(await a.progress.tickHabit(a.week, 'bath'));
    final small = ok(await a.family.send());
    expect(small.length, lessThan(fromA.length));
    ok(await b.family.receive(small));
    expect(await seenFrom(b.db), await seenFrom(a.db));

    ok(await a.backup.restore(ok(await b.backup.export())));
    expect(await seenFrom(a.db), await seenFrom(b.db));
  });

  test('an award given and undone on one phone and given later on the other '
      'counts the same on both, tasks added on both are listed in the same '
      'order, and an untick made with the clock set back still wins on both '
      'and a backup restores', () async {
    final a = await phone('a');
    final b = await phone('b');
    ok(await b.family.pair(ok(await a.family.showCode()).join(' ')));
    at(1);
    final given = ok(
      await a.progress.give(
        weekId: a.week,
        weekday: Weekday.monday,
        taskId: 't1',
        awardRef: 'test.pack/star',
      ),
    );
    at(5);
    ok(await a.progress.undo(given.id));
    at(30);
    ok(await a.progress.tickHabit(a.week, 'teeth'));
    at(28);
    ok(await a.progress.undoHabit('teeth'));
    at(20);
    ok(
      await b.progress.give(
        weekId: b.week,
        weekday: Weekday.monday,
        taskId: 't1',
        awardRef: 'test.pack/sticker',
      ),
    );
    at(22);
    ok(await a.progress.addTask(a.week, Weekday.monday, 'From A'));
    at(23);
    ok(await b.progress.addTask(b.week, Weekday.monday, 'From B'));
    at(40);
    ok(await b.family.receive(ok(await a.family.send())));
    ok(await a.family.receive(ok(await b.family.send())));
    expect(await seenFrom(a.db), await seenFrom(b.db));

    Future<List<Object?>> live(Database db) async => [
      for (final r in await db.query('awards', where: 'undone_at IS NULL'))
        (r['task_id'], r['award_ref']),
    ];
    expect(await live(a.db), [('t1', 'test.pack/sticker')]);
    expect(await live(b.db), await live(a.db));
    expect(await a.db.query('habit_ticks'), isEmpty);
    expect(await b.db.query('habit_ticks'), isEmpty);
    ok(await a.backup.restore(ok(await a.backup.export())));
    expect(await live(a.db), [('t1', 'test.pack/sticker')]);
  });

  test('a replace on one phone and an undo of the same award with its old one '
      'brought back on the other both merge, and the two phones then show '
      'the same award', () async {
    final a = await phone('a');
    final b = await phone('b');
    ok(await b.family.pair(ok(await a.family.showCode()).join(' ')));
    Future<GivenAward> give(String award, {int? replaces}) async => ok(
      await a.progress.give(
        weekId: a.week,
        weekday: Weekday.monday,
        taskId: 't1',
        awardRef: 'test.pack/$award',
        replaces: replaces,
      ),
    );
    at(1);
    final first = await give('star');
    at(2);
    final second = await give('sticker', replaces: first.id);
    ok(await b.family.receive(ok(await a.family.send())));
    final [firstB, secondB] = [
      for (final r in await b.db.query('awards', orderBy: 'id'))
        r['id']! as int,
    ];
    at(3);
    ok(await b.progress.undo(secondB, restore: firstB));
    at(4);
    await give('star', replaces: second.id);

    at(10);
    ok(await b.family.receive(ok(await a.family.send())));
    ok(await a.family.receive(ok(await b.family.send())));
    expect(await seenFrom(a.db), await seenFrom(b.db));
    final live = await a.db.query('awards', where: 'undone_at IS NULL');
    expect(live.single['id'], first.id);
  });

  test('a file made with other words, a damaged file and a file on a phone '
      'that is not paired change nothing; words not from the list are not '
      'kept', () async {
    expect(familyWords.toSet(), hasLength(256));
    final a = await phone('a');
    final b = await phone('b');
    final code = ok(await a.family.showCode());
    ok(
      await a.progress.give(
        weekId: a.week,
        weekday: Weekday.monday,
        taskId: 't1',
        awardRef: 'test.pack/star',
      ),
    );
    final file = ok(await a.family.send());
    final rows = await builtRows(b.db);
    Future<String?> refused(Uint8List bytes) async =>
        (await b.family.receive(bytes)).fold((f) => f.message, (_) => null);

    expect(await refused(file), notPaired.message);
    // The phone that sent it, opening it again.
    expect(
      (await a.family.receive(file)).fold((f) => f.message, (_) => null),
      unreadable.message,
    );
    expect(ok(await a.family.state()).lastReceived, isNull);
    for (final typed in [
      code.take(5).join(' '),
      [...code.take(5), 'spaceship'].join(' '),
      [...code, code.first].join(' '),
    ]) {
      expect(
        (await b.family.pair(typed)).fold((f) => f.message, (_) => null),
        wrongWords.message,
      );
    }
    expect(ok(await b.family.state()).code, isNull);

    final other = code.map((w) => w == 'tiger' ? 'lion' : 'tiger').toList();
    ok(await b.family.pair(other.join(' ')));
    expect(await refused(file), otherFamily.message);

    ok(await b.family.pair(code.join(' ')));
    expect(
      await refused(Uint8List.sublistView(file, 0, file.length - 30)),
      unreadable.message,
    );
    expect(await refused(Uint8List.fromList([1, 2, 3])), unreadable.message);
    // A zip anyone could make without the words.
    final plain = ZipEncoder().encodeBytes(
      Archive()..add(
        ArchiveFile.string(
          'starbook-family.json',
          jsonEncode({'starbookFamily': 1, 'has': {}, 'events': []}),
        ),
      ),
    );
    expect(b.family.isFamilyFile(plain), isTrue);
    expect(await refused(plain), unreadable.message);
    expect(b.family.isFamilyFile(Uint8List.fromList([1, 2, 3])), isFalse);
    expect(ok(await b.family.state()).lastReceived, isNull);
    final after = await builtRows(b.db);
    expect(after['awards'], rows['awards']);
    expect(after['weeks'], rows['weeks']);

    ok(await b.family.receive(file));
    expect(await b.db.query('awards'), hasLength(1));
  });
}
