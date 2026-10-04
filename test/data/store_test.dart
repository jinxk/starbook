import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:starbook/data/db/store_db.dart';
import 'package:starbook/data/repositories/sqlite_backup_repository.dart';
import 'package:starbook/data/repositories/sqlite_pack_repository.dart';
import 'package:starbook/data/repositories/sqlite_progress_repository.dart';
import 'package:starbook/data/repositories/sqlite_voice_repository.dart';
import 'package:starbook/domain/failure.dart';
import 'package:starbook/domain/pack/pack.dart';
import 'package:starbook/domain/progress/progress.dart';
import 'package:starbook/domain/repositories.dart';

String packJson({
  String id = 'test.pack',
  Object revision = 1,
  String firstTask = 'Write A',
}) => jsonEncode({
  'starbook': 1,
  'id': id,
  'revision': revision,
  'title': 'Test',
  'sheets': [
    {
      'id': 'week',
      'title': 'Week',
      'days': [
        {
          'weekday': 'monday',
          'title': 'Mon',
          'tasks': [
            {'id': 't1', 'text': firstTask},
            {'id': 't2', 'text': 'Count'},
          ],
        },
      ],
      'everyDay': [
        {'id': 'e1', 'text': 'Read'},
      ],
      'habits': [
        {'id': 'teeth', 'text': 'Brush', 'picture': 'toothbrush'},
      ],
    },
  ],
  'awards': [
    {'id': 'star', 'kind': 'star', 'label': 'Star'},
    {
      'id': 'sticker',
      'kind': 'sticker',
      'label': 'Sticker',
      'stickers': ['lion', 'tiger'],
    },
  ],
  'milestones': [
    for (final m in [
      ('one-star', {'stars': 1}),
      ('two-stars', {'stars': 2}),
      ('one-story', {'storiesRead': 1}),
    ])
      {'id': m.$1, 'title': m.$1, 'trophy': 'star-big', 'when': m.$2},
  ],
});

T ok<T>(Either<Failure, T> result) =>
    result.getOrElse((f) => throw StateError(f.message));

void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = ok(await openStore(databaseFactoryFfi, inMemoryDatabasePath));
  });

  tearDown(() => db.close());

  test('a higher revision replaces, same or lower asks, and a started week '
      'keeps its sheet', () async {
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs);
    Future<Week> week() async => ok(await progress.currentWeek())!;
    String firstTask(Sheet s) => s.days.single.tasks.first.text;

    final noId = jsonEncode((jsonDecode(packJson()) as Map)..remove('id'));
    expect((await packs.install(noId)).isLeft(), isTrue);
    expect(packs.installed, isEmpty);

    expect(await packs.install(packJson()), right(InstallResult.installed));
    final started = await week();
    expect(firstTask(started.sheet), 'Write A');

    final b = packJson(revision: 2, firstTask: 'Write B');
    expect(await packs.install(b), right(InstallResult.installed));
    expect(packs.installed.single.revision, 2);
    expect(firstTask((await week()).sheet), 'Write A');

    final c = packJson(revision: 2, firstTask: 'Write C');
    expect(await packs.install(c), right(InstallResult.needsConfirm));
    expect(await packs.install(packJson()), right(InstallResult.needsConfirm));
    expect(firstTask(packs.installed.single.sheets.single), 'Write B');

    expect(
      await packs.install(packJson(), confirmed: true),
      right(InstallResult.installed),
    );
    expect(packs.installed.single.revision, 1);

    expect((await packs.remove('test.pack')).isRight(), isTrue);
    expect(packs.installed, isEmpty);
    final after = await week();
    expect(after.id, started.id);
    expect(firstTask(after.sheet), 'Write A');

    expect(
      await packs.install(packJson(revision: 1e19)),
      right(InstallResult.installed),
    );
    final huge = packJson(revision: 2e19);
    expect(await packs.install(huge), right(InstallResult.needsConfirm));
    expect(
      await packs.install(huge, confirmed: true),
      right(InstallResult.installed),
    );
  });

  test('a switched sheet starts with the next week and the week in progress '
      "keeps its own; a removed pack's sheet gives way to the first installed "
      'one', () async {
    var now = DateTime.now();
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, now: () => now);
    await packs.install(packJson(id: 'a'));
    await packs.install(packJson(id: 'b', firstTask: 'Write B'));
    String firstTask(Week w) => w.sheet.days.single.tasks.first.text;

    expect(ok(await progress.activeSheet()), 'a/week');
    final started = ok(await progress.currentWeek())!;
    expect(started.sheetRef, 'a/week');

    ok(await progress.setActiveSheet('b/week'));
    expect(ok(await progress.activeSheet()), 'b/week');
    final same = ok(await progress.currentWeek())!;
    expect(same.id, started.id);
    expect(same.sheetRef, 'a/week');
    expect(firstTask(same), 'Write A');

    now = now.add(const Duration(days: 7));
    final next = ok(await progress.currentWeek())!;
    expect(next.id, isNot(started.id));
    expect(next.sheetRef, 'b/week');
    expect(firstTask(next), 'Write B');

    await packs.remove('b');
    expect(ok(await progress.activeSheet()), 'a/week');
    final kept = ok(await progress.currentWeek())!;
    expect(kept.id, next.id);
    expect(kept.sheetRef, 'b/week');
    expect(firstTask(kept), 'Write B');
  });

  test('a default pack installs once, a removed one stays removed, and a '
      'higher bundled revision replaces it on start', () async {
    final r1 = packJson();
    final r2 = packJson(revision: 2);
    final first = SqlitePackRepository(db);
    expect((await first.start([r1])).isRight(), isTrue);
    expect(first.installed.map((p) => p.id), ['test.pack']);

    await first.remove('test.pack');
    final second = SqlitePackRepository(db);
    await second.start([r1]);
    expect(second.installed, isEmpty);

    await second.start([r1, packJson(id: 'new.pack')]);
    expect(second.installed.map((p) => p.id), ['new.pack']);

    expect(await second.install(r1), right(InstallResult.installed));
    await second.start([r2]);
    expect(second.installed.firstWhere((p) => p.id == 'test.pack').revision, 2);
    await second.start([r1]);
    expect(second.installed.firstWhere((p) => p.id == 'test.pack').revision, 2);
  });

  test('milestones are inserted once and never removed after undo', () async {
    var now = DateTime.now();
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, now: () => now);
    await packs.install(packJson());
    final weekId = ok(await progress.currentWeek())!.id;
    Future<Either<Failure, GivenAward>> give(String task) => progress.give(
      weekId: weekId,
      weekday: Weekday.monday,
      taskId: task,
      awardRef: 'test.pack/star',
    );
    Future<List<(String, DateTime)>> trophies() async => [
      for (final t in ok(await progress.trophies()))
        (t.milestoneRef, t.earnedAt),
    ];

    final first = ok(await give('t1'));
    expect((await trophies()).map((t) => t.$1), ['test.pack/one-star']);
    expect((await give('t1')).isLeft(), isTrue);
    final tuesday = await progress.give(
      weekId: weekId,
      weekday: Weekday.tuesday,
      taskId: 'e1',
      awardRef: 'test.pack/star',
    );
    expect(tuesday.isLeft(), isTrue);

    final second = ok(await give('t2'));
    expect((await trophies()).map((t) => t.$1), [
      'test.pack/one-star',
      'test.pack/two-stars',
    ]);

    final earned = await trophies();
    await progress.undo(first.id);
    await progress.undo(second.id);
    expect(ok(await progress.counters()).stars, 0);
    expect(await trophies(), earned);

    now = now.add(const Duration(minutes: 1));
    ok(await give('t1'));
    expect(await trophies(), earned);

    expect(
      (await progress.finish(BookKind.story, 'x.pack/s')).isRight(),
      isTrue,
    );
    expect(
      (await progress.finish(BookKind.story, 'x.pack/s')).isRight(),
      isTrue,
    );
    expect(ok(await progress.counters()).storiesRead, 1);
    expect(
      (await trophies()).map((t) => t.$1),
      contains('test.pack/one-story'),
    );
  });

  test('a week starts on Monday local time, and a week never opened has no '
      'record', () async {
    final m = mondayOf(DateTime.now());
    DateTime day(int plus, [int hour = 0, int minute = 0]) =>
        DateTime(m.year, m.month, m.day + plus, hour, minute);
    var now = day(0);
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, now: () => now);

    expect(ok(await progress.currentWeek()), isNull);
    await packs.install(packJson());

    now = day(6, 23, 59);
    final a = ok(await progress.currentWeek())!;
    expect(a.start, m);

    now = day(7);
    final b = ok(await progress.currentWeek())!;
    expect(b.id, isNot(a.id));
    expect(b.start, day(7));

    now = day(8, 12);
    expect(ok(await progress.currentWeek())!.id, b.id);

    now = day(21, 9);
    final c = ok(await progress.currentWeek())!;
    expect(c.start, day(21));
    expect(c.id, b.id + 1);
    expect(ok(await progress.counters()).daysDone, 0);
  });

  test('an award is unseen once, stays seen for a new repository on the same '
      'store, and an undone award is never unseen', () async {
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs);
    await packs.install(packJson());
    final weekId = ok(await progress.currentWeek())!.id;
    Future<GivenAward> give(String task) async => ok(
      await progress.give(
        weekId: weekId,
        weekday: Weekday.monday,
        taskId: task,
        awardRef: 'test.pack/star',
      ),
    );

    final first = await give('t1');
    expect(ok(await progress.takeUnseen(weekId)), {first.id});
    expect(ok(await progress.takeUnseen(weekId)), isEmpty);
    expect(
      ok(await SqliteProgressRepository(db, packs).takeUnseen(weekId)),
      isEmpty,
    );

    final undone = await give('t2');
    await progress.undo(undone.id);
    expect(ok(await progress.takeUnseen(weekId)), isEmpty);

    final again = await give('t2');
    expect(ok(await progress.takeUnseen(weekId)), {again.id});
  });

  test('a replacing award undoes the old one in the same write, and undo '
      'brings back that same award, already seen', () async {
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs);
    await packs.install(packJson());
    final weekId = ok(await progress.currentWeek())!.id;
    Future<Either<Failure, GivenAward>> give(String award, {int? replaces}) =>
        progress.give(
          weekId: weekId,
          weekday: Weekday.monday,
          taskId: 't1',
          awardRef: 'test.pack/$award',
          replaces: replaces,
        );
    Future<List<GivenAward>> live() async => [
      for (final a in ok(await progress.awardsFor(weekId)))
        if (a.undoneAt == null) a,
    ];

    final first = ok(await give('star'));
    expect(ok(await progress.takeUnseen(weekId)), {first.id});

    final second = ok(await give('sticker', replaces: first.id));
    expect((await live()).map((a) => a.id), [second.id]);
    expect(second.sticker, 'lion');

    ok(await progress.undo(second.id, restore: first.id));
    final back = await live();
    expect(back.map((a) => a.id), [first.id]);
    expect(back.single.sticker, isNull);
    final counters = ok(await progress.counters());
    expect(counters.stars, 1);
    expect(counters.stickers, 0);
    expect(ok(await progress.takeUnseen(weekId)), isEmpty);
  });

  test('a finished week and the newest new trophy are each taken once, never '
      'again after undo and redo or on a new repository', () async {
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs);
    await packs.install(packJson());
    final weekId = ok(await progress.currentWeek())!.id;
    Future<GivenAward> give(String task) async => ok(
      await progress.give(
        weekId: weekId,
        weekday: Weekday.monday,
        taskId: task,
        awardRef: 'test.pack/star',
      ),
    );
    Future<(bool, String?)> take([SqliteProgressRepository? repo]) async {
      final m = ok(await (repo ?? progress).takeMoments(weekId));
      return (m.weekDone, m.trophy);
    }

    await give('t1');
    await give('t2');
    expect(await take(), (false, 'test.pack/two-stars'));
    expect(await take(), (false, null));

    final last = await give('e1');
    expect(await take(), (true, null));
    await progress.undo(last.id);
    await give('e1');
    expect(await take(), (false, null));
    expect(await take(SqliteProgressRepository(db, packs)), (false, null));
  });

  test('the album lists live stickers newest first; a replaced sticker '
      'leaves it and a restored one comes back in its place', () async {
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs);
    await packs.install(packJson());
    final weekId = ok(await progress.currentWeek())!.id;
    Future<GivenAward> give(String task, String award, {int? replaces}) async =>
        ok(
          await progress.give(
            weekId: weekId,
            weekday: Weekday.monday,
            taskId: task,
            awardRef: 'test.pack/$award',
            replaces: replaces,
          ),
        );
    Future<List<String>> album() async => ok(await progress.album());

    await give('t1', 'sticker');
    final tiger = await give('t2', 'sticker');
    expect(await album(), ['tiger', 'lion']);

    final star = await give('t2', 'star', replaces: tiger.id);
    expect(await album(), ['lion']);

    ok(await progress.undo(star.id, restore: tiger.id));
    expect(await album(), ['tiger', 'lion']);
  });

  test('a habit is ticked once a day; a second tick changes nothing, undo '
      'removes it and it can be ticked again', () async {
    final m = mondayOf(DateTime.now());
    var now = DateTime(m.year, m.month, m.day, 8);
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, now: () => now);
    await packs.install(packJson());
    final weekId = ok(await progress.currentWeek())!.id;

    expect(await progress.tickHabit(weekId, 'teeth'), right(true));
    expect(await progress.tickHabit(weekId, 'teeth'), right(false));
    expect(ok(await progress.ticksToday()), {'teeth'});
    expect((await progress.tickHabit(weekId, 'nope')).isLeft(), isTrue);

    expect((await progress.undoHabit('teeth')).isRight(), isTrue);
    expect(ok(await progress.ticksToday()), isEmpty);
    expect((await progress.undoHabit('teeth')).isLeft(), isTrue);
    expect(await progress.tickHabit(weekId, 'teeth'), right(true));

    now = DateTime(m.year, m.month, m.day + 1, 8);
    expect(ok(await progress.ticksToday()), isEmpty);
  });

  test('seven days of one week earn the habit trophy once; undo keeps it, and '
      'habit ticks reach no counter or milestone', () async {
    final m = mondayOf(DateTime.now());
    DateTime day(int i) => DateTime(m.year, m.month, m.day + i, 8);
    var now = day(0);
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, now: () => now);
    await packs.install(packJson());
    final weekId = ok(await progress.currentWeek())!.id;
    Future<List<String>> refs() async => [
      for (final t in ok(await progress.trophies())) t.milestoneRef,
    ];

    for (var i = 0; i < 7; i++) {
      now = day(i);
      expect(await progress.tickHabit(weekId, 'teeth'), right(true));
      if (i == 5) expect(await refs(), isNot(contains('test.pack/week/teeth')));
    }
    expect(await refs(), ['test.pack/week/teeth']);

    final counters = ok(await progress.counters());
    expect((counters.stars, counters.daysDone, counters.weeksDone), (0, 0, 0));
    final moments = ok(await progress.takeMoments(weekId));
    expect((moments.weekDone, moments.trophy), (false, 'test.pack/week/teeth'));

    ok(await progress.undoHabit('teeth'));
    expect(await progress.tickHabit(weekId, 'teeth'), right(true));
    expect(await refs(), ['test.pack/week/teeth']);

    now = day(7);
    expect((await progress.tickHabit(weekId, 'teeth')).isLeft(), isTrue);
  });

  test('a week edit changes this week only: the new text, an added task and a '
      "removed task's award stay in this week, a day keeps one task that is "
      'not a bonus, a done day takes no new task, and next week starts from '
      'the sheet as imported', () async {
    var now = mondayOf(DateTime.now());
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, now: () => now);
    await packs.install(packJson());
    final week = ok(await progress.currentWeek())!;
    Future<GivenAward> star(String task) async => ok(
      await progress.give(
        weekId: week.id,
        weekday: Weekday.monday,
        taskId: task,
        awardRef: 'test.pack/star',
      ),
    );
    Future<Week> current() async => ok(await progress.currentWeek())!;
    Future<List<String>> monday() async => [
      for (final t in (await current()).sheet.days.single.tasks) t.text,
    ];

    await star('t2');
    ok(await progress.editTask(week.id, 't1', ' Write B '));
    ok(await progress.addTask(week.id, Weekday.monday, 'Draw'));
    ok(await progress.removeTask(week.id, 't2'));
    expect((await current()).id, week.id);
    expect(await monday(), ['Write B', 'Draw']);
    expect(ok(await progress.counters()).stars, 1);

    expect(
      (await progress.addTask(week.id, Weekday.monday, '  ')).isLeft(),
      isTrue,
    );
    expect((await progress.removeTask(week.id, 'e1')).isRight(), isTrue);
    expect((await progress.removeTask(week.id, 't1')).isRight(), isTrue);
    final added = (await current()).sheet.days.single.tasks.single.id;
    expect((await progress.removeTask(week.id, added)).isLeft(), isTrue);

    await star(added);
    expect(
      (await progress.addTask(week.id, Weekday.monday, 'More')).isLeft(),
      isTrue,
    );

    now = now.add(const Duration(days: 7));
    final next = await current();
    expect(next.id, isNot(week.id));
    expect(await monday(), ['Write A', 'Count']);
    expect([for (final t in next.sheet.everyDay) t.text], ['Read']);
  });

  test(
    'a backup restores every table into another store, with habit ticks, '
    'the active voice and settings, and replaces what that store had',
    () async {
      final dir = await Directory.systemTemp.createTemp('starbook_backup');
      addTearDown(() => dir.delete(recursive: true));
      final packs = SqlitePackRepository(db);
      final progress = SqliteProgressRepository(db, packs);
      final backup = SqliteBackupRepository(
        db,
        packs,
        SqliteVoiceRepository(db, dir.path),
      );
      ok(await packs.start(const []));
      await packs.install(packJson());
      final week = ok(await progress.currentWeek())!;
      for (final (task, award) in [('t2', 'star'), ('t1', 'sticker')]) {
        ok(
          await progress.give(
            weekId: week.id,
            weekday: Weekday.monday,
            taskId: task,
            awardRef: 'test.pack/$award',
          ),
        );
      }
      ok(await progress.tickHabit(week.id, 'teeth'));
      ok(await progress.setChild(const Child(name: 'Asha', picture: 'lion')));
      ok(await progress.editTask(week.id, 't1', 'Write B'));
      ok(await progress.setActiveSheet('test.pack/week'));
      await db.insert('settings', {'key': 'activeVoice', 'value': '["b"]'});
      ok(await progress.setPrefs((sound: false, slowReading: true)));
      final json = ok(await backup.export());

      final dbB = ok(
        await openStore(
          databaseFactoryFfi,
          '${dir.path}${Platform.pathSeparator}b.db',
        ),
      );
      addTearDown(() async {
        if (dbB.isOpen) await dbB.close();
      });
      final packsB = SqlitePackRepository(dbB);
      await packsB.install(packJson(id: 'other'));
      final progressB = SqliteProgressRepository(dbB, packsB);
      ok(await progressB.setChild(const Child(name: 'Bo')));
      final backupB = SqliteBackupRepository(
        dbB,
        packsB,
        SqliteVoiceRepository(dbB, dir.path),
      );

      final info = ok(backupB.check(json));
      expect((info.child, info.stars, info.packs), ('Asha', 2, 1));
      ok(await backupB.restore(json));
      for (final table in [
        'packs',
        'child',
        'weeks',
        'awards',
        'trophies',
        'finished',
        'habit_ticks',
        'settings',
      ]) {
        // start rewrites defaultsOffered, which moves its rowid.
        final order = table == 'settings' ? 'key' : 'rowid';
        expect(
          await dbB.query(table, orderBy: order),
          await db.query(table, orderBy: order),
          reason: table,
        );
      }
      expect(packsB.installed.map((p) => p.id), ['test.pack']);
      expect(ok(await progressB.prefs()), (sound: false, slowReading: true));
    },
  );

  test('a refused restore changes nothing: not a backup, a newer backup, and '
      'a backup that fails part way; wrong types are refused', () async {
    final dir = await Directory.systemTemp.createTemp('starbook_backup');
    addTearDown(() => dir.delete(recursive: true));
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs);
    final backup = SqliteBackupRepository(
      db,
      packs,
      SqliteVoiceRepository(db, dir.path),
    );
    await packs.install(packJson());
    final week = ok(await progress.currentWeek())!;
    ok(
      await progress.give(
        weekId: week.id,
        weekday: Weekday.monday,
        taskId: 't1',
        awardRef: 'test.pack/star',
      ),
    );
    ok(await progress.tickHabit(week.id, 'teeth'));
    ok(await progress.setChild(const Child(name: 'Asha')));
    const tables = [
      'packs',
      'child',
      'weeks',
      'awards',
      'trophies',
      'finished',
      'habit_ticks',
      'settings',
    ];
    Future<List<Object>> snapshot() async => [
      for (final t in tables) await db.query(t, orderBy: 'rowid'),
    ];
    String? why(Either<Failure, Object?> r) =>
        r.fold((f) => f.message, (_) => null);

    final before = await snapshot();
    final installed = packs.installed.map((p) => p.id).toList();
    final broken =
        jsonDecode(ok(await backup.export())) as Map<String, dynamic>;
    // The same id twice: the second insert fails after the deletes.
    final awards = broken['awards'] as List;
    awards.add(Map<String, Object?>.from(awards.single as Map));

    expect(
      await backup.restore('nope').then(why),
      'the file is not a Starbook backup',
    );
    expect(
      await backup.restore('{"starbookBackup": 99}').then(why),
      'the backup is from a newer Starbook',
    );
    expect(
      await backup.restore(jsonEncode(broken)).then(why),
      'the backup is damaged',
    );
    final missing =
        jsonDecode(ok(await backup.export())) as Map<String, dynamic>;
    missing.remove('habit_ticks');
    expect(
      await backup.restore(jsonEncode(missing)).then(why),
      'the backup is damaged',
    );
    for (final (column, value) in [('stars', '1'), ('weekday', 'funday')]) {
      final typed =
          jsonDecode(ok(await backup.export())) as Map<String, dynamic>;
      ((typed['awards'] as List).single as Map)[column] = value;
      final text = jsonEncode(typed);
      expect(why(backup.check(text)), 'the backup is damaged', reason: column);
      expect(
        await backup.restore(text).then(why),
        'the backup is damaged',
        reason: column,
      );
    }
    for (final (key, value) in [
      ('seenAward', 'abc'),
      ('seenTrophies', '{"a":1}'),
      ('defaultsOffered', '[1]'),
    ]) {
      final bad = jsonDecode(ok(await backup.export())) as Map<String, dynamic>;
      (bad['settings'] as List).add({'key': key, 'value': value});
      final text = jsonEncode(bad);
      expect(why(backup.check(text)), 'the backup is damaged', reason: key);
      expect(
        await backup.restore(text).then(why),
        'the backup is damaged',
        reason: key,
      );
    }
    expect(await snapshot(), before);
    expect(packs.installed.map((p) => p.id), installed);
  });

  test('a version 1 store upgrades to version 2 and keeps its data', () async {
    final dir = await Directory.systemTemp.createTemp('starbook_store');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}store.db';

    final old = ok(await openStore(databaseFactoryFfi, path));
    // A version 1 store is today's store without habit_ticks.
    await old.execute('DROP TABLE habit_ticks');
    await old.setVersion(1);
    final packs = SqlitePackRepository(old);
    final progress = SqliteProgressRepository(old, packs);
    await packs.install(packJson());
    final weekId = ok(await progress.currentWeek())!.id;
    ok(
      await progress.give(
        weekId: weekId,
        weekday: Weekday.monday,
        taskId: 't1',
        awardRef: 'test.pack/star',
      ),
    );
    await old.close();

    final upgraded = ok(await openStore(databaseFactoryFfi, path));
    addTearDown(() async {
      if (upgraded.isOpen) await upgraded.close();
    });
    expect(await upgraded.getVersion(), 2);
    for (final table in ['packs', 'weeks', 'awards']) {
      expect(await upgraded.query(table), hasLength(1));
    }
    expect(
      await upgraded.insert('habit_ticks', {
        'day': '2026-01-05',
        'habit_id': 'teeth',
      }),
      isNonZero,
    );
    await upgraded.close();
  });
}
