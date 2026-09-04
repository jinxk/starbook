import 'package:fpdart/fpdart.dart' show Either, Unit;

import 'failure.dart';
import 'pack/pack.dart';
import 'progress/progress.dart';

enum InstallResult { installed, needsConfirm }

abstract interface class PackRepository {
  List<Pack> get installed;

  /// Replaces a default only when the bundled revision is higher; installs a
  /// default that was never offered before; never puts back a removed one.
  Future<Either<Failure, Unit>> start(List<String> defaultPacks);

  /// Installs when the id is new or the revision is higher. At the same or a
  /// lower revision it returns needsConfirm and writes nothing until called
  /// again with confirmed: true.
  Future<Either<Failure, InstallResult>> install(
    String json, {
    bool confirmed = false,
  });

  Future<Either<Failure, Unit>> remove(String id);
}

abstract interface class ProgressRepository {
  /// The week row for this Monday, created from the active sheet on first
  /// call. Right(null) when no sheet is installed.
  Future<Either<Failure, Week?>> currentWeek();

  Future<Either<Failure, List<GivenAward>>> awardsFor(int weekId);

  Future<Either<Failure, GivenAward>> give({
    required int weekId,
    required Weekday weekday,
    required String taskId,
    required String awardRef,
  });

  Future<Either<Failure, Unit>> undo(int awardId);

  Future<Either<Failure, Unit>> finish(BookKind kind, String ref);

  Future<Either<Failure, Counters>> counters();

  Future<Either<Failure, List<Trophy>>> trophies();

  Future<Either<Failure, Child?>> child();

  /// Ids of this week's live awards the child has not seen yet; marks every
  /// award so far as seen, so each one arrives once.
  Future<Either<Failure, Set<int>>> takeUnseen(int weekId);
}
