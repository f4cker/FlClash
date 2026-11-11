// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../tailscale.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The panel's overrides and logout guards for every profile, seeded from
/// preferences before the first setup.

@ProviderFor(TailscaleNodeRecords)
final tailscaleNodeRecordsProvider = TailscaleNodeRecordsProvider._();

/// The panel's overrides and logout guards for every profile, seeded from
/// preferences before the first setup.
final class TailscaleNodeRecordsProvider
    extends $NotifierProvider<TailscaleNodeRecords, List<TailscaleNodeRecord>> {
  /// The panel's overrides and logout guards for every profile, seeded from
  /// preferences before the first setup.
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

/// The panel's overrides and logout guards for every profile, seeded from
/// preferences before the first setup.

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

String _$tailscaleSetupHash() => r'7b2f82c50f089699f29668b784edc60b6e22c127';

/// The nodes of the running config; read only while something watches it.

@ProviderFor(TailscaleNodes)
final tailscaleNodesProvider = TailscaleNodesProvider._();

/// The nodes of the running config; read only while something watches it.
final class TailscaleNodesProvider
    extends $AsyncNotifierProvider<TailscaleNodes, List<TailscaleNode>> {
  /// The nodes of the running config; read only while something watches it.
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

/// The nodes of the running config; read only while something watches it.

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

/// The last state the Core reported for each node name; compare its
/// generation with the node's before acting on it.

@ProviderFor(TailscaleStateEvents)
final tailscaleStateEventsProvider = TailscaleStateEventsProvider._();

/// The last state the Core reported for each node name; compare its
/// generation with the node's before acting on it.
final class TailscaleStateEventsProvider
    extends
        $NotifierProvider<
          TailscaleStateEvents,
          Map<String, TailscaleStateEvent>
        > {
  /// The last state the Core reported for each node name; compare its
  /// generation with the node's before acting on it.
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

/// The last state the Core reported for each node name; compare its
/// generation with the node's before acting on it.

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
