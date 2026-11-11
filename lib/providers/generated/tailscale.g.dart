// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../tailscale.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Seeded from preferences before the first setup.

@ProviderFor(TailscaleNodeRecords)
final tailscaleNodeRecordsProvider = TailscaleNodeRecordsProvider._();

/// Seeded from preferences before the first setup.
final class TailscaleNodeRecordsProvider
    extends $NotifierProvider<TailscaleNodeRecords, List<TailscaleNodeRecord>> {
  /// Seeded from preferences before the first setup.
  TailscaleNodeRecordsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tailscaleNodeRecordsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tailscaleNodeRecordsHash();

  @$internal
  @override
  TailscaleNodeRecords create() => TailscaleNodeRecords();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TailscaleNodeRecord> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TailscaleNodeRecord>>(value),
    );
  }
}

String _$tailscaleNodeRecordsHash() =>
    r'504e2ae5ab72ad105b5ea51eb885b323f264fb5c';

/// Seeded from preferences before the first setup.

abstract class _$TailscaleNodeRecords
    extends $Notifier<List<TailscaleNodeRecord>> {
  List<TailscaleNodeRecord> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<List<TailscaleNodeRecord>, List<TailscaleNodeRecord>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<TailscaleNodeRecord>, List<TailscaleNodeRecord>>,
              List<TailscaleNodeRecord>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The node the legacy shared login went to; seeded with the node records.

@ProviderFor(TailscaleLegacyMigrated)
final tailscaleLegacyMigratedProvider = TailscaleLegacyMigratedProvider._();

/// The node the legacy shared login went to; seeded with the node records.
final class TailscaleLegacyMigratedProvider
    extends
        $NotifierProvider<TailscaleLegacyMigrated, TailscaleLegacyMigration?> {
  /// The node the legacy shared login went to; seeded with the node records.
  TailscaleLegacyMigratedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tailscaleLegacyMigratedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tailscaleLegacyMigratedHash();

  @$internal
  @override
  TailscaleLegacyMigrated create() => TailscaleLegacyMigrated();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TailscaleLegacyMigration? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TailscaleLegacyMigration?>(value),
    );
  }
}

String _$tailscaleLegacyMigratedHash() =>
    r'7269902dabde57ea1f289eef15efe9314a54be2a';

/// The node the legacy shared login went to; seeded with the node records.

abstract class _$TailscaleLegacyMigrated
    extends $Notifier<TailscaleLegacyMigration?> {
  TailscaleLegacyMigration? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<TailscaleLegacyMigration?, TailscaleLegacyMigration?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TailscaleLegacyMigration?, TailscaleLegacyMigration?>,
              TailscaleLegacyMigration?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(tailscaleSetup)
final tailscaleSetupProvider = TailscaleSetupProvider._();

final class TailscaleSetupProvider
    extends
        $FunctionalProvider<TailscaleSetup?, TailscaleSetup?, TailscaleSetup?>
    with $Provider<TailscaleSetup?> {
  TailscaleSetupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tailscaleSetupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tailscaleSetupHash();

  @$internal
  @override
  $ProviderElement<TailscaleSetup?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TailscaleSetup? create(Ref ref) {
    return tailscaleSetup(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TailscaleSetup? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TailscaleSetup?>(value),
    );
  }
}

String _$tailscaleSetupHash() => r'7f4c9f8b03c48c9b78fe30fdb98800489db70d4a';

@ProviderFor(TailscaleNodes)
final tailscaleNodesProvider = TailscaleNodesProvider._();

final class TailscaleNodesProvider
    extends $AsyncNotifierProvider<TailscaleNodes, List<TailscaleNode>> {
  TailscaleNodesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tailscaleNodesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tailscaleNodesHash();

  @$internal
  @override
  TailscaleNodes create() => TailscaleNodes();
}

String _$tailscaleNodesHash() => r'e47ce4280e3888c6507e5bf969a23ef1cd30cf11';

abstract class _$TailscaleNodes extends $AsyncNotifier<List<TailscaleNode>> {
  FutureOr<List<TailscaleNode>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<TailscaleNode>>, List<TailscaleNode>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<TailscaleNode>>, List<TailscaleNode>>,
              AsyncValue<List<TailscaleNode>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// By node name; an event of another generation is not about the node read.

@ProviderFor(TailscaleStateEvents)
final tailscaleStateEventsProvider = TailscaleStateEventsProvider._();

/// By node name; an event of another generation is not about the node read.
final class TailscaleStateEventsProvider
    extends
        $NotifierProvider<
          TailscaleStateEvents,
          Map<String, TailscaleStateEvent>
        > {
  /// By node name; an event of another generation is not about the node read.
  TailscaleStateEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tailscaleStateEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tailscaleStateEventsHash();

  @$internal
  @override
  TailscaleStateEvents create() => TailscaleStateEvents();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, TailscaleStateEvent> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, TailscaleStateEvent>>(
        value,
      ),
    );
  }
}

String _$tailscaleStateEventsHash() =>
    r'9bc725736122a69be7f3ae976cb04a0a0ef2d251';

/// By node name; an event of another generation is not about the node read.

abstract class _$TailscaleStateEvents
    extends $Notifier<Map<String, TailscaleStateEvent>> {
  Map<String, TailscaleStateEvent> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              Map<String, TailscaleStateEvent>,
              Map<String, TailscaleStateEvent>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<String, TailscaleStateEvent>,
                Map<String, TailscaleStateEvent>
              >,
              Map<String, TailscaleStateEvent>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
