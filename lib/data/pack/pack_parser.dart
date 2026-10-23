import 'dart:convert';

import 'package:fpdart/fpdart.dart' show Either, left, right;

import '../../domain/failure.dart';
import '../../domain/pack/pack.dart';
import 'pack_validator.dart';

typedef _Json = Map<String, dynamic>;

Either<Failure, Pack> parsePack(String text) {
  final Object? json;
  try {
    json = jsonDecode(text.startsWith('\uFEFF') ? text.substring(1) : text);
  } on FormatException {
    return left(const Failure('the file is not valid JSON'));
  }
  final errors = validatePack(json);
  if (errors.isNotEmpty) return left(Failure(errors.first));
  return right(_pack(json as _Json));
}

List<T> _all<T>(Object? list, T Function(_Json) build) => [
  for (final item in (list as List?) ?? const []) build(item as _Json),
];

int _int(Object? v) => (v as num).toInt();

Pack _pack(_Json m) => Pack(
  id: m['id'] as String,
  revision: _int(m['revision']),
  title: m['title'] as String,
  language: m['language'] as String? ?? 'en-IN',
  author: m['author'] as String?,
  license: m['license'] as String?,
  sheets: _all(m['sheets'], _sheet),
  awards: _all(m['awards'], _award),
  milestones: _all(m['milestones'], _milestone),
  wordBooks: _all(m['wordbooks'], _wordBook),
  stories: _all(m['stories'], _story),
);

/// For a sheet already validated as part of an installed pack.
Sheet parseSheet(String json) => _sheet(jsonDecode(json) as _Json);

Sheet _sheet(_Json m) => Sheet(
  id: m['id'] as String,
  title: m['title'] as String,
  intro: m['intro'] as String?,
  language: m['language'] as String?,
  days: _all(m['days'], _day),
  everyDay: _all(m['everyDay'], _task),
  restDays: [
    for (final d in (m['restDays'] as List?) ?? const [])
      Weekday.values.byName(d as String),
  ],
  restMessage: m['restMessage'] as String?,
  weekGoal: m['weekGoal'] as String?,
  habits: _all(m['habits'], _habit),
);

Habit _habit(_Json m) => Habit(
  id: m['id'] as String,
  text: m['text'] as String,
  picture: m['picture'] as String,
  sticker: m['sticker'] as String?,
  say: m['say'] as String?,
);

Day _day(_Json m) => Day(
  weekday: Weekday.values.byName(m['weekday'] as String),
  title: m['title'] as String,
  colour: m['colour'] as String?,
  tasks: _all(m['tasks'], _task),
);

Task _task(_Json m) => Task(
  id: m['id'] as String,
  text: m['text'] as String,
  say: m['say'] as String?,
  cheer: m['cheer'] as String?,
  tip: (m['tip'] as String?)?.trim(),
  language: m['language'] as String?,
  icon: m['icon'] as String?,
  opens: m['opens'] as String?,
  bonus: m['bonus'] as bool? ?? false,
);

Award _award(_Json m) => Award(
  id: m['id'] as String,
  kind: AwardKind.values.byName(m['kind'] as String),
  label: m['label'] as String,
  say: m['say'] as String?,
  language: m['language'] as String?,
  colour: m['colour'] as String?,
  stars: m['stars'] == null ? 1 : _int(m['stars']),
  stickers: [for (final s in (m['stickers'] as List?) ?? const []) s as String],
  retired: m['retired'] as bool? ?? false,
);

Milestone _milestone(_Json m) {
  final when = (m['when'] as _Json).entries.single;
  return Milestone(
    id: m['id'] as String,
    title: m['title'] as String,
    trophy: m['trophy'] as String,
    counter: MilestoneCounter.values.byName(when.key),
    target: _int(when.value),
  );
}

WordBook _wordBook(_Json m) => WordBook(
  id: m['id'] as String,
  title: m['title'] as String,
  letter: m['letter'] as String?,
  colour: m['colour'] as String?,
  language: m['language'] as String?,
  cards: _all(m['cards'], _card),
);

WordCard _card(_Json m) => WordCard(
  word: m['word'] as String,
  picture: m['picture'] as String?,
  big: m['big'] as String?,
  count: m['count'] == null ? null : _int(m['count']),
  group: m['group'] as String?,
  say: m['say'] as String?,
  language: m['language'] as String?,
);

Story _story(_Json m) => Story(
  id: m['id'] as String,
  title: m['title'] as String,
  level: _int(m['level']),
  cover: m['cover'] as String?,
  language: m['language'] as String?,
  pages: _all(m['pages'], _page),
  say: ((m['say'] as Map?) ?? const {}).cast<String, String>(),
  credit: m['credit'] == null ? null : _credit(m['credit'] as _Json),
);

StoryPage _page(_Json m) => StoryPage(
  text: m['text'] as String,
  picture: m['picture'] as String?,
  ask: (m['ask'] as String?)?.trim(),
);

Credit _credit(_Json m) => Credit(
  source: m['source'] as String,
  url: m['url'] as String?,
  license: m['license'] as String,
  text: m['text'] as String?,
);
