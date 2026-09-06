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

String _$parentTodayHash() => r'0230b4c4cdff56732bf9b2af1c9f1c8220f2c7a6';

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
