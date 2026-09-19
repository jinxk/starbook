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

/// What the child sees once: a finished week, and the newest new trophy ref.
typedef Moments = ({bool weekDone, String? trophy});

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

const defaultStickers = [
  'lion',
  'peacock',
  'tiger',
  'elephant',
  'unicorn',
  'dog',
  'cat',
  'rocket',
  'star',
  'rainbow',
  'mango',
  'ice-cream',
  'party-popper',
  'panda',
  'monkey',
  'turtle',
  'frog',
  'penguin',
  'dolphin',
  'butterfly',
  'owl',
  'flying-saucer',
  'planet',
  'comet',
  'moon',
  'glowing-star',
  'watermelon',
  'strawberry',
  'birthday-cake',
  'popcorn',
  'doughnut',
  'sun',
  'cloud-rain',
  'lightning',
  'snowflake',
  'snowman',
  'balloon',
  'gift',
  'crown',
  'kite',
];

DateTime mondayOf(DateTime t) =>
    DateTime(t.year, t.month, t.day - t.weekday + 1);

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

/// The first sticker with the fewest copies in [album], so a full list cycles.
String nextSticker(List<String> stickers, List<String> album) {
  final list = stickers.isEmpty ? defaultStickers : stickers;
  int copies(String s) => album.where((a) => a == s).length;
  return list.reduce((best, s) => copies(s) < copies(best) ? s : best);
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
