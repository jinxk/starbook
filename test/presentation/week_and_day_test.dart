import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' show Either, right;
import 'package:starbook/domain/failure.dart';
import 'package:starbook/domain/pack/pack.dart';
import 'package:starbook/domain/progress/progress.dart';
import 'package:starbook/domain/repositories.dart';
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

class _Packs extends Fake implements PackRepository {
  _Packs(this.installed);

  @override
  final List<Pack> installed;
}

class _Progress extends Fake implements ProgressRepository {
  _Progress(this.week, this.awards, this.unseen);

  final Week week;
  final List<GivenAward> awards;
  final Set<int> unseen;

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
  Future<Either<Failure, Moments>> takeMoments(int weekId) async =>
      right((weekDone: false, trophy: null));
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
  sticker: award == 'sticker' ? 'elephant' : null,
  givenAt: DateTime.now(),
);

Widget _app({
  required Sheet sheet,
  required List<GivenAward> awards,
  required Set<int> unseen,
  required _Player player,
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
        _Progress(week, awards, unseen),
      ),
      sfxProvider.overrideWithValue(Sfx(player)),
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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('home shows the week, the rest message today and the default '
      'goal; Words and Stories stay on home; a finished day opens with one open '
      'bar and the banner', (tester) async {
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

    for (final label in ['Words', 'Stories']) {
      await tester.tap(find.text(label));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('MY STAR CHART'), findsOneWidget);
    expect(tester.takeException(), isNull);

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

  testWidgets('new awards land once on home with a rising star note and the '
      'sticker sounds; seen awards and the day screen play nothing', (
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
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (i == 3) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
      }
    }
    expect(player.played, [
      'sounds/star-2.ogg',
      'sounds/peel.ogg',
      'sounds/press.ogg',
    ]);

    await tester.tap(find.text(weekdayShort[other.index]));
    await _settle(tester);
    await tester.tap(find.bySemanticsLabel('Back'));
    await _settle(tester);
    expect(find.text('MY STAR CHART'), findsOneWidget);
    expect(player.played, hasLength(3));
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
