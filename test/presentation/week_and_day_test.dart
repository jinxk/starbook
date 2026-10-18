import 'dart:async';

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
import 'package:starbook/presentation/child/sticker_book_screen.dart';
import 'package:starbook/presentation/child/word_books_screen.dart'
    show PageArrow;
import 'package:starbook/presentation/parent/gate_screen.dart';
import 'package:starbook/presentation/providers.dart';
import 'package:starbook/presentation/router.dart';
import 'package:starbook/presentation/sfx.dart';
import 'package:starbook/presentation/widgets/award_mark.dart';
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
  Future<void> stop() async => stops++;
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
  });

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
  Future<Either<Failure, Child?>> child() async =>
      right(const Child(name: 'Asha'));

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
}

final today = Weekday.values[DateTime.now().weekday - 1];
final other = Weekday.values[(today.index + 1) % 7];

Task _task(String id, {String? opens, bool bonus = false}) =>
    Task(id: id, text: 'Task $id', opens: opens, bonus: bonus);

GivenAward _given(int id, String task, {String award = 'star'}) => GivenAward(
  id: id,
  weekId: 1,
  weekday: other,
  taskId: task,
  awardRef: 'books/$award',
  stars: 1,
  sticker: award == 'sticker' ? 'lion' : null,
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
        ),
      ),
      sfxProvider.overrideWithValue(Sfx(player)),
      speakerProvider.overrideWithValue(speaker ?? _Speaker()),
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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('home shows the week, the rest message today and the default '
      'goal; a finished day opens with one open bar and the banner', (
    tester,
  ) async {
    _phone(tester);
    final semantics = tester.ensureSemantics();
    final sheet = Sheet(
      id: 'week',
      title: 'Week',
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
      "This week's reward",
      'Finish all your days for a big reward!',
      'No homework today. Play, draw, dance!',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }

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

  testWidgets('new awards land once on home, then a new sticker opens big with '
      'its sound; seen awards and the day screen play nothing', (tester) async {
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
      'sticker-sounds/lion.ogg',
    ]);
    await _load(tester);
    await _run(tester, 2600);
    final revealed = _revealController(tester);
    expect(revealed.value, 1);
    expect(revealed.isAnimating, isFalse);
    await _run(tester, 800);
    expect(_reveal, findsNothing);

    await tester.tap(find.text(weekdayShort[other.index]));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    await _run(tester, 4000);
    expect(find.text('MY STAR CHART'), findsOneWidget);
    expect(_reveal, findsNothing);
    expect(player.played, hasLength(4));
    semantics.dispose();
    expect(tester.takeException(), isNull);
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
    semantics.dispose();
  });

  testWidgets('a moment closes only itself: the gate opened over it stays '
      'open', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(
        sheet: _oneDay(),
        awards: [_given(1, 't1')],
        unseen: {},
        player: _Player(),
        firstMoments: (weekDone: true, trophy: null, allDone: null),
      ),
    );
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('You did the whole week!'), findsOneWidget);

    // What a file opened with Starbook does (main.dart).
    ProviderScope.containerOf(
      tester.element(find.byType(StarbookApp)),
    ).read(routerProvider).go('/gate');
    await _settle(tester);
    await _run(tester, 3000);
    expect(find.byType(GateScreen), findsOneWidget);
    expect(
      find.text('You did the whole week!', skipOffstage: false),
      findsNothing,
    );
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
}
