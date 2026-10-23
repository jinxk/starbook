import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
import 'package:starbook/presentation/child/trophy_room_screen.dart';

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
        {'id': 'bath', 'text': 'Bath', 'picture': 'soap'},
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
    {'id': 'surprise', 'kind': 'sticker', 'label': 'Surprise'},
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

class _First extends Fake implements Random {
  @override
  int nextInt(int max) => 0;
}

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

  test(
    "a fresh install starts the sample pack's Little learner week",
    () async {
      final packs = SqlitePackRepository(db);
      final progress = SqliteProgressRepository(db, packs);
      await packs.start([File('packs/sample-week.json').readAsStringSync()]);

      expect(
        ok(await progress.activeSheet()),
        'starbook.sample-week/little-learner',
      );
      expect(
        ok(await progress.currentWeek())!.sheetRef,
        'starbook.sample-week/little-learner',
      );
    },
  );

  test('after the sample pack update a phone with weeks keeps the school '
      'sheet until the parent picks, and a habit trophy stays one across '
      'both sheets', () async {
    final text = File('packs/sample-week.json').readAsStringSync();
    final old = jsonDecode(text) as Map<String, dynamic>
      ..['revision'] = 4
      ..['sheets'] = [
        for (final s in (jsonDecode(text) as Map)['sheets'] as List)
          if ((s as Map)['id'] != 'little-learner') s,
      ];
    final m = mondayOf(DateTime.now());
    DateTime day(int i) => DateTime(m.year, m.month, m.day + i, 8);
    var now = day(0);
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, now: () => now);
    Future<void> tickFive(int from) async {
      final weekId = ok(await progress.currentWeek())!.id;
      for (var i = from; i < from + 5; i++) {
        now = day(i);
        ok(await progress.tickHabit(weekId, 'teeth-morning'));
      }
    }

    await packs.start([jsonEncode(old)]);
    final first = ok(await progress.currentWeek())!;
    expect(first.sheetRef, 'starbook.sample-week/superstar-week');
    await tickFive(0);
    final earned = ok(await progress.trophies()).single;

    await packs.start([text]);
    expect(ok(await progress.currentWeek())!.id, first.id);
    now = day(7);
    final second = ok(await progress.currentWeek())!;
    expect(second.id, isNot(first.id));
    expect(second.sheetRef, 'starbook.sample-week/superstar-week');
    expect(
      ok(await progress.activeSheet()),
      'starbook.sample-week/superstar-week',
    );

    ok(await progress.setActiveSheet('starbook.sample-week/little-learner'));
    now = day(14);
    expect(
      ok(await progress.currentWeek())!.sheetRef,
      'starbook.sample-week/little-learner',
    );
    await tickFive(14);
    final rows = ok(await progress.trophies());
    expect(rows.single.milestoneRef, earned.milestoneRef);
    expect(rows.single.earnedAt, earned.earnedAt);

    final teeth = shelfOf(
      packs.installed,
    ).where((t) => t.ref.endsWith('/teeth-morning'));
    expect(teeth, hasLength(1));
    expect(trophyKey(teeth.single.ref), trophyKey(rows.single.milestoneRef));
    expect(
      trophyKey('starbook.sample-week/superstar-week/bath'),
      isNot('starbook.sample-week/bath'),
    );
  });

  test('after the habits update a trophy for a habit the Little learner week '
      'dropped still shows, and the four new habits start with the next '
      'week', () async {
    final text = File('packs/sample-week.json').readAsStringSync();
    final old = jsonDecode(text) as Map<String, dynamic>;
    final sheets = old['sheets'] as List;
    old['revision'] = 7;
    (sheets[0] as Map)['habits'] = (sheets[1] as Map)['habits'];
    old['awards'] = [
      {'id': 'star', 'kind': 'star', 'label': 'Star'},
      {'id': 'sticker', 'kind': 'sticker', 'label': 'Sticker'},
    ];
    final m = mondayOf(DateTime.now());
    DateTime day(int i) => DateTime(m.year, m.month, m.day + i, 8);
    var now = day(0);
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, now: () => now);

    await packs.start([jsonEncode(old)]);
    final first = ok(await progress.currentWeek())!;
    expect(first.sheetRef, 'starbook.sample-week/little-learner');
    final star = ok(
      await progress.give(
        weekId: first.id,
        weekday: Weekday.monday,
        taskId: 'mon-name',
        awardRef: 'starbook.sample-week/star',
      ),
    );
    final sticker = ok(
      await progress.give(
        weekId: first.id,
        weekday: Weekday.monday,
        taskId: 'mon-count',
        awardRef: 'starbook.sample-week/sticker',
      ),
    );
    for (var i = 0; i < 5; i++) {
      now = day(i);
      ok(await progress.tickHabit(first.id, 'lunch'));
    }
    final earned = ok(await progress.trophies()).single;

    await packs.start([text]);
    final running = ok(await progress.currentWeek())!;
    expect(running.id, first.id);
    expect(running.sheet.habits.map((h) => h.id), contains('lunch'));

    now = day(7);
    final next = ok(await progress.currentWeek())!;
    expect(next.sheet.habits.map((h) => h.id).toList(), [
      'teeth-morning',
      'own-hands',
      'toys',
      'teeth-night',
    ]);
    final rows = ok(await progress.trophies());
    expect(rows.single.earnedAt, earned.earnedAt);
    final shelf = shelfOf(packs.installed);
    final lunch = shelf.where(
      (t) => trophyKey(t.ref) == trophyKey(earned.milestoneRef),
    );
    expect(lunch, hasLength(1));

    expect(
      [for (final a in ok(await progress.awardsFor(first.id))) a.id],
      [star.id, sticker.id],
    );
    final counters = ok(await progress.counters());
    expect((counters.stars, counters.stickers), (2, 1));
    expect(ok(await progress.album()), [sticker.sticker]);

    const pack = 'starbook.sample-week';
    expect(
      [
        for (final t in shelf)
          if (t.ref.split('/').length == 3) (t.ref, t.title),
      ],
      [
        (
          '$pack/little-learner/teeth-morning',
          'I brushed my teeth after breakfast',
        ),
        ('$pack/little-learner/own-hands', 'I ate with my own hands'),
        ('$pack/little-learner/toys', 'I put my toys away'),
        ('$pack/little-learner/teeth-night', 'I brushed my teeth before bed'),
        ('$pack/superstar-week/bath', 'I had my bath by myself'),
        (
          '$pack/superstar-week/breakfast',
          'I ate my breakfast with my own hands',
        ),
        ('$pack/superstar-week/lunch', 'I ate my lunch with my own hands'),
        ('$pack/superstar-week/dinner', 'I ate my dinner with my own hands'),
      ],
    );
  });

  test('after the trophy names update a star trophy earned before it keeps '
      'its date and shows its new name', () async {
    final basicsText = File('packs/basics.json').readAsStringSync();
    final sampleText = File('packs/sample-week.json').readAsStringSync();
    final old = jsonDecode(basicsText) as Map<String, dynamic>;
    old['revision'] = 5;
    final first = (old['milestones'] as List).firstWhere(
      (m) => (m as Map)['id'] == 'first-star',
    );
    (first as Map)['title'] = 'First star';
    final m = mondayOf(DateTime.now());
    final now = DateTime(m.year, m.month, m.day, 8);
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, now: () => now);

    await packs.start([jsonEncode(old), sampleText]);
    final week = ok(await progress.currentWeek())!;
    ok(
      await progress.give(
        weekId: week.id,
        weekday: Weekday.monday,
        taskId: 'mon-name',
        awardRef: 'starbook.basics/sticker',
      ),
    );
    final earned = ok(
      await progress.trophies(),
    ).singleWhere((t) => t.milestoneRef == 'starbook.basics/first-star');

    await packs.start([basicsText, sampleText]);

    final rows = ok(await progress.trophies());
    expect(
      rows.singleWhere((t) => t.milestoneRef == earned.milestoneRef).earnedAt,
      earned.earnedAt,
    );
    final shelf = shelfOf(packs.installed);
    const ids = [
      'first-star',
      'ten-stars',
      'twenty-five-stars',
      'fifty-stars',
      'hundred-stars',
    ];
    expect(
      [
        for (final id in ids)
          for (final t in shelf)
            if (t.ref == 'starbook.basics/$id') (t.ref, t.title),
      ],
      [
        ('starbook.basics/first-star', 'First job done'),
        ('starbook.basics/ten-stars', '10 jobs done'),
        ('starbook.basics/twenty-five-stars', '25 jobs done'),
        ('starbook.basics/fifty-stars', '50 jobs done'),
        ('starbook.basics/hundred-stars', '100 jobs done'),
      ],
    );
    expect(
      shelf
          .singleWhere(
            (t) => trophyKey(t.ref) == trophyKey(earned.milestoneRef),
          )
          .title,
      'First job done',
    );
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

  test('a page trophy comes with the award that fills the page, once, and '
      'stays after undo; stickers stored before count, for a child who had '
      'the whole old set', () async {
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, random: _First());
    await packs.install(packJson());
    final weekId = ok(await progress.currentWeek())!.id;
    final friends = stickerPages[5].stickers;
    final stored = [
      for (final p in stickerPages.take(5)) ...p.stickers,
      for (final s in friends)
        if (s != 'paw-prints') s,
      'lion',
    ];
    for (var i = 0; i < stored.length; i++) {
      await db.insert('awards', {
        'week_id': weekId,
        'weekday': 'monday',
        'task_id': 'old-$i',
        'award_ref': 'test.pack/sticker',
        'stars': 0,
        'sticker': stored[i],
        'given_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
    Future<GivenAward> give(String task, String award) async => ok(
      await progress.give(
        weekId: weekId,
        weekday: Weekday.monday,
        taskId: task,
        awardRef: 'test.pack/$award',
      ),
    );
    Future<List<String>> pageTrophies() async => [
      for (final t in ok(await progress.trophies()))
        if (t.milestoneRef == 'sticker-page:animal-friends') t.milestoneRef,
    ];

    await give('t1', 'star');
    expect(await pageTrophies(), isEmpty);

    final last = await give('t2', 'surprise');
    expect(last.sticker, 'paw-prints');
    expect(await pageTrophies(), ['sticker-page:animal-friends']);
    final moments = ok(await progress.takeMoments(weekId));
    expect(moments.trophy, 'sticker-page:animal-friends');

    ok(await progress.undo(last.id));
    expect(await pageTrophies(), ['sticker-page:animal-friends']);
    await give('t2', 'surprise');
    expect(await pageTrophies(), ['sticker-page:animal-friends']);
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
    final m = mondayOf(DateTime.now());
    final now = DateTime(m.year, m.month, m.day, 8);
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, now: () => now);
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
      ok(
        await SqliteProgressRepository(
          db,
          packs,
          now: () => now,
        ).takeUnseen(weekId),
      ),
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
    final m = mondayOf(DateTime.now());
    final now = DateTime(m.year, m.month, m.day, 8);
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(
      db,
      packs,
      now: () => now,
      random: _First(),
    );
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

  test('a day moment is taken once for each week, day and place, and stays '
      'taken after a restart', () async {
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs);
    await packs.install(packJson());
    final weekId = ok(await progress.currentWeek())!.id;
    Future<bool> take(
      SqliteProgressRepository repo,
      Weekday day, {
      required bool home,
    }) async => ok(await repo.takeDayMoment(weekId, day, home: home));

    expect(await take(progress, Weekday.monday, home: true), isTrue);
    expect(await take(progress, Weekday.monday, home: true), isFalse);
    expect(await take(progress, Weekday.monday, home: false), isTrue);
    expect(await take(progress, Weekday.tuesday, home: true), isTrue);

    final again = SqliteProgressRepository(db, packs);
    expect(await take(again, Weekday.monday, home: false), isFalse);
    expect(await take(again, Weekday.tuesday, home: true), isFalse);
  });

  test('the album lists live stickers newest first; a replaced sticker '
      'leaves it and a restored one comes back in its place', () async {
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, random: _First());
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
    expect(ok(await progress.ticksOn(now)), {'teeth'});
    expect((await progress.tickHabit(weekId, 'nope')).isLeft(), isTrue);

    expect((await progress.undoHabit('teeth')).isRight(), isTrue);
    expect(ok(await progress.ticksOn(now)), isEmpty);
    expect((await progress.undoHabit('teeth')).isLeft(), isTrue);
    expect(await progress.tickHabit(weekId, 'teeth'), right(true));

    now = DateTime(m.year, m.month, m.day + 1, 8);
    expect(ok(await progress.ticksOn(now)), isEmpty);
  });

  test(
    'the all-habits sticker comes once a day: only when every habit is '
    'ticked, not again after an untick and re-tick or from a new repository, '
    'kept after an untick, never unseen on home, and again the next day',
    () async {
      final m = mondayOf(DateTime.now());
      var now = DateTime(m.year, m.month, m.day, 8);
      final packs = SqlitePackRepository(db);
      final progress = SqliteProgressRepository(
        db,
        packs,
        now: () => now,
        random: _First(),
      );
      await packs.install(packJson());
      final weekId = ok(await progress.currentWeek())!.id;
      Future<String?> take() async =>
          ok(await progress.takeHabitSticker(weekId));

      ok(await progress.tickHabit(weekId, 'teeth'));
      expect(await take(), isNull);
      ok(await progress.tickHabit(weekId, 'bath'));
      expect(await take(), 'lion');
      expect(ok(await progress.album()), ['lion']);
      expect(ok(await progress.counters()).stars, 0);
      expect(await take(), isNull);

      ok(await progress.undoHabit('bath'));
      expect(ok(await progress.album()), ['lion']);
      ok(await progress.tickHabit(weekId, 'bath'));
      expect(await take(), isNull);
      final again = SqliteProgressRepository(db, packs, now: () => now);
      expect(ok(await again.takeHabitSticker(weekId)), isNull);

      final unseen = ok(await progress.takeUnseen(weekId));
      final rows = await db.query(
        'awards',
        columns: ['id'],
        where: "task_id = 'habits:done'",
      );
      expect(rows, hasLength(1));
      expect(unseen, isNot(contains(rows.single['id'])));

      now = DateTime(m.year, m.month, m.day + 1, 8);
      ok(await progress.tickHabit(weekId, 'teeth'));
      ok(await progress.tickHabit(weekId, 'bath'));
      expect(await take(), 'tiger');
    },
  );

  test('five days of one week earn the habit trophy once; undo keeps it, and '
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

    for (final i in [0, 1, 2, 4]) {
      now = day(i);
      expect(await progress.tickHabit(weekId, 'teeth'), right(true));
    }
    expect(await refs(), isEmpty);

    // A backdated tick on a ticked day counts once, so 4 days stay 4.
    expect(
      await progress.tickHabit(weekId, 'teeth', day: day(1)),
      right(false),
    );
    expect(await refs(), isEmpty);

    // A backdated tick on an unticked day of the same week is the 5th day.
    expect(await progress.tickHabit(weekId, 'teeth', day: day(3)), right(true));
    expect(await refs(), ['test.pack/week/teeth']);
    Future<DateTime> earnedAt() async =>
        ok(await progress.trophies()).single.earnedAt;
    final earned = await earnedAt();

    for (final i in [5, 6]) {
      now = day(i);
      expect(await progress.tickHabit(weekId, 'teeth'), right(true));
    }
    expect(await refs(), ['test.pack/week/teeth']);
    expect(await earnedAt(), earned);

    final counters = ok(await progress.counters());
    expect((counters.stars, counters.daysDone, counters.weeksDone), (0, 0, 0));
    final moments = ok(await progress.takeMoments(weekId));
    expect((moments.weekDone, moments.trophy), (false, 'test.pack/week/teeth'));

    ok(await progress.undoHabit('teeth'));
    expect(await progress.tickHabit(weekId, 'teeth'), right(true));
    expect(await refs(), ['test.pack/week/teeth']);
    expect(await earnedAt(), earned);

    now = day(7);
    expect((await progress.tickHabit(weekId, 'teeth')).isLeft(), isTrue);
  });

  test('a day can be marked from the 6th day back to today and on no other '
      "day, by the store's clock, for a tick, an untick and a give", () async {
    final m = mondayOf(DateTime.now());
    // Days counted from this week's Monday; last week's days are negative.
    DateTime at(int i) => DateTime(m.year, m.month, m.day + i, 8);
    var now = at(-7);
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, now: () => now);
    await packs.install(packJson());
    final w0 = ok(await progress.currentWeek())!;
    now = at(0);
    final w1 = ok(await progress.currentWeek())!;

    now = at(1);
    expect(await progress.tickHabit(w0.id, 'teeth', day: at(-5)), right(true));
    expect(
      (await progress.tickHabit(w0.id, 'teeth', day: at(-6))).isLeft(),
      isTrue,
    );
    expect(
      (await progress.tickHabit(w1.id, 'teeth', day: at(2))).isLeft(),
      isTrue,
    );
    expect(ok(await progress.ticksOn(at(-6))), isEmpty);
    expect(ok(await progress.ticksOn(at(2))), isEmpty);

    now = at(2);
    expect((await progress.undoHabit('teeth', day: at(-5))).isLeft(), isTrue);
    expect(ok(await progress.ticksOn(at(-5))), {'teeth'});

    Future<Either<Failure, GivenAward>> give(String task) => progress.give(
      weekId: w1.id,
      weekday: Weekday.monday,
      taskId: task,
      awardRef: 'test.pack/star',
    );
    now = at(-1);
    expect((await give('t1')).isLeft(), isTrue);
    now = at(6);
    final oldest = ok(await give('t1'));
    now = at(7);
    expect((await give('t2')).isLeft(), isTrue);
    expect((await progress.undo(oldest.id)).isLeft(), isTrue);
    expect(ok(await progress.awardsFor(w1.id)).single.undoneAt, isNull);
  });

  test("a parent tick on a day of last week counts in that week's habit "
      'trophy, Monday to Sunday', () async {
    final m = mondayOf(DateTime.now());
    DateTime at(int i) => DateTime(m.year, m.month, m.day + i, 8);
    var now = at(-7);
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, now: () => now);
    await packs.install(packJson());
    final w0 = ok(await progress.currentWeek())!;
    Future<List<String>> refs() async => [
      for (final t in ok(await progress.trophies())) t.milestoneRef,
    ];

    for (var i = 0; i < 4; i++) {
      now = at(-7 + i);
      ok(await progress.tickHabit(w0.id, 'teeth'));
    }
    now = at(0);
    final w1 = ok(await progress.currentWeek())!;
    ok(await progress.tickHabit(w1.id, 'teeth'));
    expect(await refs(), isEmpty);

    now = at(1);
    expect(await progress.tickHabit(w0.id, 'teeth', day: at(-1)), right(true));
    expect(await refs(), ['test.pack/week/teeth']);
  });

  test('a past-day award never arrives on home, counts like one given that '
      'day, and pays once after an undo and a new give', () async {
    final m = mondayOf(DateTime.now());
    var now = DateTime(m.year, m.month, m.day, 8);
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(
      db,
      packs,
      now: () => now,
      random: _First(),
    );
    await packs.install(packJson());
    final w1 = ok(await progress.currentWeek())!;
    now = DateTime(m.year, m.month, m.day + 1, 8);
    Future<GivenAward> give() async => ok(
      await progress.give(
        weekId: w1.id,
        weekday: Weekday.monday,
        taskId: 't1',
        awardRef: 'test.pack/sticker',
      ),
    );

    final first = await give();
    expect(ok(await progress.takeUnseen(w1.id)), isEmpty);
    ok(await progress.undo(first.id));
    await give();
    expect(ok(await progress.takeUnseen(w1.id)), isEmpty);
    final counters = ok(await progress.counters());
    expect((counters.stars, counters.stickers), (1, 1));
    expect(ok(await progress.album()), hasLength(1));

    now = DateTime(m.year, m.month, m.day, 9);
    final own = ok(
      await progress.give(
        weekId: w1.id,
        weekday: Weekday.monday,
        taskId: 't2',
        awardRef: 'test.pack/star',
      ),
    );
    now = DateTime(m.year, m.month, m.day + 1, 8);
    expect(ok(await progress.takeUnseen(w1.id)), {own.id});
  });

  test("a parent tick that finishes today's habits gives home its All done! "
      "moment once, not again after a restart; a child's own all-done gives "
      'home none, and one left from yesterday does not play', () async {
    final m = mondayOf(DateTime.now());
    DateTime at(int i) => DateTime(m.year, m.month, m.day + i, 8);
    var now = at(0);
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(
      db,
      packs,
      now: () => now,
      random: _First(),
    );
    await packs.install(packJson());
    final w1 = ok(await progress.currentWeek())!;
    ok(await progress.tickHabit(w1.id, 'teeth'));
    ok(await progress.tickHabit(w1.id, 'bath', day: now));
    final sticker = ok(
      await progress.takeHabitSticker(w1.id, day: now, byParent: true),
    );
    expect(sticker, isNotNull);
    expect(ok(await progress.takeMoments(w1.id)).allDone, sticker);
    expect(ok(await progress.takeMoments(w1.id)).allDone, isNull);
    final restarted = SqliteProgressRepository(db, packs, now: () => now);
    expect(ok(await restarted.takeMoments(w1.id)).allDone, isNull);

    now = at(1);
    ok(await progress.tickHabit(w1.id, 'teeth'));
    ok(await progress.tickHabit(w1.id, 'bath'));
    expect(ok(await progress.takeHabitSticker(w1.id)), isNotNull);
    expect(ok(await progress.takeMoments(w1.id)).allDone, isNull);

    now = at(2);
    ok(await progress.tickHabit(w1.id, 'teeth', day: now));
    ok(await progress.tickHabit(w1.id, 'bath', day: now));
    expect(
      ok(await progress.takeHabitSticker(w1.id, day: now, byParent: true)),
      isNotNull,
    );
    now = at(3);
    expect(ok(await progress.takeMoments(w1.id)).allDone, isNull);
  });

  test("a past day's all-habits sticker comes once for that day: not again "
      'after an untick and re-tick, kept after the untick, and no moment on '
      'home', () async {
    final m = mondayOf(DateTime.now());
    final monday = DateTime(m.year, m.month, m.day, 8);
    var now = monday;
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(
      db,
      packs,
      now: () => now,
      random: _First(),
    );
    await packs.install(packJson());
    final w1 = ok(await progress.currentWeek())!;
    now = DateTime(m.year, m.month, m.day + 1, 8);

    ok(await progress.tickHabit(w1.id, 'teeth', day: monday));
    ok(await progress.tickHabit(w1.id, 'bath', day: monday));
    expect(
      ok(await progress.takeHabitSticker(w1.id, day: monday, byParent: true)),
      'lion',
    );
    expect(ok(await progress.takeMoments(w1.id)).allDone, isNull);
    final rows = await db.query('awards', where: "task_id = 'habits:done'");
    expect(rows.single['weekday'], 'monday');

    ok(await progress.undoHabit('bath', day: monday));
    expect(ok(await progress.album()), ['lion']);
    ok(await progress.tickHabit(w1.id, 'bath', day: monday));
    expect(ok(await progress.takeHabitSticker(w1.id, day: monday)), isNull);
    expect(
      await db.query('awards', where: "task_id = 'habits:done'"),
      hasLength(1),
    );
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

  test('a backup restores every table into another store, with habit ticks, '
      'the active voice and settings, and a day\'s all-habits sticker, which '
      'does not come again, and replaces what that store had', () async {
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
    ok(await progress.tickHabit(week.id, 'bath'));
    final habitSticker = ok(await progress.takeHabitSticker(week.id));
    expect(habitSticker, isNotNull);
    ok(await progress.setChild(const Child(name: 'Asha', picture: 'lion')));
    ok(await progress.editTask(week.id, 't1', 'Write B'));
    ok(await progress.addTask(week.id, Weekday.monday, 'Draw'));
    ok(await progress.setActiveSheet('test.pack/week'));
    await db.insert('settings', {'key': 'activeVoice', 'value': '["b"]'});
    // An old row nothing reads; a backup that holds it still restores.
    await db.insert('settings', {'key': 'seenSticker', 'value': 'abc'});
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
    expect(ok(await progressB.takeHabitSticker(week.id)), isNull);
    expect(ok(await progressB.album()), contains(habitSticker));
  });

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
      ('allDoneMoment', 'abc'),
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

  test('a backup whose week sheet fails the pack checks is refused and '
      'nothing is written', () async {
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
    final before = [
      await db.query('weeks', orderBy: 'rowid'),
      await db.query('awards', orderBy: 'rowid'),
    ];

    final bad = jsonDecode(ok(await backup.export())) as Map<String, dynamic>;
    final row = (bad['weeks'] as List).single as Map<String, dynamic>;
    final sheet =
        jsonDecode(row['sheet_json'] as String) as Map<String, dynamic>;
    final day = (sheet['days'] as List).first as Map<String, dynamic>;
    ((day['tasks'] as List).first as Map<String, dynamic>)['tip'] = 'x' * 81;
    row['sheet_json'] = jsonEncode(sheet);
    final text = jsonEncode(bad);

    final check = backup.check(text);
    expect(check.fold((f) => f.message, (_) => null), 'the backup is damaged');
    final restored = await backup.restore(text);
    expect(
      restored.fold((f) => f.message, (_) => null),
      'the backup is damaged',
    );
    expect([
      await db.query('weeks', orderBy: 'rowid'),
      await db.query('awards', orderBy: 'rowid'),
    ], before);
  });

  test('a backup made before a pack update is brought up to the app revision '
      'on restore, so the next week has the new sheet', () async {
    final dir = await Directory.systemTemp.createTemp('starbook_backup');
    addTearDown(() => dir.delete(recursive: true));
    final text = File('packs/sample-week.json').readAsStringSync();
    final old = jsonDecode(text) as Map<String, dynamic>;
    final sheets = old['sheets'] as List;
    old['revision'] = 7;
    (sheets[0] as Map)['habits'] = (sheets[1] as Map)['habits'];
    old['awards'] = [
      {'id': 'star', 'kind': 'star', 'label': 'Star'},
      {'id': 'sticker', 'kind': 'sticker', 'label': 'Sticker'},
    ];
    final m = mondayOf(DateTime.now());
    DateTime day(int i) => DateTime(m.year, m.month, m.day + i, 8);
    var now = day(0);
    final packs = SqlitePackRepository(db);
    final progress = SqliteProgressRepository(db, packs, now: () => now);
    final backup = SqliteBackupRepository(
      db,
      packs,
      SqliteVoiceRepository(db, dir.path),
      defaultPacks: [text],
    );

    await packs.start([jsonEncode(old)]);
    ok(await progress.currentWeek());
    final saved = ok(await backup.export());

    await packs.start([text]);
    ok(await backup.restore(saved));

    final revision = (jsonDecode(text) as Map<String, dynamic>)['revision'];
    expect(
      packs.installed
          .singleWhere((p) => p.id == 'starbook.sample-week')
          .revision,
      revision,
    );
    now = day(7);
    final next = ok(await progress.currentWeek())!;
    expect(next.sheet.habits.map((h) => h.id).toList(), [
      'teeth-morning',
      'own-hands',
      'toys',
      'teeth-night',
    ]);
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
