import 'dart:async';
import 'dart:math' show Random;
import 'dart:typed_data';

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
VoiceRepository voiceRepository(Ref ref) => throw UnimplementedError();

@Riverpod(keepAlive: true)
BackupRepository backupRepository(Ref ref) => throw UnimplementedError();

typedef PickedFile = ({String name, Uint8List bytes});

/// A file opened with Starbook from another app, waiting for the gate.
@Riverpod(keepAlive: true)
class IncomingFile extends _$IncomingFile {
  @override
  PickedFile? build() => null;

  void set(PickedFile file) => state = file;

  void drop() => state = null;
}

@Riverpod(keepAlive: true)
Sfx sfx(Ref ref) => Sfx();

/// The clock for today and this week. The store screenshot tool sets a fixed
/// school day. The progress repository takes its own now, so the tool sets
/// both from one date.
@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => DateTime.now;

/// The roll for home's day surprise; tests set it.
@Riverpod(keepAlive: true)
Random random(Ref ref) => Random();

/// The date of the last day surprise on home, in memory only.
@Riverpod(keepAlive: true)
class SurpriseDay extends _$SurpriseDay {
  @override
  DateTime? build() => null;

  void played(DateTime day) => state = day;
}

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
  Week? lastWeek,
  List<GivenAward> lastAwards,
  Child? child,
  Map<DateTime, Set<String>> ticked,
  Map<String, int> tickedDays,
  HabitPrefs habits,
});

/// This week and the stored week before it when the 7 days reach it, their
/// live awards, the child, the ticks of each of the 7 days, the days each
/// habit was ticked in total and the parent's habit choices. It marks
/// nothing seen, so awards still land on home afterwards.
@riverpod
Future<ParentToday> parentToday(Ref ref) async {
  final progress = ref.watch(progressRepositoryProvider);
  final days = markableDays(ref.watch(clockProvider)());
  final week = _value(await progress.currentWeek());
  final lastWeek = mondayOf(days.first) == mondayOf(days.last)
      ? null
      : _value(await progress.weekOf(days.first));
  Future<List<GivenAward>> live(Week? w) async => w == null
      ? const <GivenAward>[]
      : [
          for (final a in _value(await progress.awardsFor(w.id)))
            if (a.undoneAt == null) a,
        ];
  return (
    week: week,
    awards: await live(week),
    lastWeek: lastWeek,
    lastAwards: await live(lastWeek),
    child: _value(await progress.child()),
    ticked: {for (final d in days) d: _value(await progress.ticksOn(d))},
    tickedDays: _value(await progress.tickedDays()),
    habits: _value(await progress.habitPrefs()),
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

/// The sticker album, newest first.
@riverpod
Future<List<String>> stickerBook(Ref ref) async =>
    _value(await ref.watch(progressRepositoryProvider).album());

typedef HabitsToday = ({Week? week, Set<String> done});

/// The current week and the habits ticked today, read each time the habit
/// screen opens.
@riverpod
Future<HabitsToday> habitsToday(Ref ref) async {
  final progress = ref.watch(progressRepositoryProvider);
  return (
    week: _value(await progress.currentWeek()),
    done: _value(await progress.ticksOn(ref.watch(clockProvider)())),
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
