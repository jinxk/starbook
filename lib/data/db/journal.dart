import 'dart:convert';
import 'dart:math' show Random;

import 'package:sqflite/sqflite.dart';

/// The tables and settings worked out from the journal. Every other setting
/// belongs to the phone.
const builtTables = [
  'child',
  'weeks',
  'awards',
  'trophies',
  'finished',
  'habit_ticks',
  'own_habits',
];
const builtSettings = ['activeSheet', 'habitsAnswered', 'habitStickersOff'];

/// Every kind of event this version applies.
const eventKinds = {
  'week',
  'sheet',
  'reward',
  'task-add',
  'task-edit',
  'task-remove',
  'give',
  'undo',
  'child',
  'finished',
  'trophy',
  'tick',
  'untick',
  'habit-prefs',
  'own',
  'own-remove',
};

/// This phone's id, made at random the first time it is asked for.
Future<String> phoneId(DatabaseExecutor e) async {
  final rows = await e.query('settings', where: "key = 'phone'");
  if (rows.isNotEmpty) return rows.single['value']! as String;
  final random = Random.secure();
  final id = [
    for (var i = 0; i < 8; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
  await e.insert('settings', {'key': 'phone', 'value': id});
  return id;
}

/// Adds an event of this phone to the journal and applies it; returns the
/// event's id. The event is timed after every event from another phone, so
/// it wins over them whatever the two clocks say.
Future<String> record(
  DatabaseExecutor e,
  String kind,
  Map<String, Object?> data,
  DateTime at,
) async {
  final other = Sqflite.firstIntValue(
    await e.rawQuery('SELECT MAX(at) FROM journal WHERE phone != ?', [
      await phoneId(e),
    ]),
  );
  var millis = at.millisecondsSinceEpoch;
  if (other != null && millis <= other) millis = other + 1;
  final row = await _event(e, kind, data, millis);
  await _apply(e, row);
  return row['id']! as String;
}

/// The highest event number held from each phone.
Future<Map<String, int>> heldNumbers(DatabaseExecutor e) async {
  final held = <String, int>{};
  for (final r in await e.query('journal', columns: ['id'])) {
    final (phone, n) = _split(r['id']! as String);
    if (n > (held[phone] ?? 0)) held[phone] = n;
  }
  return held;
}

/// The events, in journal order, numbered above what [held] gives for their
/// phone.
Future<List<Map<String, Object?>>> eventsBeyond(
  DatabaseExecutor e,
  Map<String, int> held,
) async => [
  for (final r in await e.query(
    'journal',
    columns: ['id', 'phone', 'at', 'kind', 'data'],
    orderBy: 'seq',
  ))
    if (_split(r['id']! as String).$2 > (held[r['phone']] ?? 0)) r,
];

/// Adds the [events] this phone does not hold yet, then works the tables out
/// again. Throws when an event cannot be applied.
Future<void> merge(
  DatabaseExecutor e,
  List<Map<String, Object?>> events,
) async {
  for (final row in events) {
    await e.insert('journal', {
      'id': row['id'],
      'phone': row['phone'],
      'at': row['at'],
      'kind': row['kind'],
      'data': row['data'],
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  await rebuild(e);
}

(String, int) _split(String id) {
  final i = id.lastIndexOf(':');
  return (id.substring(0, i), int.parse(id.substring(i + 1)));
}

/// Whether event [a] comes before event [b]: by time, then by phone and
/// number, so every phone puts two events in the same order.
bool _before(Map<String, Object?> a, Map<String, Object?> b) {
  final (atA, atB) = (a['at']! as int, b['at']! as int);
  if (atA != atB) return atA < atB;
  final (phoneA, nA) = _split(a['id']! as String);
  final (phoneB, nB) = _split(b['id']! as String);
  return phoneA != phoneB ? phoneA.compareTo(phoneB) < 0 : nA < nB;
}

/// What an event sets, for the events where only one counts: the latest edit
/// of words or a setting, and the earliest start of a week.
String? _slot(String kind, Map<String, Object?> d) => switch (kind) {
  'sheet' || 'habit-prefs' || 'child' => kind,
  'reward' => 'reward ${d['week']}',
  'task-edit' => 'task-edit ${d['week']} ${d['task']}',
  'own' => 'own ${d['id']}',
  'tick' || 'untick' => 'tick ${d['day']} ${d['habit']}',
  'week' => 'week ${d['start']}',
  _ => null,
};

Future<Map<String, Object?>> _event(
  DatabaseExecutor e,
  String kind,
  Map<String, Object?> data,
  int at,
) async {
  final phone = await phoneId(e);
  final last = Sqflite.firstIntValue(
    await e.rawQuery(
      'SELECT MAX(CAST(substr(id, ?) AS INTEGER)) FROM journal '
      'WHERE phone = ?',
      [phone.length + 2, phone],
    ),
  );
  final row = <String, Object?>{
    'id': '$phone:${(last ?? 0) + 1}',
    'phone': phone,
    'at': at,
    'kind': kind,
    'data': jsonEncode(data),
  };
  await e.insert('journal', row);
  return row;
}

/// Clears the rows worked out from the journal and applies every event again,
/// in journal order. Where only one event of a kind counts for the same thing
/// (the latest edit, the earliest week start), the others are left out; the
/// weeks and own habits come first, as events from another phone can follow
/// the events that use them.
Future<void> rebuild(DatabaseExecutor e) async {
  for (final table in builtTables) {
    await e.delete(table);
  }
  await e.delete(
    'settings',
    where: 'key IN (${builtSettings.map((_) => '?').join(', ')})',
    whereArgs: builtSettings,
  );
  // A list of its own: a query result makes a new row on each read, and the
  // rows are told apart by identity below.
  final events = [...await e.query('journal', orderBy: 'seq')];
  final winner = <String, Map<String, Object?>>{};
  final slots = Map<Map<String, Object?>, String>.identity();
  for (final row in events) {
    final kind = row['kind']! as String;
    final slot = _slot(
      kind,
      jsonDecode(row['data']! as String) as Map<String, Object?>,
    );
    if (slot == null) continue;
    slots[row] = slot;
    final had = winner[slot];
    if (had == null ||
        (kind == 'week' ? _before(row, had) : _before(had, row))) {
      winner[slot] = row;
    }
  }
  bool counts(Map<String, Object?> row) =>
      slots[row] == null || identical(winner[slots[row]], row);
  bool early(Map<String, Object?> row) =>
      row['kind'] == 'week' || row['kind'] == 'own';
  for (final row in events) {
    if (early(row) && counts(row)) await _apply(e, row);
  }
  for (final row in events) {
    if (!early(row) && counts(row)) await _apply(e, row);
  }
}

/// Writes one event for each row of a store that has no journal yet; the rows
/// stay as they are. A row with no time of its own gets [now].
Future<void> convertToJournal(DatabaseExecutor e, DateTime now) async {
  Future<String> add(String kind, Map<String, Object?> data, [int? at]) async {
    final row = await _event(e, kind, data, at ?? now.millisecondsSinceEpoch);
    return row['id']! as String;
  }

  Future<String?> setting(String key) async {
    final rows = await e.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.single['value']! as String;
  }

  final active = await setting('activeSheet');
  if (active != null) await add('sheet', {'ref': active});
  final answered = await setting('habitsAnswered');
  final off = await setting('habitStickersOff');
  if (answered != null || off != null) {
    await add('habit-prefs', {
      'answered': answered == null ? const [] : jsonDecode(answered),
      'stickerOff': off == null ? const [] : jsonDecode(off),
    });
  }
  for (final r in await e.query('child')) {
    await add('child', {'name': r['name'], 'picture': r['picture']});
  }
  for (final r in await e.query('weeks', orderBy: 'id')) {
    final start = r['week_start']! as String;
    await add('week', {
      'start': start,
      'sheetRef': r['sheet_ref'],
      'sheet': jsonDecode(r['sheet_json']! as String),
    }, DateTime.parse(start).millisecondsSinceEpoch);
    if (r['special_reward'] != null) {
      await add('reward', {'week': start, 'text': r['special_reward']});
    }
  }
  for (final r in await e.query('own_habits', orderBy: 'id')) {
    await add('own', {
      'id': r['id'],
      'text': r['text'],
      'picture': r['picture'],
      'days': r['days'],
    });
    if (r['removed_at'] != null) {
      await add('own-remove', {'id': r['id']}, r['removed_at']! as int);
    }
  }
  for (final r in await e.rawQuery(
    'SELECT a.*, w.week_start FROM awards a JOIN weeks w ON w.id = a.week_id '
    'ORDER BY a.id',
  )) {
    final id = await add('give', {
      'week': r['week_start'],
      'day': r['weekday'],
      'task': r['task_id'],
      'award': r['award_ref'],
      'stars': r['stars'],
      'sticker': r['sticker'],
      'undone': r['undone_at'],
    }, r['given_at']! as int);
    await e.update(
      'awards',
      {'event': id},
      where: 'id = ?',
      whereArgs: [r['id']],
    );
  }
  for (final r in await e.query('habit_ticks', orderBy: 'rowid')) {
    final day = r['day']! as String;
    await add('tick', {
      'day': day,
      'habit': r['habit_id'],
    }, DateTime.parse(day).millisecondsSinceEpoch);
  }
  for (final r in await e.query('finished', orderBy: 'rowid')) {
    await add('finished', {
      'kind': r['kind'],
      'ref': r['ref'],
    }, r['finished_at']! as int);
  }
  for (final r in await e.query('trophies', orderBy: 'rowid')) {
    await add('trophy', {'ref': r['milestone_ref']}, r['earned_at']! as int);
  }
}

Future<void> _apply(DatabaseExecutor e, Map<String, Object?> event) async {
  final at = event['at']! as int;
  final d = jsonDecode(event['data']! as String) as Map<String, Object?>;
  switch (event['kind']) {
    case 'week':
      await e.insert('weeks', {
        'week_start': d['start']! as String,
        'sheet_ref': d['sheetRef']! as String,
        'sheet_json': jsonEncode(d['sheet']! as Map),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    case 'sheet':
      await _put(e, 'activeSheet', d['ref']! as String);
    case 'reward':
      await e.update(
        'weeks',
        {'special_reward': d['text'] as String?},
        where: 'id = ?',
        whereArgs: [await _weekId(e, d['week'])],
      );
    case 'task-add':
      await _changeSheet(
        e,
        d['week'],
        (s) => addTaskTo(
          s,
          d['day']! as String,
          d['id']! as String,
          d['text']! as String,
        ),
      );
    case 'task-edit':
      await _changeSheet(
        e,
        d['week'],
        (s) => editTaskIn(s, d['task']! as String, d['text']! as String),
      );
    case 'task-remove':
      await _changeSheet(
        e,
        d['week'],
        (s) => removeTaskFrom(s, d['task']! as String),
      );
    case 'give':
      final week = await _weekId(e, d['week']);
      if (d['replaces'] != null) {
        await e.update(
          'awards',
          {'undone_at': at},
          where:
              'event = ? AND week_id = ? AND weekday = ? AND task_id = ? '
              'AND undone_at IS NULL',
          whereArgs: [d['replaces'], week, d['day'], d['task']],
        );
      }
      var undone = d['undone'] as int?;
      final live = undone != null
          ? null
          : (await e.query(
              'awards',
              columns: ['id', 'given_at', 'event'],
              where: _liveIn,
              whereArgs: [week, d['day'], d['task']],
            )).firstOrNull;
      // Two phones gave an award for the same task and day: the earlier one
      // counts. From one phone it is refused, as before.
      if (live != null &&
          _split(live['event']! as String).$1 != event['phone']) {
        final other = {'at': live['given_at'], 'id': live['event']};
        if (_before(other, event)) {
          undone = at;
        } else {
          await e.update(
            'awards',
            {'undone_at': live['given_at']},
            where: 'id = ?',
            whereArgs: [live['id']],
          );
        }
      }
      await e.insert('awards', {
        'week_id': week,
        'weekday': d['day']! as String,
        'task_id': d['task']! as String,
        'award_ref': d['award']! as String,
        'stars': d['stars']! as int,
        'sticker': d['sticker'] as String?,
        'given_at': at,
        'undone_at': undone,
        'event': event['id']! as String,
      });
    case 'undo':
      await e.update(
        'awards',
        {'undone_at': at},
        where: 'event = ? AND undone_at IS NULL',
        whereArgs: [d['award']],
      );
      final back = d['restore'] == null
          ? null
          : (await e.query(
              'awards',
              where: 'event = ? AND undone_at IS NOT NULL',
              whereArgs: [d['restore']],
            )).firstOrNull;
      // Not when an award from the other phone holds the place.
      if (back != null &&
          (await e.query(
            'awards',
            columns: ['id'],
            where: _liveIn,
            whereArgs: [back['week_id'], back['weekday'], back['task_id']],
          )).isEmpty) {
        await e.update(
          'awards',
          {'undone_at': null},
          where: 'id = ?',
          whereArgs: [back['id']],
        );
      }
    case 'child':
      await e.insert('child', {
        'id': 1,
        'name': d['name'] as String?,
        'picture': d['picture'] as String?,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    case 'finished':
      await e.insert('finished', {
        'kind': d['kind']! as String,
        'ref': d['ref']! as String,
        'finished_at': at,
      });
    case 'trophy':
      await e.insert('trophies', {
        'milestone_ref': d['ref']! as String,
        'earned_at': at,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      // Earned on both phones: the earlier time counts.
      await e.update(
        'trophies',
        {'earned_at': at},
        where: 'milestone_ref = ? AND earned_at > ?',
        whereArgs: [d['ref'], at],
      );
    case 'tick':
      await e.insert('habit_ticks', {
        'day': d['day']! as String,
        'habit_id': d['habit']! as String,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    case 'untick':
      await e.delete(
        'habit_ticks',
        where: 'day = ? AND habit_id = ?',
        whereArgs: [d['day'], d['habit']],
      );
    case 'habit-prefs':
      await _put(
        e,
        'habitsAnswered',
        jsonEncode((d['answered']! as List).cast<String>()),
      );
      await _put(
        e,
        'habitStickersOff',
        jsonEncode((d['stickerOff']! as List).cast<String>()),
      );
    case 'own':
      final row = {
        'text': d['text']! as String,
        'picture': d['picture']! as String,
        'days': d['days']! as int,
      };
      final changed = await e.update(
        'own_habits',
        row,
        where: 'id = ?',
        whereArgs: [d['id']],
      );
      if (changed == 0) {
        await e.insert('own_habits', {'id': d['id']! as int, ...row});
      }
    case 'own-remove':
      await e.update(
        'own_habits',
        {'removed_at': at},
        where: 'id = ? AND removed_at IS NULL',
        whereArgs: [d['id']],
      );
    default:
      throw FormatException('unknown event ${event['kind']}');
  }
}

const _liveIn =
    'week_id = ? AND weekday = ? AND task_id = ? AND undone_at IS NULL';

Future<int> _weekId(DatabaseExecutor e, Object? start) async {
  final rows = await e.query(
    'weeks',
    columns: ['id'],
    where: 'week_start = ?',
    whereArgs: [start],
  );
  if (rows.isEmpty) throw FormatException('no week $start');
  return rows.single['id']! as int;
}

Future<void> _changeSheet(
  DatabaseExecutor e,
  Object? start,
  void Function(Map<String, Object?> sheet) change,
) async {
  final id = await _weekId(e, start);
  final rows = await e.query(
    'weeks',
    columns: ['sheet_json'],
    where: 'id = ?',
    whereArgs: [id],
  );
  final sheet =
      jsonDecode(rows.single['sheet_json']! as String) as Map<String, Object?>;
  change(sheet);
  await e.update(
    'weeks',
    {'sheet_json': jsonEncode(sheet)},
    where: 'id = ?',
    whereArgs: [id],
  );
}

Future<void> _put(DatabaseExecutor e, String key, String value) => e.insert(
  'settings',
  {'key': key, 'value': value},
  conflictAlgorithm: ConflictAlgorithm.replace,
);

List<Map<String, Object?>> _days(Map<String, Object?> sheet) =>
    ((sheet['days'] as List?) ?? const []).cast<Map<String, Object?>>();

/// The task lists of a raw sheet: every day's tasks, then the every-day ones.
List<List<Object?>> taskLists(Map<String, Object?> sheet) => [
  for (final d in _days(sheet))
    if (d['tasks'] != null) d['tasks']! as List<Object?>,
  if (sheet['everyDay'] != null) sheet['everyDay']! as List<Object?>,
];

/// Adds task [id] to [weekday]'s list of a raw sheet; nothing when the day is
/// not on it.
void addTaskTo(
  Map<String, Object?> sheet,
  String weekday,
  String id,
  String text,
) {
  final day = _days(sheet).where((d) => d['weekday'] == weekday).firstOrNull;
  if (day == null) return;
  ((day['tasks'] ??= <Object?>[]) as List<Object?>).add({
    'id': id,
    'text': text,
  });
}

/// Gives task [id] of a raw sheet new words and drops the words written for
/// the old ones.
void editTaskIn(Map<String, Object?> sheet, String id, String text) {
  final task = [
    for (final list in taskLists(sheet))
      ...list.cast<Map<String, Object?>>().where((t) => t['id'] == id),
  ].firstOrNull;
  if (task == null) return;
  task['text'] = text;
  task.remove('say');
  task.remove('cheer');
  task.remove('tip');
}

/// Removes task [id] from every list of a raw sheet; false when it was on none.
bool removeTaskFrom(Map<String, Object?> sheet, String id) {
  var found = false;
  for (final list in taskLists(sheet)) {
    final before = list.length;
    list.removeWhere((t) => (t as Map)['id'] == id);
    found = found || list.length != before;
  }
  return found;
}
