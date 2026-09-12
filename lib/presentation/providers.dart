import 'dart:async';

import 'package:fpdart/fpdart.dart' show Either;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/failure.dart';
import '../domain/progress/progress.dart';
import '../domain/repositories.dart';
import '../domain/speaker.dart';
import 'sfx.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
PackRepository packRepository(Ref ref) => throw UnimplementedError();

@Riverpod(keepAlive: true)
ProgressRepository progressRepository(Ref ref) => throw UnimplementedError();

@Riverpod(keepAlive: true)
Sfx sfx(Ref ref) => Sfx();

@Riverpod(keepAlive: true)
Speaker speaker(Ref ref) => throw UnimplementedError();

typedef ThisWeek = ({
  Week week,
  List<GivenAward> awards,
  Set<int> unseen,
  Child? child,
});

T _value<T>(Either<Failure, T> result) =>
    result.getOrElse((failure) => throw failure);

/// The current week with its live awards. Null when no sheet is installed.
@riverpod
Future<ThisWeek?> thisWeek(Ref ref) async {
  final progress = ref.watch(progressRepositoryProvider);
  final week = _value(await progress.currentWeek());
  if (week == null) return null;
  final awards = _value(await progress.awardsFor(week.id));
  // takeUnseen marks awards seen, so nothing that can fail runs after it.
  final child = _value(await progress.child());
  return (
    week: week,
    awards: [
      for (final a in awards)
        if (a.undoneAt == null) a,
    ],
    unseen: _value(await progress.takeUnseen(week.id)),
    child: child,
  );
}

typedef ParentToday = ({
  Week? week,
  List<GivenAward> awards,
  Child? child,
  Set<String> ticked,
});

/// The current week, its live awards and the child, for parent today. It
/// marks nothing seen, so awards still land on home afterwards.
@riverpod
Future<ParentToday> parentToday(Ref ref) async {
  final progress = ref.watch(progressRepositoryProvider);
  final week = _value(await progress.currentWeek());
  final awards = week == null
      ? const <GivenAward>[]
      : _value(await progress.awardsFor(week.id));
  return (
    week: week,
    awards: [
      for (final a in awards)
        if (a.undoneAt == null) a,
    ],
    child: _value(await progress.child()),
    ticked: _value(await progress.ticksToday()),
  );
}

typedef TrophyRoom = ({List<Trophy> trophies, List<String> album});

/// Earned trophies and the sticker album, read each time the room opens.
@riverpod
Future<TrophyRoom> trophyRoom(Ref ref) async {
  final progress = ref.watch(progressRepositoryProvider);
  return (
    trophies: _value(await progress.trophies()),
    album: _value(await progress.album()),
  );
}

typedef HabitsToday = ({Week? week, Set<String> done});

/// The current week and the habits ticked today, read each time the habit
/// screen opens.
@riverpod
Future<HabitsToday> habitsToday(Ref ref) async {
  final progress = ref.watch(progressRepositoryProvider);
  return (
    week: _value(await progress.currentWeek()),
    done: _value(await progress.ticksToday()),
  );
}

/// Seconds left on the gate's lock, 0 when open. Kept alive so closing and
/// reopening the gate does not end the wait.
@Riverpod(keepAlive: true)
class GateLock extends _$GateLock {
  int _wrong = 0;
  Timer? _timer;

  @override
  int build() {
    ref.onDispose(() => _timer?.cancel());
    return 0;
  }

  /// A right answer.
  void passed() => _wrong = 0;

  /// A wrong answer; the third in a row locks the gate for 60 seconds.
  void failed() {
    if (++_wrong < 3) return;
    _wrong = 0;
    state = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state--;
      if (state == 0) timer.cancel();
    });
  }
}
