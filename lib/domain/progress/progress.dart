import 'dart:math';

import '../pack/pack.dart';

enum BookKind { wordbook, story }

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

/// The kind of installed item [ref] opens: `pack-id/item-id`, or `item-id`
/// inside the pack of [sheetRef]. Null when nothing installed matches.
BookKind? bookKindOf(List<Pack> packs, String sheetRef, String ref) {
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
