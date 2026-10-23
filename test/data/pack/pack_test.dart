import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:starbook/data/pack/default_packs.dart';
import 'package:starbook/data/pack/pack_parser.dart';
import 'package:starbook/data/pack/pack_validator.dart';
import 'package:starbook/domain/pack/pack.dart';

Map<String, dynamic> validPack() =>
    jsonDecode('''
{"starbook": 1, "id": "test.pack", "revision": 1, "title": "Test",
 "sheets": [{"id": "week", "title": "Week",
   "days": [{"weekday": "monday", "title": "Mon", "tasks": [{"id": "t1", "text": "Write A"}]}],
   "everyDay": [{"id": "t2", "text": "Read", "bonus": true}]}],
 "awards": [{"id": "star", "kind": "star", "label": "Star"}]}
''')
        as Map<String, dynamic>;

void main() {
  group('validatePack rejects', () {
    test('a pack without an id', () {
      final p = validPack()..remove('id');
      expect(validatePack(p), ['id is missing']);
    });

    test('a day with a weekday that does not exist', () {
      final p = validPack();
      p['sheets'][0]['days'][0]['weekday'] = 'funday';
      expect(validatePack(p), [
        'sheets[0].days[0].weekday: "funday" is not one of monday, tuesday, '
            'wednesday, thursday, friday, saturday, sunday',
      ]);
    });

    test('an id used twice in a list, and a task id used twice in a sheet', () {
      final p = validPack();
      p['awards'].add({'id': 'star', 'kind': 'stamp', 'label': 'Good'});
      expect(validatePack(p), ['awards[1].id: "star" is already used']);

      final q = validPack();
      q['sheets'][0]['everyDay'][0]['id'] = 't1';
      expect(validatePack(q), [
        'sheets[0].everyDay[0].id: "t1" is already used',
      ]);
    });

    test('an award of an unknown kind', () {
      final p = validPack();
      p['awards'][0]['kind'] = 'badge';
      expect(validatePack(p), [
        'awards[0].kind: "badge" is not one of star, stamp, sticker',
      ]);
    });

    test('an award whose retired is not true or false', () {
      final p = validPack();
      p['awards'][0]['retired'] = 'yes';
      expect(validatePack(p), ['awards[0].retired: must be true or false']);
    });

    test('a revision that is not a whole number, but takes 2.0 as 2', () {
      final p = validPack()..['revision'] = 1.5;
      expect(validatePack(p), ['revision: must be a whole number']);

      p['revision'] = 2.0;
      expect(validatePack(p), isEmpty);
      final parsed = parsePack(jsonEncode(p));
      expect(parsed.isRight(), isTrue);
      expect((parsed as Right).value.revision, 2);
    });

    test('a task cheer that is empty or over 40 characters, and loads one of '
        '40', () {
      final p = validPack();
      p['sheets'][0]['days'][0]['tasks'][0]['cheer'] = 'x' * 40;
      expect(validatePack(p), isEmpty);
      final parsed = parsePack(jsonEncode(p));
      expect(
        (parsed as Right).value.sheets[0].days[0].tasks[0].cheer,
        'x' * 40,
      );

      p['sheets'][0]['days'][0]['tasks'][0]['cheer'] = '';
      expect(validatePack(p), [
        'sheets[0].days[0].tasks[0].cheer: must not be empty',
      ]);

      p['sheets'][0]['days'][0]['tasks'][0]['cheer'] = 'x' * 41;
      expect(validatePack(p), [
        'sheets[0].days[0].tasks[0].cheer: must be 40 characters or fewer',
      ]);
    });

    test('a task tip that is not text, blank, on two lines or over 80 '
        'characters, and loads one of 80 trimmed', () {
      final p = validPack();
      final task = p['sheets'][0]['days'][0]['tasks'][0];
      task['tip'] = ' ${'x' * 80} ';
      expect(validatePack(p), isEmpty);
      expect(
        (parsePack(jsonEncode(p)) as Right)
            .value
            .sheets[0]
            .days[0]
            .tasks[0]
            .tip,
        'x' * 80,
      );

      for (final (value, reason) in [
        (5, 'must be text'),
        ('   ', 'must not be empty'),
        ('Ask.\nWait.', 'must not have line breaks'),
        ('x' * 81, 'must be 80 characters or fewer'),
      ]) {
        task['tip'] = value;
        expect(validatePack(p), ['sheets[0].days[0].tasks[0].tip: $reason']);
      }
    });

    test('a card count that is not a whole number from 1 to 10, or has no '
        'picture, and loads a count of 10', () {
      final p = validPack();
      final card = <String, dynamic>{
        'word': 'ten',
        'picture': 'banana',
        'count': 10,
      };
      p['wordbooks'] = [
        {
          'id': 'count',
          'title': 'Count',
          'cards': [card],
        },
      ];
      expect(validatePack(p), isEmpty);
      final parsed = parsePack(jsonEncode(p));
      expect((parsed as Right).value.wordBooks[0].cards[0].count, 10);

      for (final n in [11, 0]) {
        card['count'] = n;
        expect(validatePack(p), [
          'wordbooks[0].cards[0].count: must be from 1 to 10',
        ]);
      }

      card['count'] = 2.5;
      expect(validatePack(p), [
        'wordbooks[0].cards[0].count: must be a whole number',
      ]);

      card
        ..['count'] = 3
        ..remove('picture')
        ..['big'] = '3';
      expect(validatePack(p), ['wordbooks[0].cards[0]: count needs a picture']);
    });

    test('a habit list with a missing id, a missing text, a repeated id, a '
        'bad picture or a bad sticker', () {
      final p = validPack();
      p['sheets'][0]['habits'] = [
        {'text': 'Bath', 'picture': 'soap'},
        {'id': 'teeth', 'picture': 'toothbrush'},
        {'id': 'teeth', 'text': 'Teeth at night', 'picture': 'moon'},
        {'id': 'lunch', 'text': 'Lunch', 'picture': 'Rice Bowl'},
        {'id': 'bath', 'text': 'Bath', 'picture': 'soap', 'sticker': 'bubbles'},
        {'id': 'play', 'text': 'Play', 'picture': 'ball', 'sticker': 'bubble'},
      ];
      expect(validatePack(p), [
        'sheets[0].habits[0]: id is missing',
        'sheets[0].habits[1]: text is missing',
        'sheets[0].habits[2].id: "teeth" is already used',
        'sheets[0].habits[3].picture: "Rice Bowl" is not a valid picture',
        'sheets[0].habits[5].sticker: "bubble" is not a sticker',
      ]);
    });
  });

  test(
    'parsePack gives a failure, never throws, for text that is not a pack',
    () {
      expect(
        (parsePack('{') as Left).value.message,
        'the file is not valid JSON',
      );
      expect(
        (parsePack('[]') as Left).value.message,
        'the file is not a Starbook pack',
      );
      expect(parsePack('\uFEFF${jsonEncode(validPack())}').isRight(), isTrue);
    },
  );

  test('every default pack loads from the app bundle and passes', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final result = await loadDefaultPacks();
    if (result.isLeft()) fail((result as Left).value.message);
    final files = Directory(
      'packs',
    ).listSync().where((f) => f.path.endsWith('.json')).length;
    expect((result as Right).value.length, files);
  });

  test('every task on the Little learner week sheet has a tip', () {
    final Pack pack =
        (parsePack(File('packs/sample-week.json').readAsStringSync()) as Right)
            .value;
    final sheet = pack.sheets.firstWhere((s) => s.id == 'little-learner');
    expect([
      for (final t in [
        for (final d in sheet.days) ...d.tasks,
        ...sheet.everyDay,
      ])
        if (t.tip == null) t.id,
    ], isEmpty);
  });
}
