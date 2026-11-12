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

/// Panel-added accounts of every profile, seeded from preferences; null when
/// the stored list could not be read, which refuses every write.

@ProviderFor(TailscaleManagedRecords)
final tailscaleManagedRecordsProvider = TailscaleManagedRecordsProvider._();

/// Panel-added accounts of every profile, seeded from preferences; null when
/// the stored list could not be read, which refuses every write.
final class TailscaleManagedRecordsProvider
    extends
        $NotifierProvider<
          TailscaleManagedRecords,
          List<TailscaleManagedRecord>?
        > {
  /// Panel-added accounts of every profile, seeded from preferences; null when
  /// the stored list could not be read, which refuses every write.
  TailscaleManagedRecordsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tailscaleManagedRecordsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tailscaleManagedRecordsHash();

  @$internal
  @override
  TailscaleManagedRecords create() => TailscaleManagedRecords();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TailscaleManagedRecord>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TailscaleManagedRecord>?>(
        value,
      ),
    );
  }
}

String _$tailscaleManagedRecordsHash() =>
    r'ea80c4d457f1d9a5f8d0c552b0eba0b57a3031b3';

/// Panel-added accounts of every profile, seeded from preferences; null when
/// the stored list could not be read, which refuses every write.

abstract class _$TailscaleManagedRecords
    extends $Notifier<List<TailscaleManagedRecord>?> {
  List<TailscaleManagedRecord>? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              List<TailscaleManagedRecord>?,
              List<TailscaleManagedRecord>?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                List<TailscaleManagedRecord>?,
                List<TailscaleManagedRecord>?
              >,
              List<TailscaleManagedRecord>?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The panel's view of each panel-added account, by its node key.

@ProviderFor(TailscaleManagedPanels)
final tailscaleManagedPanelsProvider = TailscaleManagedPanelsProvider._();

/// The panel's view of each panel-added account, by its node key.
final class TailscaleManagedPanelsProvider
    extends
        $NotifierProvider<
          TailscaleManagedPanels,
          Map<TailscaleNodeKey, TailscaleManagedPanel>
        > {
  /// The panel's view of each panel-added account, by its node key.
  TailscaleManagedPanelsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tailscaleManagedPanelsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tailscaleManagedPanelsHash();

  @$internal
  @override
  TailscaleManagedPanels create() => TailscaleManagedPanels();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    Map<TailscaleNodeKey, TailscaleManagedPanel> value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Map<TailscaleNodeKey, TailscaleManagedPanel>>(
            value,
          ),
    );
  }
}

String _$tailscaleManagedPanelsHash() =>
    r'bd38acfaa8f29892c3535383df9e6aa7bc4a3178';

/// The panel's view of each panel-added account, by its node key.

abstract class _$TailscaleManagedPanels
    extends $Notifier<Map<TailscaleNodeKey, TailscaleManagedPanel>> {
  Map<TailscaleNodeKey, TailscaleManagedPanel> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              Map<TailscaleNodeKey, TailscaleManagedPanel>,
              Map<TailscaleNodeKey, TailscaleManagedPanel>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<TailscaleNodeKey, TailscaleManagedPanel>,
                Map<TailscaleNodeKey, TailscaleManagedPanel>
              >,
              Map<TailscaleNodeKey, TailscaleManagedPanel>,
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

@ProviderFor(TailscaleLegacyStates)
final tailscaleLegacyStatesProvider = TailscaleLegacyStatesProvider._();

final class TailscaleLegacyStatesProvider
    extends
        $NotifierProvider<
          TailscaleLegacyStates,
          Map<TailscaleNodeKey, TailscaleLegacyState>
        > {
  TailscaleLegacyStatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tailscaleLegacyStatesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tailscaleLegacyStatesHash();

  @$internal
  @override
  TailscaleLegacyStates create() => TailscaleLegacyStates();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    Map<TailscaleNodeKey, TailscaleLegacyState> value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Map<TailscaleNodeKey, TailscaleLegacyState>>(
            value,
          ),
    );
  }
}

String _$tailscaleLegacyStatesHash() =>
    r'9a378a7e6d76ccc03c99bf26310e8999efca2302';

abstract class _$TailscaleLegacyStates
    extends $Notifier<Map<TailscaleNodeKey, TailscaleLegacyState>> {
  Map<TailscaleNodeKey, TailscaleLegacyState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              Map<TailscaleNodeKey, TailscaleLegacyState>,
              Map<TailscaleNodeKey, TailscaleLegacyState>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<TailscaleNodeKey, TailscaleLegacyState>,
                Map<TailscaleNodeKey, TailscaleLegacyState>
              >,
              Map<TailscaleNodeKey, TailscaleLegacyState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The panel's view of each node, by node key, so a result lands on the node
/// that asked for it whichever one the page shows by then.

@ProviderFor(TailscalePanelNodes)
final tailscalePanelNodesProvider = TailscalePanelNodesProvider._();

/// The panel's view of each node, by node key, so a result lands on the node
/// that asked for it whichever one the page shows by then.
final class TailscalePanelNodesProvider
    extends
        $NotifierProvider<
          TailscalePanelNodes,
          Map<TailscaleNodeKey, TailscalePanelNode>
        > {
  /// The panel's view of each node, by node key, so a result lands on the node
  /// that asked for it whichever one the page shows by then.
  TailscalePanelNodesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tailscalePanelNodesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tailscalePanelNodesHash();

  @$internal
  @override
  TailscalePanelNodes create() => TailscalePanelNodes();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<TailscaleNodeKey, TailscalePanelNode> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<Map<TailscaleNodeKey, TailscalePanelNode>>(value),
    );
  }
}

String _$tailscalePanelNodesHash() =>
    r'0b52d3784bf700e89ee9112db639b29935c8a5d6';

/// The panel's view of each node, by node key, so a result lands on the node
/// that asked for it whichever one the page shows by then.

abstract class _$TailscalePanelNodes
    extends $Notifier<Map<TailscaleNodeKey, TailscalePanelNode>> {
  Map<TailscaleNodeKey, TailscalePanelNode> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              Map<TailscaleNodeKey, TailscalePanelNode>,
              Map<TailscaleNodeKey, TailscalePanelNode>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<TailscaleNodeKey, TailscalePanelNode>,
                Map<TailscaleNodeKey, TailscalePanelNode>
              >,
              Map<TailscaleNodeKey, TailscalePanelNode>,
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

String _$tailscaleSetupHash() => r'23298e10a80d82a419904f72d8090aa7d420ace2';

/// The exit group the running config holds, read back after every groups
/// read; null while the current profile has no panel-added account.

@ProviderFor(TailscaleExitRuntime)
final tailscaleExitRuntimeProvider = TailscaleExitRuntimeProvider._();

/// The exit group the running config holds, read back after every groups
/// read; null while the current profile has no panel-added account.
final class TailscaleExitRuntimeProvider
    extends $AsyncNotifierProvider<TailscaleExitRuntime, TailscaleExitReport?> {
  /// The exit group the running config holds, read back after every groups
  /// read; null while the current profile has no panel-added account.
  TailscaleExitRuntimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tailscaleExitRuntimeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tailscaleExitRuntimeHash();

  @$internal
  @override
  TailscaleExitRuntime create() => TailscaleExitRuntime();
}

String _$tailscaleExitRuntimeHash() =>
    r'f7b561a7d2ed06afa2c89935a05b14f7cd6590f1';

/// The exit group the running config holds, read back after every groups
/// read; null while the current profile has no panel-added account.

abstract class _$TailscaleExitRuntime
    extends $AsyncNotifier<TailscaleExitReport?> {
  FutureOr<TailscaleExitReport?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<TailscaleExitReport?>, TailscaleExitReport?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<TailscaleExitReport?>,
                TailscaleExitReport?
              >,
              AsyncValue<TailscaleExitReport?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The Core's routing for the current profile's panel-added accounts; null
/// while it has none.

@ProviderFor(TailscaleRoutesReport)
final tailscaleRoutesReportProvider = TailscaleRoutesReportProvider._();

/// The Core's routing for the current profile's panel-added accounts; null
/// while it has none.
final class TailscaleRoutesReportProvider
    extends $AsyncNotifierProvider<TailscaleRoutesReport, TailscaleRoutes?> {
  /// The Core's routing for the current profile's panel-added accounts; null
  /// while it has none.
  TailscaleRoutesReportProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tailscaleRoutesReportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tailscaleRoutesReportHash();

  @$internal
  @override
  TailscaleRoutesReport create() => TailscaleRoutesReport();
}

String _$tailscaleRoutesReportHash() =>
    r'cce43c387eb6a68cdf333c9267632e6397f44a28';

/// The Core's routing for the current profile's panel-added accounts; null
/// while it has none.

abstract class _$TailscaleRoutesReport
    extends $AsyncNotifier<TailscaleRoutes?> {
  FutureOr<TailscaleRoutes?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<TailscaleRoutes?>, TailscaleRoutes?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TailscaleRoutes?>, TailscaleRoutes?>,
              AsyncValue<TailscaleRoutes?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

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
