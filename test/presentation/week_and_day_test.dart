import 'dart:async';
import 'dart:math' show Random;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, right;
import 'package:lottie/lottie.dart';
import 'package:starbook/domain/failure.dart';
import 'package:starbook/domain/pack/pack.dart';
import 'package:starbook/domain/progress/progress.dart';
import 'package:starbook/domain/repositories.dart';
import 'package:starbook/domain/speaker.dart';
import 'package:starbook/main.dart';
import 'package:starbook/presentation/child/days.dart';
import 'package:starbook/presentation/child/habits_screen.dart'
    show allDoneLine;
import 'package:starbook/presentation/child/sticker_book_screen.dart';
import 'package:starbook/presentation/child/word_books_screen.dart'
    show PageArrow;
import 'package:starbook/presentation/parent/gate_screen.dart';
import 'package:starbook/presentation/providers.dart';
import 'package:starbook/presentation/router.dart';
import 'package:starbook/presentation/sfx.dart';
import 'package:starbook/presentation/widgets/award_mark.dart';
import 'package:starbook/presentation/widgets/picture.dart';
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
  _Speaker({this.read});

  // When set, a read stays open until it completes.
  final Completer<bool>? read;
  // When set, saying "ten" stays open until it completes.
  Completer<bool>? ten;
  final spoken = <(String, String)>[];
  var stops = 0;

  @override
  Future<bool> speakSentence(
    String text,
    String language, {
    bool? slow,
    void Function(int word)? onWord,
  }) {
    spoken.add((text, language));
    return read?.future ?? Future.value(true);
  }

  @override
  Future<bool> speakWord(String text, String language, {bool? slow}) {
    spoken.add((text, language));
    if (text == 'ten' && ten != null) return ten!.future;
    return read?.future ?? Future.value(true);
  }

  @override
  Future<void> stop() async => stops++;
}

class _Roll extends Fake implements Random {
  _Roll(this.value);

  // 0 is a hit.
  int value;

  @override
  int nextInt(int max) {
    expect(max, 4);
    return value;
  }
}

class _Spins extends Fake implements Random {
  _Spins(this.values);

  final List<int> values;

  @override
  int nextInt(int max) {
    expect(max, 2);
    return values.removeAt(0);
  }
}

class _Packs extends Fake implements PackRepository {
  _Packs(this.installed);

  @override
  final List<Pack> installed;
}

class _Progress extends Fake implements ProgressRepository {
  _Progress(
    this.week,
    this.awards,
    this.unseen, {
    this.first,
    this.takes,
    this.stickers = const [],
    this.childRow = const Child(name: 'Asha'),
  });

  final Child childRow;
  final Week week;
  final List<GivenAward> awards;
  final Set<int> unseen;
  final List<String> stickers;

  // Returned by the first takeMoments only; takes counts the calls.
  Moments? first;
  final ValueNotifier<int>? takes;

  @override
  Future<Either<Failure, Week?>> currentWeek() async => right(week);

  @override
  Future<Either<Failure, List<GivenAward>>> awardsFor(int weekId) async =>
      right(awards);

  @override
  Future<Either<Failure, Child?>> child() async => right(childRow);

  @override
  Future<Either<Failure, Set<int>>> takeUnseen(int weekId) async =>
      right(unseen);

  @override
  Future<Either<Failure, List<String>>> album() async => right(stickers);

  @override
  Future<Either<Failure, List<Trophy>>> trophies() async => right(const []);

  @override
  Future<Either<Failure, Moments>> takeMoments(int weekId) async {
    takes?.value++;
    final moments = first ?? (weekDone: false, trophy: null, allDone: null);
    first = null;
    return right(moments);
  }

  // Day moments already taken, as weekday/home.
  final dayMoments = <String>{};

  @override
  Future<Either<Failure, bool>> takeDayMoment(
    int weekId,
    Weekday day, {
    required bool home,
  }) async => right(dayMoments.add('${day.name}/$home'));

  // Done-for-today lines already taken, by weekday.
  final doneCards = <Weekday>{};

  @override
  Future<Either<Failure, bool>> takeDoneCard(int weekId, Weekday day) async =>
      right(doneCards.add(day));
}

final today = Weekday.values[DateTime.now().weekday - 1];
final other = Weekday.values[(today.index + 1) % 7];

Task _task(String id, {String? opens, bool bonus = false}) =>
    Task(id: id, text: 'Task $id', opens: opens, bonus: bonus);

GivenAward _given(
  int id,
  String task, {
  String award = 'star',
  String sticker = 'lion',
}) => GivenAward(
  id: id,
  weekId: 1,
  weekday: other,
  taskId: task,
  awardRef: 'books/$award',
  stars: 1,
  sticker: award == 'sticker' ? sticker : null,
  givenAt: DateTime.now(),
);

Widget _app({
  required Sheet sheet,
  required List<GivenAward> awards,
  required Set<int> unseen,
  required _Player player,
  _Speaker? speaker,
  Moments? firstMoments,
  ValueNotifier<int>? takes,
  List<String> album = const [],
  String? reward,
  Random? roll,
  Child? childRow,
  DateTime Function()? clock,
}) {
  const star = Award(id: 'star', kind: AwardKind.star, label: 'Star');
  const sticker = Award(
    id: 'sticker',
    kind: AwardKind.sticker,
    label: 'Sticker',
  );
  final packs = _Packs([
    const Pack(
      id: 'books',
      revision: 1,
      title: 'Books',
      language: 'en',
      awards: [star, sticker],
      wordBooks: [WordBook(id: 'a', title: 'A', cards: [])],
    ),
  ]);
  final week = Week(
    id: 1,
    start: mondayOf(DateTime.now()),
    sheetRef: 'books/week',
    sheet: sheet,
    specialReward: reward,
  );
  return ProviderScope(
    overrides: [
      packRepositoryProvider.overrideWithValue(packs),
      progressRepositoryProvider.overrideWithValue(
        _Progress(
          week,
          awards,
          unseen,
          first: firstMoments,
          takes: takes,
          stickers: album,
          childRow: childRow ?? const Child(name: 'Asha'),
        ),
      ),
      sfxProvider.overrideWithValue(Sfx(player)),
      speakerProvider.overrideWithValue(speaker ?? _Speaker()),
      randomProvider.overrideWithValue(roll ?? _Roll(1)),
      if (clock != null) clockProvider.overrideWithValue(clock),
    ],
    child: const StarbookApp(),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

Sheet _oneDay() => Sheet(
  id: 'week',
  title: 'Week',
  days: [
    Day(weekday: other, title: 'Alphabet adventure', tasks: [_task('t1')]),
  ],
);

final _reveal = find.byWidgetPredicate(
  (w) => w is StickerView && w.size == 240,
);

// The stickers of a group reveal: 112 dp in rows of 3, 84 dp in rows of 4.
final _group = find.byWidgetPredicate(
  (w) => w is StickerView && (w.size == 112 || w.size == 84),
);

List<String> _calls(_Player player) => [
  for (final p in player.played)
    if (p.startsWith('sticker-sounds/')) p,
];

Future<void> _run(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// The three outline layers of the reveal sticker share one controller.
AnimationController _revealController(WidgetTester tester) =>
    tester
            .widgetList<LottieBuilder>(
              find.descendant(
                of: _reveal,
                matching: find.byType(LottieBuilder),
              ),
            )
            .first
            .controller!
        as AnimationController;

Future<void> _load(WidgetTester tester) => tester.runAsync(
  () => Future<void>.delayed(const Duration(milliseconds: 200)),
);

// One controller per sticker; its three outline layers share it.
List<AnimationController> _bookControllers(WidgetTester tester) => {
  for (final l in tester.widgetList<LottieBuilder>(
    find.descendant(
      of: find.byType(StickerBookScreen),
      matching: find.byType(LottieBuilder),
    ),
  ))
    l.controller! as AnimationController,
}.toList();

void _phone(WidgetTester tester, [Size size = const Size(390, 844)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('home shows the week and the rest message today, with no reward '
      'box when no reward is typed; a finished day opens with one open bar '
      'and the banner', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final sheet = Sheet(
      id: 'week',
      title: 'Week',
      weekGoal: 'Our week together',
      days: [
        Day(
          weekday: other,
          title: 'Alphabet adventure',
          colour: 'sky',
          tasks: [
            _task('t1', opens: 'books/a'),
            _task('t2', opens: 'books/missing'),
          ],
        ),
      ],
      everyDay: [_task('e1', bonus: true)],
      restDays: [today],
    );
    await tester.pumpWidget(
      _app(
        sheet: sheet,
        awards: [_given(1, 't1'), _given(2, 't2')],
        unseen: {},
        player: _Player(),
      ),
    );
    await _settle(tester);

    for (final text in [
      "Asha's week",
      'MY STAR CHART',
      'No homework today. Play, draw, dance!',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.text("This week's reward"), findsNothing);
    expect(find.text('Our week together'), findsNothing);

    await tester.tap(find.text(weekdayShort[other.index]));
    await _settle(tester);
    expect(find.text('Alphabet adventure'), findsOneWidget);
    expect(find.text('BONUS'), findsOneWidget);
    expect(find.text('Practise'), findsOneWidget);
    expect(
      find.text('You finished ${weekdayNames[other.index]}!'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    expect(find.text('MY STAR CHART'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('new awards land once on home; the big star drops with the top '
      'note and the day is named before the new sticker opens with its sound; '
      'the day screen names it the first time only', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final player = _Player();
    final speaker = _Speaker();
    final sheet = Sheet(
      id: 'week',
      title: 'Week',
      days: [
        Day(
          weekday: other,
          title: 'Alphabet adventure',
          tasks: [_task('t1'), _task('t2'), _task('t3')],
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        sheet: sheet,
        awards: [
          _given(1, 't1'),
          _given(2, 't2'),
          _given(3, 't3', award: 'sticker'),
        ],
        unseen: {2, 3},
        player: player,
        speaker: speaker,
      ),
    );
    await _settle(tester);
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (i == 3) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
      }
    }
    await _run(tester, 300);
    expect(_reveal, findsOneWidget);
    expect(player.played, [
      'sounds/star-2.ogg',
      'sounds/peel.ogg',
      'sounds/press.ogg',
      'sounds/star-5.ogg',
      'sticker-sounds/lion.ogg',
    ]);
    expect(speaker.spoken, [
      ('You finished ${weekdayNames[other.index]}!', 'en-IN'),
    ]);
    await _load(tester);
    await _run(tester, 2600);
    final revealed = _revealController(tester);
    expect(revealed.value, 1);
    expect(revealed.isAnimating, isFalse);
    await _run(tester, 800);
    expect(_reveal, findsNothing);
    expect(speaker.spoken[1], ('A sticker for you!', 'en-IN'));

    await tester.tap(find.text(weekdayShort[other.index]));
    await _settle(tester);
    expect(speaker.spoken, hasLength(3));
    expect(speaker.spoken.last, (
      'You finished ${weekdayNames[other.index]}!',
      'en-IN',
    ));
    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    await tester.tap(find.text(weekdayShort[other.index]));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    await _run(tester, 4000);
    expect(find.text('MY STAR CHART'), findsOneWidget);
    expect(_reveal, findsNothing);
    expect(speaker.spoken, hasLength(3));
    expect(player.played, hasLength(5));
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets("today's card: with today's tasks done (a bonus task left open) "
      "it shows with the sticker today's habits gave and says its line once; "
      'a reload of home says nothing', (tester) async {
    _phone(tester);
    final speaker = _Speaker();
    final sheet = Sheet(
      id: 'week',
      title: 'Week',
      days: [
        Day(
          weekday: today,
          title: 'Letters',
          colour: 'plum',
          tasks: [_task('t1')],
        ),
      ],
      everyDay: [_task('e1', bonus: true)],
    );
    GivenAward award(int id, String task, String ref, int stars, String? s) =>
        GivenAward(
          id: id,
          weekId: 1,
          weekday: today,
          taskId: task,
          awardRef: ref,
          stars: stars,
          sticker: s,
          givenAt: DateTime.now(),
        );
    await tester.pumpWidget(
      _app(
        sheet: sheet,
        awards: [
          award(1, 't1', 'books/star', 1, null),
          award(2, habitsDoneTask, habitsDoneTask, 0, 'balloon'),
        ],
        unseen: {},
        player: _Player(),
        speaker: speaker,
      ),
    );
    await _settle(tester);
    await _run(tester, 300);
    final card = find.text('All done for today.\nTime to play!');
    final sticker = find.byWidgetPredicate(
      (w) => w is StickerView && w.name == 'balloon' && w.size == 64,
    );
    expect(card, findsOneWidget);
    expect(sticker, findsOneWidget);
    expect(speaker.spoken, [('All done for today. Time to play!', 'en-IN')]);

    ProviderScope.containerOf(
      tester.element(find.byType(StarbookApp)),
    ).invalidate(thisWeekProvider);
    await _settle(tester);
    await _run(tester, 300);
    expect(card, findsOneWidget);
    expect(speaker.spoken, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two new stickers on home each open their own reveal and say one '
      "line after its sound: the task's cheer, else a line for its icon that "
      'differs between two stickers of the same icon, else A sticker for you!, '
      'and the next sticker waits for the line', (tester) async {
    _phone(tester);
    final read = Completer<bool>();
    final speaker = _Speaker(read: read);
    final sheet = Sheet(
      id: 'week',
      title: 'Week',
      days: [
        Day(
          weekday: other,
          title: 'Alphabet adventure',
          tasks: const [
            Task(id: 't1', text: 'Task t1', icon: 'shapes'),
            Task(id: 't2', text: 'Task t2', icon: 'shapes'),
            Task(
              id: 't3',
              text: 'Task t3',
              icon: 'book',
              cheer: 'You read about trains!',
            ),
            Task(id: 't4', text: 'Task t4'),
            // No award, so the day is not finished and no day line is spoken.
            Task(id: 't5', text: 'Task t5'),
          ],
        ),
      ],
    );
    final unseen = {1, 2};
    await tester.pumpWidget(
      _app(
        sheet: sheet,
        awards: [
          for (var i = 1; i <= 4; i++) _given(i, 't$i', award: 'sticker'),
        ],
        unseen: unseen,
        player: _Player(),
        speaker: speaker,
      ),
    );
    await _settle(tester);
    for (var i = 0; i < 80 && _reveal.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_reveal, findsOneWidget);
    expect(_group, findsNothing);
    await _load(tester);
    await _run(tester, 1300);
    expect(speaker.spoken, isEmpty);
    await _run(tester, 300);
    expect(speaker.spoken, hasLength(1));

    // The first read is still open: the reveal closes and the next waits.
    await _run(tester, 3000);
    expect(_reveal, findsNothing);
    expect(speaker.spoken, hasLength(1));

    read.complete(true);
    await _load(tester);
    await _run(tester, 12000);
    expect(_reveal, findsNothing);
    expect(_group, findsNothing);
    expect(speaker.spoken, hasLength(2));
    expect(
      {for (final s in speaker.spoken) s.$1},
      {'You did your shapes!', 'You named the shapes!'},
    );
    expect(speaker.spoken.map((s) => s.$2), ['en-IN', 'en-IN']);

    unseen
      ..clear()
      ..addAll({3, 4});
    ProviderScope.containerOf(
      tester.element(find.byType(StarbookApp)),
    ).invalidate(thisWeekProvider);
    await _settle(tester);
    await _run(tester, 12000);
    expect(_reveal, findsNothing);
    expect(_group, findsNothing);
    expect(speaker.spoken.length, 4);
    expect(
      {for (final s in speaker.spoken.take(2)) s.$1},
      {'You did your shapes!', 'You named the shapes!'},
    );
    expect(speaker.spoken.take(2).map((s) => s.$2), ['en-IN', 'en-IN']);
    expect(speaker.spoken[2], ('You read about trains!', 'en'));
    expect(speaker.spoken[3], ('A sticker for you!', 'en-IN'));
  });

  testWidgets('a tap anywhere ends the sticker reveal at once and home works '
      'again', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        sheet: _oneDay(),
        awards: [_given(1, 't1', award: 'sticker')],
        unseen: {1},
        player: _Player(),
      ),
    );
    await _settle(tester);
    await _run(tester, 1500);
    expect(_reveal, findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await _run(tester, 300);
    expect(_reveal, findsNothing);

    await tester.tap(find.text('Stickers'));
    await _settle(tester);
    expect(find.text('My stickers'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('with remove animations on, a new sticker fades in and out in '
      'the middle without moving, and a book page plays nothing', (
    tester,
  ) async {
    _phone(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final player = _Player();
    await tester.pumpWidget(
      _app(
        sheet: _oneDay(),
        awards: [_given(1, 't1', award: 'sticker')],
        unseen: {1},
        player: player,
        album: ['lion', 'panda'],
      ),
    );
    await _settle(tester);
    for (var i = 0; i < 40 && _reveal.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_reveal, findsOneWidget);
    await _load(tester);
    await _run(tester, 2800);
    expect(tester.getCenter(_reveal), const Offset(195, 422));
    expect(_revealController(tester).value, 0);
    expect(player.played, contains('sticker-sounds/lion.ogg'));
    await _run(tester, 600);
    expect(_reveal, findsNothing);

    await tester.tap(find.text('Stickers'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await _run(tester, 1000);
    final controllers = _bookControllers(tester);
    expect(controllers, hasLength(2));
    for (final c in controllers) {
      expect(c.value, 0);
    }
  });

  testWidgets('three new stickers on home show in one group reveal: after the '
      'day line they pop in award order 900 ms apart, each with its own sound, '
      'then one line says how many, they fly only after the line, a tap ends '
      'the group but the next moment waits for the line, then the day '
      'surprise and All done! follow', (tester) async {
    _phone(tester);
    final player = _Player();
    final read = Completer<bool>();
    final speaker = _Speaker(read: read);
    final dance = find.byWidgetPredicate(
      (w) => w is StickerView && w.size == 56,
    );
    final sheet = Sheet(
      id: 'week',
      title: 'Week',
      days: [
        Day(
          weekday: other,
          title: 'Alphabet adventure',
          tasks: [_task('t1'), _task('t2'), _task('t3')],
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        sheet: sheet,
        awards: [
          _given(1, 't1', award: 'sticker', sticker: 'cat'),
          _given(2, 't2', award: 'sticker', sticker: 'owl'),
          _given(3, 't3', award: 'sticker', sticker: 'fox'),
        ],
        unseen: {1, 2, 3},
        player: player,
        speaker: speaker,
        roll: _Roll(0),
        firstMoments: (weekDone: false, trophy: null, allDone: 'lion'),
      ),
    );
    await _settle(tester);
    // The held day line takes its 4 second cap first.
    for (var i = 0; i < 120 && _group.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_group, findsNWidgets(3));
    await _load(tester);
    expect(speaker.spoken, hasLength(1));
    expect(_reveal, findsNothing);
    expect(_calls(player), ['sticker-sounds/cat.ogg']);
    await _run(tester, 400);
    expect(_calls(player), ['sticker-sounds/cat.ogg']);
    await _run(tester, 900);
    expect(_calls(player), [
      'sticker-sounds/cat.ogg',
      'sticker-sounds/owl.ogg',
    ]);
    await _run(tester, 900);
    expect(_calls(player), [
      'sticker-sounds/cat.ogg',
      'sticker-sounds/owl.ogg',
      'sticker-sounds/fox.ogg',
    ]);
    expect(speaker.spoken, hasLength(1));
    // The last pop was at 1800 ms; the line waits 1500 ms for its call.
    await _run(tester, 900);
    expect(speaker.spoken, hasLength(1));
    await _run(tester, 300);
    expect(speaker.spoken, hasLength(2));
    expect(speaker.spoken.last, ('Three new stickers!', 'en-IN'));

    // The line is still open: they stay until it ends or hits its cap.
    await _run(tester, 2000);
    expect(_group, findsNWidgets(3));
    expect(find.text('All done!'), findsNothing);

    // A tap ends the group, but nothing else starts while the line is open.
    await tester.tapAt(const Offset(10, 10));
    await _run(tester, 1400);
    expect(_group, findsNothing);
    expect(dance, findsNothing);
    expect(_calls(player), hasLength(3));
    expect(find.text('All done!'), findsNothing);
    expect(speaker.spoken, hasLength(2));

    read.complete(true);
    await _load(tester);
    for (var i = 0; i < 80 && dance.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(dance, findsOneWidget);
    expect(_calls(player), [
      'sticker-sounds/cat.ogg',
      'sticker-sounds/owl.ogg',
      'sticker-sounds/fox.ogg',
      'sticker-sounds/fox.ogg',
    ]);
    expect(find.text('All done!'), findsNothing);
    expect(speaker.spoken, isNot(contains((allDoneLine, 'en-IN'))));

    for (var i = 0; i < 80 && find.text('All done!').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('All done!'), findsOneWidget);
    await _load(tester);
    await _run(tester, 8000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ten or more new stickers sit in rows of 4 that fit a 320 dp '
      'screen with the last row centred, ten say Ten new stickers! and eleven '
      'say So many new stickers!, and a tap ends the group at once', (
    tester,
  ) async {
    _phone(tester, const Size(320, 640));
    final speaker = _Speaker(read: Completer<bool>());
    final sheet = Sheet(
      id: 'week',
      title: 'Week',
      days: [
        Day(
          weekday: other,
          title: 'Alphabet adventure',
          // The last task has no award, so no day line and no surprise.
          tasks: [for (var i = 1; i <= 12; i++) _task('t$i')],
        ),
      ],
    );
    final unseen = {for (var i = 1; i <= 10; i++) i};
    await tester.pumpWidget(
      _app(
        sheet: sheet,
        awards: [
          for (var i = 1; i <= 11; i++) _given(i, 't$i', award: 'sticker'),
        ],
        unseen: unseen,
        player: _Player(),
        speaker: speaker,
      ),
    );
    await _settle(tester);
    // The new stars land 800 ms apart before the reveal starts.
    for (var i = 0; i < 200 && _group.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_group, findsNWidgets(10));
    await _load(tester);
    await _run(tester, 10000);
    expect(speaker.spoken.last, ('Ten new stickers!', 'en-IN'));
    final rects = [for (var i = 0; i < 10; i++) tester.getRect(_group.at(i))];
    for (final r in rects) {
      expect(r.left, greaterThanOrEqualTo(-0.5));
      expect(r.top, greaterThanOrEqualTo(-0.5));
      expect(r.right, lessThanOrEqualTo(320.5));
      expect(r.bottom, lessThanOrEqualTo(640.5));
      expect(r.width, closeTo(rects.first.width, 0.01));
    }
    for (var i = 1; i < 4; i++) {
      expect(rects[i].top, closeTo(rects[0].top, 0.01));
    }
    expect(rects[4].top, greaterThan(rects[0].bottom));
    expect((rects[8].center.dx + rects[9].center.dx) / 2, closeTo(160, 0.5));

    await tester.tapAt(const Offset(10, 10));
    await _run(tester, 400);
    expect(_group, findsNothing);
    await _run(tester, 4000);

    unseen.add(11);
    ProviderScope.containerOf(
      tester.element(find.byType(StarbookApp)),
    ).invalidate(thisWeekProvider);
    await _settle(tester);
    for (var i = 0; i < 200 && _group.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_group, findsNWidgets(11));
    await _load(tester);
    await _run(tester, 11000);
    expect(speaker.spoken.last, ('So many new stickers!', 'en-IN'));
    // The line stays open: its cap, then the flight.
    await _run(tester, 5000);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'with remove animations on, a group shows each sticker still in '
    'its place at its turn, its sound on time, and fades it out where it is',
    (tester) async {
      _phone(tester, const Size(320, 640));
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final player = _Player();
      final sheet = Sheet(
        id: 'week',
        title: 'Week',
        days: [
          Day(
            weekday: other,
            title: 'Alphabet adventure',
            tasks: [for (var i = 1; i <= 4; i++) _task('t$i')],
          ),
        ],
      );
      await tester.pumpWidget(
        _app(
          sheet: sheet,
          awards: [
            _given(1, 't1', award: 'sticker', sticker: 'cat'),
            _given(2, 't2', award: 'sticker', sticker: 'owl'),
            _given(3, 't3', award: 'sticker', sticker: 'fox'),
          ],
          unseen: {1, 2, 3},
          player: player,
        ),
      );
      await _settle(tester);
      for (var i = 0; i < 60 && _group.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_group, findsNWidgets(3));
      await _load(tester);
      final first = [for (var i = 0; i < 3; i++) tester.getRect(_group.at(i))];

      void inPlace() {
        for (var i = 0; i < 3; i++) {
          final r = tester.getRect(_group.at(i));
          expect(r.left, closeTo(first[i].left, 0.5));
          expect(r.top, closeTo(first[i].top, 0.5));
          expect(r.width, closeTo(first[i].width, 0.5));
          expect(r.left, greaterThanOrEqualTo(-0.5));
          expect(r.right, lessThanOrEqualTo(320.5));
          expect(r.bottom, lessThanOrEqualTo(640.5));
        }
      }

      await _run(tester, 400);
      expect(_calls(player), ['sticker-sounds/cat.ogg']);
      inPlace();
      await _run(tester, 900);
      expect(_calls(player), [
        'sticker-sounds/cat.ogg',
        'sticker-sounds/owl.ogg',
      ]);
      inPlace();
      for (var i = 0; i < 60 && _group.evaluate().isNotEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (_group.evaluate().isNotEmpty) inPlace();
      }
      expect(_group, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('on a hit roll, a day finished on home is followed by its newest '
      'sticker dancing with its call, after the sticker reveal and its line and '
      'before All done!', (tester) async {
    _phone(tester);
    final player = _Player();
    final speaker = _Speaker();
    final dance = find.byWidgetPredicate(
      (w) => w is StickerView && w.size == 56,
    );
    await tester.pumpWidget(
      _app(
        sheet: _oneDay(),
        awards: [_given(1, 't1', award: 'sticker')],
        unseen: {1},
        player: player,
        speaker: speaker,
        roll: _Roll(0),
        firstMoments: (weekDone: false, trophy: null, allDone: 'lion'),
      ),
    );
    await _settle(tester);
    for (var i = 0; i < 80 && _reveal.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_reveal, findsOneWidget);
    await _load(tester);
    for (var i = 0; i < 80 && dance.evaluate().isEmpty; i++) {
      expect(dance, findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(dance, findsOneWidget);
    // The reveal has played out; its route is only fading away.
    expect(_revealController(tester).value, 1);
    expect(speaker.spoken, contains(('A sticker for you!', 'en-IN')));
    expect(speaker.spoken, isNot(contains((allDoneLine, 'en-IN'))));
    expect(find.text('All done!'), findsNothing);
    expect(player.played.last, 'sticker-sounds/lion.ogg');
    expect(
      player.played.where((p) => p == 'sticker-sounds/lion.ogg'),
      hasLength(2),
    );

    await _run(tester, 1400);
    expect(dance, findsNothing);
    for (var i = 0; i < 40 && find.text('All done!').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('All done!'), findsOneWidget);
    await _load(tester);
    await _run(tester, 8000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the child\'s animal, a hit roll after a star drop hops it '
      'with its call at most once a day: a miss plays nothing, a second drop '
      'the same day plays nothing, a drop on another day plays again, and a '
      'load with no drop plays nothing', (tester) async {
    _phone(tester);
    final player = _Player();
    final unseen = {1};
    final roll = _Roll(1);
    var now = DateTime.now();
    final hop = find.byWidgetPredicate(
      (w) => w is Picture && w.name == 'cat' && w.size == 56,
    );
    int calls() =>
        player.played.where((p) => p == 'sticker-sounds/cat.ogg').length;
    // Runs out one load; whether the hop showed during it.
    Future<bool> run() async {
      var hopped = false;
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (hop.evaluate().length == 2) hopped = true;
      }
      return hopped;
    }

    Future<bool> reload() async {
      ProviderScope.containerOf(
        tester.element(find.byType(StarbookApp)),
      ).invalidate(thisWeekProvider);
      await _settle(tester);
      return run();
    }

    await tester.pumpWidget(
      _app(
        sheet: _oneDay(),
        awards: [_given(1, 't1')],
        unseen: unseen,
        player: player,
        roll: roll,
        clock: () => now,
        childRow: const Child(name: 'Asha', picture: 'cat'),
      ),
    );
    await _settle(tester);
    expect(await run(), isFalse);
    expect(calls(), 0);

    roll.value = 0;
    expect(await reload(), isTrue);
    expect(calls(), 1);

    expect(await reload(), isFalse);
    expect(calls(), 1);

    now = now.add(const Duration(days: 7));
    expect(await reload(), isTrue);
    expect(calls(), 2);

    unseen.clear();
    now = now.add(const Duration(days: 7));
    expect(await reload(), isFalse);
    expect(calls(), 2);
  });

  testWidgets('with remove animations on, a hit roll after a star drop plays '
      'no surprise and no extra sound', (tester) async {
    _phone(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final player = _Player();
    final hop = find.byWidgetPredicate(
      (w) => w is Picture && w.name == 'cat' && w.size == 56,
    );
    await tester.pumpWidget(
      _app(
        sheet: _oneDay(),
        awards: [_given(1, 't1')],
        unseen: {1},
        player: player,
        roll: _Roll(0),
        childRow: const Child(name: 'Asha', picture: 'cat'),
      ),
    );
    await _settle(tester);
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(hop, findsOneWidget);
    }
    expect(player.played, isNot(contains('sticker-sounds/cat.ogg')));
  });

  testWidgets('an award that lands while the day screen is open plays no '
      'sound, and nothing plays for it when the child comes back', (
    tester,
  ) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final player = _Player();
    final sheet = Sheet(
      id: 'week',
      title: 'Week',
      days: [
        Day(
          weekday: other,
          title: 'Alphabet adventure',
          tasks: [_task('t1'), _task('t2'), _task('t3')],
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        sheet: sheet,
        awards: [
          _given(1, 't1'),
          _given(2, 't2'),
          _given(3, 't3', award: 'sticker'),
        ],
        unseen: {2, 3},
        player: player,
      ),
    );
    await _settle(tester);
    await tester.tap(find.text(weekdayShort[other.index]));
    await _settle(tester);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(player.played, ['sounds/star-2.ogg']);
    semantics.dispose();
  });

  testWidgets('a moment that comes due while the gate is open shows after '
      'the child leaves the gate', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final takes = ValueNotifier(0);
    final sheet = Sheet(
      id: 'week',
      title: 'Week',
      days: [
        Day(weekday: other, title: 'Alphabet adventure', tasks: [_task('t1')]),
      ],
    );
    await tester.pumpWidget(
      _app(
        sheet: sheet,
        awards: [_given(1, 't1')],
        unseen: {},
        player: _Player(),
        firstMoments: (weekDone: true, trophy: null, allDone: null),
        takes: takes,
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.bySemanticsLabel('Grown-ups'));
    await _settle(tester);
    expect(find.text('You did the whole week!'), findsNothing);
    expect(takes.value, 0);

    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('You did the whole week!'), findsOneWidget);
    expect(takes.value, 1);
    await _run(tester, 1100);
    semantics.dispose();
  });

  testWidgets('a moment never closes the gate a file opens over it', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(
        sheet: _oneDay(),
        awards: [_given(1, 't1')],
        unseen: {},
        player: _Player(),
        firstMoments: (weekDone: false, trophy: null, allDone: 'lion'),
      ),
    );
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('All done!'), findsOneWidget);

    // What a file opened with Starbook does (main.dart).
    ProviderScope.containerOf(
      tester.element(find.byType(StarbookApp)),
    ).read(routerProvider).go('/gate');
    await _settle(tester);
    await _run(tester, 3000);
    expect(find.byType(GateScreen), findsOneWidget);
    expect(find.text('All done!', skipOffstage: false), findsNothing);
  });

  testWidgets('a day and week finished by a backdated tick: home names no day, '
      'the week moment chimes, sparks, says the week and then the reward, and '
      'stays until a tap; the day screen names the day once', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final player = _Player();
    final speaker = _Speaker();
    await tester.pumpWidget(
      _app(
        sheet: _oneDay(),
        awards: [_given(1, 't1')],
        unseen: {},
        player: player,
        speaker: speaker,
        firstMoments: (weekDone: true, trophy: null, allDone: null),
        reward: 'Park with Papa on Sunday',
      ),
    );
    await _settle(tester);
    for (var i = 0; i < 20; i++) {
      if (find.text('You did the whole week!').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('You did the whole week!'), findsOneWidget);
    expect(speaker.spoken, isEmpty);
    expect(player.played, ['sounds/trophy.ogg']);

    await _run(tester, 1100);
    expect(speaker.spoken, [
      ('You did the whole week!', 'en-IN'),
      ('Park with Papa on Sunday', 'en-IN'),
    ]);
    await _run(tester, 3000);
    expect(find.text('You did the whole week!'), findsOneWidget);
    await tester.tapAt(const Offset(195, 422));
    await _run(tester, 400);
    expect(find.text('You did the whole week!'), findsNothing);

    final dayLine = ('You finished ${weekdayNames[other.index]}!', 'en-IN');
    await tester.tap(find.text(weekdayShort[other.index]));
    await _settle(tester);
    expect(speaker.spoken, hasLength(3));
    expect(speaker.spoken.last, dayLine);
    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    await tester.tap(find.text(weekdayShort[other.index]));
    await _settle(tester);
    expect(speaker.spoken, hasLength(3));
    expect(player.played, ['sounds/trophy.ogg']);
    semantics.dispose();
  });

  testWidgets('a full page trophy celebrates over home with the page picture '
      'and name', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final speaker = _Speaker();
    final sheet = Sheet(
      id: 'week',
      title: 'Week',
      days: [
        Day(weekday: other, title: 'Alphabet adventure', tasks: [_task('t1')]),
      ],
    );
    await tester.pumpWidget(
      _app(
        sheet: sheet,
        awards: [_given(1, 't1')],
        unseen: {},
        player: _Player(),
        firstMoments: (
          weekDone: false,
          trophy: 'sticker-page:animals',
          allDone: null,
        ),
        speaker: speaker,
      ),
    );
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Full animal page'), findsOneWidget);
    expect(speaker.spoken, contains(('Full animal page', 'en-IN')));
    semantics.dispose();
  });

  testWidgets('the sticker book opens on the newest sticker\'s page and counts '
      'each sticker once, and a tap on an earned sticker plays its sound while '
      'a grey one stays silent', (tester) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final player = _Player();
    final sheet = Sheet(
      id: 'week',
      title: 'Week',
      days: [
        Day(weekday: other, title: 'Alphabet adventure', tasks: [_task('t1')]),
      ],
    );
    await tester.pumpWidget(
      _app(
        sheet: sheet,
        awards: [],
        unseen: {},
        player: player,
        album: ['heart', 'mango', 'lion', 'lion'],
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Trophies'));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('My stickers, 2 of 188'));
    await _settle(tester);

    expect(find.text('2 of 188'), findsOneWidget);
    expect(find.text('More stickers'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('heart'));
    await _settle(tester);
    expect(player.played.last, 'sticker-sounds/twinkle.ogg');
    Future<void> back(int times) async {
      for (var i = 0; i < times; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 350)),
        );
        await tester.tap(find.byType(PageArrow).first);
        await _settle(tester);
      }
    }

    await back(6);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('1 of 24'), findsOneWidget);

    await back(2);
    expect(find.text('Animals'), findsOneWidget);
    expect(find.text('1 of 24'), findsOneWidget);
    expect(find.bySemanticsLabel('Not yet'), findsNWidgets(23));

    await tester.tap(find.bySemanticsLabel('lion'));
    await _settle(tester);
    expect(player.played.last, 'sticker-sounds/lion.ogg');
    final taps = player.played.length;
    await tester.tap(find.bySemanticsLabel('Not yet').first);
    await _settle(tester);
    expect(player.played, hasLength(taps));
    semantics.dispose();
  });

  testWidgets('a book page plays each earned sticker once when it opens, later '
      'ones after earlier ones, and grey shapes have no animation', (
    tester,
  ) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        sheet: _oneDay(),
        awards: [],
        unseen: {},
        player: _Player(),
        album: ['lion', 'panda', 'monkey'],
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('Trophies'));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('My stickers, 3 of 188'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final started = _bookControllers(tester);
    expect(started, hasLength(3));
    expect(started[0].value, greaterThan(0));
    expect(started[2].value, 0);

    for (var i = 0; i < 35; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (final c in _bookControllers(tester)) {
      expect(c.value, 1);
      expect(c.isAnimating, isFalse);
    }
    semantics.dispose();
  });

  testWidgets('tapping a task reads its say with the row lit until the read '
      'ends; it gives no award, and leaving the day stops the read', (
    tester,
  ) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final read = Completer<bool>();
    final speaker = _Speaker(read: read);
    final sheet = Sheet(
      id: 'week',
      title: 'Week',
      days: [
        Day(
          weekday: other,
          title: 'Alphabet adventure',
          tasks: [const Task(id: 't1', text: 'Task t1', say: 'Say t1')],
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        sheet: sheet,
        awards: [],
        unseen: {},
        player: _Player(),
        speaker: speaker,
      ),
    );
    await _settle(tester);
    await tester.tap(find.text(weekdayShort[other.index]));
    await _settle(tester);

    final lit = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color == const Color(0xFFFFEDB8),
    );
    expect(lit, findsNothing);
    await tester.tap(find.text('Task t1'));
    await tester.pump();
    expect(speaker.spoken, [('Say t1', 'en')]);
    expect(lit, findsOneWidget);

    read.complete(true);
    await tester.pump();
    await tester.pump();
    expect(lit, findsNothing);
    expect(find.byType(AwardMark), findsNothing);

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.tap(find.text('Task t1'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    expect(speaker.stops, 1);
    semantics.dispose();
  });

  testWidgets('the number board: a number-board task opens it from Count to 10 '
      'and an unknown opens shows no bar; each spin is 1 or 2 and once per '
      'move, the token says each number it lands on and a 2 from 9 stops on '
      '10, where one line is said with no sound, sticker or award; Play again '
      'starts over and Back leaves', (tester) async {
    _phone(tester, const Size(360, 640));
    final semantics = tester.ensureSemantics();
    final spins = _Spins([1, 1, 1, 1, 0, 1, 0]);
    final speaker = _Speaker();
    final player = _Player();
    final sheet = Sheet(
      id: 'week',
      title: 'Week',
      days: [
        Day(
          weekday: other,
          title: 'Counting',
          tasks: [
            _task('t1', opens: 'number-board'),
            _task('t2', opens: 'clock-game'),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      _app(
        sheet: sheet,
        awards: [],
        unseen: {},
        player: player,
        speaker: speaker,
        roll: spins,
      ),
    );
    await _settle(tester);
    await tester.tap(find.text(weekdayShort[other.index]));
    await _settle(tester);
    expect(find.text('Count to 10'), findsOneWidget);
    expect(find.text('Practise'), findsNothing);
    expect(find.text('Pick a story'), findsNothing);

    Future<void> wait() => tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    final spin = find.bySemanticsLabel('Spin');
    final token = find.byWidgetPredicate(
      (w) => w is Picture && w.name == 'teddy-bear',
    );
    await tester.tap(find.text('Count to 10'));
    await _settle(tester);
    expect(spin, findsOneWidget);

    await tester.tap(spin);
    await tester.pump();
    await wait();
    await tester.tap(spin);
    await tester.pump();
    expect(spins.values, hasLength(6));
    await tester.tap(token);
    await _settle(tester);
    for (var i = 0; i < 5; i++) {
      await wait();
      await tester.tap(spin);
      await tester.pump();
      await tester.tap(token);
      await _settle(tester);
    }

    expect(speaker.spoken, [
      for (final w in [
        'one',
        'two',
        'three',
        'four',
        'five',
        'six',
        'seven',
        'eight',
        'nine',
        'ten',
      ])
        (w, 'en-IN'),
      ('You got to the end!', 'en-IN'),
    ]);
    expect(
      tester.getCenter(token).dx,
      closeTo(tester.getCenter(find.text('10')).dx, 0.5),
    );
    expect(spins.values, [0]);
    expect(spin, findsNothing);
    expect(find.text('Play again'), findsOneWidget);
    expect(player.played, isEmpty);
    expect(find.byType(StickerView), findsNothing);
    expect(find.byType(AwardMark), findsNothing);
    expect(find.text('All done!'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Play again'));
    await _settle(tester);
    await wait();
    await tester.tap(spin);
    await tester.pump();
    // The corner of the token takes the tap at the start cell too.
    await tester.tapAt(tester.getTopLeft(token) + const Offset(2, 2));
    await _settle(tester);
    expect(speaker.spoken.last, ('one', 'en-IN'));
    expect(spins.values, isEmpty);

    // Play again during "ten" resets the board and the token stays put.
    spins.values.addAll([1, 1, 1, 1, 0]);
    speaker.ten = Completer<bool>();
    for (var i = 0; i < 5; i++) {
      await wait();
      await tester.tap(spin);
      await tester.pump();
      await tester.tap(token);
      await _settle(tester);
    }
    expect(speaker.spoken.last, ('ten', 'en-IN'));
    await tester.tap(find.text('Play again'));
    await _settle(tester);
    speaker.ten!.complete(true);
    await _settle(tester);
    expect(speaker.spoken.last, ('ten', 'en-IN'));
    expect(
      tester.getCenter(token).dx,
      lessThan(tester.getCenter(find.text('10')).dx - 200),
    );
    expect(spin, findsOneWidget);

    final stops = speaker.stops;
    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    expect(find.text('Counting'), findsOneWidget);
    expect(speaker.stops, stops + 1);
    semantics.dispose();
  });
}
