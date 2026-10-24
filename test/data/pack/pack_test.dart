import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:starbook/data/pack/default_packs.dart';
import 'package:starbook/data/pack/pack_parser.dart';
import 'package:starbook/data/pack/pack_validator.dart';
import 'package:starbook/domain/pack/pack.dart';
import 'package:starbook/domain/progress/progress.dart';

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

    test('a story page ask that is not text, blank, on two lines or over 45 '
        'characters, and loads one of 45 trimmed', () {
      final p = validPack();
      final page = <String, dynamic>{'text': 'I see a cat.'};
      p['stories'] = [
        {
          'id': 's',
          'title': 'S',
          'level': 1,
          'pages': [page],
        },
      ];
      page['ask'] = ' ${'x' * 45} ';
      expect(validatePack(p), isEmpty);
      expect(
        (parsePack(jsonEncode(p)) as Right).value.stories[0].pages[0].ask,
        'x' * 45,
      );

      for (final (value, reason) in [
        (5, 'must be text'),
        ('   ', 'must not be empty'),
        ('Ask.\nWait.', 'must not have line breaks'),
        ('x' * 46, 'must be 45 characters or fewer'),
      ]) {
        page['ask'] = value;
        expect(validatePack(p), ['stories[0].pages[0].ask: $reason']);
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

  test('an opens of number-board passes the pack check and opens the board; an '
      'opens this app does not know passes and opens nothing', () {
    final p = validPack();
    final sheet = (p['sheets'] as List).first as Map<String, dynamic>;
    final days = sheet['days'] as List;
    final everyDay = sheet['everyDay'] as List;
    ((days.first as Map)['tasks'] as List).first['opens'] = 'number-board';
    (everyDay.first as Map)['opens'] = 'clock-game';
    expect(validatePack(p), isEmpty);
    final Pack pack = (parsePack(jsonEncode(p)) as Right).value;
    expect(
      bookKindOf([pack], 'test.pack/week', 'number-board'),
      BookKind.board,
    );
    expect(bookKindOf([pack], 'test.pack/week', 'clock-game'), isNull);
  });

  test('the Little learner week has the four cue habits in day order, and the '
      'school sheet keeps its six habit ids', () {
    final Pack pack =
        (parsePack(File('packs/sample-week.json').readAsStringSync()) as Right)
            .value;
    List<String> habitIds(String sheet) => [
      for (final h in pack.sheets.firstWhere((s) => s.id == sheet).habits) h.id,
    ];
    expect(habitIds('little-learner'), [
      'teeth-morning',
      'own-hands',
      'toys',
      'teeth-night',
    ]);
    expect(habitIds('superstar-week'), [
      'bath',
      'teeth-morning',
      'teeth-night',
      'breakfast',
      'lunch',
      'dinner',
    ]);
  });

  test('the Letter sounds book has A to Z once each, B D P T K first and C, W '
      'last, its word is the letter pair, and no consonant says its sound as a '
      'bare letter (read as its name)', () {
    final json =
        jsonDecode(File('packs/vowels.json').readAsStringSync())
            as Map<String, dynamic>;
    final book =
        (json['wordbooks'] as List).firstWhere(
              (b) => (b as Map)['id'] == 'letter-sounds',
            )
            as Map<String, dynamic>;
    final say = RegExp(r'^([A-Z])\. \1 says ([a-z]+)[.,] ');
    final letters = <String>[];
    for (final card in (book['cards'] as List).cast<Map<String, dynamic>>()) {
      final m = say.firstMatch(card['say'] as String);
      expect(m, isNotNull, reason: card['say'] as String);
      final letter = m!.group(1)!;
      expect(card['word'], '$letter${letter.toLowerCase()}');
      if (!'AEIOU'.contains(letter)) {
        expect(m.group(2)!.length, greaterThan(1), reason: letter);
      }
      letters.add(letter);
    }
    expect(letters.toSet().length, 26);
    expect(letters.take(5), ['B', 'D', 'P', 'T', 'K']);
    expect(letters.skip(24), ['C', 'W']);
  });

  test('the Sound games book has its clap, rhyme and first sound cards in that '
      'order, rhyme is not the largest group, every clap card says its word in '
      'beats and claps once for each beat, and no first sound line ends on a '
      'bare letter (read as its name)', () {
    final json =
        jsonDecode(File('packs/vowels.json').readAsStringSync())
            as Map<String, dynamic>;
    final book =
        (json['wordbooks'] as List).firstWhere(
              (b) => (b as Map)['id'] == 'sound-games',
            )
            as Map<String, dynamic>;
    final cards = (book['cards'] as List).cast<Map<String, dynamic>>();
    final groups = <String>[];
    final counts = <String, int>{};
    for (final card in cards) {
      final group = card['group'] as String;
      if (groups.isEmpty || groups.last != group) groups.add(group);
      counts[group] = (counts[group] ?? 0) + 1;
    }
    expect(groups, ['Clap', 'Rhyme', 'First sound']);
    expect(counts['Rhyme'], lessThan(counts.values.reduce(max)));

    final clap = RegExp(
      r'^([A-Z][a-z]+)\. ([A-Z][a-z]*(?:, [a-z]+)+)\. Clap (\d+) times!$',
    );
    final first = RegExp(
      r'^([A-Z][a-z]+(?:, [a-z]+)+)\. They all start with ([a-z]+)\.$',
    );
    for (final card in cards) {
      final say = card['say'] as String;
      switch (card['group']) {
        case 'Clap':
          final m = clap.firstMatch(say);
          expect(m, isNotNull, reason: say);
          final beats = m!.group(2)!.split(', ');
          expect(beats.join().toLowerCase(), m.group(1)!.toLowerCase());
          expect(int.parse(m.group(3)!), beats.length);
          expect(card['word'], beats.join('-').toLowerCase());
        case 'First sound':
          final m = first.firstMatch(say);
          expect(m, isNotNull, reason: say);
          final sound = m!.group(2)!;
          expect(sound.length, greaterThan(1), reason: say);
          for (final word in m.group(1)!.toLowerCase().split(', ')) {
            expect(word.startsWith(sound[0]), isTrue, reason: say);
          }
      }
    }
  });

  test('every card in the fruits, vegetables, animals and helpers books says '
      'its word, then one meaning sentence under 8 words', () {
    final json =
        jsonDecode(File('packs/topics.json').readAsStringSync())
            as Map<String, dynamic>;
    const ids = ['fruits', 'vegetables', 'animals', 'helpers'];
    final books = (json['wordbooks'] as List)
        .cast<Map<String, dynamic>>()
        .where((b) => ids.contains(b['id']))
        .toList();
    expect(books.map((b) => b['id']).toSet(), ids.toSet());
    final shape = RegExp(r'^([^.!?]+)\. ([A-Z][^.!?]*)\.$');
    for (final book in books) {
      for (final card in (book['cards'] as List).cast<Map<String, dynamic>>()) {
        final say = card['say'];
        expect(say, isA<String>(), reason: '${card['word']}');
        final m = shape.firstMatch(say as String);
        expect(m, isNotNull, reason: say);
        if (card['word'] != 'chikoo') {
          expect(m!.group(1)!.toLowerCase(), card['word'], reason: say);
        }
        expect(m!.group(2)!.split(' ').length, lessThan(8), reason: say);
      }
    }
  });

  test('the Shapes book keeps its first 8 cards in order with a not-a card '
      'after circle, square and triangle, and the Patterns book is question '
      'and answer pairs of AB patterns whose answer is what comes next', () {
    final json =
        jsonDecode(File('packs/topics.json').readAsStringSync())
            as Map<String, dynamic>;
    final books = (json['wordbooks'] as List).cast<Map<String, dynamic>>();
    final shapesAt = books.indexWhere((b) => b['id'] == 'shapes');
    List<Map<String, dynamic>> cardsOf(Map<String, dynamic> b) =>
        (b['cards'] as List).cast<Map<String, dynamic>>();
    final shapes = cardsOf(books[shapesAt]);

    final old = shapes.where(
      (c) => !(c['word'] as String).startsWith('not a '),
    );
    expect(old.map((c) => c['word']), [
      'circle',
      'square',
      'triangle',
      'rectangle',
      'star',
      'heart',
      'oval',
      'diamond',
    ]);
    expect(old.every((c) => c['say'] == null), isTrue);
    final notA = <int>[];
    for (var i = 0; i < shapes.length; i++) {
      final word = shapes[i]['word'] as String;
      if (!word.startsWith('not a ')) continue;
      notA.add(i);
      final shape = shapes[i - 1];
      expect(word, 'not a ${shape['word']}');
      expect(shapes[i]['say'], matches(RegExp('^This is $word\\. [^.]+\\.\$')));
      expect(shapes[i]['picture'], isNot(shape['picture']));
    }
    expect(notA.length, 3);

    final patterns = books[shapesAt + 1];
    expect(patterns['id'], 'patterns');
    final cards = cardsOf(patterns);
    expect(cards.length.isEven, isTrue);
    expect(cards.length, inInclusiveRange(4, 10));
    String cap(String s) => s[0].toUpperCase() + s.substring(1);
    final ask = RegExp(r'^([A-Z][a-z]+(?:, [a-z]+)+)\. What comes next\?$');
    for (var i = 0; i < cards.length; i += 2) {
      final q = cards[i];
      final a = cards[i + 1];
      final m = ask.firstMatch(q['say'] as String);
      expect(m, isNotNull, reason: '${q['say']}');
      final items = m!.group(1)!.toLowerCase().split(', ');
      expect(items.length, greaterThanOrEqualTo(3));
      expect(items[0], isNot(items[1]));
      for (var k = 0; k < items.length; k++) {
        expect(items[k], items[k % 2], reason: '${q['say']}');
      }
      final answer = items[items.length % 2];
      expect(a['word'], answer);
      expect(
        a['say'],
        '${cap(answer)}! ${cap([...items, answer].join(', '))}.',
      );
      expect(a['picture'], '${q['picture']}-next');
    }
  });

  test('every card in the Shapes and Patterns books, and both titles, has a '
      'Heart clip', () {
    final voice =
        jsonDecode(
              utf8.decode(
                ZipDecoder()
                        .decodeBytes(
                          File(
                            'assets/voices/heart.starbook-voice',
                          ).readAsBytesSync(),
                        )
                        .find('voice.json')!
                        .content
                    as List<int>,
              ),
            )
            as Map<String, dynamic>;
    final clips = {
      for (final c in (voice['clips'] as List).cast<Map<String, dynamic>>())
        c['text'] as String,
    };
    final json =
        jsonDecode(File('packs/topics.json').readAsStringSync())
            as Map<String, dynamic>;
    final books = (json['wordbooks'] as List)
        .cast<Map<String, dynamic>>()
        .where((b) => b['id'] == 'shapes' || b['id'] == 'patterns');
    expect(books.length, 2);
    for (final book in books) {
      expect(clips, contains(book['title']));
      for (final card in (book['cards'] as List).cast<Map<String, dynamic>>()) {
        expect(clips, contains(card['say'] ?? card['word']));
      }
    }
  });

  test('every default story page has an ask, and each story has one ask that '
      'points to a word on its page', () {
    final point = RegExp(r"^Point to the word '([^']+)'\.$");
    final problems = <String>[];
    for (final file in Directory(
      'packs',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.json'))) {
      final Pack pack = (parsePack(file.readAsStringSync()) as Right).value;
      for (final story in pack.stories) {
        var points = 0;
        for (var n = 0; n < story.pages.length; n++) {
          final page = story.pages[n];
          final ask = page.ask;
          if (ask == null) {
            problems.add('${story.id} page ${n + 1}: no ask');
            continue;
          }
          final word = point.firstMatch(ask)?.group(1);
          if (word == null) continue;
          points++;
          final onPage = [
            for (final w in page.text.toLowerCase().split(' '))
              w.replaceAll(RegExp(r'[^\w]'), ''),
          ];
          if (!onPage.contains(word.toLowerCase())) {
            problems.add('${story.id} page ${n + 1}: $word is not on the page');
          }
        }
        if (points != 1) problems.add('${story.id}: $points point asks');
      }
    }
    expect(problems, isEmpty);
  });
}
