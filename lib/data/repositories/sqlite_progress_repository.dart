import 'dart:convert';

import 'package:fpdart/fpdart.dart' show Either, Unit, left, right, unit;
import 'package:sqflite/sqflite.dart';

import '../../domain/failure.dart';
import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';
import '../../domain/repositories.dart';
import '../db/store_db.dart';
import '../pack/pack_parser.dart';

class SqliteProgressRepository implements ProgressRepository {
  SqliteProgressRepository(this._db, this._packs, {this._now = DateTime.now});

  final Database _db;
  final PackRepository _packs;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, Week?>> currentWeek() => guard(() async {
    final start = mondayOf(_now()).toIso8601String().substring(0, 10);
    var rows = await _db.query(
      'weeks',
      where: 'week_start = ?',
      whereArgs: [start],
    );
    if (rows.isEmpty) {
      final active = await _activeSheet();
      if (active == null) return right(null);
      final (pack, sheet) = active;
      final packRows = await _db.query(
        'packs',
        columns: ['json'],
        where: 'id = ?',
        whereArgs: [pack.id],
      );
      final sheets =
          (jsonDecode(packRows.single['json'] as String) as Map)['sheets']
              as List;
      await _db.insert('weeks', {
        'week_start': start,
        'sheet_ref': '${pack.id}/${sheet.id}',
        'sheet_json': jsonEncode(
          sheets.firstWhere((s) => (s as Map)['id'] == sheet.id),
        ),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      rows = await _db.query(
        'weeks',
        where: 'week_start = ?',
        whereArgs: [start],
      );
    }
    return right(_week(rows.single));
  });

  @override
  Future<Either<Failure, List<GivenAward>>> awardsFor(int weekId) =>
      guard(() async {
        final rows = await _db.query(
          'awards',
          where: 'week_id = ?',
          whereArgs: [weekId],
          orderBy: 'id',
        );
        return right([for (final r in rows) _givenAward(r)]);
      });

  @override
  Future<Either<Failure, GivenAward>> give({
    required int weekId,
    required Weekday weekday,
    required String taskId,
    required String awardRef,
    int? replaces,
  }) => guard(
    () => _db.transaction((txn) async {
      final award = [
        for (final p in _packs.installed)
          for (final a in p.awards)
            if ('${p.id}/${a.id}' == awardRef) a,
      ].firstOrNull;
      if (award == null) {
        return left(const Failure('that award is not installed'));
      }
      final weekRows = await txn.query(
        'weeks',
        columns: ['sheet_json'],
        where: 'id = ?',
        whereArgs: [weekId],
      );
      if (weekRows.isEmpty) {
        return left(const Failure('that week does not exist'));
      }
      final sheet = parseSheet(weekRows.single['sheet_json'] as String);
      final days = sheet.days.where((d) => d.weekday == weekday);
      final tasks = [
        for (final d in days) ...[...d.tasks, ...sheet.everyDay],
      ];
      if (!tasks.any((t) => t.id == taskId)) {
        return left(
          const Failure('that task is not on the sheet for that day'),
        );
      }
      if (replaces != null) {
        await txn.update(
          'awards',
          {'undone_at': _now().millisecondsSinceEpoch},
          where:
              'id = ? AND week_id = ? AND weekday = ? AND task_id = ? '
              'AND undone_at IS NULL',
          whereArgs: [replaces, weekId, weekday.name, taskId],
        );
      }
      String? sticker;
      if (award.kind == AwardKind.sticker) {
        final album = await txn.query(
          'awards',
          columns: ['sticker'],
          where: 'undone_at IS NULL AND sticker IS NOT NULL',
        );
        sticker = nextSticker(award.stickers, [
          for (final r in album) r['sticker'] as String,
        ]);
      }
      final givenAt = _now();
      final id = await txn.insert('awards', {
        'week_id': weekId,
        'weekday': weekday.name,
        'task_id': taskId,
        'award_ref': awardRef,
        'stars': award.stars,
        'sticker': sticker,
        'given_at': givenAt.millisecondsSinceEpoch,
      });
      await _checkMilestones(txn);
      return right(
        GivenAward(
          id: id,
          weekId: weekId,
          weekday: weekday,
          taskId: taskId,
          awardRef: awardRef,
          stars: award.stars,
          sticker: sticker,
          givenAt: givenAt,
        ),
      );
    }),
  );

  @override
  Future<Either<Failure, Unit>> undo(int awardId, {int? restore}) => guard(
    () => _db.transaction((txn) async {
      final changed = await txn.update(
        'awards',
        {'undone_at': _now().millisecondsSinceEpoch},
        where: 'id = ? AND undone_at IS NULL',
        whereArgs: [awardId],
      );
      if (changed == 0) {
        return left(const Failure('there is no award to undo with that id'));
      }
      if (restore != null) {
        await txn.update(
          'awards',
          {'undone_at': null},
          where: 'id = ? AND undone_at IS NOT NULL',
          whereArgs: [restore],
        );
        await _checkMilestones(txn);
      }
      return right(unit);
    }),
  );

  @override
  Future<Either<Failure, Unit>> setSpecialReward(int weekId, String text) =>
      guard(() async {
        final trimmed = text.trim();
        await _db.update(
          'weeks',
          {'special_reward': trimmed.isEmpty ? null : trimmed},
          where: 'id = ?',
          whereArgs: [weekId],
        );
        return right(unit);
      });

  @override
  Future<Either<Failure, Unit>> finish(BookKind kind, String ref) =>
      guard(() async {
        await _db.transaction((txn) async {
          await txn.insert('finished', {
            'kind': kind.name,
            'ref': ref,
            'finished_at': _now().millisecondsSinceEpoch,
          });
          await _checkMilestones(txn);
        });
        return right(unit);
      });

  @override
  Future<Either<Failure, Counters>> counters() =>
      guard(() async => right(await _counters(_db)));

  @override
  Future<Either<Failure, List<Trophy>>> trophies() => guard(() async {
    final rows = await _db.query(
      'trophies',
      orderBy: 'earned_at, milestone_ref',
    );
    return right([
      for (final r in rows)
        Trophy(
          milestoneRef: r['milestone_ref'] as String,
          earnedAt: DateTime.fromMillisecondsSinceEpoch(r['earned_at'] as int),
        ),
    ]);
  });

  @override
  Future<Either<Failure, Child?>> child() => guard(() async {
    final rows = await _db.query('child', where: 'id = 1');
    if (rows.isEmpty) return right(null);
    return right(
      Child(
        name: rows.single['name'] as String?,
        picture: rows.single['picture'] as String?,
      ),
    );
  });

  @override
  Future<Either<Failure, Set<int>>> takeUnseen(int weekId) => guard(
    () => _db.transaction((txn) async {
      final seen = await txn.query('settings', where: "key = 'seenAward'");
      final after = seen.isEmpty
          ? 0
          : int.parse(seen.single['value'] as String);
      final rows = await txn.query(
        'awards',
        columns: ['id'],
        where: 'week_id = ? AND undone_at IS NULL AND id > ?',
        whereArgs: [weekId, after],
      );
      final newest = Sqflite.firstIntValue(
        await txn.rawQuery('SELECT MAX(id) FROM awards'),
      );
      if (newest != null) {
        await txn.insert('settings', {
          'key': 'seenAward',
          'value': '$newest',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return right({for (final r in rows) r['id'] as int});
    }),
  );

  @override
  Future<Either<Failure, List<String>>> album() => guard(() async {
    final rows = await _db.query(
      'awards',
      columns: ['sticker'],
      where: 'undone_at IS NULL AND sticker IS NOT NULL',
      orderBy: 'id DESC',
    );
    return right([for (final r in rows) r['sticker'] as String]);
  });

  @override
  Future<Either<Failure, Moments>> takeMoments(int weekId) => guard(
    () => _db.transaction((txn) async {
      final weekRows = await txn.query(
        'weeks',
        where: 'id = ?',
        whereArgs: [weekId],
      );
      if (weekRows.isEmpty) {
        return left(const Failure('that week does not exist'));
      }
      final week = _week(weekRows.single);
      final awards = [
        for (final r in await txn.query(
          'awards',
          where: 'week_id = ? AND undone_at IS NULL',
          whereArgs: [weekId],
        ))
          _givenAward(r),
      ];
      final seenWeek = await _setting(txn, 'seenWeek');
      final done = weekDone(week.sheet, awards) && seenWeek != '$weekId';
      if (done) await _putSetting(txn, 'seenWeek', '$weekId');

      final stored = await _setting(txn, 'seenTrophies');
      final seen = <String>{
        if (stored != null) ...(jsonDecode(stored) as List).cast<String>(),
      };
      final refs = [
        for (final r in await txn.query(
          'trophies',
          columns: ['milestone_ref'],
          orderBy: 'earned_at DESC, rowid DESC',
        ))
          r['milestone_ref'] as String,
      ];
      final trophy = refs.where((r) => !seen.contains(r)).firstOrNull;
      if (trophy != null) {
        await _putSetting(
          txn,
          'seenTrophies',
          jsonEncode({...seen, ...refs}.toList()),
        );
      }
      return right((weekDone: done, trophy: trophy));
    }),
  );

  @override
  Future<Either<Failure, Set<String>>> ticksToday() => guard(() async {
    final rows = await _db.query(
      'habit_ticks',
      columns: ['habit_id'],
      where: 'day = ?',
      whereArgs: [_day(_now())],
    );
    return right({for (final r in rows) r['habit_id'] as String});
  });

  @override
  Future<Either<Failure, bool>> tickHabit(int weekId, String habitId) => guard(
    () => _db.transaction((txn) async {
      final weekRows = await txn.query(
        'weeks',
        where: 'id = ?',
        whereArgs: [weekId],
      );
      if (weekRows.isEmpty) {
        return left(const Failure('that week does not exist'));
      }
      final week = _week(weekRows.single);
      if (mondayOf(_now()) != week.start) {
        return left(const Failure('that week is over'));
      }
      if (!week.sheet.habits.any((h) => h.id == habitId)) {
        return left(const Failure('that habit is not on the sheet'));
      }
      final today = _day(_now());
      final ticked = await txn.query(
        'habit_ticks',
        where: 'day = ? AND habit_id = ?',
        whereArgs: [today, habitId],
      );
      if (ticked.isNotEmpty) return right(false);
      await txn.insert('habit_ticks', {'day': today, 'habit_id': habitId});
      final s = week.start;
      final days =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM habit_ticks '
              'WHERE habit_id = ? AND day >= ? AND day <= ?',
              [habitId, _day(s), _day(DateTime(s.year, s.month, s.day + 6))],
            ),
          ) ??
          0;
      if (days == 7) {
        await txn.insert('trophies', {
          'milestone_ref': '${week.sheetRef}/$habitId',
          'earned_at': _now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      return right(true);
    }),
  );

  @override
  Future<Either<Failure, Unit>> undoHabit(String habitId) => guard(() async {
    final removed = await _db.delete(
      'habit_ticks',
      where: 'day = ? AND habit_id = ?',
      whereArgs: [_day(_now()), habitId],
    );
    if (removed == 0) {
      return left(const Failure('there is no tick to undo today'));
    }
    return right(unit);
  });

  String _day(DateTime t) => t.toIso8601String().substring(0, 10);

  Future<String?> _setting(DatabaseExecutor e, String key) async {
    final rows = await e.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  Future<void> _putSetting(Transaction txn, String key, String value) =>
      txn.insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<Either<Failure, String?>> activeSheet() => guard(() async {
    final active = await _activeSheet();
    return right(active == null ? null : '${active.$1.id}/${active.$2.id}');
  });

  @override
  Future<Either<Failure, Unit>> setActiveSheet(String ref) => guard(() async {
    await _db.insert('settings', {
      'key': 'activeSheet',
      'value': ref,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return right(unit);
  });

  /// The sheet named by the `activeSheet` setting, else the first installed one.
  Future<(Pack, Sheet)?> _activeSheet() async {
    final rows = await _db.query('settings', where: "key = 'activeSheet'");
    final wanted = rows.isEmpty ? null : rows.single['value'];
    final all = [
      for (final p in _packs.installed)
        for (final s in p.sheets) (p, s),
    ];
    return all.where((e) => '${e.$1.id}/${e.$2.id}' == wanted).firstOrNull ??
        all.firstOrNull;
  }

  Week _week(Map<String, Object?> row) => Week(
    id: row['id'] as int,
    start: DateTime.parse(row['week_start'] as String),
    sheetRef: row['sheet_ref'] as String,
    sheet: parseSheet(row['sheet_json'] as String),
    specialReward: row['special_reward'] as String?,
  );

  GivenAward _givenAward(Map<String, Object?> row) => GivenAward(
    id: row['id'] as int,
    weekId: row['week_id'] as int,
    weekday: Weekday.values.byName(row['weekday'] as String),
    taskId: row['task_id'] as String,
    awardRef: row['award_ref'] as String,
    stars: row['stars'] as int,
    sticker: row['sticker'] as String?,
    givenAt: DateTime.fromMillisecondsSinceEpoch(row['given_at'] as int),
    undoneAt: row['undone_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['undone_at'] as int),
  );

  Future<Counters> _counters(DatabaseExecutor e) async {
    final live = [
      for (final r in await e.query('awards', where: 'undone_at IS NULL'))
        _givenAward(r),
    ];
    var daysDone = 0;
    var weeksDone = 0;
    for (final row in await e.query('weeks')) {
      final week = _week(row);
      final awards = live.where((a) => a.weekId == week.id).toList();
      daysDone += week.sheet.days
          .where((d) => dayDone(week.sheet, d, awards))
          .length;
      if (weekDone(week.sheet, awards)) weeksDone++;
    }
    Future<int> distinct(BookKind kind) async =>
        Sqflite.firstIntValue(
          await e.rawQuery(
            'SELECT COUNT(DISTINCT ref) FROM finished WHERE kind = ?',
            [kind.name],
          ),
        ) ??
        0;
    return Counters(
      stars: live.fold(0, (sum, a) => sum + a.stars),
      stickers: live.where((a) => a.sticker != null).length,
      daysDone: daysDone,
      weeksDone: weeksDone,
      wordbooksDone: await distinct(BookKind.wordbook),
      storiesRead: await distinct(BookKind.story),
    );
  }

  Future<void> _checkMilestones(Transaction txn) async {
    final reached = reachedMilestones(_packs.installed, await _counters(txn));
    for (final ref in reached) {
      await txn.insert('trophies', {
        'milestone_ref': ref,
        'earned_at': _now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
