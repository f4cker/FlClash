// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../app.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(safeMode)
final safeModeProvider = SafeModeProvider._();

final class SafeModeProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  SafeModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'safeModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$safeModeHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return safeMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$safeModeHash() => r'3ef07344f5a8dbf775ccf0a4861c0317ec8b2266';

@ProviderFor(packageIconSource)
final packageIconSourceProvider = PackageIconSourceProvider._();

final class PackageIconSourceProvider
    extends $FunctionalProvider<App?, App?, App?>
    with $Provider<App?> {
  PackageIconSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'packageIconSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$packageIconSourceHash();

  @$internal
  @override
  $ProviderElement<App?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  App? create(Ref ref) {
    return packageIconSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(App? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<App?>(value),
    );
  }
}

String _$packageIconSourceHash() => r'b9b233f207f9dce3809537c3458e7a70192dd52d';

/// Android: su is there and granted FlClash's last request.

@ProviderFor(rootAccess)
final rootAccessProvider = RootAccessProvider._();

/// Android: su is there and granted FlClash's last request.

final class RootAccessProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Android: su is there and granted FlClash's last request.
  RootAccessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rootAccessProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rootAccessHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return rootAccess(ref);
  }
}

String _$rootAccessHash() => r'59f43852dbede9ebe3301b885d63cd0a3961126d';

@ProviderFor(AuthorizedTunEnable)
final authorizedTunEnableProvider = AuthorizedTunEnableProvider._();

final class AuthorizedTunEnableProvider
    extends $NotifierProvider<AuthorizedTunEnable, TunAuthorizationState> {
  AuthorizedTunEnableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authorizedTunEnableProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authorizedTunEnableHash();

  @$internal
  @override
  AuthorizedTunEnable create() => AuthorizedTunEnable();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TunAuthorizationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TunAuthorizationState>(value),
    );
  }
}

String _$authorizedTunEnableHash() =>
    r'75958aeb341f93a4573209f7bae5057936d9700a';

abstract class _$AuthorizedTunEnable extends $Notifier<TunAuthorizationState> {
  TunAuthorizationState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TunAuthorizationState, TunAuthorizationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TunAuthorizationState, TunAuthorizationState>,
              TunAuthorizationState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(UpdateDownloadState)
final updateDownloadStateProvider = UpdateDownloadStateProvider._();

final class UpdateDownloadStateProvider
    extends $NotifierProvider<UpdateDownloadState, UpdateDownload?> {
  UpdateDownloadStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateDownloadStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateDownloadStateHash();

  @$internal
  @override
  UpdateDownloadState create() => UpdateDownloadState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateDownload? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateDownload?>(value),
    );
  }
}

String _$updateDownloadStateHash() =>
    r'31a28cbffa1d4a3c35a478262ef61c10271048c9';

abstract class _$UpdateDownloadState extends $Notifier<UpdateDownload?> {
  UpdateDownload? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UpdateDownload?, UpdateDownload?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UpdateDownload?, UpdateDownload?>,
              UpdateDownload?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(AvailableUpdateState)
final availableUpdateStateProvider = AvailableUpdateStateProvider._();

final class AvailableUpdateStateProvider
    extends $NotifierProvider<AvailableUpdateState, UpdateAvailable?> {
  AvailableUpdateStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'availableUpdateStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$availableUpdateStateHash();

  @$internal
  @override
  AvailableUpdateState create() => AvailableUpdateState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateAvailable? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateAvailable?>(value),
    );
  }
}

String _$availableUpdateStateHash() =>
    r'ace841b1c0f37d154cb410d16481576542cb0aca';

abstract class _$AvailableUpdateState extends $Notifier<UpdateAvailable?> {
  UpdateAvailable? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UpdateAvailable?, UpdateAvailable?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UpdateAvailable?, UpdateAvailable?>,
              UpdateAvailable?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(TrayCoreTogglePending)
final trayCoreTogglePendingProvider = TrayCoreTogglePendingProvider._();

final class TrayCoreTogglePendingProvider
    extends $NotifierProvider<TrayCoreTogglePending, bool> {
  TrayCoreTogglePendingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trayCoreTogglePendingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trayCoreTogglePendingHash();

  @$internal
  @override
  TrayCoreTogglePending create() => TrayCoreTogglePending();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$trayCoreTogglePendingHash() =>
    r'd9ae1e5747b096282f913355f3e18a33925256e5';

abstract class _$TrayCoreTogglePending extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(LastUpdateCheckState)
final lastUpdateCheckStateProvider = LastUpdateCheckStateProvider._();

final class LastUpdateCheckStateProvider
    extends $NotifierProvider<LastUpdateCheckState, UpdateCheck?> {
  LastUpdateCheckStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lastUpdateCheckStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lastUpdateCheckStateHash();

  @$internal
  @override
  LastUpdateCheckState create() => LastUpdateCheckState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateCheck? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateCheck?>(value),
    );
  }
}

String _$lastUpdateCheckStateHash() =>
    r'31cb2589e4ee50d55dc9a64323308d4546a41486';

abstract class _$LastUpdateCheckState extends $Notifier<UpdateCheck?> {
  UpdateCheck? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UpdateCheck?, UpdateCheck?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UpdateCheck?, UpdateCheck?>,
              UpdateCheck?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(UpdateInstallBusy)
final updateInstallBusyProvider = UpdateInstallBusyProvider._();

final class UpdateInstallBusyProvider
    extends $NotifierProvider<UpdateInstallBusy, bool> {
  UpdateInstallBusyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateInstallBusyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateInstallBusyHash();

  @$internal
  @override
  UpdateInstallBusy create() => UpdateInstallBusy();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$updateInstallBusyHash() => r'2c5225d35b3b1e090e05ca16025b0f15e9283aca';

abstract class _$UpdateInstallBusy extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(UpdateInstallCommitted)
final updateInstallCommittedProvider = UpdateInstallCommittedProvider._();

final class UpdateInstallCommittedProvider
    extends $NotifierProvider<UpdateInstallCommitted, bool> {
  UpdateInstallCommittedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateInstallCommittedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateInstallCommittedHash();

  @$internal
  @override
  UpdateInstallCommitted create() => UpdateInstallCommitted();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$updateInstallCommittedHash() =>
    r'219aedf9f4e4ec1820a8b0e1f406e87419424233';

abstract class _$UpdateInstallCommitted extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(CoreCapabilitiesState)
final coreCapabilitiesStateProvider = CoreCapabilitiesStateProvider._();

final class CoreCapabilitiesStateProvider
    extends $NotifierProvider<CoreCapabilitiesState, CoreCapabilities> {
  CoreCapabilitiesStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coreCapabilitiesStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coreCapabilitiesStateHash();

  @$internal
  @override
  CoreCapabilitiesState create() => CoreCapabilitiesState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoreCapabilities value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoreCapabilities>(value),
    );
  }
}

String _$coreCapabilitiesStateHash() =>
    r'd1e986c16b1dac28ab6480019ee33108da0ef185';

abstract class _$CoreCapabilitiesState extends $Notifier<CoreCapabilities> {
  CoreCapabilities build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CoreCapabilities, CoreCapabilities>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CoreCapabilities, CoreCapabilities>,
              CoreCapabilities,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The warnings of the config the Core last set up; they end with the Core.

@ProviderFor(CoreStopReason)
final coreStopReasonProvider = CoreStopReasonProvider._();

/// The warnings of the config the Core last set up; they end with the Core.
final class CoreStopReasonProvider
    extends $NotifierProvider<CoreStopReason, String?> {
  /// The warnings of the config the Core last set up; they end with the Core.
  CoreStopReasonProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coreStopReasonProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coreStopReasonHash();

  @$internal
  @override
  CoreStopReason create() => CoreStopReason();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$coreStopReasonHash() => r'ba8ddb362ef3e025c5f052a68e896a0e728f9458';

/// The warnings of the config the Core last set up; they end with the Core.

abstract class _$CoreStopReason extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Positive evidence that the Core is stopped because of the macOS helper:
/// set exactly where the helper refused a start or was not ready for it, and
/// cleared once the Core leaves the stopped state. Only this lets the status
/// deck show the helper's card alone; a stop without it (no reason, or a
/// reason of its own) keeps its own card.

@ProviderFor(CoreStoppedForHelper)
final coreStoppedForHelperProvider = CoreStoppedForHelperProvider._();

/// Positive evidence that the Core is stopped because of the macOS helper:
/// set exactly where the helper refused a start or was not ready for it, and
/// cleared once the Core leaves the stopped state. Only this lets the status
/// deck show the helper's card alone; a stop without it (no reason, or a
/// reason of its own) keeps its own card.
final class CoreStoppedForHelperProvider
    extends $NotifierProvider<CoreStoppedForHelper, bool> {
  /// Positive evidence that the Core is stopped because of the macOS helper:
  /// set exactly where the helper refused a start or was not ready for it, and
  /// cleared once the Core leaves the stopped state. Only this lets the status
  /// deck show the helper's card alone; a stop without it (no reason, or a
  /// reason of its own) keeps its own card.
  CoreStoppedForHelperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coreStoppedForHelperProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coreStoppedForHelperHash();

  @$internal
  @override
  CoreStoppedForHelper create() => CoreStoppedForHelper();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$coreStoppedForHelperHash() =>
    r'1d54eff8cbf3f53cc4dd4dfa6d13928718088bcc';

/// Positive evidence that the Core is stopped because of the macOS helper:
/// set exactly where the helper refused a start or was not ready for it, and
/// cleared once the Core leaves the stopped state. Only this lets the status
/// deck show the helper's card alone; a stop without it (no reason, or a
/// reason of its own) keeps its own card.

abstract class _$CoreStoppedForHelper extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(Logs)
final logsProvider = LogsProvider._();

final class LogsProvider extends $NotifierProvider<Logs, FixedList<Log>> {
  LogsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'logsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$logsHash();

  @$internal
  @override
  Logs create() => Logs();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FixedList<Log> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FixedList<Log>>(value),
    );
  }
}

String _$logsHash() => r'aefb14ef2c0a3c7a4e27f2ac4188a5b2943e60b5';

abstract class _$Logs extends $Notifier<FixedList<Log>> {
  FixedList<Log> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FixedList<Log>, FixedList<Log>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FixedList<Log>, FixedList<Log>>,
              FixedList<Log>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(Requests)
final requestsProvider = RequestsProvider._();

final class RequestsProvider
    extends $NotifierProvider<Requests, FixedList<TrackerInfo>> {
  RequestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'requestsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$requestsHash();

  @$internal
  @override
  Requests create() => Requests();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FixedList<TrackerInfo> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FixedList<TrackerInfo>>(value),
    );
  }
}

String _$requestsHash() => r'f67984fd9c771f2571cfcf45b941b04ce6b61f5d';

abstract class _$Requests extends $Notifier<FixedList<TrackerInfo>> {
  FixedList<TrackerInfo> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<FixedList<TrackerInfo>, FixedList<TrackerInfo>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FixedList<TrackerInfo>, FixedList<TrackerInfo>>,
              FixedList<TrackerInfo>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(DnsQueries)
final dnsQueriesProvider = DnsQueriesProvider._();

final class DnsQueriesProvider
    extends $NotifierProvider<DnsQueries, FixedList<DnsQuery>> {
  DnsQueriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dnsQueriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dnsQueriesHash();

  @$internal
  @override
  DnsQueries create() => DnsQueries();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FixedList<DnsQuery> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FixedList<DnsQuery>>(value),
    );
  }
}

String _$dnsQueriesHash() => r'b6073d067db4fd19cc5724c5b79ecff2b0909796';

abstract class _$DnsQueries extends $Notifier<FixedList<DnsQuery>> {
  FixedList<DnsQuery> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FixedList<DnsQuery>, FixedList<DnsQuery>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FixedList<DnsQuery>, FixedList<DnsQuery>>,
              FixedList<DnsQuery>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(DnsQueryCount)
final dnsQueryCountProvider = DnsQueryCountProvider._();

final class DnsQueryCountProvider
    extends $NotifierProvider<DnsQueryCount, int> {
  DnsQueryCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dnsQueryCountProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dnsQueryCountHash();

  @$internal
  @override
  DnsQueryCount create() => DnsQueryCount();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$dnsQueryCountHash() => r'2de3bcb1c2fd622af728158bd9a1e169af632395';

abstract class _$DnsQueryCount extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(RequestCount)
final requestCountProvider = RequestCountProvider._();

final class RequestCountProvider extends $NotifierProvider<RequestCount, int> {
  RequestCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'requestCountProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$requestCountHash();

  @$internal
  @override
  RequestCount create() => RequestCount();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$requestCountHash() => r'aedb813c287a83a2588517f6c5c13e3f8089e0bc';

abstract class _$RequestCount extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(Providers)
final providersProvider = ProvidersProvider._();

final class ProvidersProvider
    extends $NotifierProvider<Providers, List<ExternalProvider>> {
  ProvidersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'providersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$providersHash();

  @$internal
  @override
  Providers create() => Providers();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ExternalProvider> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ExternalProvider>>(value),
    );
  }
}

String _$providersHash() => r'51d9bc898e1af8a7179c1c53145705b57d9a5996';

abstract class _$Providers extends $Notifier<List<ExternalProvider>> {
  List<ExternalProvider> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<List<ExternalProvider>, List<ExternalProvider>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<ExternalProvider>, List<ExternalProvider>>,
              List<ExternalProvider>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(Packages)
final packagesProvider = PackagesProvider._();

final class PackagesProvider
    extends $NotifierProvider<Packages, List<Package>> {
  PackagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'packagesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$packagesHash();

  @$internal
  @override
  Packages create() => Packages();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Package> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Package>>(value),
    );
  }
}

String _$packagesHash() => r'93c92438ed777ec4c3017b90c22f4ddd1c02e931';

abstract class _$Packages extends $Notifier<List<Package>> {
  List<Package> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<Package>, List<Package>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Package>, List<Package>>,
              List<Package>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(SystemBrightness)
final systemBrightnessProvider = SystemBrightnessProvider._();

final class SystemBrightnessProvider
    extends $NotifierProvider<SystemBrightness, Brightness> {
  SystemBrightnessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemBrightnessProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemBrightnessHash();

  @$internal
  @override
  SystemBrightness create() => SystemBrightness();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Brightness value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Brightness>(value),
    );
  }
}

String _$systemBrightnessHash() => r'5b8c93dc20f048b12cdad42b301afe8b9aa864cf';

abstract class _$SystemBrightness extends $Notifier<Brightness> {
  Brightness build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Brightness, Brightness>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Brightness, Brightness>,
              Brightness,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(Traffics)
final trafficsProvider = TrafficsProvider._();

final class TrafficsProvider
    extends $NotifierProvider<Traffics, FixedList<Traffic>> {
  TrafficsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trafficsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trafficsHash();

  @$internal
  @override
  Traffics create() => Traffics();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FixedList<Traffic> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FixedList<Traffic>>(value),
    );
  }
}

String _$trafficsHash() => r'1fea2cb24af6903156ffa46394a71d953092f33d';

abstract class _$Traffics extends $Notifier<FixedList<Traffic>> {
  FixedList<Traffic> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FixedList<Traffic>, FixedList<Traffic>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FixedList<Traffic>, FixedList<Traffic>>,
              FixedList<Traffic>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(TotalTraffic)
final totalTrafficProvider = TotalTrafficProvider._();

final class TotalTrafficProvider
    extends $NotifierProvider<TotalTraffic, Traffic> {
  TotalTrafficProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'totalTrafficProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$totalTrafficHash();

  @$internal
  @override
  TotalTraffic create() => TotalTraffic();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Traffic value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Traffic>(value),
    );
  }
}

String _$totalTrafficHash() => r'fc933692cd103acc8bcf02054a399659c08d9054';

abstract class _$TotalTraffic extends $Notifier<Traffic> {
  Traffic build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Traffic, Traffic>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Traffic, Traffic>,
              Traffic,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(LoadedLocale)
final loadedLocaleProvider = LoadedLocaleProvider._();

final class LoadedLocaleProvider
    extends $NotifierProvider<LoadedLocale, Locale?> {
  LoadedLocaleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loadedLocaleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loadedLocaleHash();

  @$internal
  @override
  LoadedLocale create() => LoadedLocale();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Locale? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Locale?>(value),
    );
  }
}

String _$loadedLocaleHash() => r'6ca54222dc817825edac43735535d96c2b0559d4';

abstract class _$LoadedLocale extends $Notifier<Locale?> {
  Locale? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Locale?, Locale?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Locale?, Locale?>,
              Locale?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(LocalIp)
final localIpProvider = LocalIpProvider._();

final class LocalIpProvider extends $NotifierProvider<LocalIp, String?> {
  LocalIpProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localIpProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localIpHash();

  @$internal
  @override
  LocalIp create() => LocalIp();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$localIpHash() => r'7daf4c498425db64db4e33b10c870d8fa10695d8';

abstract class _$LocalIp extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(RunTime)
final runTimeProvider = RunTimeProvider._();

final class RunTimeProvider extends $NotifierProvider<RunTime, int?> {
  RunTimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runTimeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runTimeHash();

  @$internal
  @override
  RunTime create() => RunTime();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$runTimeHash() => r'665a3a58487bb59aa54c3f797db0627986aa878f';

abstract class _$RunTime extends $Notifier<int?> {
  int? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The mixed port the desktop Core confirmed it holds since the run last
/// started, null until it has answered. The system proxy waits for it.

@ProviderFor(ListeningMixedPort)
final listeningMixedPortProvider = ListeningMixedPortProvider._();

/// The mixed port the desktop Core confirmed it holds since the run last
/// started, null until it has answered. The system proxy waits for it.
final class ListeningMixedPortProvider
    extends $NotifierProvider<ListeningMixedPort, int?> {
  /// The mixed port the desktop Core confirmed it holds since the run last
  /// started, null until it has answered. The system proxy waits for it.
  ListeningMixedPortProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'listeningMixedPortProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$listeningMixedPortHash();

  @$internal
  @override
  ListeningMixedPort create() => ListeningMixedPort();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }
}

String _$listeningMixedPortHash() =>
    r'19c00bf21419c59988ba396d284fd8638e325456';

/// The mixed port the desktop Core confirmed it holds since the run last
/// started, null until it has answered. The system proxy waits for it.

abstract class _$ListeningMixedPort extends $Notifier<int?> {
  int? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The inbounds the config last built asks for.

@ProviderFor(BuiltInbounds)
final builtInboundsProvider = BuiltInboundsProvider._();

/// The inbounds the config last built asks for.
final class BuiltInboundsProvider
    extends $NotifierProvider<BuiltInbounds, Map<String, Object?>> {
  /// The inbounds the config last built asks for.
  BuiltInboundsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'builtInboundsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$builtInboundsHash();

  @$internal
  @override
  BuiltInbounds create() => BuiltInbounds();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, Object?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, Object?>>(value),
    );
  }
}

String _$builtInboundsHash() => r'37154b622856783929fcb863fbe655b7527f4813';

/// The inbounds the config last built asks for.

abstract class _$BuiltInbounds extends $Notifier<Map<String, Object?>> {
  Map<String, Object?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Map<String, Object?>, Map<String, Object?>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, Object?>, Map<String, Object?>>,
              Map<String, Object?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Where each rule of the config last applied came from. The rules page
/// shows them only while the Core's list agrees with them.

@ProviderFor(AppliedRuleSourcesState)
final appliedRuleSourcesStateProvider = AppliedRuleSourcesStateProvider._();

/// Where each rule of the config last applied came from. The rules page
/// shows them only while the Core's list agrees with them.
final class AppliedRuleSourcesStateProvider
    extends $NotifierProvider<AppliedRuleSourcesState, AppliedRuleSources> {
  /// Where each rule of the config last applied came from. The rules page
  /// shows them only while the Core's list agrees with them.
  AppliedRuleSourcesStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appliedRuleSourcesStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appliedRuleSourcesStateHash();

  @$internal
  @override
  AppliedRuleSourcesState create() => AppliedRuleSourcesState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppliedRuleSources value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppliedRuleSources>(value),
    );
  }
}

String _$appliedRuleSourcesStateHash() =>
    r'eaa7b6bef22acbbd33eb223c1b4dbd2220559aed';

/// Where each rule of the config last applied came from. The rules page
/// shows them only while the Core's list agrees with them.

abstract class _$AppliedRuleSourcesState extends $Notifier<AppliedRuleSources> {
  AppliedRuleSources build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppliedRuleSources, AppliedRuleSources>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppliedRuleSources, AppliedRuleSources>,
              AppliedRuleSources,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(RulesLookupRequest)
final rulesLookupRequestProvider = RulesLookupRequestProvider._();

final class RulesLookupRequestProvider
    extends $NotifierProvider<RulesLookupRequest, RulesLookupAsk?> {
  RulesLookupRequestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rulesLookupRequestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rulesLookupRequestHash();

  @$internal
  @override
  RulesLookupRequest create() => RulesLookupRequest();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RulesLookupAsk? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RulesLookupAsk?>(value),
    );
  }
}

String _$rulesLookupRequestHash() =>
    r'02831a9c199e1027c0fb0e5949655ca33d5da0e8';

abstract class _$RulesLookupRequest extends $Notifier<RulesLookupAsk?> {
  RulesLookupAsk? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<RulesLookupAsk?, RulesLookupAsk?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<RulesLookupAsk?, RulesLookupAsk?>,
              RulesLookupAsk?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// A group the proxies page is asked to bring into view, unfolded and
/// briefly marked.

@ProviderFor(ProxiesReveal)
final proxiesRevealProvider = ProxiesRevealProvider._();

/// A group the proxies page is asked to bring into view, unfolded and
/// briefly marked.
final class ProxiesRevealProvider
    extends $NotifierProvider<ProxiesReveal, ({String group, int serial})?> {
  /// A group the proxies page is asked to bring into view, unfolded and
  /// briefly marked.
  ProxiesRevealProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'proxiesRevealProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$proxiesRevealHash();

  @$internal
  @override
  ProxiesReveal create() => ProxiesReveal();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({String group, int serial})? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<({String group, int serial})?>(
        value,
      ),
    );
  }
}

String _$proxiesRevealHash() => r'627e89925a7b031db637854e8114fd238b115d94';

/// A group the proxies page is asked to bring into view, unfolded and
/// briefly marked.

abstract class _$ProxiesReveal
    extends $Notifier<({String group, int serial})?> {
  ({String group, int serial})? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({String group, int serial})?,
              ({String group, int serial})?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({String group, int serial})?,
                ({String group, int serial})?
              >,
              ({String group, int serial})?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The current profile's own settings, as the last build read them.

@ProviderFor(ProfileSettings)
final profileSettingsProvider = ProfileSettingsProvider._();

/// The current profile's own settings, as the last build read them.
final class ProfileSettingsProvider
    extends $NotifierProvider<ProfileSettings, Map<String, Object?>?> {
  /// The current profile's own settings, as the last build read them.
  ProfileSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileSettingsHash();

  @$internal
  @override
  ProfileSettings create() => ProfileSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, Object?>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, Object?>?>(value),
    );
  }
}

String _$profileSettingsHash() => r'068f18d65ed3b97c1b5aab3802d1091470450240';

/// The current profile's own settings, as the last build read them.

abstract class _$ProfileSettings extends $Notifier<Map<String, Object?>?> {
  Map<String, Object?>? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Map<String, Object?>?, Map<String, Object?>?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, Object?>?, Map<String, Object?>?>,
              Map<String, Object?>?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The fields the config the Core runs takes from the profile.

@ProviderFor(AppliedFollowKeys)
final appliedFollowKeysProvider = AppliedFollowKeysProvider._();

/// The fields the config the Core runs takes from the profile.
final class AppliedFollowKeysProvider
    extends $NotifierProvider<AppliedFollowKeys, Set<PageConfigKey>> {
  /// The fields the config the Core runs takes from the profile.
  AppliedFollowKeysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appliedFollowKeysProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appliedFollowKeysHash();

  @$internal
  @override
  AppliedFollowKeys create() => AppliedFollowKeys();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<PageConfigKey> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<PageConfigKey>>(value),
    );
  }
}

String _$appliedFollowKeysHash() => r'a7412c3f5b5c9438ec9ce0a51ead38a2e3dc9967';

/// The fields the config the Core runs takes from the profile.

abstract class _$AppliedFollowKeys extends $Notifier<Set<PageConfigKey>> {
  Set<PageConfigKey> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<PageConfigKey>, Set<PageConfigKey>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<PageConfigKey>, Set<PageConfigKey>>,
              Set<PageConfigKey>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// What the running Android service was started with: it builds the tunnel
/// once, so a later change waits for a restart.

@ProviderFor(RunningVpnOptions)
final runningVpnOptionsProvider = RunningVpnOptionsProvider._();

/// What the running Android service was started with: it builds the tunnel
/// once, so a later change waits for a restart.
final class RunningVpnOptionsProvider
    extends $NotifierProvider<RunningVpnOptions, VpnOptions?> {
  /// What the running Android service was started with: it builds the tunnel
  /// once, so a later change waits for a restart.
  RunningVpnOptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runningVpnOptionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runningVpnOptionsHash();

  @$internal
  @override
  RunningVpnOptions create() => RunningVpnOptions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VpnOptions? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VpnOptions?>(value),
    );
  }
}

String _$runningVpnOptionsHash() => r'9025007c52157af09895d6e0b3ab3c1f0fa801ca';

/// What the running Android service was started with: it builds the tunnel
/// once, so a later change waits for a restart.

abstract class _$RunningVpnOptions extends $Notifier<VpnOptions?> {
  VpnOptions? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<VpnOptions?, VpnOptions?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VpnOptions?, VpnOptions?>,
              VpnOptions?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// False while the window is hidden or the Android activity is in the
/// background; work that only feeds the UI waits for it to come back.

@ProviderFor(AppVisible)
final appVisibleProvider = AppVisibleProvider._();

/// False while the window is hidden or the Android activity is in the
/// background; work that only feeds the UI waits for it to come back.
final class AppVisibleProvider extends $NotifierProvider<AppVisible, bool> {
  /// False while the window is hidden or the Android activity is in the
  /// background; work that only feeds the UI waits for it to come back.
  AppVisibleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appVisibleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appVisibleHash();

  @$internal
  @override
  AppVisible create() => AppVisible();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$appVisibleHash() => r'98f3d41169c74da3d8655695627c8e4a5413c73d';

/// False while the window is hidden or the Android activity is in the
/// background; work that only feeds the UI waits for it to come back.

abstract class _$AppVisible extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ViewSize)
final viewSizeProvider = ViewSizeProvider._();

final class ViewSizeProvider extends $NotifierProvider<ViewSize, Size> {
  ViewSizeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewSizeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewSizeHash();

  @$internal
  @override
  ViewSize create() => ViewSize();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Size value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Size>(value),
    );
  }
}

String _$viewSizeHash() => r'3f355412237dc1234cca0d97972ac2eef1eb4792';

abstract class _$ViewSize extends $Notifier<Size> {
  Size build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Size, Size>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Size, Size>,
              Size,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(SideWidth)
final sideWidthProvider = SideWidthProvider._();

final class SideWidthProvider extends $NotifierProvider<SideWidth, double> {
  SideWidthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sideWidthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sideWidthHash();

  @$internal
  @override
  SideWidth create() => SideWidth();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$sideWidthHash() => r'2f849d52dab271831bad68b07c1f90b5c18c0cc4';

abstract class _$SideWidth extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The opacity the sidebar keeps its own color at over the backdrop the native
/// window draws behind the content, or null while it draws none.

@ProviderFor(WindowBlur)
final windowBlurProvider = WindowBlurProvider._();

/// The opacity the sidebar keeps its own color at over the backdrop the native
/// window draws behind the content, or null while it draws none.
final class WindowBlurProvider extends $NotifierProvider<WindowBlur, double?> {
  /// The opacity the sidebar keeps its own color at over the backdrop the native
  /// window draws behind the content, or null while it draws none.
  WindowBlurProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'windowBlurProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$windowBlurHash();

  @$internal
  @override
  WindowBlur create() => WindowBlur();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double?>(value),
    );
  }
}

String _$windowBlurHash() => r'0233223726071e4dd10bcb5875977dc652100e15';

/// The opacity the sidebar keeps its own color at over the backdrop the native
/// window draws behind the content, or null while it draws none.

abstract class _$WindowBlur extends $Notifier<double?> {
  double? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<double?, double?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double?, double?>,
              double?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(viewWidth)
final viewWidthProvider = ViewWidthProvider._();

final class ViewWidthProvider
    extends $FunctionalProvider<double, double, double>
    with $Provider<double> {
  ViewWidthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewWidthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewWidthHash();

  @$internal
  @override
  $ProviderElement<double> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  double create(Ref ref) {
    return viewWidth(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$viewWidthHash() => r'5ee8f1bdebe44760f7333f88127108f5ffd70214';

@ProviderFor(viewMode)
final viewModeProvider = ViewModeProvider._();

final class ViewModeProvider
    extends $FunctionalProvider<ViewMode, ViewMode, ViewMode>
    with $Provider<ViewMode> {
  ViewModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'viewModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$viewModeHash();

  @$internal
  @override
  $ProviderElement<ViewMode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ViewMode create(Ref ref) {
    return viewMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewMode>(value),
    );
  }
}

String _$viewModeHash() => r'56f81d519e3835bddef4a3905182991169c17619';

@ProviderFor(isMobileView)
final isMobileViewProvider = IsMobileViewProvider._();

final class IsMobileViewProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  IsMobileViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isMobileViewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isMobileViewHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isMobileView(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isMobileViewHash() => r'1d75bccb4f50ae206bf43b68df869a5d95e5ea5f';

@ProviderFor(Init)
final initProvider = InitProvider._();

final class InitProvider extends $NotifierProvider<Init, bool> {
  InitProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initHash();

  @$internal
  @override
  Init create() => Init();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$initHash() => r'0fcded1ed3c62f2658898dee845455e412b171b1';

abstract class _$Init extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(CurrentPageLabel)
final currentPageLabelProvider = CurrentPageLabelProvider._();

final class CurrentPageLabelProvider
    extends $NotifierProvider<CurrentPageLabel, PageLabel> {
  CurrentPageLabelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentPageLabelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentPageLabelHash();

  @$internal
  @override
  CurrentPageLabel create() => CurrentPageLabel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PageLabel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PageLabel>(value),
    );
  }
}

String _$currentPageLabelHash() => r'ccdbe5d0e0d2c324f74b3e2086d3e581740dd9bf';

abstract class _$CurrentPageLabel extends $Notifier<PageLabel> {
  PageLabel build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PageLabel, PageLabel>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PageLabel, PageLabel>,
              PageLabel,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(SortNum)
final sortNumProvider = SortNumProvider._();

final class SortNumProvider extends $NotifierProvider<SortNum, int> {
  SortNumProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sortNumProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sortNumHash();

  @$internal
  @override
  SortNum create() => SortNum();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$sortNumHash() => r'6682f00d1f87cb17f294ad181ac96bf4dc6edb52';

abstract class _$SortNum extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(Version)
final versionProvider = VersionProvider._();

final class VersionProvider extends $NotifierProvider<Version, int> {
  VersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'versionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$versionHash();

  @$internal
  @override
  Version create() => Version();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$versionHash() => r'00b43faa4061121d30a0612ed275644a402ce3fa';

abstract class _$Version extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(Groups)
final groupsProvider = GroupsProvider._();

final class GroupsProvider extends $NotifierProvider<Groups, List<Group>> {
  GroupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupsHash();

  @$internal
  @override
  Groups create() => Groups();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Group> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Group>>(value),
    );
  }
}

String _$groupsHash() => r'180ede48880a239add201c111ae45b2a6d98f3a5';

abstract class _$Groups extends $Notifier<List<Group>> {
  List<Group> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<Group>, List<Group>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Group>, List<Group>>,
              List<Group>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(DelayDataSource)
final delayDataSourceProvider = DelayDataSourceProvider._();

final class DelayDataSourceProvider
    extends $NotifierProvider<DelayDataSource, DelayMap> {
  DelayDataSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'delayDataSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$delayDataSourceHash();

  @$internal
  @override
  DelayDataSource create() => DelayDataSource();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DelayMap value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DelayMap>(value),
    );
  }
}

String _$delayDataSourceHash() => r'0d0fb2faccb3ce4539ce683b1a2bc4dcb8c8f3c0';

abstract class _$DelayDataSource extends $Notifier<DelayMap> {
  DelayMap build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DelayMap, DelayMap>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DelayMap, DelayMap>,
              DelayMap,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(PendingDelayTests)
final pendingDelayTestsProvider = PendingDelayTestsProvider._();

final class PendingDelayTestsProvider
    extends $NotifierProvider<PendingDelayTests, Map<String, DelayTestPhase>> {
  PendingDelayTestsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingDelayTestsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingDelayTestsHash();

  @$internal
  @override
  PendingDelayTests create() => PendingDelayTests();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, DelayTestPhase> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, DelayTestPhase>>(value),
    );
  }
}

String _$pendingDelayTestsHash() => r'e1e306c07e3ee017fe87ffd2f93884418b6caa03';

abstract class _$PendingDelayTests
    extends $Notifier<Map<String, DelayTestPhase>> {
  Map<String, DelayTestPhase> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<Map<String, DelayTestPhase>, Map<String, DelayTestPhase>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<String, DelayTestPhase>,
                Map<String, DelayTestPhase>
              >,
              Map<String, DelayTestPhase>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(DelayTestingGroups)
final delayTestingGroupsProvider = DelayTestingGroupsProvider._();

final class DelayTestingGroupsProvider
    extends $NotifierProvider<DelayTestingGroups, Set<String>> {
  DelayTestingGroupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'delayTestingGroupsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$delayTestingGroupsHash();

  @$internal
  @override
  DelayTestingGroups create() => DelayTestingGroups();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$delayTestingGroupsHash() =>
    r'3a56d623f940786303d78590b18440bcd007fab4';

abstract class _$DelayTestingGroups extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(HotKeyFailures)
final hotKeyFailuresProvider = HotKeyFailuresProvider._();

final class HotKeyFailuresProvider
    extends $NotifierProvider<HotKeyFailures, Map<HotAction, String>> {
  HotKeyFailuresProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hotKeyFailuresProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hotKeyFailuresHash();

  @$internal
  @override
  HotKeyFailures create() => HotKeyFailures();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<HotAction, String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<HotAction, String>>(value),
    );
  }
}

String _$hotKeyFailuresHash() => r'ab0d31dd41cae6a1445461c5a978809eee350509';

abstract class _$HotKeyFailures extends $Notifier<Map<HotAction, String>> {
  Map<HotAction, String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<Map<HotAction, String>, Map<HotAction, String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<HotAction, String>, Map<HotAction, String>>,
              Map<HotAction, String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(HotKeyRecording)
final hotKeyRecordingProvider = HotKeyRecordingProvider._();

final class HotKeyRecordingProvider
    extends $NotifierProvider<HotKeyRecording, bool> {
  HotKeyRecordingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hotKeyRecordingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hotKeyRecordingHash();

  @$internal
  @override
  HotKeyRecording create() => HotKeyRecording();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hotKeyRecordingHash() => r'8cbbdb394fcc10ae564e4e91696668cc8a327507';

abstract class _$HotKeyRecording extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(SystemUiOverlayStyleState)
final systemUiOverlayStyleStateProvider = SystemUiOverlayStyleStateProvider._();

final class SystemUiOverlayStyleStateProvider
    extends $NotifierProvider<SystemUiOverlayStyleState, SystemUiOverlayStyle> {
  SystemUiOverlayStyleStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemUiOverlayStyleStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemUiOverlayStyleStateHash();

  @$internal
  @override
  SystemUiOverlayStyleState create() => SystemUiOverlayStyleState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemUiOverlayStyle value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemUiOverlayStyle>(value),
    );
  }
}

String _$systemUiOverlayStyleStateHash() =>
    r'e933e3b01fca397e084f75fab5f0be22f0a08257';

abstract class _$SystemUiOverlayStyleState
    extends $Notifier<SystemUiOverlayStyle> {
  SystemUiOverlayStyle build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SystemUiOverlayStyle, SystemUiOverlayStyle>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SystemUiOverlayStyle, SystemUiOverlayStyle>,
              SystemUiOverlayStyle,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(_CoreStatus)
final coreStatusProvider = _CoreStatusProvider._();

final class _CoreStatusProvider
    extends $NotifierProvider<_CoreStatus, CoreStatus> {
  _CoreStatusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coreStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_coreStatusHash();

  @$internal
  @override
  _CoreStatus create() => _CoreStatus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoreStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoreStatus>(value),
    );
  }
}

String _$_coreStatusHash() => r'e2e7fe37f66b906877e678149d09c656993e1405';

abstract class _$CoreStatus extends $Notifier<CoreStatus> {
  CoreStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CoreStatus, CoreStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CoreStatus, CoreStatus>,
              CoreStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The find-process-mode the running Core was confirmed to apply, as the
/// config spells it; null while unconfirmed or with the Core stopped.

@ProviderFor(RunningFindProcessMode)
final runningFindProcessModeProvider = RunningFindProcessModeProvider._();

/// The find-process-mode the running Core was confirmed to apply, as the
/// config spells it; null while unconfirmed or with the Core stopped.
final class RunningFindProcessModeProvider
    extends $NotifierProvider<RunningFindProcessMode, String?> {
  /// The find-process-mode the running Core was confirmed to apply, as the
  /// config spells it; null while unconfirmed or with the Core stopped.
  RunningFindProcessModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'runningFindProcessModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$runningFindProcessModeHash();

  @$internal
  @override
  RunningFindProcessMode create() => RunningFindProcessMode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$runningFindProcessModeHash() =>
    r'be3a3f09e9a3ce76ef5a23464237bbc24252efa8';

/// The find-process-mode the running Core was confirmed to apply, as the
/// config spells it; null while unconfirmed or with the Core stopped.

abstract class _$RunningFindProcessMode extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(Query)
final queryProvider = QueryFamily._();

final class QueryProvider extends $NotifierProvider<Query, String> {
  QueryProvider._({
    required QueryFamily super.from,
    required QueryTag super.argument,
  }) : super(
         retry: null,
         name: r'queryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$queryHash();

  @override
  String toString() {
    return r'queryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  Query create() => Query();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is QueryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$queryHash() => r'b6be53823f3351ee2bf1c0d147c0ccf5f31bb8b5';

final class QueryFamily extends $Family
    with $ClassFamilyOverride<Query, String, String, String, QueryTag> {
  QueryFamily._()
    : super(
        retry: null,
        name: r'queryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  QueryProvider call(QueryTag tag) =>
      QueryProvider._(argument: tag, from: this);

  @override
  String toString() => r'queryProvider';
}

abstract class _$Query extends $Notifier<String> {
  late final _$args = ref.$arg as QueryTag;
  QueryTag get tag => _$args;

  String build(QueryTag tag);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(Loading)
final loadingProvider = LoadingFamily._();

final class LoadingProvider extends $NotifierProvider<Loading, bool> {
  LoadingProvider._({
    required LoadingFamily super.from,
    required LoadingTag super.argument,
  }) : super(
         retry: null,
         name: r'loadingProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$loadingHash();

  @override
  String toString() {
    return r'loadingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  Loading create() => Loading();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LoadingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$loadingHash() => r'0e92aaf1ff26aeba3fb3dc196bbf2ab0a061b720';

final class LoadingFamily extends $Family
    with $ClassFamilyOverride<Loading, bool, bool, bool, LoadingTag> {
  LoadingFamily._()
    : super(
        retry: null,
        name: r'loadingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  LoadingProvider call(LoadingTag tag) =>
      LoadingProvider._(argument: tag, from: this);

  @override
  String toString() => r'loadingProvider';
}

abstract class _$Loading extends $Notifier<bool> {
  late final _$args = ref.$arg as LoadingTag;
  LoadingTag get tag => _$args;

  bool build(LoadingTag tag);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(Items)
final itemsProvider = ItemsFamily._();

final class ItemsProvider extends $NotifierProvider<Items, Set<dynamic>> {
  ItemsProvider._({
    required ItemsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'itemsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$itemsHash();

  @override
  String toString() {
    return r'itemsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  Items create() => Items();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<dynamic> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<dynamic>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ItemsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$itemsHash() => r'e4d68c86d62dfa3ba7153954208891e4df4c4355';

final class ItemsFamily extends $Family
    with
        $ClassFamilyOverride<
          Items,
          Set<dynamic>,
          Set<dynamic>,
          Set<dynamic>,
          String
        > {
  ItemsFamily._()
    : super(
        retry: null,
        name: r'itemsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ItemsProvider call(String key) => ItemsProvider._(argument: key, from: this);

  @override
  String toString() => r'itemsProvider';
}

abstract class _$Items extends $Notifier<Set<dynamic>> {
  late final _$args = ref.$arg as String;
  String get key => _$args;

  Set<dynamic> build(String key);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<dynamic>, Set<dynamic>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<dynamic>, Set<dynamic>>,
              Set<dynamic>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(UpdatingKeys)
final updatingKeysProvider = UpdatingKeysProvider._();

final class UpdatingKeysProvider
    extends $NotifierProvider<UpdatingKeys, Set<String>> {
  UpdatingKeysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updatingKeysProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updatingKeysHash();

  @$internal
  @override
  UpdatingKeys create() => UpdatingKeys();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$updatingKeysHash() => r'db5de1510c55c26685ac3055f199535e7eba42c3';

abstract class _$UpdatingKeys extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(isUpdating)
final isUpdatingProvider = IsUpdatingFamily._();

final class IsUpdatingProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  IsUpdatingProvider._({
    required IsUpdatingFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'isUpdatingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$isUpdatingHash();

  @override
  String toString() {
    return r'isUpdatingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    final argument = this.argument as String;
    return isUpdating(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IsUpdatingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$isUpdatingHash() => r'5055409241b737f6d0b9e43d850a5beea9c2b4c8';

final class IsUpdatingFamily extends $Family
    with $FunctionalFamilyOverride<bool, String> {
  IsUpdatingFamily._()
    : super(
        retry: null,
        name: r'isUpdatingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  IsUpdatingProvider call(String name) =>
      IsUpdatingProvider._(argument: name, from: this);

  @override
  String toString() => r'isUpdatingProvider';
}

@ProviderFor(CurrentSSID)
final currentSSIDProvider = CurrentSSIDProvider._();

final class CurrentSSIDProvider
    extends $NotifierProvider<CurrentSSID, String?> {
  CurrentSSIDProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSSIDProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentSSIDHash();

  @$internal
  @override
  CurrentSSID create() => CurrentSSID();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$currentSSIDHash() => r'287929b3e4d6658775012eb47f0d4f956ae31d0d';

abstract class _$CurrentSSID extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(installedMacRelease)
final installedMacReleaseProvider = InstalledMacReleaseProvider._();

final class InstalledMacReleaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<MacInstalledIdentity?>,
          MacInstalledIdentity?,
          FutureOr<MacInstalledIdentity?>
        >
    with
        $FutureModifier<MacInstalledIdentity?>,
        $FutureProvider<MacInstalledIdentity?> {
  InstalledMacReleaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'installedMacReleaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$installedMacReleaseHash();

  @$internal
  @override
  $FutureProviderElement<MacInstalledIdentity?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MacInstalledIdentity?> create(Ref ref) {
    return installedMacRelease(ref);
  }
}

String _$installedMacReleaseHash() =>
    r'2319420bb77f7ad5dbd11d356908df1aa7d32524';

@ProviderFor(appUpdateRequest)
final appUpdateRequestProvider = AppUpdateRequestProvider._();

final class AppUpdateRequestProvider
    extends $FunctionalProvider<Request, Request, Request>
    with $Provider<Request> {
  AppUpdateRequestProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appUpdateRequestProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appUpdateRequestHash();

  @$internal
  @override
  $ProviderElement<Request> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Request create(Ref ref) {
    return appUpdateRequest(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Request value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Request>(value),
    );
  }
}

String _$appUpdateRequestHash() => r'5202f7edd03b259ec0469aefaba4bba4f2811086';
