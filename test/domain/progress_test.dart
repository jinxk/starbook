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

  test('a sticker award gives the first sticker missing from the album, then '
      'cycles', () {
    const list = ['a', 'b', 'c'];
    expect(nextSticker(list, []), 'a');
    expect(nextSticker(list, ['b']), 'a');
    expect(nextSticker(list, ['a', 'b']), 'c');
    expect(nextSticker(list, ['a', 'b', 'c']), 'a');
    expect(nextSticker(list, ['a', 'b', 'c', 'a']), 'b');
    expect(nextSticker([], []), defaultStickers.first);
  });
}
