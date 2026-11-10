import 'dart:math';

import '../pack/pack.dart';

enum BookKind { wordbook, story, board }

class Week {
  const Week({
    required this.id,
    required this.start,
    required this.sheetRef,
    required this.sheet,
    this.specialReward,
  });

  final int id;
  final DateTime start;
  final String sheetRef;
  final Sheet sheet;
  final String? specialReward;
}

class GivenAward {
  const GivenAward({
    required this.id,
    required this.weekId,
    required this.weekday,
    required this.taskId,
    required this.awardRef,
    required this.stars,
    required this.givenAt,
    this.sticker,
    this.undoneAt,
  });

  final int id;
  final int weekId;
  final Weekday weekday;
  final String taskId;
  final String awardRef;
  final int stars;
  final String? sticker;
  final DateTime givenAt;
  final DateTime? undoneAt;
}

class Child {
  const Child({this.name, this.picture});

  final String? name;
  final String? picture;
}

class Trophy {
  const Trophy({required this.milestoneRef, required this.earnedAt});

  final String milestoneRef;
  final DateTime earnedAt;
}

/// What the child sees once: a finished week, the newest new trophy ref, and
/// the book sticker of today's all-done that a parent's tick gave.
typedef Moments = ({bool weekDone, String? trophy, String? allDone});

class Counters {
  const Counters({
    required this.stars,
    required this.stickers,
    required this.daysDone,
    required this.weeksDone,
    required this.wordbooksDone,
    required this.storiesRead,
  });

  final int stars;
  final int stickers;
  final int daysDone;
  final int weeksDone;
  final int wordbooksDone;
  final int storiesRead;

  int of(MilestoneCounter c) => switch (c) {
    MilestoneCounter.stars => stars,
    MilestoneCounter.stickers => stickers,
    MilestoneCounter.daysDone => daysDone,
    MilestoneCounter.weeksDone => weeksDone,
    MilestoneCounter.wordbooksDone => wordbooksDone,
    MilestoneCounter.storiesRead => storiesRead,
  };
}

typedef StickerPage = ({
  String ref,
  String name,
  String trophy,
  String picture,
  List<String> stickers,
});

/// The sticker set as album pages, in the order of docs/stickers.md. [ref] is
/// the page trophy; no pack ref can hold a colon, so it never clashes.
const stickerPages = <StickerPage>[
  (
    ref: 'sticker-page:animals',
    name: 'Animals',
    trophy: 'Full animal page',
    picture: 'lion',
    stickers: [
      'lion',
      'tiger',
      'elephant',
      'panda',
      'monkey',
      'dog',
      'cat',
      'unicorn',
      'peacock',
      'owl',
      'bear',
      'fox',
      'cow',
      'rabbit',
      'pig',
      'horse',
      'goat',
      'kangaroo',
      'sloth',
      'hedgehog',
      'chipmunk',
      'rooster',
      'chick',
      'dinosaur',
    ],
  ),
  (
    ref: 'sticker-page:sea-and-garden',
    name: 'Sea and garden',
    trophy: 'Full sea and garden page',
    picture: 'butterfly',
    stickers: [
      'dolphin',
      'turtle',
      'frog',
      'penguin',
      'butterfly',
      'whale',
      'fish',
      'blowfish',
      'octopus',
      'crab',
      'seal',
      'otter',
      'flamingo',
      'snail',
      'bee',
      'ladybird',
      'caterpillar',
      'tulip',
      'blossom',
      'cherry-blossom',
      'cactus',
      'mushroom',
      'clover',
      'seedling',
    ],
  ),
  (
    ref: 'sticker-page:food',
    name: 'Food',
    trophy: 'Full food page',
    picture: 'mango',
    stickers: [
      'mango',
      'watermelon',
      'strawberry',
      'ice-cream',
      'birthday-cake',
      'popcorn',
      'doughnut',
      'cherries',
      'apple',
      'orange',
      'pineapple',
      'lemon',
      'grapes',
      'pear',
      'kiwi',
      'blueberries',
      'carrot',
      'corn',
      'broccoli',
      'tomato',
      'pancakes',
      'cookie',
      'soft-serve',
      'bread',
    ],
  ),
  (
    ref: 'sticker-page:sky-and-space',
    name: 'Sky and space',
    trophy: 'Full sky and space page',
    picture: 'rocket',
    stickers: [
      'sun',
      'moon',
      'star',
      'glowing-star',
      'rainbow',
      'cloud-rain',
      'lightning',
      'snowflake',
      'snowman',
      'comet',
      'planet',
      'rocket',
      'flying-saucer',
      'sparkles',
      'cloud',
      'sun-cloud',
      'droplet',
      'wind',
      'milky-way',
      'globe',
      'full-moon',
      'aeroplane',
      'parachute',
      'sunrise',
    ],
  ),
  (
    ref: 'sticker-page:fun-things',
    name: 'Fun things',
    trophy: 'Full fun things page',
    picture: 'balloon',
    stickers: [
      'party-popper',
      'balloon',
      'gift',
      'crown',
      'kite',
      'confetti',
      'pinata',
      'football',
      'basketball',
      'cricket',
      'badminton',
      'flying-disc',
      'skateboard',
      'magic-wand',
      'trumpet',
      'guitar',
      'drum',
      'music',
      'bicycle',
      'bus',
      'train',
      'sailboat',
      'ferris-wheel',
      'carousel',
    ],
  ),
  (
    ref: 'sticker-page:animal-friends',
    name: 'Animal friends',
    trophy: 'Full animal friends page',
    picture: 'ox',
    stickers: [
      'poodle',
      'guide-dog',
      'donkey',
      'ox',
      'gorilla',
      'orangutan',
      'raccoon',
      'sauropod',
      'lizard',
      'bird',
      'hatching-chick',
      'eagle',
      'dove',
      'goose',
      'jellyfish',
      'lobster',
      'ant',
      'grasshopper',
      'worm',
      'paw-prints',
    ],
  ),
  (
    ref: 'sticker-page:out-and-about',
    name: 'Out and about',
    trophy: 'Full out and about page',
    picture: 'tractor',
    stickers: [
      'car',
      'taxi',
      'racing-car',
      'motorbike',
      'tractor',
      'truck',
      'canoe',
      'roller-coaster',
      'traffic-light',
      'house',
      'tent',
      'anchor',
      'ring-buoy',
      'wave',
      'bubbles',
      'rose',
      'bouquet',
      'lotus',
      'hyacinth',
      'maple-leaf',
      'fallen-leaf',
      'herb',
      'leaves',
      'tree',
    ],
  ),
  (
    ref: 'sticker-page:play-and-music',
    name: 'Play and music',
    trophy: 'Full play and music page',
    picture: 'music-note',
    stickers: [
      'tennis',
      'baseball',
      'rugby',
      'ping-pong',
      'bowling',
      'hockey',
      'ice-skate',
      'roller-skates',
      'ballet-shoes',
      'skis',
      'golf',
      'target',
      'boomerang',
      'chess',
      'saxophone',
      'karate',
      'banjo',
      'violin',
      'maracas',
      'fishing',
      'disco-ball',
      'tickets',
      'camera',
      'clapper',
    ],
  ),
];

final defaultStickers = [for (final p in stickerPages) ...p.stickers];

DateTime mondayOf(DateTime t) =>
    DateTime(t.year, t.month, t.day - t.weekday + 1);

/// Today and the 6 days before it, oldest first, at midnight: the days a
/// parent can mark.
List<DateTime> markableDays(DateTime now) => [
  for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i),
];

/// [awards] are the awards of one week.
bool dayDone(Sheet sheet, Day day, List<GivenAward> awards) {
  final given = {
    for (final a in awards)
      if (a.weekday == day.weekday && a.undoneAt == null) a.taskId,
  };
  return [
    ...day.tasks,
    ...sheet.everyDay,
  ].where((t) => !t.bonus).every((t) => given.contains(t.id));
}

bool weekDone(Sheet sheet, List<GivenAward> awards) =>
    sheet.days.every((d) => dayDone(sheet, d, awards));

/// A stored week with its awards that are not undone and the habit ids ticked
/// on each of its dates that had a tick.
typedef KeptWeek = ({
  Week week,
  List<GivenAward> awards,
  Map<DateTime, Set<String>> ticks,
});

/// One date of a kept week with something marked: [day] is the sheet's day,
/// null on a rest day; [jobs] are the tasks done that day, bonus ones too.
typedef MarkedDay = ({
  DateTime date,
  Day? day,
  List<Task> jobs,
  List<Habit> habits,
});

bool _given(List<GivenAward> awards, Weekday day, Task task) =>
    awards.any((a) => a.weekday == day && a.taskId == task.id);

/// Over the school days of [sheet], the tasks that are not bonus (each day's
/// own and the every-day ones), and how many of them have an award.
({int done, int total}) jobsDone(Sheet sheet, List<GivenAward> awards) {
  var done = 0;
  var total = 0;
  for (final day in sheet.days) {
    for (final task in [...day.tasks, ...sheet.everyDay]) {
      if (task.bonus) continue;
      total++;
      if (_given(awards, day.weekday, task)) done++;
    }
  }
  return (done: done, total: total);
}

/// The habits of [habits] ticked on at least one date, in that order, with
/// the number of dates each was ticked on.
List<(Habit, int)> habitDays(
  List<Habit> habits,
  Map<DateTime, Set<String>> ticks,
) => [
  for (final h in habits)
    if (ticks.values.where((t) => t.contains(h.id)).length case final n
        when n > 0)
      (h, n),
];

/// Monday to Sunday of [kept], each date with a job done or one of [habits]
/// ticked.
List<MarkedDay> markedDays(KeptWeek kept, List<Habit> habits) {
  final sheet = kept.week.sheet;
  final start = kept.week.start;
  final marked = <MarkedDay>[];
  for (final weekday in Weekday.values) {
    final date = DateTime(start.year, start.month, start.day + weekday.index);
    final day = sheet.days.where((d) => d.weekday == weekday).firstOrNull;
    final jobs = [
      if (day != null)
        for (final t in [...day.tasks, ...sheet.everyDay])
          if (_given(kept.awards, weekday, t)) t,
    ];
    final ticked = kept.ticks[date] ?? const <String>{};
    final done = [
      for (final h in habits)
        if (ticked.contains(h.id)) h,
    ];
    if (jobs.isEmpty && done.isEmpty) continue;
    marked.add((date: date, day: day, jobs: jobs, habits: done));
  }
  return marked;
}

/// The task id of the award that gives a day's book sticker for ticking every
/// habit that day. Also its award ref; no sheet id holds a colon.
const habitsDoneTask = 'habits:done';

/// The most own habits a parent can keep at once.
const ownHabitsMax = 6;

/// The longest own habit text.
const ownHabitTextMax = 40;

/// The library pictures a parent picks an own habit's picture from.
const ownHabitPictures = [
  'tidy-up',
  'toothbrush',
  'wash-hands',
  'tub',
  'sleep',
  'broom',
  'plant',
  'share',
  'kind',
  'namaste',
  'sun',
  'ball',
  'bicycle',
  'swing',
  'slide',
  'kite',
  'tree',
  'water',
  'book',
  'crayon',
  'music-note',
  'apple',
  'milk',
  'television',
  'swimming',
  'timer',
];

/// A ready habit the add screen offers; the parent can change it before
/// saving.
typedef OwnHabitIdea = ({String text, String picture, Set<Weekday> days});

const _everyDay = {...Weekday.values};

/// Built into the app, not a pack. Swimming leaves the days to the parent.
const ownHabitIdeas = <OwnHabitIdea>[
  (text: 'I cleaned up after toy play', picture: 'tidy-up', days: _everyDay),
  (text: 'I played outside', picture: 'tree', days: _everyDay),
  (text: 'I went swimming', picture: 'swimming', days: {}),
  (text: 'I kept screen time to 20 minutes', picture: 'timer', days: _everyDay),
];

/// A habit the parent added, on the weekdays in [days]. A removed one stays
/// stored so a trophy it earned keeps its picture and words.
class OwnHabit {
  const OwnHabit({
    required this.id,
    required this.text,
    required this.picture,
    required this.days,
    this.removed = false,
  });

  final int id;
  final String text;
  final String picture;
  final Set<Weekday> days;
  final bool removed;

  /// Its id among habit ticks; no sheet habit id holds a colon.
  String get habitId => 'own:$id';

  /// Its trophy ref; no pack ref holds a colon.
  String get trophyRef => 'own-habit:$id';

  Habit get habit => Habit(id: habitId, text: text, picture: picture);

  /// Ticked days in one week that earn its trophy: 5, or each of its days
  /// when it has fewer.
  int get trophyDays => min(5, days.length);
}

/// [days] as a bit set, bit 0 for Monday; the stored form.
int daysMask(Set<Weekday> days) =>
    days.fold(0, (mask, d) => mask | (1 << d.index));

Set<Weekday> daysOfMask(int mask) => {
  for (final d in Weekday.values)
    if (mask & (1 << d.index) != 0) d,
};

/// Trophy refs of the sticker pages whose every sticker is in [album].
List<String> fullPages(List<String> album) {
  final earned = album.toSet();
  return [
    for (final p in stickerPages)
      if (p.stickers.every(earned.contains)) p.ref,
  ];
}

/// How many stickers of the set [album] holds, each counted once.
int stickersEarned(List<String> album) =>
    album.toSet().intersection(defaultStickers.toSet()).length;

/// A surprise pick among [stickers] (the default set when empty) not in
/// [album]; any of them once the album has them all.
String nextSticker(List<String> stickers, List<String> album, Random random) {
  final list = stickers.isEmpty ? defaultStickers : stickers;
  final owned = album.toSet();
  final left = list.where((s) => !owned.contains(s)).toList();
  final from = left.isEmpty ? list : left;
  return from[random.nextInt(from.length)];
}

/// [ref] as `pack-id/item-id`; a bare `item-id` is in the pack of [sheetRef].
String fullRef(String sheetRef, String ref) =>
    ref.contains('/') ? ref : '${sheetRef.split('/').first}/$ref';

/// The identity of a trophy. A habit trophy is one per pack and habit,
/// whichever sheet earned it: `pack/sheet/habit` gives `pack/*/habit`, which
/// no other ref can equal because ids never contain `*`. Other refs come back
/// unchanged.
String trophyKey(String ref) {
  final parts = ref.split('/');
  return parts.length == 3 ? '${parts.first}/*/${parts.last}' : ref;
}

/// The kind of item [ref] opens: `number-board` is the 1 to 10 board; else an
/// installed word book or story, `pack-id/item-id`, or `item-id` inside the
/// pack of [sheetRef]. Null when nothing matches.
BookKind? bookKindOf(List<Pack> packs, String sheetRef, String ref) {
  if (ref == 'number-board') return BookKind.board;
  final full = fullRef(sheetRef, ref);
  for (final p in packs) {
    if (p.wordBooks.any((b) => '${p.id}/${b.id}' == full)) {
      return BookKind.wordbook;
    }
  }
  for (final p in packs) {
    if (p.stories.any((s) => '${p.id}/${s.id}' == full)) {
      return BookKind.story;
    }
  }
  return null;
}

/// Refs (`pack-id/milestone-id`) of every milestone whose target is met.
List<String> reachedMilestones(List<Pack> packs, Counters counters) => [
  for (final p in packs)
    for (final m in p.milestones)
      if (counters.of(m.counter) >= m.target) '${p.id}/${m.id}',
];
