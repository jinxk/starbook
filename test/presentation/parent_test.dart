import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:starbook/data/db/store_db.dart';
import 'package:starbook/data/repositories/sqlite_pack_repository.dart';
import 'package:starbook/data/repositories/sqlite_progress_repository.dart';
import 'package:starbook/data/repositories/sqlite_voice_repository.dart';
import 'package:starbook/domain/pack/pack.dart';
import 'package:starbook/domain/speaker.dart';
import 'package:starbook/main.dart';
import 'package:starbook/presentation/child/days.dart';
import 'package:starbook/presentation/providers.dart';
import 'package:starbook/presentation/sfx.dart';

class _Player extends Fake implements AudioPlayer {
  final played = <String>[];

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    played.add((source as AssetSource).path);
  }
}

class _Speaker extends Fake implements Speaker {
  final spoken = <(String, String)>[];

  @override
  Future<bool> speakSentence(
    String text,
    String language, {
    bool slow = false,
    void Function(int word)? onWord,
  }) async {
    spoken.add((text, language));
    return true;
  }

  @override
  Future<bool> speakWord(
    String text,
    String language, {
    bool slow = false,
  }) async {
    spoken.add((text, language));
    return true;
  }

  var stops = 0;

  @override
  Future<void> stop() async => stops++;
}

const _words = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
];

final _today = Weekday.values[DateTime.now().weekday - 1];

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

late Database _db;

Future<Widget> _app(
  WidgetTester tester,
  _Player player, {
  _Speaker? speaker,
  List<Object> milestones = const [],
  List<Object> habits = const [],
  List<Object> wordbooks = const [],
  List<Object> stories = const [],
}) async {
  final (db, packs) = (await tester.runAsync(() async {
    final db = (await openStore(
      databaseFactoryFfiNoIsolate,
      inMemoryDatabasePath,
    )).getOrElse((f) => throw StateError(f.message));
    final packs = SqlitePackRepository(db);
    await packs.install(
      jsonEncode({
        'starbook': 1,
        'id': 'home',
        'revision': 1,
        'title': 'Home',
        'sheets': [
          {
            'id': 'week',
            'title': 'Week',
            'days': [
              {
                'weekday': _today.name,
                'title': 'Letters',
                'tasks': [
                  {'id': 't1', 'text': 'Write A'},
                  {'id': 't2', 'text': 'Count'},
                ],
              },
            ],
            'everyDay': [
              {'id': 'e1', 'text': 'Read a story', 'bonus': true},
            ],
            'habits': habits,
          },
        ],
        'awards': [
          {'id': 'star', 'kind': 'star', 'label': 'Star'},
          {
            'id': 'sticker',
            'kind': 'sticker',
            'label': 'Sticker',
            'stickers': ['lion'],
          },
        ],
        'milestones': milestones,
        'wordbooks': wordbooks,
        'stories': stories,
      }),
    );
    return (db, packs);
  }))!;
  _db = db;
  addTearDown(db.close);
  return ProviderScope(
    overrides: [
      packRepositoryProvider.overrideWithValue(packs),
      voiceRepositoryProvider.overrideWithValue(
        SqliteVoiceRepository(db, Directory.systemTemp.path),
      ),
      progressRepositoryProvider.overrideWithValue(
        SqliteProgressRepository(db, packs),
      ),
      sfxProvider.overrideWithValue(Sfx(player)),
      speakerProvider.overrideWithValue(speaker ?? _Speaker()),
    ],
    child: const StarbookApp(),
  );
}

List<int> _shown(WidgetTester tester) {
  final words = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .firstWhere(RegExp(r'^[a-z]+, [a-z]+, [a-z]+$').hasMatch);
  return [for (final w in words.split(', ')) _words.indexOf(w)];
}

Future<void> _type(WidgetTester tester, List<int> digits) async {
  for (final d in digits) {
    await tester.tap(find.widgetWithText(OutlinedButton, '$d'));
    await tester.pump();
  }
  await _settle(tester);
}

Future<void> _openGate(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 350)),
  );
  await tester.tap(find.bySemanticsLabel('Grown-ups'));
  await _settle(tester);
}

Map<String, Object?> _home() => {
  'starbook': 1,
  'id': 'home',
  'revision': 1,
  'title': 'Home again',
  'sheets': [
    {
      'id': 'week',
      'title': 'Week',
      'days': [
        {
          'weekday': 'monday',
          'title': 'Mon',
          'tasks': [
            {'id': 't1', 'text': 'Write'},
            {'id': 't2', 'text': 'Count'},
          ],
        },
      ],
      'everyDay': [
        {'id': 'e1', 'text': 'Read'},
      ],
    },
  ],
};

Map<String, Object?> _file(String name, Map<String, Object?> pack) => {
  'name': name,
  'bytes': Uint8List.fromList(utf8.encode(jsonEncode(pack))),
};

final _diwaliFile = _file('diwali-week.json', {
  ..._home(),
  'id': 'diwali',
  'title': 'Diwali week',
  'author': 'Ms Rao',
  'stories': [
    {
      'id': 'diya',
      'title': 'The diya',
      'level': 1,
      'pages': [
        {'text': 'A diya.'},
      ],
    },
  ],
});

/// Files Android hands over on the next `take`, one per call.
List<Map<String, Object?>> _arrivals(WidgetTester tester) {
  final queue = <Map<String, Object?>>[];
  const channel = MethodChannel('starbook/open');
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    channel,
    (call) async => queue.isEmpty ? null : queue.removeAt(0),
  );
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return queue;
}

Future<void> _resume(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await _settle(tester);
  await _settle(tester);
}

Future<List<String>> _packIds(WidgetTester tester) async {
  final rows = await tester.runAsync(
    () => _db.query('packs', columns: ['id'], orderBy: 'id'),
  );
  return [for (final r in rows!) r['id']! as String];
}

Future<void> _done(WidgetTester tester) async {
  await tester.tap(find.text('Done'));
  await tester.pump();
  for (var i = 0; i < 24; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (i == 3) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
    }
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('the gate opens parent today only for the shown numbers, shows '
      'new numbers after a wrong try, and three wrong tries lock it for 60 '
      'seconds even across closing and reopening', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(await _app(tester, _Player()));
    await _settle(tester);

    await _openGate(tester);
    expect(find.text('Grown-ups only'), findsOneWidget);
    expect(find.text('Type the numbers'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      final before = _shown(tester);
      await _type(tester, [before[0] % 9 + 1, before[1], before[2]]);
      if (i < 2) expect(_shown(tester), isNot(before));
    }
    expect(find.text('Please wait a minute (60)'), findsOneWidget);
    expect(find.text('Type the numbers'), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, '1'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('MY STAR CHART'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await _openGate(tester);
    expect(find.textContaining('Please wait a minute'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(find.text('Type the numbers'), findsOneWidget);
    await _type(tester, _shown(tester));
    expect(find.text('Today, ${weekdayNames[_today.index]}'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an award given in parent today can be replaced and undone, and '
      'after Done the home lands only the award left live, once, with the '
      'typed reward', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final player = _Player();
    await tester.pumpWidget(await _app(tester, player));
    await _settle(tester);

    await _openGate(tester);
    await _type(tester, _shown(tester));
    for (final text in [
      'LETTERS',
      'Write A',
      'EVERY DAY (BONUS)',
      'Read a story',
      "THIS WEEK'S REWARD",
      'MORE',
      'Packs',
      '1 installed ›',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }

    await tester.tap(find.text('★ Star').first);
    await _settle(tester);
    expect(find.text('Star given for "Write A"'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('◐ Sticker').first);
    await _settle(tester);
    expect(find.text('Sticker given for "Write A"'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _settle(tester);

    await tester.enterText(find.byType(TextFormField), 'Park on Sunday');
    await _settle(tester);

    await _done(tester);
    expect(find.text('Park on Sunday'), findsOneWidget);
    expect(player.played, ['sounds/star-1.ogg']);
    semantics.dispose();
  });

  testWidgets('a trophy and a finished week reached in parent today are shown '
      'on home after the landings, week first, once each, and not again '
      'after a later award', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final player = _Player();
    final speaker = _Speaker();
    await tester.pumpWidget(
      await _app(
        tester,
        player,
        speaker: speaker,
        milestones: [
          {
            'id': 'first-star',
            'title': 'First star',
            'trophy': 'star-big',
            'when': {'stars': 1},
          },
        ],
      ),
    );
    await _settle(tester);

    await _openGate(tester);
    await _type(tester, _shown(tester));
    await tester.tap(find.text('★ Star').first);
    await _settle(tester);
    expect(find.text('A new trophy!'), findsNothing);
    await tester.tap(find.text('★ Star').at(1));
    await _settle(tester);
    await _done(tester);
    await _settle(tester);
    await _settle(tester);
    expect(find.text('You did the whole week!'), findsOneWidget);
    expect(player.played, ['sounds/star-1.ogg', 'sounds/star-2.ogg']);

    await tester.tapAt(const Offset(195, 422));
    await _settle(tester);
    expect(find.text('A new trophy!'), findsOneWidget);
    expect(find.text('First star'), findsOneWidget);
    expect(player.played.last, 'sounds/trophy.ogg');
    expect(speaker.spoken.map((s) => s.$1), ['A new trophy!', 'First star']);

    await tester.tapAt(const Offset(195, 422));
    await _settle(tester);
    expect(find.text('MY STAR CHART'), findsOneWidget);
    expect(find.text('A new trophy!'), findsNothing);
    expect(find.text('You did the whole week!'), findsNothing);

    await _openGate(tester);
    await _type(tester, _shown(tester));
    await tester.tap(find.text('◐ Sticker').at(1));
    await _settle(tester);
    await _done(tester);
    await _settle(tester);
    await _settle(tester);
    expect(find.text('You did the whole week!'), findsNothing);
    expect(find.text('A new trophy!'), findsNothing);
    expect(player.played.where((p) => p == 'sounds/trophy.ogg'), hasLength(1));

    await tester.tap(find.text('Trophies'));
    await _settle(tester);
    expect(find.text('My trophies'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('First star'));
    await _settle(tester);
    expect(find.text('First star!'), findsOneWidget);
    expect(find.textContaining('Earned on '), findsOneWidget);
    expect(speaker.spoken.map((s) => s.$1), [
      'A new trophy!',
      'First star',
      'First star',
    ]);
    await tester.pump(const Duration(seconds: 5));
    semantics.dispose();
  });

  testWidgets('a habit ticked on the habit screen plays one star note, a '
      'second tap changes nothing, and Undo in parent today lets the child '
      'tick it again', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final player = _Player();
    final speaker = _Speaker();
    await tester.pumpWidget(
      await _app(
        tester,
        player,
        speaker: speaker,
        habits: [
          {
            'id': 'teeth',
            'text': 'I brushed my teeth',
            'picture': 'toothbrush',
          },
          {'id': 'bath', 'text': 'I had my bath', 'picture': 'soap'},
        ],
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Habits'));
    await _settle(tester);
    await tester.tap(find.text('I brushed my teeth'));
    await _settle(tester);
    expect(player.played, ['sounds/star-1.ogg']);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.tap(find.text('I brushed my teeth'));
    await _settle(tester);
    expect(player.played, ['sounds/star-1.ogg']);
    expect(speaker.spoken.map((s) => s.$1), [
      'I brushed my teeth',
      'I brushed my teeth',
    ]);

    await tester.tap(find.text('I had my bath'));
    await _settle(tester);
    expect(player.played, ['sounds/star-1.ogg', 'sounds/star-2.ogg']);

    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    await _openGate(tester);
    await _type(tester, _shown(tester));
    expect(find.text('GOOD HABITS'), findsOneWidget);
    expect(find.text('Undo'), findsNWidgets(2));

    await tester.tap(find.text('Undo').first);
    await _settle(tester);
    expect(find.text('Undo'), findsOneWidget);
    await _done(tester);

    await tester.tap(find.text('Habits'));
    await _settle(tester);
    await tester.tap(find.text('I brushed my teeth'));
    await _settle(tester);
    expect(player.played, hasLength(3));
    expect(player.played.last, 'sounds/star-2.ogg');
    await tester.pump(const Duration(seconds: 2));
    semantics.dispose();
  });

  testWidgets('a word book read to its last card writes one finished row per '
      'visit, wordbooksDone counts distinct books, and the trophy it reaches '
      'celebrates on the shelf once', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final player = _Player();
    final speaker = _Speaker();
    await tester.pumpWidget(
      await _app(
        tester,
        player,
        speaker: speaker,
        milestones: [
          {
            'id': 'first-book',
            'title': 'First word book',
            'trophy': 'book-gold',
            'when': {'wordbooksDone': 1},
          },
        ],
        wordbooks: [
          {
            'id': 'short-a',
            'title': 'a as in cat',
            'letter': 'a',
            'colour': 'tomato',
            'cards': [
              {'word': 'cat', 'picture': 'cat'},
              {'word': 'hat', 'picture': 'hat'},
            ],
          },
          {
            'id': 'fruits',
            'title': 'Fruits',
            'colour': 'sand',
            'cards': [
              {'word': 'mango', 'picture': 'mango'},
            ],
          },
        ],
      ),
    );
    await _settle(tester);

    Future<int> rows() async =>
        (await tester.runAsync(() => _db.query('finished')))!.length;
    Future<int> books() async {
      final repo = ProviderScope.containerOf(
        tester.element(find.byType(StarbookApp)),
      ).read(progressRepositoryProvider);
      final counters = await tester.runAsync(repo.counters);
      return counters!
          .getOrElse((f) => throw StateError(f.message))
          .wordbooksDone;
    }

    Future<void> leave() async {
      await tester.binding.handlePopRoute();
      await _settle(tester);
      await _settle(tester);
    }

    await tester.tap(find.text('Words'));
    await _settle(tester);
    expect(find.text('Word books'), findsOneWidget);
    expect(find.text('a as in cat'), findsOneWidget);
    expect(find.text('Fruits'), findsOneWidget);

    await tester.tap(find.text('a as in cat'));
    await _settle(tester);
    expect(find.text('Tap to hear'), findsOneWidget);
    expect(speaker.spoken, contains(('cat', 'en-IN')));
    expect(await rows(), 0);

    await tester.tap(find.bySemanticsLabel('Next'));
    await _settle(tester);
    expect(find.text('All done!'), findsOneWidget);
    expect(player.played.last, 'sounds/flip.ogg');
    expect(speaker.stops, 1);

    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await _settle(tester);
    expect(find.text('Tap to hear'), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.tap(find.bySemanticsLabel('Next'));
    await _settle(tester);
    expect(find.text('All done!'), findsOneWidget);

    await leave();
    expect(find.text('A new trophy!'), findsOneWidget);
    expect(find.text('First word book'), findsOneWidget);
    expect(await rows(), 1);
    expect(await books(), 1);

    await tester.tapAt(const Offset(195, 422));
    await _settle(tester);
    expect(find.text('Word books'), findsOneWidget);
    expect(find.text('A new trophy!'), findsNothing);

    await tester.tap(find.text('a as in cat'));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Next'));
    await _settle(tester);
    await leave();
    expect(await rows(), 2);
    expect(await books(), 1);
    expect(find.text('A new trophy!'), findsNothing);
    expect(player.played.where((p) => p == 'sounds/trophy.ogg'), hasLength(1));

    await tester.tap(find.text('Fruits'));
    await _settle(tester);
    expect(find.text('All done!'), findsOneWidget);
    await leave();
    expect(await rows(), 3);
    expect(await books(), 2);

    await tester.pump(const Duration(seconds: 5));
    semantics.dispose();
  });

  testWidgets('a story read to its last page writes one finished row per '
      'visit, storiesRead counts distinct stories, and the trophy it reaches '
      'celebrates on the list once', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final player = _Player();
    await tester.pumpWidget(
      await _app(
        tester,
        player,
        milestones: [
          {
            'id': 'first-story',
            'title': 'First story',
            'trophy': 'book-gold',
            'when': {'storiesRead': 1},
          },
        ],
        stories: [
          {
            'id': 'hen',
            'title': 'The red hen',
            'level': 2,
            'pages': [
              {'text': 'The hen is red.', 'picture': 'hen'},
              {'text': 'I like the hen!', 'picture': 'hen'},
            ],
            'credit': {
              'source': 'StoryWeaver',
              'license': 'CC-BY-4.0',
              'text': 'Written by Asha',
            },
          },
          {
            'id': 'cat',
            'title': 'My cat',
            'level': 1,
            'cover': 'cat',
            'pages': [
              {'text': 'I see a cat.'},
            ],
          },
        ],
      ),
    );
    await _settle(tester);

    Future<int> rows() async =>
        (await tester.runAsync(() => _db.query('finished')))!.length;
    Future<int> read() async {
      final repo = ProviderScope.containerOf(
        tester.element(find.byType(StarbookApp)),
      ).read(progressRepositoryProvider);
      final counters = await tester.runAsync(repo.counters);
      return counters!
          .getOrElse((f) => throw StateError(f.message))
          .storiesRead;
    }

    Future<void> leave() async {
      await tester.binding.handlePopRoute();
      await _settle(tester);
      await _settle(tester);
    }

    await tester.tap(find.text('Stories'));
    await _settle(tester);
    expect(
      tester.getTopLeft(find.text('My cat')).dy,
      lessThan(tester.getTopLeft(find.text('The red hen')).dy),
    );

    await tester.tap(find.text('The red hen'));
    await _settle(tester);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.text('The end.'), findsNothing);
    expect(await rows(), 0);

    await tester.tap(find.bySemanticsLabel('Next page'));
    await _settle(tester);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('The end.'), findsOneWidget);
    expect(find.text('Written by Asha'), findsOneWidget);
    expect(find.text('StoryWeaver, CC-BY-4.0'), findsOneWidget);
    expect(player.played.last, 'sounds/flip.ogg');

    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await _settle(tester);
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.tap(find.bySemanticsLabel('Next page'));
    await _settle(tester);
    expect(find.text('2 of 2'), findsOneWidget);

    await leave();
    expect(find.text('A new trophy!'), findsOneWidget);
    expect(find.text('First story'), findsOneWidget);
    expect(await rows(), 1);
    expect(await read(), 1);

    await tester.tapAt(const Offset(195, 422));
    await _settle(tester);
    expect(find.text('Stories'), findsOneWidget);
    expect(find.text('A new trophy!'), findsNothing);

    await tester.tap(find.text('The red hen'));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Next page'));
    await _settle(tester);
    await leave();
    expect(await rows(), 2);
    expect(await read(), 1);
    expect(find.text('A new trophy!'), findsNothing);
    expect(player.played.where((p) => p == 'sounds/trophy.ogg'), hasLength(1));

    await tester.tap(find.text('My cat'));
    await _settle(tester);
    expect(find.text('The end.'), findsOneWidget);
    await leave();
    expect(await rows(), 3);
    expect(await read(), 2);

    await tester.pump(const Duration(seconds: 5));
    semantics.dispose();
  });

  testWidgets('a file opened with Starbook waits for the gate: leaving the '
      'gate drops it, and after the gate the preview shows before anything '
      'is added', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final arrivals = _arrivals(tester);
    arrivals.add(_diwaliFile);
    await tester.pumpWidget(await _app(tester, _Player()));
    await _settle(tester);
    expect(find.text('Grown-ups only'), findsOneWidget);
    expect(find.text('Add this pack?'), findsNothing);

    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('MY STAR CHART'), findsOneWidget);
    await _openGate(tester);
    await _type(tester, _shown(tester));
    await _settle(tester);
    expect(find.text('Today, ${weekdayNames[_today.index]}'), findsOneWidget);
    expect(find.text('Add this pack?'), findsNothing);
    expect(await _packIds(tester), ['home']);

    arrivals.add(_diwaliFile);
    await _resume(tester);
    expect(find.text('Grown-ups only'), findsOneWidget);
    expect(find.text('Add this pack?'), findsNothing);
    expect(await _packIds(tester), ['home']);
    await _type(tester, _shown(tester));
    await _settle(tester);
    expect(find.text('Add this pack?'), findsOneWidget);
    expect(
      find.text('diwali-week.json · revision 1 · from Ms Rao'),
      findsOneWidget,
    );
    expect(find.text('1 sheet: 1 day, 3 tasks'), findsOneWidget);
    expect(find.text('1 story'), findsOneWidget);
    expect(await _packIds(tester), ['home']);

    await tester.tap(find.text('Add'));
    await _settle(tester);
    expect(find.text('Added: Diwali week'), findsOneWidget);
    expect(find.text('Diwali week'), findsWidgets);
    expect(await _packIds(tester), ['diwali', 'home']);

    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    expect(find.text('2 installed ›'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('on the packs screen a bad file changes nothing, the same '
      'revision asks before it replaces, and remove asks first while the '
      'pack with the only awards cannot be removed', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final arrivals = _arrivals(tester);
    await tester.pumpWidget(await _app(tester, _Player()));
    await _settle(tester);

    Future<void> arrive(Map<String, Object?> file) async {
      arrivals.add(file);
      await _resume(tester);
      await _type(tester, _shown(tester));
      await _settle(tester);
    }

    await arrive(_file('bad.json', {'starbook': 1, 'id': 'x', 'revision': 1}));
    expect(find.text('This file could not be added.'), findsOneWidget);
    expect(find.text('title is missing'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await _settle(tester);
    expect(await _packIds(tester), ['home']);

    await arrive(_file('home.json', {..._home(), 'title': 'Home again'}));
    expect(find.text('Replace this pack?'), findsOneWidget);
    expect(
      find.text('This pack is already added at revision 1.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    final stored = await tester.runAsync(() => _db.query('packs'));
    expect(stored!.single['title'], 'Home');

    await arrive(_diwaliFile);
    await tester.tap(find.text('Add'));
    await _settle(tester);
    expect(await _packIds(tester), ['diwali', 'home']);

    final home = find.byKey(const ValueKey('home'));
    expect(
      find.descendant(of: home, matching: find.text('Remove')),
      findsNothing,
    );
    expect(
      find.descendant(of: home, matching: find.text('Needed for the awards.')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('diwali')),
        matching: find.text('Remove'),
      ),
    );
    await _settle(tester);
    expect(find.text('Remove this pack?'), findsOneWidget);
    expect(find.text('Stars already given stay.'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Remove'),
      ),
    );
    await _settle(tester);
    expect(find.text('Diwali week'), findsNothing);
    expect(await _packIds(tester), ['home']);
    semantics.dispose();
  });
}
