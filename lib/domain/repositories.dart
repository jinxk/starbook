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

  /// Parses and checks [json] against the pack rules; writes nothing.
  Either<Failure, Pack> check(String json);
}

/// A voice pack clip: the file to play and the start time in seconds of each
/// word, when the pack has them.
typedef Clip = ({String path, List<double>? starts});

typedef VoiceInfo = ({String id, String title, String language, int revision});

abstract interface class VoiceRepository {
  /// Installs a bundled voice pack when its id is not installed or its revision
  /// is higher; at the same or a lower revision nothing is written. Every zip
  /// is decoded and checked on each start, and one that fails a check writes
  /// nothing.
  Future<Either<Failure, Unit>> start(List<Uint8List> bundled);

  /// The installed voice packs, by id.
  List<VoiceInfo> get installed;

  /// The ids of the voices used first, one for each installed language.
  Set<String> get active;

  /// Runs the checks of [start] on [zip]; writes nothing.
  Either<Failure, VoiceInfo> check(Uint8List zip);

  /// Same checks as [start]. A new id or a higher revision installs; the same
  /// or a lower revision returns needsConfirm and writes nothing until called
  /// again with confirmed: true.
  Future<Either<Failure, InstallResult>> install(
    Uint8List zip, {
    bool confirmed = false,
  });

  /// Makes [id] the active voice for its language.
  Future<Either<Failure, Unit>> pick(String id);

  /// The clip for [text] in a voice pack that serves [language]: the active
  /// voice first, then the other installed voices by id.
  Clip? clipFor(String text, String language);
}

typedef Prefs = ({bool sound, bool slowReading});

typedef BackupInfo = ({DateTime made, String? child, int stars, int packs});

abstract interface class BackupRepository {
  /// Every table but voices as one JSON text.
  Future<Either<Failure, String>> export();

  /// Checks [json] as a backup this version can restore; writes nothing.
  Either<Failure, BackupInfo> check(String json);

  /// Replaces every table but voices in one transaction; a failure changes
  /// nothing.
  Future<Either<Failure, Unit>> restore(String json);
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

  /// Adds a task to a school day of this week's sheet only. Refuses blank text,
  /// a day not on the sheet and a day that is already done.
  Future<Either<Failure, Unit>> addTask(int weekId, Weekday day, String text);

  /// Changes the text of a task of this week's sheet only; the id and its
  /// awards stay. Refuses blank text.
  Future<Either<Failure, Unit>> editTask(
    int weekId,
    String taskId,
    String text,
  );

  /// Removes a task from this week's sheet only; awards stay. Refuses when a
  /// day would be left with no task that is not a bonus.
  Future<Either<Failure, Unit>> removeTask(int weekId, String taskId);

  /// Writes the child; blank name stores null, picture is a bundled name.
  Future<Either<Failure, Unit>> setChild(Child child);

  /// Sound on and slow reading off when nothing is stored.
  Future<Either<Failure, Prefs>> prefs();

  Future<Either<Failure, Unit>> setPrefs(Prefs prefs);

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

  /// When every habit of week [weekId]'s sheet is ticked today and today has
  /// not had its habit sticker, gives one new book sticker and returns it;
  /// Right(null) otherwise. An untick never takes it back.
  Future<Either<Failure, String?>> takeHabitSticker(int weekId);

  /// The sheet new weeks start from, as pack-id/sheet-id: the activeSheet
  /// setting when it is installed, else the first installed sheet; null when
  /// none is installed.
  Future<Either<Failure, String?>> activeSheet();

  /// The week in progress keeps its own sheet.
  Future<Either<Failure, Unit>> setActiveSheet(String ref);
}
