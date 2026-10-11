import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:starbook/domain/pack/pack.dart';
import 'package:starbook/domain/progress/progress.dart';

GivenAward given(Weekday day, String task, {bool undone = false}) {
  final t = DateTime.now();
  return GivenAward(
    id: 1,
    weekId: 1,
    weekday: day,
    taskId: task,
    awardRef: 'p/star',
    stars: 1,
    givenAt: t,
    undoneAt: undone ? t : null,
  );
}

void main() {
  test('a day needs every non-bonus task, everyDay included, and a week needs '
      'every listed day', () {
    const monday = Day(
      weekday: Weekday.monday,
      title: 'Mon',
      tasks: [
        Task(id: 't1', text: 'One'),
        Task(id: 'b1', text: 'Extra', bonus: true),
      ],
    );
    const tuesday = Day(
      weekday: Weekday.tuesday,
      title: 'Tue',
      tasks: [Task(id: 't2', text: 'Two')],
    );
    const sheet = Sheet(
      id: 's',
      title: 'S',
      days: [monday, tuesday],
      everyDay: [Task(id: 'e1', text: 'Every')],
      restDays: [Weekday.saturday],
    );

    final mondayDone = [
      given(Weekday.monday, 't1'),
      given(Weekday.monday, 'e1'),
    ];
    expect(dayDone(sheet, monday, mondayDone), isTrue);

    final tuesdayPart = [...mondayDone, given(Weekday.tuesday, 't2')];
    expect(dayDone(sheet, tuesday, tuesdayPart), isFalse);
    expect(weekDone(sheet, tuesdayPart), isFalse);

    final all = [...tuesdayPart, given(Weekday.tuesday, 'e1')];
    expect(weekDone(sheet, all), isTrue);

    final undone = [
      ...mondayDone,
      given(Weekday.tuesday, 't2', undone: true),
      given(Weekday.tuesday, 'e1'),
    ];
    expect(dayDone(sheet, tuesday, undone), isFalse);

    const bonusOnly = Day(
      weekday: Weekday.wednesday,
      title: 'Wed',
      tasks: [Task(id: 'b2', text: 'Extra', bonus: true)],
    );
    const second = Sheet(id: 's2', title: 'S2', days: [bonusOnly]);
    expect(dayDone(second, bonusOnly, const []), isTrue);
  });

  test('a sticker award picks only stickers not yet earned until the list is '
      'complete, then any', () {
    const list = ['a', 'b', 'c', 'd', 'e'];
    Set<String> picks(List<String> stickers, List<String> album) => {
      for (var seed = 0; seed < 100; seed++)
        nextSticker(stickers, album, Random(seed)),
    };

    expect(picks(list, ['a', 'c']), {'b', 'd', 'e'});
    expect(picks(list, ['a', 'b', 'c', 'd']), {'e'});
    final complete = picks(list, ['a', 'b', 'c', 'd', 'e', 'a']);
    expect(complete.length, greaterThan(1));
    expect(complete.difference(list.toSet()), isEmpty);
    final album = defaultStickers.take(10).toList();
    final fromDefault = picks([], album);
    expect(fromDefault.intersection(album.toSet()), isEmpty);
    expect(fromDefault.length, greaterThan(1));
  });

  test('the 40 stickers from before the set grew are all still in it and fill '
      'no page', () {
    const old = [
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
    expect(defaultStickers, containsAll(old));
    expect(fullPages(old), isEmpty);
  });
}
