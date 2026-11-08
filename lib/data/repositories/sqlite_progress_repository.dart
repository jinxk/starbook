import 'dart:convert';
import 'dart:math' show Random;

import 'package:fpdart/fpdart.dart'
    show Either, Left, Right, Unit, left, right, unit;
import 'package:sqflite/sqflite.dart';

import '../../domain/failure.dart';
import '../../domain/pack/pack.dart';
import '../../domain/progress/progress.dart';
import '../../domain/repositories.dart';
import '../db/journal.dart';
import '../db/store_db.dart';
import '../pack/pack_parser.dart';

class SqliteProgressRepository implements ProgressRepository {
  SqliteProgressRepository(
    this._db,
    this._packs, {
    this._now = DateTime.now,
    Random? random,
  }) : _random = random ?? Random();

  final Database _db;
  final PackRepository _packs;
  final DateTime Function() _now;
  final Random _random;

  @override
  Future<Either<Failure, Week?>> currentWeek() => guard(() async {
    final start = mondayOf(_now()).toIso8601String().substring(0, 10);
    var rows = await _db.query(
      'weeks',
      where: 'week_start = ?',
      whereArgs: [start],
    );
    if (rows.isEmpty) {
      final started = await _db.transaction((txn) => _startWeek(txn, start));
      if (!started) return right(null);
      rows = await _db.query(
        'weeks',
        where: 'week_start = ?',
        whereArgs: [start],
      );
    }
    return right(_week(rows.single));
  });

  /// Stores the week of [start]; false when no sheet is installed. A sheet that
  /// the week before used moves on to its next sheet. A sheet the parent picked
  /// since then differs from that week's, so it starts as it is. Only weeks the
  /// app opened are stored, so a gap moves on one sheet and skips none.
  Future<bool> _startWeek(Transaction txn, String start) async {
    final stored = await txn.query(
      'weeks',
      columns: ['id'],
      where: 'week_start = ?',
      whereArgs: [start],
    );
    if (stored.isNotEmpty) return true;
    final active = await _activeSheet(txn);
    if (active == null) return false;
    var (pack, sheet) = active;
    final before = await txn.query(
      'weeks',
      columns: ['sheet_ref'],
      where: 'week_start < ?',
      whereArgs: [start],
      orderBy: 'week_start DESC',
      limit: 1,
    );
    final next = pack.sheets.where((s) => s.id == sheet.next).firstOrNull;
    if (next != null &&
        before.firstOrNull?['sheet_ref'] == '${pack.id}/${sheet.id}') {
      sheet = next;
      await record(txn, 'sheet', {'ref': '${pack.id}/${next.id}'}, _now());
    }
    final packRows = await txn.query(
      'packs',
      columns: ['json'],
      where: 'id = ?',
      whereArgs: [pack.id],
    );
    final sheets =
        (jsonDecode(packRows.single['json'] as String) as Map)['sheets']
            as List;
    await record(txn, 'week', {
      'start': start,
      'sheetRef': '${pack.id}/${sheet.id}',
      'sheet': sheets.firstWhere((s) => (s as Map)['id'] == sheet.id),
    }, _now());
    return true;
  }

  @override
  Future<Either<Failure, Week?>> weekOf(DateTime day) => guard(() async {
    final rows = await _db.query(
      'weeks',
      where: 'week_start = ?',
      whereArgs: [_day(mondayOf(day))],
    );
    return right(rows.isEmpty ? null : _week(rows.single));
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
            if ('${p.id}/${a.id}' == awardRef && !a.retired) a,
      ].firstOrNull;
      if (award == null) {
        return left(const Failure('that award is not installed'));
      }
      final weekRows = await txn.query(
        'weeks',
        columns: ['week_start', 'sheet_json'],
        where: 'id = ?',
        whereArgs: [weekId],
      );
      if (weekRows.isEmpty) {
        return left(const Failure('that week does not exist'));
      }
      final start = DateTime.parse(weekRows.single['week_start'] as String);
      if (!_markable(
        DateTime(start.year, start.month, start.day + weekday.index),
      )) {
        return left(const Failure('that day cannot be marked'));
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
      final replaced = replaces == null
          ? null
          : (await txn.query(
                  'awards',
                  columns: ['event'],
                  where:
                      'id = ? AND week_id = ? AND weekday = ? '
                      'AND task_id = ? AND undone_at IS NULL',
                  whereArgs: [replaces, weekId, weekday.name, taskId],
                )).firstOrNull?['event']
                as String?;
      String? sticker;
      if (award.kind == AwardKind.sticker) {
        sticker = nextSticker(
          award.stickers,
          await _liveStickers(txn, unless: replaced),
          _random,
        );
      }
      final givenAt = _now();
      final event = await record(txn, 'give', {
        'week': weekRows.single['week_start'],
        'day': weekday.name,
        'task': taskId,
        'award': awardRef,
        'stars': award.stars,
        'sticker': sticker,
        'replaces': ?replaced,
      }, givenAt);
      final id = await _awardOf(txn, event);
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
      final rows = await txn.rawQuery(
        'SELECT w.week_start, a.weekday, a.event FROM awards a '
        'JOIN weeks w ON w.id = a.week_id '
        'WHERE a.id = ? AND a.undone_at IS NULL',
        [awardId],
      );
      if (rows.isEmpty) {
        return left(const Failure('there is no award to undo with that id'));
      }
      final start = DateTime.parse(rows.single['week_start'] as String);
      final index = Weekday.values
          .byName(rows.single['weekday'] as String)
          .index;
      if (!_markable(DateTime(start.year, start.month, start.day + index))) {
        return left(const Failure('that day cannot be marked'));
      }
      final restored = restore == null
          ? null
          : (await txn.query(
                  'awards',
                  columns: ['event'],
                  where: 'id = ? AND undone_at IS NOT NULL',
                  whereArgs: [restore],
                )).firstOrNull?['event']
                as String?;
      await record(txn, 'undo', {
        'award': rows.single['event'],
        'restore': ?restored,
      }, _now());
      if (restore != null) await _checkMilestones(txn);
      return right(unit);
    }),
  );

  @override
  Future<Either<Failure, Unit>> setSpecialReward(int weekId, String text) =>
      guard(
        () => _db.transaction((txn) async {
          final trimmed = text.trim();
          final start = await _weekStart(txn, weekId);
          if (start != null) {
            await record(txn, 'reward', {
              'week': start,
              'text': trimmed.isEmpty ? null : trimmed,
            }, _now());
          }
          return right(unit);
        }),
      );

  Future<String?> _weekStart(DatabaseExecutor e, int weekId) async {
    final rows = await e.query(
      'weeks',
      columns: ['week_start'],
      where: 'id = ?',
      whereArgs: [weekId],
    );
    return rows.firstOrNull?['week_start'] as String?;
  }

  @override
  Future<Either<Failure, Unit>> addTask(int weekId, Weekday day, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return _refuse('the task text is empty');
    return _editSheet(weekId, (sheet, live) {
      final parsed = parseSheet(jsonEncode(sheet));
      final listed = parsed.days.where((d) => d.weekday == day).firstOrNull;
      if (listed == null) {
        return left(const Failure('that day is not on the sheet'));
      }
      if (dayDone(parsed, listed, live)) {
        return left(const Failure('that day is done'));
      }
      final taken = {
        for (final t in [
          ...parsed.everyDay,
          for (final d in parsed.days) ...d.tasks,
        ])
          t.id,
      };
      var millis = _now().millisecondsSinceEpoch;
      while (taken.contains('added-$millis')) {
        millis++;
      }
      return right((
        'task-add',
        {'day': day.name, 'id': 'added-$millis', 'text': trimmed},
      ));
    });
  }

  @override
  Future<Either<Failure, Unit>> editTask(
    int weekId,
    String taskId,
    String text,
  ) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return _refuse('the task text is empty');
    return _editSheet(weekId, (sheet, live) {
      final found = taskLists(
        sheet,
      ).any((list) => list.any((t) => (t as Map)['id'] == taskId));
      if (!found) return left(const Failure('that task is not on the sheet'));
      return right(('task-edit', {'task': taskId, 'text': trimmed}));
    });
  }

  @override
  Future<Either<Failure, Unit>> removeTask(int weekId, String taskId) =>
      _editSheet(weekId, (sheet, live) {
        final onlyOwn = _rawList(sheet, 'days').any((d) {
          final tasks = (d['tasks'] as List?) ?? const [];
          return tasks.length == 1 && (tasks.single as Map)['id'] == taskId;
        });
        if (onlyOwn) return left(const Failure('each day keeps one task'));
        if (!removeTaskFrom(sheet, taskId)) {
          return left(const Failure('that task is not on the sheet'));
        }
        final parsed = parseSheet(jsonEncode(sheet));
        final kept = parsed.days.every(
          (d) => [...d.tasks, ...parsed.everyDay].any((t) => !t.bonus),
        );
        if (!kept) return left(const Failure('each day keeps one task'));
        return right(('task-remove', {'task': taskId}));
      });

  Future<Either<Failure, Unit>> _refuse(String reason) =>
      Future.value(left(Failure(reason)));

  List<Map<String, Object?>> _rawList(Map<String, Object?> sheet, String key) =>
      ((sheet[key] as List?) ?? const []).cast<Map<String, Object?>>();

  /// Runs [change] on a copy of this week's sheet with the week's live awards,
  /// in one transaction. A failure is the result and nothing is written; else
  /// the event it returns is recorded.
  Future<Either<Failure, Unit>> _editSheet(
    int weekId,
    Either<Failure, (String, Map<String, Object?>)> Function(
      Map<String, Object?> sheet,
      List<GivenAward> live,
    )
    change,
  ) => guard(
    () => _db.transaction((txn) async {
      final rows = await txn.query(
        'weeks',
        columns: ['week_start', 'sheet_json'],
        where: 'id = ?',
        whereArgs: [weekId],
      );
      if (rows.isEmpty) {
        return left(const Failure('that week does not exist'));
      }
      final sheet =
          jsonDecode(rows.single['sheet_json'] as String)
              as Map<String, Object?>;
      final live = [
        for (final r in await txn.query(
          'awards',
          where: 'week_id = ? AND undone_at IS NULL',
          whereArgs: [weekId],
        ))
          _givenAward(r),
      ];
      switch (change(sheet, live)) {
        case Left(:final value):
          return left(value);
        case Right(value: (final kind, final data)):
          await record(txn, kind, {
            'week': rows.single['week_start'],
            ...data,
          }, _now());
          return right(unit);
      }
    }),
  );

  @override
  Future<Either<Failure, Unit>> setChild(Child child) => guard(
    () => _db.transaction((txn) async {
      final name = child.name?.trim();
      await record(txn, 'child', {
        'name': name == null || name.isEmpty ? null : name,
        'picture': child.picture,
      }, _now());
      return right(unit);
    }),
  );

  @override
  Future<Either<Failure, Prefs>> prefs() => guard(() async {
    final sound = await _setting(_db, 'sound');
    final slow = await _setting(_db, 'slowReading');
    return right((sound: sound != 'false', slowReading: slow == 'true'));
  });

  @override
  Future<Either<Failure, Unit>> setPrefs(Prefs prefs) => guard(
    () => _db.transaction((txn) async {
      await _putSetting(txn, 'sound', '${prefs.sound}');
      await _putSetting(txn, 'slowReading', '${prefs.slowReading}');
      return right(unit);
    }),
  );

  @override
  Future<Either<Failure, Unit>> finish(BookKind kind, String ref) => guard(
    () async {
      await _db.transaction((txn) async {
        await record(txn, 'finished', {'kind': kind.name, 'ref': ref}, _now());
        await _checkMilestones(txn);
      });
      return right(unit);
    },
  );

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
      final weekRows = await txn.query(
        'weeks',
        columns: ['week_start'],
        where: 'id = ?',
        whereArgs: [weekId],
      );
      final rows = await txn.query(
        'awards',
        columns: ['id', 'weekday', 'given_at'],
        where: 'week_id = ? AND undone_at IS NULL AND id > ? AND task_id != ?',
        whereArgs: [weekId, after, habitsDoneTask],
      );
      // An award given for a past day is not news to the child.
      final start = weekRows.isEmpty
          ? null
          : DateTime.parse(weekRows.single['week_start'] as String);
      bool backdated(Map<String, Object?> r) {
        if (start == null) return false;
        final own = DateTime(
          start.year,
          start.month,
          start.day + Weekday.values.byName(r['weekday'] as String).index,
        );
        final given = DateTime.fromMillisecondsSinceEpoch(r['given_at'] as int);
        return DateTime(given.year, given.month, given.day).isAfter(own);
      }

      final newest = Sqflite.firstIntValue(
        await txn.rawQuery('SELECT MAX(id) FROM awards'),
      );
      if (newest != null) {
        await txn.insert('settings', {
          'key': 'seenAward',
          'value': '$newest',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return right({
        for (final r in rows)
          if (!backdated(r)) r['id'] as int,
      });
    }),
  );

  @override
  Future<Either<Failure, List<String>>> album() =>
      guard(() async => right(await _liveStickers(_db)));

  /// Stickers of live awards, newest first, leaving out the award of event
  /// [unless], which the write in progress undoes.
  Future<List<String>> _liveStickers(
    DatabaseExecutor e, {
    String? unless,
  }) async {
    final rows = await e.query(
      'awards',
      columns: ['sticker'],
      where:
          'undone_at IS NULL AND sticker IS NOT NULL'
          '${unless == null ? '' : ' AND event != ?'}',
      whereArgs: [?unless],
      orderBy: 'id DESC',
    );
    return [for (final r in rows) r['sticker'] as String];
  }

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
      String? allDone;
      final waiting = await _setting(txn, 'allDoneMoment');
      if (waiting != null) {
        await txn.delete('settings', where: "key = 'allDoneMoment'");
        final rows = await txn.query(
          'awards',
          columns: ['sticker', 'given_at'],
          where: 'id = ? AND undone_at IS NULL',
          whereArgs: [int.parse(waiting)],
        );
        if (rows.isNotEmpty) {
          final givenAt = DateTime.fromMillisecondsSinceEpoch(
            rows.single['given_at'] as int,
          );
          if (_day(givenAt) == _day(_now())) {
            allDone = rows.single['sticker'] as String?;
          }
        }
      }
      return right((weekDone: done, trophy: trophy, allDone: allDone));
    }),
  );

  /// Writes [mark] to `seenDays`, keeping only week [weekId]'s marks; false
  /// when it is there already.
  Future<Either<Failure, bool>> _takeMark(int weekId, String mark) => guard(
    () => _db.transaction((txn) async {
      final stored = await _setting(txn, 'seenDays');
      final seen = <String>[
        if (stored != null) ...(jsonDecode(stored) as List).cast<String>(),
      ];
      if (seen.contains(mark)) return right(false);
      await _putSetting(
        txn,
        'seenDays',
        jsonEncode([...seen.where((s) => s.startsWith('$weekId/')), mark]),
      );
      return right(true);
    }),
  );

  @override
  Future<Either<Failure, bool>> takeDayMoment(
    int weekId,
    Weekday day, {
    required bool home,
  }) => _takeMark(weekId, '$weekId/${day.name}/${home ? 'home' : 'day'}');

  @override
  Future<Either<Failure, bool>> takeDoneCard(int weekId, Weekday day) =>
      _takeMark(weekId, '$weekId/${day.name}/done');

  @override
  Future<Either<Failure, Set<String>>> ticksOn(DateTime day) => guard(() async {
    final rows = await _db.query(
      'habit_ticks',
      columns: ['habit_id'],
      where: 'day = ?',
      whereArgs: [_day(day)],
    );
    return right({for (final r in rows) r['habit_id'] as String});
  });

  @override
  Future<Either<Failure, bool>> tickHabit(
    int weekId,
    String habitId, {
    DateTime? day,
  }) => guard(
    () => _db.transaction((txn) async {
      final on = day ?? _now();
      final weekRows = await txn.query(
        'weeks',
        where: 'id = ?',
        whereArgs: [weekId],
      );
      if (weekRows.isEmpty) {
        return left(const Failure('that week does not exist'));
      }
      final week = _week(weekRows.single);
      if (!_markable(on) || mondayOf(on) != week.start) {
        return left(const Failure('that day cannot be marked'));
      }
      final own = (await _ownHabits(
        txn,
      )).where((h) => h.habitId == habitId && !h.removed).firstOrNull;
      if (own != null) {
        if (!own.days.contains(Weekday.values[on.weekday - 1])) {
          return left(const Failure('that habit is not for that day'));
        }
      } else if (!week.sheet.habits.any((h) => h.id == habitId)) {
        return left(const Failure('that habit is not on the sheet'));
      }
      final onDay = _day(on);
      final ticked = await txn.query(
        'habit_ticks',
        where: 'day = ? AND habit_id = ?',
        whereArgs: [onDay, habitId],
      );
      if (ticked.isNotEmpty) return right(false);
      await record(txn, 'tick', {'day': onDay, 'habit': habitId}, _now());
      final s = week.start;
      final weekTicks = await txn.query(
        'habit_ticks',
        columns: ['day'],
        where: 'habit_id = ? AND day >= ? AND day <= ?',
        whereArgs: [
          habitId,
          _day(s),
          _day(DateTime(s.year, s.month, s.day + 6)),
        ],
      );
      // An own habit counts only the ticks on its days, so a day dropped by
      // an edit stops counting.
      final days = weekTicks
          .map((r) => DateTime.parse(r['day'] as String))
          .where(
            (d) =>
                own == null || own.days.contains(Weekday.values[d.weekday - 1]),
          )
          .length;
      if (days >= (own?.trophyDays ?? 5)) {
        final ref = own?.trophyRef ?? '${week.sheetRef}/$habitId';
        final earned = await txn.query('trophies', columns: ['milestone_ref']);
        if (!earned.any(
          (r) => trophyKey(r['milestone_ref'] as String) == trophyKey(ref),
        )) {
          await record(txn, 'trophy', {'ref': ref}, _now());
        }
      }
      return right(true);
    }),
  );

  @override
  Future<Either<Failure, Unit>> undoHabit(String habitId, {DateTime? day}) =>
      guard(
        () => _db.transaction((txn) async {
          final on = day ?? _now();
          if (!_markable(on)) {
            return left(const Failure('that day cannot be marked'));
          }
          final ticked = await txn.query(
            'habit_ticks',
            where: 'day = ? AND habit_id = ?',
            whereArgs: [_day(on), habitId],
          );
          if (ticked.isEmpty) {
            return left(const Failure('there is no tick to undo on that day'));
          }
          await record(txn, 'untick', {
            'day': _day(on),
            'habit': habitId,
          }, _now());
          return right(unit);
        }),
      );

  @override
  Future<Either<Failure, String?>> takeHabitSticker(
    int weekId, {
    DateTime? day,
    bool byParent = false,
  }) => guard(
    () => _db.transaction((txn) async {
      final now = _now();
      final on = day ?? now;
      final weekRows = await txn.query(
        'weeks',
        where: 'id = ?',
        whereArgs: [weekId],
      );
      if (weekRows.isEmpty) {
        return left(const Failure('that week does not exist'));
      }
      final week = _week(weekRows.single);
      if (!_markable(on) || mondayOf(on) != week.start) return right(null);
      final weekday = Weekday.values[on.weekday - 1];
      final given = await txn.query(
        'awards',
        columns: ['id'],
        where: 'week_id = ? AND weekday = ? AND task_id = ?',
        whereArgs: [weekId, weekday.name, habitsDoneTask],
      );
      if (given.isNotEmpty) return right(null);
      final ticked = {
        for (final r in await txn.query(
          'habit_ticks',
          columns: ['habit_id'],
          where: 'day = ?',
          whereArgs: [_day(on)],
        ))
          r['habit_id'] as String,
      };
      final off = await _ids(txn, 'habitStickersOff');
      final habits = [
        for (final h in week.sheet.habits)
          if (!off.contains(h.id)) h.id,
        for (final h in await _ownHabits(txn))
          if (!h.removed && h.days.contains(weekday)) h.habitId,
      ];
      if (habits.isEmpty || habits.any((h) => !ticked.contains(h))) {
        return right(null);
      }
      final sticker = nextSticker(const [], await _liveStickers(txn), _random);
      final event = await record(txn, 'give', {
        'week': weekRows.single['week_start'],
        'day': weekday.name,
        'task': habitsDoneTask,
        'award': habitsDoneTask,
        'stars': 0,
        'sticker': sticker,
      }, now);
      final id = await _awardOf(txn, event);
      if (byParent && _day(on) == _day(now)) {
        await _putSetting(txn, 'allDoneMoment', '$id');
      }
      await _checkMilestones(txn);
      return right(sticker);
    }),
  );

  @override
  Future<Either<Failure, Map<String, int>>> tickedDays() => guard(() async {
    final rows = await _db.rawQuery(
      'SELECT habit_id, COUNT(*) AS days FROM habit_ticks GROUP BY habit_id',
    );
    return right({
      for (final r in rows) r['habit_id'] as String: r['days'] as int,
    });
  });

  @override
  Future<Either<Failure, HabitPrefs>> habitPrefs() => guard(
    () async => right((
      answered: await _ids(_db, 'habitsAnswered'),
      stickerOff: await _ids(_db, 'habitStickersOff'),
    )),
  );

  @override
  Future<Either<Failure, Unit>> setHabitPrefs(HabitPrefs prefs) => guard(
    () => _db.transaction((txn) async {
      await record(txn, 'habit-prefs', {
        'answered': prefs.answered.toList(),
        'stickerOff': prefs.stickerOff.toList(),
      }, _now());
      return right(unit);
    }),
  );

  @override
  Future<Either<Failure, List<OwnHabit>>> ownHabits() =>
      guard(() async => right(await _ownHabits(_db)));

  @override
  Future<Either<Failure, Unit>> addOwnHabit(
    String text,
    String picture,
    Set<Weekday> days,
  ) => guard(
    () => _db.transaction((txn) async {
      final bad = _badOwnHabit(text, picture, days);
      if (bad != null) return left(bad);
      final live = (await _ownHabits(txn)).where((h) => !h.removed);
      if (live.length >= ownHabitsMax) {
        return left(const Failure('there are already 6 own habits'));
      }
      final last = Sqflite.firstIntValue(
        await txn.rawQuery('SELECT MAX(id) FROM own_habits'),
      );
      await record(txn, 'own', {
        'id': (last ?? 0) + 1,
        'text': text.trim(),
        'picture': picture,
        'days': daysMask(days),
      }, _now());
      return right(unit);
    }),
  );

  @override
  Future<Either<Failure, Unit>> editOwnHabit(OwnHabit habit) => guard(
    () => _db.transaction((txn) async {
      final bad = _badOwnHabit(habit.text, habit.picture, habit.days);
      if (bad != null) return left(bad);
      if (!await _ownHabitLive(txn, habit.id)) {
        return left(const Failure('that habit is not there'));
      }
      await record(txn, 'own', {
        'id': habit.id,
        'text': habit.text.trim(),
        'picture': habit.picture,
        'days': daysMask(habit.days),
      }, _now());
      return right(unit);
    }),
  );

  @override
  Future<Either<Failure, Unit>> removeOwnHabit(int id) => guard(
    () => _db.transaction((txn) async {
      if (!await _ownHabitLive(txn, id)) {
        return left(const Failure('that habit is not there'));
      }
      await record(txn, 'own-remove', {'id': id}, _now());
      return right(unit);
    }),
  );

  Future<bool> _ownHabitLive(DatabaseExecutor e, int id) async =>
      (await e.query(
        'own_habits',
        where: 'id = ? AND removed_at IS NULL',
        whereArgs: [id],
      )).isNotEmpty;

  Failure? _badOwnHabit(String text, String picture, Set<Weekday> days) {
    final t = text.trim();
    if (t.isEmpty || t.length > ownHabitTextMax) {
      return const Failure('the habit needs words, at most 40 letters');
    }
    if (days.isEmpty) return const Failure('the habit needs a day');
    if (!ownHabitPictures.contains(picture)) {
      return const Failure('that picture is not offered');
    }
    return null;
  }

  Future<List<OwnHabit>> _ownHabits(DatabaseExecutor e) async => [
    for (final r in await e.query('own_habits', orderBy: 'id'))
      OwnHabit(
        id: r['id'] as int,
        text: r['text'] as String,
        picture: r['picture'] as String,
        days: daysOfMask(r['days'] as int),
        removed: r['removed_at'] != null,
      ),
  ];

  Future<Set<String>> _ids(DatabaseExecutor e, String key) async {
    final v = await _setting(e, key);
    return v == null ? {} : (jsonDecode(v) as List).cast<String>().toSet();
  }

  String _day(DateTime t) => t.toIso8601String().substring(0, 10);

  bool _markable(DateTime day) =>
      markableDays(_now()).contains(DateTime(day.year, day.month, day.day));

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
    final active = await _activeSheet(_db);
    return right(active == null ? null : '${active.$1.id}/${active.$2.id}');
  });

  @override
  Future<Either<Failure, Unit>> setActiveSheet(String ref) => guard(
    () => _db.transaction((txn) async {
      await record(txn, 'sheet', {'ref': ref}, _now());
      return right(unit);
    }),
  );

  /// The sheet named by the `activeSheet` setting, else the sheet of the newest
  /// week, else the first installed one.
  Future<(Pack, Sheet)?> _activeSheet(DatabaseExecutor e) async {
    final rows = await e.query('settings', where: "key = 'activeSheet'");
    final Object? wanted;
    if (rows.isEmpty) {
      final newest = await e.query(
        'weeks',
        columns: ['sheet_ref'],
        orderBy: 'week_start DESC',
        limit: 1,
      );
      wanted = newest.firstOrNull?['sheet_ref'];
    } else {
      wanted = rows.single['value'];
    }
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
    final pages = fullPages(await _liveStickers(txn));
    final earned = {
      for (final r in await txn.query('trophies', columns: ['milestone_ref']))
        r['milestone_ref'] as String,
    };
    for (final ref in [...reached, ...pages]) {
      if (earned.add(ref)) await record(txn, 'trophy', {'ref': ref}, _now());
    }
  }

  Future<int> _awardOf(DatabaseExecutor e, String event) async {
    final rows = await e.query(
      'awards',
      columns: ['id'],
      where: 'event = ?',
      whereArgs: [event],
    );
    return rows.single['id']! as int;
  }
}
