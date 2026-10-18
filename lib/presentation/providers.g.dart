// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(packRepository)
final packRepositoryProvider = PackRepositoryProvider._();

final class PackRepositoryProvider
    extends $FunctionalProvider<PackRepository, PackRepository, PackRepository>
    with $Provider<PackRepository> {
  PackRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'packRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$packRepositoryHash();

  @$internal
  @override
  $ProviderElement<PackRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PackRepository create(Ref ref) {
    return packRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PackRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PackRepository>(value),
    );
  }
}

String _$packRepositoryHash() => r'3b2bb8890576d21feb026b0654c9ae057c9c6405';

@ProviderFor(progressRepository)
final progressRepositoryProvider = ProgressRepositoryProvider._();

final class ProgressRepositoryProvider
    extends
        $FunctionalProvider<
          ProgressRepository,
          ProgressRepository,
          ProgressRepository
        >
    with $Provider<ProgressRepository> {
  ProgressRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'progressRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$progressRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProgressRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProgressRepository create(Ref ref) {
    return progressRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProgressRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProgressRepository>(value),
    );
  }
}

String _$progressRepositoryHash() =>
    r'0c0fb43e0abfb59207e3b96310bc2ff5ec60e042';

@ProviderFor(voiceRepository)
final voiceRepositoryProvider = VoiceRepositoryProvider._();

final class VoiceRepositoryProvider
    extends
        $FunctionalProvider<VoiceRepository, VoiceRepository, VoiceRepository>
    with $Provider<VoiceRepository> {
  VoiceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voiceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voiceRepositoryHash();

  @$internal
  @override
  $ProviderElement<VoiceRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VoiceRepository create(Ref ref) {
    return voiceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoiceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoiceRepository>(value),
    );
  }
}

String _$voiceRepositoryHash() => r'd64551a891dd4f56dd77262f123ecb83fe5f9a67';

@ProviderFor(backupRepository)
final backupRepositoryProvider = BackupRepositoryProvider._();

final class BackupRepositoryProvider
    extends
        $FunctionalProvider<
          BackupRepository,
          BackupRepository,
          BackupRepository
        >
    with $Provider<BackupRepository> {
  BackupRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupRepositoryHash();

  @$internal
  @override
  $ProviderElement<BackupRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BackupRepository create(Ref ref) {
    return backupRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackupRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackupRepository>(value),
    );
  }
}

String _$backupRepositoryHash() => r'9c73f549fd0ddf5e5861a02e0222820d6efab440';

/// A file opened with Starbook from another app, waiting for the gate.

@ProviderFor(IncomingFile)
final incomingFileProvider = IncomingFileProvider._();

/// A file opened with Starbook from another app, waiting for the gate.
final class IncomingFileProvider
    extends $NotifierProvider<IncomingFile, PickedFile?> {
  /// A file opened with Starbook from another app, waiting for the gate.
  IncomingFileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'incomingFileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$incomingFileHash();

  @$internal
  @override
  IncomingFile create() => IncomingFile();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PickedFile? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PickedFile?>(value),
    );
  }
}

String _$incomingFileHash() => r'ee4d346bc7d285404dee174efb29d53044b27604';

/// A file opened with Starbook from another app, waiting for the gate.

abstract class _$IncomingFile extends $Notifier<PickedFile?> {
  PickedFile? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PickedFile?, PickedFile?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PickedFile?, PickedFile?>,
              PickedFile?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(sfx)
final sfxProvider = SfxProvider._();

final class SfxProvider extends $FunctionalProvider<Sfx, Sfx, Sfx>
    with $Provider<Sfx> {
  SfxProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sfxProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sfxHash();

  @$internal
  @override
  $ProviderElement<Sfx> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Sfx create(Ref ref) {
    return sfx(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Sfx value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Sfx>(value),
    );
  }
}

String _$sfxHash() => r'a5294d12053ee40050523ee7d6b4fa3d8bdd1cfc';

/// The clock for today and this week. The store screenshot tool sets a fixed
/// school day. The progress repository takes its own now, so the tool sets
/// both from one date.

@ProviderFor(clock)
final clockProvider = ClockProvider._();

/// The clock for today and this week. The store screenshot tool sets a fixed
/// school day. The progress repository takes its own now, so the tool sets
/// both from one date.

final class ClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// The clock for today and this week. The store screenshot tool sets a fixed
  /// school day. The progress repository takes its own now, so the tool sets
  /// both from one date.
  ClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return clock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$clockHash() => r'3f65ad34ac6fcd532de9004042bdf2ed2bd85b13';

@ProviderFor(speaker)
final speakerProvider = SpeakerProvider._();

final class SpeakerProvider
    extends $FunctionalProvider<Speaker, Speaker, Speaker>
    with $Provider<Speaker> {
  SpeakerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'speakerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$speakerHash();

  @$internal
  @override
  $ProviderElement<Speaker> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Speaker create(Ref ref) {
    return speaker(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Speaker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Speaker>(value),
    );
  }
}

String _$speakerHash() => r'bd3a651d9e0f9a0cfed61210eb58863adb7502e0';

/// The current week with its live awards. Null when no sheet is installed.

@ProviderFor(thisWeek)
final thisWeekProvider = ThisWeekProvider._();

/// The current week with its live awards. Null when no sheet is installed.

final class ThisWeekProvider
    extends
        $FunctionalProvider<
          AsyncValue<ThisWeek?>,
          ThisWeek?,
          FutureOr<ThisWeek?>
        >
    with $FutureModifier<ThisWeek?>, $FutureProvider<ThisWeek?> {
  /// The current week with its live awards. Null when no sheet is installed.
  ThisWeekProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'thisWeekProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$thisWeekHash();

  @$internal
  @override
  $FutureProviderElement<ThisWeek?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ThisWeek?> create(Ref ref) {
    return thisWeek(ref);
  }
}

String _$thisWeekHash() => r'5ac91625edfbf8ed6ef518293af1daed6c2a86c6';

/// The current week, its live awards and the child, for parent today. It
/// marks nothing seen, so awards still land on home afterwards.

@ProviderFor(parentToday)
final parentTodayProvider = ParentTodayProvider._();

/// The current week, its live awards and the child, for parent today. It
/// marks nothing seen, so awards still land on home afterwards.

final class ParentTodayProvider
    extends
        $FunctionalProvider<
          AsyncValue<ParentToday>,
          ParentToday,
          FutureOr<ParentToday>
        >
    with $FutureModifier<ParentToday>, $FutureProvider<ParentToday> {
  /// The current week, its live awards and the child, for parent today. It
  /// marks nothing seen, so awards still land on home afterwards.
  ParentTodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'parentTodayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$parentTodayHash();

  @$internal
  @override
  $FutureProviderElement<ParentToday> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ParentToday> create(Ref ref) {
    return parentToday(ref);
  }
}

String _$parentTodayHash() => r'31540b3e66c15ee0b1b1e6571e082b41a2c65878';

/// Earned trophies and the sticker album, read each time the room opens.

@ProviderFor(trophyRoom)
final trophyRoomProvider = TrophyRoomProvider._();

/// Earned trophies and the sticker album, read each time the room opens.

final class TrophyRoomProvider
    extends
        $FunctionalProvider<
          AsyncValue<TrophyRoom>,
          TrophyRoom,
          FutureOr<TrophyRoom>
        >
    with $FutureModifier<TrophyRoom>, $FutureProvider<TrophyRoom> {
  /// Earned trophies and the sticker album, read each time the room opens.
  TrophyRoomProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trophyRoomProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trophyRoomHash();

  @$internal
  @override
  $FutureProviderElement<TrophyRoom> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<TrophyRoom> create(Ref ref) {
    return trophyRoom(ref);
  }
}

String _$trophyRoomHash() => r'639f0eb4c10ee966664d9fa29e07dc0c7bde434b';

/// The sticker album, newest first.

@ProviderFor(stickerBook)
final stickerBookProvider = StickerBookProvider._();

/// The sticker album, newest first.

final class StickerBookProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>
        >
    with $FutureModifier<List<String>>, $FutureProvider<List<String>> {
  /// The sticker album, newest first.
  StickerBookProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'stickerBookProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$stickerBookHash();

  @$internal
  @override
  $FutureProviderElement<List<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<String>> create(Ref ref) {
    return stickerBook(ref);
  }
}

String _$stickerBookHash() => r'f65ca6aa1890d581e7881daa995df62b063ad13b';

/// The current week and the habits ticked today, read each time the habit
/// screen opens.

@ProviderFor(habitsToday)
final habitsTodayProvider = HabitsTodayProvider._();

/// The current week and the habits ticked today, read each time the habit
/// screen opens.

final class HabitsTodayProvider
    extends
        $FunctionalProvider<
          AsyncValue<HabitsToday>,
          HabitsToday,
          FutureOr<HabitsToday>
        >
    with $FutureModifier<HabitsToday>, $FutureProvider<HabitsToday> {
  /// The current week and the habits ticked today, read each time the habit
  /// screen opens.
  HabitsTodayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'habitsTodayProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$habitsTodayHash();

  @$internal
  @override
  $FutureProviderElement<HabitsToday> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<HabitsToday> create(Ref ref) {
    return habitsToday(ref);
  }
}

String _$habitsTodayHash() => r'166423d7ab65dc9d8f1a856e5f5a9f88812f90aa';

/// Seconds left on the gate's lock, 0 when open. Kept alive so closing and
/// reopening the gate does not end the wait.

@ProviderFor(GateLock)
final gateLockProvider = GateLockProvider._();

/// Seconds left on the gate's lock, 0 when open. Kept alive so closing and
/// reopening the gate does not end the wait.
final class GateLockProvider extends $NotifierProvider<GateLock, int> {
  /// Seconds left on the gate's lock, 0 when open. Kept alive so closing and
  /// reopening the gate does not end the wait.
  GateLockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gateLockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gateLockHash();

  @$internal
  @override
  GateLock create() => GateLock();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$gateLockHash() => r'f8790a0939d4505e151c15c07098a22be0e572a8';

/// Seconds left on the gate's lock, 0 when open. Kept alive so closing and
/// reopening the gate does not end the wait.

abstract class _$GateLock extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
