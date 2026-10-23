import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, left;
import 'package:lottie/lottie.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:starbook/data/db/store_db.dart';
import 'package:starbook/data/repositories/sqlite_pack_repository.dart';
import 'package:starbook/data/repositories/sqlite_progress_repository.dart';
import 'package:starbook/data/repositories/sqlite_voice_repository.dart';
import 'package:starbook/domain/failure.dart';
import 'package:starbook/domain/pack/pack.dart';
import 'package:starbook/domain/progress/progress.dart';
import 'package:starbook/domain/speaker.dart';
import 'package:starbook/main.dart';
import 'package:starbook/presentation/child/days.dart';
import 'package:starbook/presentation/child/sticker_book_screen.dart';
import 'package:starbook/presentation/providers.dart';
import 'package:starbook/presentation/router.dart';
import 'package:starbook/presentation/sfx.dart';
import 'package:starbook/presentation/widgets/award_mark.dart';
import 'package:starbook/presentation/widgets/back_disc.dart';
import 'package:starbook/presentation/widgets/picture.dart';
import 'package:starbook/presentation/widgets/plain_line.dart';
import 'package:starbook/presentation/widgets/sticker_view.dart';

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
  bool slowReading = false;

  @override
  Future<bool> speakSentence(
    String text,
    String language, {
    bool? slow,
    void Function(int word)? onWord,
  }) async {
    spoken.add((text, language));
    return true;
  }

  @override
  Future<bool> speakWord(String text, String language, {bool? slow}) async {
    spoken.add((text, language));
    return true;
  }

  var stops = 0;

  @override
  Future<void> stop() async => stops++;

  @override
  Future<VoiceStatus> voiceStatus(String language) async =>
      (installed: true, offline: true);
}

class _NoWrites extends SqliteProgressRepository {
  _NoWrites(super.db, super.packs);

  @override
  Future<Either<Failure, GivenAward>> give({
    required int weekId,
    required Weekday weekday,
    required String taskId,
    required String awardRef,
    int? replaces,
  }) async => left(const Failure('SqliteException(10): disk I/O error'));
}

final _today = Weekday.values[DateTime.now().weekday - 1];

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _run(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _load(WidgetTester tester) => tester.runAsync(
  () => Future<void>.delayed(const Duration(milliseconds: 200)),
);

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
  bool noWrites = false,
  List<Object>? awards,
  List<Object>? tasks,
  List<String> morePacks = const [],
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
                'tasks':
                    tasks ??
                    [
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
        'awards':
            awards ??
            [
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
    for (final text in morePacks) {
      await packs.install(text);
    }
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
        noWrites ? _NoWrites(db, packs) : SqliteProgressRepository(db, packs),
      ),
      sfxProvider.overrideWithValue(Sfx(player)),
      speakerProvider.overrideWithValue(speaker ?? _Speaker()),
    ],
    child: const StarbookApp(),
  );
}

String _question(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .whereType<String>()
    .firstWhere(RegExp(r'^\d+ [+−×] \d+$').hasMatch);

/// The digits of the right answer to the question on screen.
List<int> _shown(WidgetTester tester) {
  final p = _question(tester).split(' ');
  final a = int.parse(p[0]);
  final b = int.parse(p[2]);
  final answer = switch (p[1]) {
    '+' => a + b,
    '−' => a - b,
    _ => a * b,
  };
  return '$answer'.split('').map(int.parse).toList();
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

  testWidgets('the gate opens parent today only for the right answer, shows '
      'a new sum after a wrong try, and three wrong tries lock it for 60 '
      'seconds even across closing and reopening', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(await _app(tester, _Player()));
    await _settle(tester);

    await _openGate(tester);
    expect(find.text('Grown-ups only'), findsOneWidget);
    expect(find.text('Type the answer'), findsOneWidget);
    final p = _question(tester).split(' ');
    final word = {'+': 'plus', '−': 'minus', '×': 'times'}[p[1]];
    expect(find.bySemanticsLabel('${p[0]} $word ${p[2]}'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      final before = _question(tester);
      final answer = _shown(tester);
      await _type(tester, [answer[0] % 9 + 1, answer[1]]);
      if (i < 2) expect(_question(tester), isNot(before));
    }
    expect(find.text('Please wait a minute (60)'), findsOneWidget);
    expect(find.text('Type the answer'), findsNothing);
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
    expect(find.text('Type the answer'), findsOneWidget);
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
    expect(
      find.text('Now tell your child what was done, with a high five.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Undo'));
    await _settle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StarbookApp)),
    );
    await tester.runAsync(
      () => container
          .read(progressRepositoryProvider)
          .setChild(const Child(name: 'Asha')),
    );
    await tester.tap(find.text('◐ Sticker').first);
    await _settle(tester);
    expect(
      find.text('Now tell Asha what was done, with a high five.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Undo'));
    await _settle(tester);

    await tester.enterText(find.byType(TextFormField), 'Park on Sunday');
    await _settle(tester);

    await _done(tester);
    expect(find.text('Park on Sunday'), findsOneWidget);
    expect(player.played, ['sounds/star-1.ogg']);
    semantics.dispose();
  });

  testWidgets('a give that the store refuses shows the calm line, never the '
      "store's text, and changes nothing", (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(await _app(tester, _Player(), noWrites: true));
    await _settle(tester);

    await _openGate(tester);
    await _type(tester, _shown(tester));
    await tester.tap(find.text('★ Star').first);
    await _settle(tester);
    expect(find.text(notSaved), findsOneWidget);
    expect(find.textContaining('Sqlite'), findsNothing);
    expect(await tester.runAsync(() => _db.query('awards')), isEmpty);
    semantics.dispose();
  });

  testWidgets('Star, Very good! and Well done! awards given under the old '
      'default pack still show as given after the new default pack installs, '
      'parent today offers only Sticker, and a sticker still counts 1 star', (
    tester,
  ) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final text = File('packs/basics.json').readAsStringSync();
    final old = jsonDecode(text) as Map<String, dynamic>;
    old['revision'] = 3;
    for (final a in old['awards'] as List) {
      (a as Map<String, dynamic>).remove('retired');
    }
    await tester.pumpWidget(
      await _app(tester, _Player(), awards: [], morePacks: [jsonEncode(old)]),
    );
    await _settle(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StarbookApp)),
    );
    await tester.runAsync(() async {
      final progress = container.read(progressRepositoryProvider);
      final week = (await progress.currentWeek()).getOrElse(
        (f) => throw StateError(f.message),
      )!;
      for (final (task, award) in [
        ('t1', 'shabash'),
        ('t2', 'star'),
        ('e1', 'very-good'),
      ]) {
        final given = await progress.give(
          weekId: week.id,
          weekday: _today,
          taskId: task,
          awardRef: 'starbook.basics/$award',
        );
        expect(given.isRight(), isTrue, reason: award);
      }
      await container.read(packRepositoryProvider).start([text]);
      final counters = (await progress.counters()).getOrElse(
        (f) => throw StateError(f.message),
      );
      expect(counters.stars, 3);
    });
    final basics = container
        .read(packRepositoryProvider)
        .installed
        .firstWhere((p) => p.id == 'starbook.basics');
    expect(basics.awards.where((a) => !a.retired).map((a) => a.id), [
      'sticker',
    ]);
    expect(basics.awards.firstWhere((a) => a.id == 'sticker').stars, 1);

    await _openGate(tester);
    await _type(tester, _shown(tester));
    expect(find.text('◐ Sticker'), findsNWidgets(3));
    for (final gone in ['★ Star', 'Very good!', 'Well done!']) {
      expect(find.text(gone), findsNothing, reason: gone);
    }

    await _done(tester);
    await tester.pump(const Duration(seconds: 3));
    for (final stamp in ['Well done!', 'Very good!']) {
      expect(
        find.descendant(of: find.byType(AwardMark), matching: find.text(stamp)),
        findsOneWidget,
        reason: stamp,
      );
      expect(find.bySemanticsLabel(RegExp(stamp)), findsOneWidget);
    }
    expect(find.bySemanticsLabel(RegExp('Star')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a trophy and a finished week reached in parent today are shown '
      'on home after the landings, the day line, then week first, once each; '
      "today's card waits for them and says its line once, not again after "
      'the award is replaced', (tester) async {
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
    expect(find.text('All done for today.\nTime to play!'), findsNothing);
    await _run(tester, 1100);
    expect(player.played, [
      'sounds/star-1.ogg',
      'sounds/star-2.ogg',
      'sounds/star-5.ogg',
      'sounds/trophy.ogg',
    ]);

    await tester.tapAt(const Offset(195, 422));
    await _settle(tester);
    expect(find.text('A new trophy!'), findsOneWidget);
    expect(find.text('First star'), findsOneWidget);
    expect(player.played.last, 'sounds/trophy.ogg');
    expect(speaker.spoken.map((s) => s.$1), [
      'You finished ${weekdayNames[_today.index]}!',
      'You did the whole week!',
      'A new trophy!',
      'First star',
    ]);

    await tester.tapAt(const Offset(195, 422));
    await _settle(tester);
    expect(find.text('MY STAR CHART'), findsOneWidget);
    expect(find.text('A new trophy!'), findsNothing);
    expect(find.text('You did the whole week!'), findsNothing);
    expect(find.text('All done for today.\nTime to play!'), findsOneWidget);
    expect(speaker.spoken.last.$1, 'All done for today. Time to play!');

    await _openGate(tester);
    await _type(tester, _shown(tester));
    await tester.tap(find.text('◐ Sticker').at(1));
    await _settle(tester);
    await _done(tester);
    await _settle(tester);
    await _settle(tester);
    // The new sticker opens big over home first.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('You did the whole week!'), findsNothing);
    expect(find.text('A new trophy!'), findsNothing);
    expect(player.played.where((p) => p == 'sounds/trophy.ogg'), hasLength(2));

    await tester.tap(find.text('Trophies'));
    await _settle(tester);
    expect(find.text('My trophies'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('First star'));
    await _settle(tester);
    expect(find.text('First star!'), findsOneWidget);
    expect(find.textContaining('Earned on '), findsOneWidget);
    expect(speaker.spoken.map((s) => s.$1), [
      'You finished ${weekdayNames[_today.index]}!',
      'You did the whole week!',
      'A new trophy!',
      'First star',
      'All done for today. Time to play!',
      'A sticker for you!',
      'First star',
    ]);
    await tester.pump(const Duration(seconds: 5));
    semantics.dispose();
  });

  testWidgets('a ticked habit presses in its own sticker or its own picture, '
      'the last habit of the day plays All done! and reveals one new book '
      'sticker, and a parent Undo and a re-tick give nothing more and take '
      'nothing back', (tester) async {
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
          {'id': 'teeth', 'text': 'I brushed my teeth', 'picture': 'moon'},
          {
            'id': 'bath',
            'text': 'I had my bath',
            'picture': 'soap',
            'sticker': 'bubbles',
          },
        ],
      ),
    );
    await _settle(tester);
    final moon = find.byWidgetPredicate(
      (w) =>
          w is SvgPicture &&
          w.bytesLoader is SvgAssetLoader &&
          (w.bytesLoader as SvgAssetLoader).assetName ==
              'assets/pictures/moon.svg',
    );
    final reveal = find.byWidgetPredicate(
      (w) => w is StickerView && w.size == 240,
    );
    Future<List<Map<String, Object?>>> bonusRows() => tester
        .runAsync(() => _db.query('awards', where: "task_id = 'habits:done'"))
        .then((rows) => rows!);

    await tester.tap(find.text('Habits'));
    await _settle(tester);
    await tester.tap(find.text('I brushed my teeth'));
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 700));
    expect(player.played, ['sounds/peel.ogg', 'sounds/press.ogg']);
    expect(moon, findsNWidgets(4));
    expect(find.byType(LottieBuilder), findsNothing);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.tap(find.text('I brushed my teeth'));
    await _settle(tester);
    expect(player.played, ['sounds/peel.ogg', 'sounds/press.ogg']);
    expect(speaker.spoken.map((s) => s.$1), [
      'I brushed my teeth',
      'I brushed my teeth',
    ]);
    expect(await bonusRows(), isEmpty);

    await tester.tap(find.text('I had my bath'));
    await tester.pump();
    await _load(tester);
    await _run(tester, 1200);
    expect(player.played, [
      'sounds/peel.ogg',
      'sounds/press.ogg',
      'sounds/peel.ogg',
      'sounds/press.ogg',
    ]);
    expect(find.text('All done!'), findsOneWidget);
    expect(speaker.spoken.map((s) => s.$1).toList().reversed.take(2), [
      'All done! A new sticker for you!',
      'I had my bath',
    ]);
    expect(reveal, findsNothing);
    await _run(tester, 3300);
    expect(find.text('All done!'), findsNothing);
    expect(reveal, findsOneWidget);
    expect(player.played.last, startsWith('sticker-sounds/'));
    await _load(tester);
    await _run(tester, 3400);
    expect(reveal, findsNothing);
    expect(await bonusRows(), hasLength(1));

    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    await _run(tester, 3000);
    expect(reveal, findsNothing);
    await _openGate(tester);
    await _type(tester, _shown(tester));
    expect(find.text('GOOD HABITS'), findsOneWidget);
    expect(find.text('Undo'), findsNWidgets(2));

    await tester.tap(find.text('Undo').first);
    await _settle(tester);
    expect(find.text('Undo'), findsOneWidget);
    await _done(tester);

    final before = player.played.length;
    await tester.tap(find.text('Habits'));
    await _settle(tester);
    await tester.tap(find.text('I brushed my teeth'));
    await _settle(tester);
    await _run(tester, 6000);
    expect(player.played.skip(before), ['sounds/peel.ogg', 'sounds/press.ogg']);
    expect(find.text('All done!'), findsNothing);
    expect(reveal, findsNothing);
    final rows = await bonusRows();
    expect(rows, hasLength(1));
    expect(rows.single['undone_at'], isNull);
    semantics.dispose();
  });

  testWidgets('a parent Tick on the last habit of today shows the all-done '
      'line, and home then plays All done! and reveals the new sticker once', (
    tester,
  ) async {
    _phone(tester);
    final player = _Player();
    final speaker = _Speaker();
    await tester.pumpWidget(
      await _app(
        tester,
        player,
        speaker: speaker,
        habits: [
          {'id': 'teeth', 'text': 'I brushed my teeth', 'picture': 'moon'},
        ],
      ),
    );
    await _settle(tester);
    final reveal = find.byWidgetPredicate(
      (w) => w is StickerView && w.size == 240,
    );

    await _openGate(tester);
    await _type(tester, _shown(tester));
    await tester.tap(find.text('Tick'));
    await _settle(tester);
    expect(
      find.text('All habits done for today. A new sticker is in the book.'),
      findsOneWidget,
    );
    final rows = await tester.runAsync(
      () => _db.query('awards', where: "task_id = 'habits:done'"),
    );
    expect(rows, hasLength(1));
    expect(find.text('All done!'), findsNothing);

    await _done(tester);
    expect(find.text('All done!'), findsOneWidget);
    expect(
      speaker.spoken.map((s) => s.$1),
      contains('All done! A new sticker for you!'),
    );
    expect(reveal, findsNothing);
    await _run(tester, 3000);
    expect(find.text('All done!'), findsNothing);
    expect(reveal, findsOneWidget);
    await _load(tester);
    await _run(tester, 3400);
    expect(reveal, findsNothing);

    await _openGate(tester);
    await _type(tester, _shown(tester));
    await _done(tester);
    await _load(tester);
    await _run(tester, 3000);
    expect(find.text('All done!'), findsNothing);
    expect(reveal, findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('home keeps the All done! moment while another screen is over '
      'it, and plays it once on the next home load', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      await _app(
        tester,
        _Player(),
        speaker: _Speaker(),
        habits: [
          {'id': 'teeth', 'text': 'I brushed my teeth', 'picture': 'moon'},
        ],
      ),
    );
    await _settle(tester);

    await _openGate(tester);
    await _type(tester, _shown(tester));
    await tester.tap(find.text('Tick'));
    await _settle(tester);
    // A load that finishes with another screen over home, as a finished story
    // or word book causes.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StarbookApp)),
    );
    container.read(routerProvider).go('/stickers');
    await _settle(tester);
    container.invalidate(thisWeekProvider);
    await _run(tester, 1000);
    expect(find.byType(StickerBookScreen), findsOneWidget);
    expect(find.text('All done!'), findsNothing);

    await tester.binding.handlePopRoute();
    await _run(tester, 1000);
    expect(find.text('All done!'), findsNothing);
    await _openGate(tester);
    await _type(tester, _shown(tester));
    await _done(tester);
    expect(find.text('All done!'), findsOneWidget);
    await _run(tester, 3300);
    await _load(tester);
    await _run(tester, 3400);
    expect(find.text('All done!'), findsNothing);
    semantics.dispose();
  });

  testWidgets('Back does nothing in the wait after the last tick, and the '
      'All done! moment still opens', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      await _app(
        tester,
        _Player(),
        speaker: _Speaker(),
        habits: [
          {'id': 'teeth', 'text': 'I brushed my teeth', 'picture': 'moon'},
        ],
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Habits'));
    await _settle(tester);
    await tester.tap(find.text('I brushed my teeth'));
    await tester.pump();
    await _load(tester);
    await _run(tester, 300);
    expect(find.text('All done!'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    await _run(tester, 100);
    expect(find.text('My good habits'), findsOneWidget);

    await _run(tester, 1000);
    expect(find.text('All done!'), findsOneWidget);
    await _run(tester, 3300);
    await _load(tester);
    await _run(tester, 3400);
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

  testWidgets('home shows the Stickers button without overflow on 320, 360 and '
      '430 wide phones; it opens the album and back returns home', (
    tester,
  ) async {
    await tester.pumpWidget(await _app(tester, _Player()));
    for (final width in const [320.0, 360.0, 430.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'home at $width');
      expect(find.text('Stickers'), findsOneWidget);
    }

    await tester.tap(find.text('Stickers'));
    await _settle(tester);
    expect(find.text('My stickers'), findsOneWidget);
    await tester.tap(find.byType(BackDisc));
    await _settle(tester);
    expect(find.text('MY STAR CHART'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('every screen fits a 360 x 640 phone and an 800 x 1280 tablet '
      'with no overflow, and every control has a screen-reader label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      await _app(
        tester,
        _Player(),
        habits: [
          {
            'id': 'teeth',
            'text': 'I brushed my teeth',
            'picture': 'toothbrush',
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
          },
        ],
      ),
    );
    await _settle(tester);
    final router = ProviderScope.containerOf(
      tester.element(find.byType(StarbookApp)),
    ).read(routerProvider);

    for (final size in const [Size(360, 640), Size(800, 1280)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final path in [
        '/',
        '/day/${_today.name}',
        '/habits',
        '/words',
        '/words/home/short-a',
        '/stories',
        '/stories/home/hen',
        '/trophies',
        '/gate',
        '/parent',
        '/parent/packs',
        '/parent/week',
        '/parent/child',
        '/parent/backup',
        '/parent/settings',
        '/parent/credits',
        '/parent/tips',
      ]) {
        router.go(path);
        await _settle(tester);
        final where = '$path at ${size.width.toInt()} x ${size.height.toInt()}';
        expect(tester.takeException(), isNull, reason: where);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      }
    }
    await tester.pump(const Duration(seconds: 5));
    semantics.dispose();
  });

  testWidgets('a count card with 10 pictures fits a 360 x 640 phone at the '
      'largest font size with no overflow', (tester) async {
    await tester.pumpWidget(
      await _app(
        tester,
        _Player(),
        wordbooks: [
          {
            'id': 'count',
            'title': 'Count with me 1 to 10',
            'colour': 'tomato',
            'cards': [
              {
                'word': 'ten',
                'picture': 'banana',
                'count': 10,
                'say':
                    'One, two, three, four, five, six, seven, eight, nine, '
                    'ten. Ten bananas!',
              },
              {'word': 'one', 'picture': 'elephant', 'count': 1},
            ],
          },
        ],
      ),
    );
    await _settle(tester);
    ProviderScope.containerOf(
      tester.element(find.byType(StarbookApp)),
    ).read(routerProvider).go('/words/home/count');
    await _settle(tester);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('10'), findsOneWidget);
    expect(find.byType(Picture), findsNWidgets(10));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a word card that fits today keeps its full size inside the '
      'scale-down box', (tester) async {
    await tester.pumpWidget(
      await _app(
        tester,
        _Player(),
        wordbooks: [
          {
            'id': 'short-a',
            'title': 'a as in cat',
            'cards': [
              {'word': 'cat', 'picture': 'cat'},
              {'word': 'hat', 'picture': 'hat'},
            ],
          },
        ],
      ),
    );
    await _settle(tester);
    ProviderScope.containerOf(
      tester.element(find.byType(StarbookApp)),
    ).read(routerProvider).go('/words/home/short-a');
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Picture)), const Size(230, 230));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a task tip shows under its task in parent today and Whole week, '
      "not on the child's day, and fits a 360 x 640 phone at the largest font "
      'size', (tester) async {
    const tip =
        'Count each step out loud as you climb. At 4, stop and ask: what comes '
        'next? Yes!';
    await tester.pumpWidget(
      await _app(
        tester,
        _Player(),
        tasks: [
          {
            'id': 't1',
            'text': "Open 'First sounds'. Which words start like apple?",
            'icon': 'letters',
            'tip': tip,
          },
          {'id': 't2', 'text': 'Count'},
        ],
      ),
    );
    await _settle(tester);
    final router = ProviderScope.containerOf(
      tester.element(find.byType(StarbookApp)),
    ).read(routerProvider);
    router.go('/day/${_today.name}');
    await _settle(tester);
    expect(find.text(tip), findsNothing);

    router.go('/parent');
    await _settle(tester);
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(tip), findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(find.text(tip)).didExceedMaxLines,
      isFalse,
    );

    router.go('/parent/week');
    await _settle(tester);
    await tester.scrollUntilVisible(find.text(tip), 200);
    expect(tester.takeException(), isNull, reason: 'Whole week');
    expect(find.text(tip), findsOneWidget, reason: 'Whole week');
    expect(
      tester.renderObject<RenderParagraph>(find.text(tip)).didExceedMaxLines,
      isFalse,
      reason: 'Whole week',
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('the parent changes a task for this week and names the child; '
      'today and home show both, and a task with a star has no Remove', (
    tester,
  ) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(await _app(tester, _Player()));
    await _settle(tester);

    await _openGate(tester);
    await _type(tester, _shown(tester));
    await tester.tap(find.text('★ Star').at(1));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));

    await tester.ensureVisible(find.text('Whole week'));
    await tester.tap(find.text('Whole week'));
    await _settle(tester);
    final count = find.byKey(const ValueKey('t2'));
    expect(find.descendant(of: count, matching: find.text('done')), findsOne);
    expect(
      find.descendant(of: count, matching: find.text('Remove')),
      findsNothing,
    );
    await tester.tap(find.text('Write A'));
    await _settle(tester);
    expect(find.text('Change this task'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Write B');
    await tester.tap(find.text('Save'));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    expect(find.text('Write B'), findsOneWidget);
    expect(find.text('Write A'), findsNothing);

    await tester.ensureVisible(find.text('Child'));
    await tester.tap(find.text('Child'));
    await _settle(tester);
    await tester.enterText(find.byType(TextFormField), 'Asha');
    await tester.tap(find.byKey(const ValueKey('lion')));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    expect(find.text('Asha ›'), findsOneWidget);

    await _done(tester);
    await _settle(tester);
    expect(find.text("Asha's week"), findsOneWidget);
    final child = await tester.runAsync(() => _db.query('child'));
    expect((child!.single['name'], child.single['picture']), ('Asha', 'lion'));
    semantics.dispose();
  });
}
