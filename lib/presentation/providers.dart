import 'package:fpdart/fpdart.dart' show Either;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/failure.dart';
import '../domain/progress/progress.dart';
import '../domain/repositories.dart';
import 'sfx.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
PackRepository packRepository(Ref ref) => throw UnimplementedError();

@Riverpod(keepAlive: true)
ProgressRepository progressRepository(Ref ref) => throw UnimplementedError();

@Riverpod(keepAlive: true)
Sfx sfx(Ref ref) => Sfx();

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
