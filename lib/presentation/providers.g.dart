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

String _$thisWeekHash() => r'f37dee1d5f84139b37963e41bffd73e56f57f933';
