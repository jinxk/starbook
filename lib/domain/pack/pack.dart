enum Weekday { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

enum AwardKind { star, stamp, sticker }

enum MilestoneCounter {
  stars,
  stickers,
  daysDone,
  weeksDone,
  wordbooksDone,
  storiesRead,
}

class Pack {
  const Pack({
    required this.id,
    required this.revision,
    required this.title,
    required this.language,
    this.author,
    this.license,
    this.sheets = const [],
    this.awards = const [],
    this.milestones = const [],
    this.wordBooks = const [],
    this.stories = const [],
  });

  final String id;
  final int revision;
  final String title;
  final String language;
  final String? author;
  final String? license;
  final List<Sheet> sheets;
  final List<Award> awards;
  final List<Milestone> milestones;
  final List<WordBook> wordBooks;
  final List<Story> stories;
}

class Sheet {
  const Sheet({
    required this.id,
    required this.title,
    required this.days,
    this.intro,
    this.language,
    this.everyDay = const [],
    this.restDays = const [],
    this.restMessage,
    this.weekGoal,
  });

  final String id;
  final String title;
  final String? intro;
  final String? language;
  final List<Day> days;
  final List<Task> everyDay;
  final List<Weekday> restDays;
  final String? restMessage;
  final String? weekGoal;
}

class Day {
  const Day({
    required this.weekday,
    required this.title,
    required this.tasks,
    this.colour,
  });

  final Weekday weekday;
  final String title;
  final String? colour;
  final List<Task> tasks;
}

class Task {
  const Task({
    required this.id,
    required this.text,
    this.say,
    this.language,
    this.icon,
    this.opens,
    this.bonus = false,
  });

  final String id;
  final String text;
  final String? say;
  final String? language;
  final String? icon;
  final String? opens;
  final bool bonus;
}

class Award {
  const Award({
    required this.id,
    required this.kind,
    required this.label,
    this.say,
    this.language,
    this.colour,
    this.stars = 1,
    this.stickers = const [],
  });

  final String id;
  final AwardKind kind;
  final String label;
  final String? say;
  final String? language;
  final String? colour;
  final int stars;
  final List<String> stickers;
}

class Milestone {
  const Milestone({
    required this.id,
    required this.title,
    required this.trophy,
    required this.counter,
    required this.target,
  });

  final String id;
  final String title;
  final String trophy;
  final MilestoneCounter counter;
  final int target;
}

class WordBook {
  const WordBook({
    required this.id,
    required this.title,
    required this.cards,
    this.letter,
    this.colour,
    this.language,
  });

  final String id;
  final String title;
  final String? letter;
  final String? colour;
  final String? language;
  final List<WordCard> cards;
}

class WordCard {
  const WordCard({
    required this.word,
    this.picture,
    this.big,
    this.group,
    this.say,
    this.language,
  });

  final String word;
  final String? picture;
  final String? big;
  final String? group;
  final String? say;
  final String? language;
}

class Story {
  const Story({
    required this.id,
    required this.title,
    required this.level,
    required this.pages,
    this.cover,
    this.language,
    this.say = const {},
    this.credit,
  });

  final String id;
  final String title;
  final int level;
  final String? cover;
  final String? language;
  final List<StoryPage> pages;
  final Map<String, String> say;
  final Credit? credit;
}

class StoryPage {
  const StoryPage({required this.text, this.picture});

  final String text;
  final String? picture;
}

class Credit {
  const Credit({
    required this.source,
    required this.license,
    this.url,
    this.text,
  });

  final String source;
  final String? url;
  final String license;
  final String? text;
}
