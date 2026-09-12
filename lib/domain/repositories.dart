import 'dart:typed_data';

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

/// A voice pack clip: the file to play and the start time in seconds of each
/// word, when the pack has them.
typedef Clip = ({String path, List<double>? starts});

abstract interface class VoiceRepository {
  /// Installs a bundled voice pack when its id is not installed or its revision
  /// is higher; at the same or a lower revision it is skipped without being
  /// unpacked. A zip that fails a check writes nothing.
  Future<Either<Failure, Unit>> start(List<Uint8List> bundled);

  /// The clip for [text] in a voice pack that serves [language]: the active
  /// voice first, then the other installed voices by id.
  Clip? clipFor(String text, String language);
}

abstract interface class ProgressRepository {
  /// The week row for this Monday, created from the active sheet on first
  /// call. Right(null) when no sheet is installed.
  Future<Either<Failure, Week?>> currentWeek();

  Future<Either<Failure, List<GivenAward>>> awardsFor(int weekId);

  /// [replaces] is the task's live award, undone in the same write.
  Future<Either<Failure, GivenAward>> give({
    required int weekId,
    required Weekday weekday,
    required String taskId,
    required String awardRef,
    int? replaces,
  });

  /// [restore] is the award [awardId] replaced; it is made live again in the
  /// same write.
  Future<Either<Failure, Unit>> undo(int awardId, {int? restore});

  /// Stores the parent's reward text for the week; blank text clears it.
  Future<Either<Failure, Unit>> setSpecialReward(int weekId, String text);

  Future<Either<Failure, Unit>> finish(BookKind kind, String ref);

  Future<Either<Failure, Counters>> counters();

  Future<Either<Failure, List<Trophy>>> trophies();

  Future<Either<Failure, Child?>> child();

  /// Ids of this week's live awards the child has not seen yet; marks every
  /// award so far as seen, so each one arrives once.
  Future<Either<Failure, Set<int>>> takeUnseen(int weekId);

  /// Stickers of every award that is not undone, newest first.
  Future<Either<Failure, List<String>>> album();

  /// Whether week [weekId] is done and its moment not shown yet, and the
  /// newest trophy not celebrated yet; marks both shown, so each comes once.
  Future<Either<Failure, Moments>> takeMoments(int weekId);

  /// Ids of the habits ticked today.
  Future<Either<Failure, Set<String>>> ticksToday();

  /// Ticks habit [habitId] of week [weekId] for today; Right(false) when it is
  /// already ticked today. A habit ticked on all seven days of the week earns
  /// its trophy, `pack-id/sheet-id/habit-id`.
  Future<Either<Failure, bool>> tickHabit(int weekId, String habitId);

  /// Removes today's tick of [habitId]; a trophy already earned stays.
  Future<Either<Failure, Unit>> undoHabit(String habitId);
}
