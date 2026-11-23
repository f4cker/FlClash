// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../mitm.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// On macOS the app, not the Core, holds the CA: its key stays in the login
/// keychain and the Core asks the app to sign each leaf.

@ProviderFor(mitmSigner)
final mitmSignerProvider = MitmSignerProvider._();

/// On macOS the app, not the Core, holds the CA: its key stays in the login
/// keychain and the Core asks the app to sign each leaf.

final class MitmSignerProvider
    extends $FunctionalProvider<MitmSigner?, MitmSigner?, MitmSigner?>
    with $Provider<MitmSigner?> {
  /// On macOS the app, not the Core, holds the CA: its key stays in the login
  /// keychain and the Core asks the app to sign each leaf.
  MitmSignerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmSignerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmSignerHash();

  @$internal
  @override
  $ProviderElement<MitmSigner?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MitmSigner? create(Ref ref) {
    return mitmSigner(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MitmSigner? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MitmSigner?>(value),
    );
  }
}

String _$mitmSignerHash() => r'ab8de0f9cd6a25e1f2dbdf96297f19f916c0b591';

@ProviderFor(MitmCa)
final mitmCaProvider = MitmCaProvider._();

final class MitmCaProvider
    extends $AsyncNotifierProvider<MitmCa, MitmCertificate?> {
  MitmCaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmCaProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmCaHash();

  @$internal
  @override
  MitmCa create() => MitmCa();
}

String _$mitmCaHash() => r'8ea205519c0e2381e2a2389f39075d8d526fd1d2';

abstract class _$MitmCa extends $AsyncNotifier<MitmCertificate?> {
  FutureOr<MitmCertificate?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<MitmCertificate?>, MitmCertificate?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MitmCertificate?>, MitmCertificate?>,
              AsyncValue<MitmCertificate?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(MitmCoreIdentityState)
final mitmCoreIdentityStateProvider = MitmCoreIdentityStateProvider._();

final class MitmCoreIdentityStateProvider
    extends $AsyncNotifierProvider<MitmCoreIdentityState, MitmCoreIdentity> {
  MitmCoreIdentityStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmCoreIdentityStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmCoreIdentityStateHash();

  @$internal
  @override
  MitmCoreIdentityState create() => MitmCoreIdentityState();
}

String _$mitmCoreIdentityStateHash() =>
    r'efd375e4416054197a22016e5f1cc405f8ab742b';

abstract class _$MitmCoreIdentityState
    extends $AsyncNotifier<MitmCoreIdentity> {
  FutureOr<MitmCoreIdentity> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<MitmCoreIdentity>, MitmCoreIdentity>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MitmCoreIdentity>, MitmCoreIdentity>,
              AsyncValue<MitmCoreIdentity>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(mitmCoreRefused)
final mitmCoreRefusedProvider = MitmCoreRefusedProvider._();

final class MitmCoreRefusedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  MitmCoreRefusedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmCoreRefusedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmCoreRefusedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return mitmCoreRefused(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$mitmCoreRefusedHash() => r'5d09203ae306fc893ff3194f4f26975d63d42cd5';

/// How many `mitm` hostnames the running profile wrote, all of them ignored.

@ProviderFor(mitmIgnoredHostnames)
final mitmIgnoredHostnamesProvider = MitmIgnoredHostnamesProvider._();

/// How many `mitm` hostnames the running profile wrote, all of them ignored.

final class MitmIgnoredHostnamesProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// How many `mitm` hostnames the running profile wrote, all of them ignored.
  MitmIgnoredHostnamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmIgnoredHostnamesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmIgnoredHostnamesHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return mitmIgnoredHostnames(ref);
  }
}

String _$mitmIgnoredHostnamesHash() =>
    r'79208567cf4cf68f68e262bb6be630681ef12327';

/// Answers the Core's `mitmSign` with a leaf for a host on the list the Core
/// decrypts (the user's hostnames, then the enabled modules', see
/// [mitmEffectiveHostnames]), or with why not; the Core passes the connection
/// through on a refusal. A module turned off, deleted or declined leaves the
/// list at once, before the Core is told.

@ProviderFor(MitmSignAction)
final mitmSignActionProvider = MitmSignActionProvider._();

/// Answers the Core's `mitmSign` with a leaf for a host on the list the Core
/// decrypts (the user's hostnames, then the enabled modules', see
/// [mitmEffectiveHostnames]), or with why not; the Core passes the connection
/// through on a refusal. A module turned off, deleted or declined leaves the
/// list at once, before the Core is told.
final class MitmSignActionProvider
    extends $NotifierProvider<MitmSignAction, void> {
  /// Answers the Core's `mitmSign` with a leaf for a host on the list the Core
  /// decrypts (the user's hostnames, then the enabled modules', see
  /// [mitmEffectiveHostnames]), or with why not; the Core passes the connection
  /// through on a refusal. A module turned off, deleted or declined leaves the
  /// list at once, before the Core is told.
  MitmSignActionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmSignActionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmSignActionHash();

  @$internal
  @override
  MitmSignAction create() => MitmSignAction();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$mitmSignActionHash() => r'6fb586a11ab0305774748e489a9ae6b4d717dfad';

/// Answers the Core's `mitmSign` with a leaf for a host on the list the Core
/// decrypts (the user's hostnames, then the enabled modules', see
/// [mitmEffectiveHostnames]), or with why not; the Core passes the connection
/// through on a refusal. A module turned off, deleted or declined leaves the
/// list at once, before the Core is told.

abstract class _$MitmSignAction extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(mitmTrustStore)
final mitmTrustStoreProvider = MitmTrustStoreProvider._();

final class MitmTrustStoreProvider
    extends
        $FunctionalProvider<MitmTrustStore?, MitmTrustStore?, MitmTrustStore?>
    with $Provider<MitmTrustStore?> {
  MitmTrustStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmTrustStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmTrustStoreHash();

  @$internal
  @override
  $ProviderElement<MitmTrustStore?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MitmTrustStore? create(Ref ref) {
    return mitmTrustStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MitmTrustStore? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MitmTrustStore?>(value),
    );
  }
}

String _$mitmTrustStoreHash() => r'a078a332cb6f2c8fb0599287b2cc820f89c326b7';

/// Whether this device trusts the CA. A check records the CA it found
/// trusted, which is the one the Core decrypts HTTPS with.

@ProviderFor(MitmTrustState)
final mitmTrustStateProvider = MitmTrustStateProvider._();

/// Whether this device trusts the CA. A check records the CA it found
/// trusted, which is the one the Core decrypts HTTPS with.
final class MitmTrustStateProvider
    extends $AsyncNotifierProvider<MitmTrustState, MitmTrustCheck> {
  /// Whether this device trusts the CA. A check records the CA it found
  /// trusted, which is the one the Core decrypts HTTPS with.
  MitmTrustStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmTrustStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmTrustStateHash();

  @$internal
  @override
  MitmTrustState create() => MitmTrustState();
}

String _$mitmTrustStateHash() => r'9dafe32c99e6c701b394bbb52296881059277080';

/// Whether this device trusts the CA. A check records the CA it found
/// trusted, which is the one the Core decrypts HTTPS with.

abstract class _$MitmTrustState extends $AsyncNotifier<MitmTrustCheck> {
  FutureOr<MitmTrustCheck> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<MitmTrustCheck>, MitmTrustCheck>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MitmTrustCheck>, MitmTrustCheck>,
              AsyncValue<MitmTrustCheck>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Fetched again while shown, until the connection has closed and none of its
/// requests is pending.

@ProviderFor(mitmExchanges)
final mitmExchangesProvider = MitmExchangesFamily._();

/// Fetched again while shown, until the connection has closed and none of its
/// requests is pending.

final class MitmExchangesProvider
    extends
        $FunctionalProvider<
          AsyncValue<MitmExchangeList>,
          MitmExchangeList,
          FutureOr<MitmExchangeList>
        >
    with $FutureModifier<MitmExchangeList>, $FutureProvider<MitmExchangeList> {
  /// Fetched again while shown, until the connection has closed and none of its
  /// requests is pending.
  MitmExchangesProvider._({
    required MitmExchangesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mitmExchangesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mitmExchangesHash();

  @override
  String toString() {
    return r'mitmExchangesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MitmExchangeList> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MitmExchangeList> create(Ref ref) {
    final argument = this.argument as String;
    return mitmExchanges(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MitmExchangesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mitmExchangesHash() => r'66e3981eecc1c4b45126a90d061ffe75e3c01585';

/// Fetched again while shown, until the connection has closed and none of its
/// requests is pending.

final class MitmExchangesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MitmExchangeList>, String> {
  MitmExchangesFamily._()
    : super(
        retry: null,
        name: r'mitmExchangesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetched again while shown, until the connection has closed and none of its
  /// requests is pending.

  MitmExchangesProvider call(String connectionId) =>
      MitmExchangesProvider._(argument: connectionId, from: this);

  @override
  String toString() => r'mitmExchangesProvider';
}

@ProviderFor(mitmExchange)
final mitmExchangeProvider = MitmExchangeFamily._();

final class MitmExchangeProvider
    extends
        $FunctionalProvider<
          AsyncValue<MitmExchange?>,
          MitmExchange?,
          FutureOr<MitmExchange?>
        >
    with $FutureModifier<MitmExchange?>, $FutureProvider<MitmExchange?> {
  MitmExchangeProvider._({
    required MitmExchangeFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'mitmExchangeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mitmExchangeHash();

  @override
  String toString() {
    return r'mitmExchangeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MitmExchange?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MitmExchange?> create(Ref ref) {
    final argument = this.argument as int;
    return mitmExchange(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MitmExchangeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mitmExchangeHash() => r'f7b026828659fb4e9ccdc7ccc8fc3e02f45f7042';

final class MitmExchangeFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MitmExchange?>, int> {
  MitmExchangeFamily._()
    : super(
        retry: null,
        name: r'mitmExchangeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MitmExchangeProvider call(int id) =>
      MitmExchangeProvider._(argument: id, from: this);

  @override
  String toString() => r'mitmExchangeProvider';
}

@ProviderFor(mitmBody)
final mitmBodyProvider = MitmBodyFamily._();

final class MitmBodyProvider
    extends
        $FunctionalProvider<
          AsyncValue<MitmBodyContent?>,
          MitmBodyContent?,
          FutureOr<MitmBodyContent?>
        >
    with $FutureModifier<MitmBodyContent?>, $FutureProvider<MitmBodyContent?> {
  MitmBodyProvider._({
    required MitmBodyFamily super.from,
    required (int, {bool response, String contentType, bool original})
    super.argument,
  }) : super(
         retry: null,
         name: r'mitmBodyProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mitmBodyHash();

  @override
  String toString() {
    return r'mitmBodyProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<MitmBodyContent?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MitmBodyContent?> create(Ref ref) {
    final argument =
        this.argument
            as (int, {bool response, String contentType, bool original});
    return mitmBody(
      ref,
      argument.$1,
      response: argument.response,
      contentType: argument.contentType,
      original: argument.original,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MitmBodyProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mitmBodyHash() => r'96c5b1536b3ef845f285b8f6e4ff60e6b4772ce7';

final class MitmBodyFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<MitmBodyContent?>,
          (int, {bool response, String contentType, bool original})
        > {
  MitmBodyFamily._()
    : super(
        retry: null,
        name: r'mitmBodyProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MitmBodyProvider call(
    int id, {
    required bool response,
    required String contentType,
    bool original = false,
  }) => MitmBodyProvider._(
    argument: (
      id,
      response: response,
      contentType: contentType,
      original: original,
    ),
    from: this,
  );

  @override
  String toString() => r'mitmBodyProvider';
}

/// Whether the user was told, this run, what a copied or exported request
/// can carry.

@ProviderFor(MitmExportWarned)
final mitmExportWarnedProvider = MitmExportWarnedProvider._();

/// Whether the user was told, this run, what a copied or exported request
/// can carry.
final class MitmExportWarnedProvider
    extends $NotifierProvider<MitmExportWarned, bool> {
  /// Whether the user was told, this run, what a copied or exported request
  /// can carry.
  MitmExportWarnedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmExportWarnedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmExportWarnedHash();

  @$internal
  @override
  MitmExportWarned create() => MitmExportWarned();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$mitmExportWarnedHash() => r'ad55f9cc5bac8541affdf131a5c8e2969f5b55c6';

/// Whether the user was told, this run, what a copied or exported request
/// can carry.

abstract class _$MitmExportWarned extends $Notifier<bool> {
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

@ProviderFor(mitmModulesToAgree)
final mitmModulesToAgreeProvider = MitmModulesToAgreeProvider._();

final class MitmModulesToAgreeProvider
    extends
        $FunctionalProvider<
          List<MitmModule>,
          List<MitmModule>,
          List<MitmModule>
        >
    with $Provider<List<MitmModule>> {
  MitmModulesToAgreeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmModulesToAgreeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmModulesToAgreeHash();

  @$internal
  @override
  $ProviderElement<List<MitmModule>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<MitmModule> create(Ref ref) {
    return mitmModulesToAgree(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<MitmModule> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<MitmModule>>(value),
    );
  }
}

String _$mitmModulesToAgreeHash() =>
    r'b6472c1b0dca198af5710006b265ac11008a0ed7';

/// Why the Core skips each of the user's hostnames, by the line.

@ProviderFor(mitmHostnameIssues)
final mitmHostnameIssuesProvider = MitmHostnameIssuesProvider._();

/// Why the Core skips each of the user's hostnames, by the line.

final class MitmHostnameIssuesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $FutureProvider<Map<String, String>> {
  /// Why the Core skips each of the user's hostnames, by the line.
  MitmHostnameIssuesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmHostnameIssuesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmHostnameIssuesHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, String>> create(Ref ref) {
    return mitmHostnameIssues(ref);
  }
}

String _$mitmHostnameIssuesHash() =>
    r'2886d5c1677c50ec08386431824c0da259701f5c';

/// A module that fails to read adds nothing, so the VPN can still start.

@ProviderFor(enabledMitmModules)
final enabledMitmModulesProvider = EnabledMitmModulesProvider._();

/// A module that fails to read adds nothing, so the VPN can still start.

final class EnabledMitmModulesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<({MitmModuleContent content, String name})>>,
          List<({MitmModuleContent content, String name})>,
          FutureOr<List<({MitmModuleContent content, String name})>>
        >
    with
        $FutureModifier<List<({MitmModuleContent content, String name})>>,
        $FutureProvider<List<({MitmModuleContent content, String name})>> {
  /// A module that fails to read adds nothing, so the VPN can still start.
  EnabledMitmModulesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'enabledMitmModulesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$enabledMitmModulesHash();

  @$internal
  @override
  $FutureProviderElement<List<({MitmModuleContent content, String name})>>
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<({MitmModuleContent content, String name})>> create(Ref ref) {
    return enabledMitmModules(ref);
  }
}

String _$enabledMitmModulesHash() =>
    r'09522d4a4e307f146f10893f7394d8bc71b8b6f9';

@ProviderFor(mitmModuleExits)
final mitmModuleExitsProvider = MitmModuleExitsProvider._();

final class MitmModuleExitsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, List<String>>>,
          Map<String, List<String>>,
          FutureOr<Map<String, List<String>>>
        >
    with
        $FutureModifier<Map<String, List<String>>>,
        $FutureProvider<Map<String, List<String>>> {
  MitmModuleExitsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmModuleExitsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmModuleExitsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, List<String>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, List<String>>> create(Ref ref) {
    return mitmModuleExits(ref);
  }
}

String _$mitmModuleExitsHash() => r'caa3ac4da1572dd187bf49adb7658d835c3c6d3f';

@ProviderFor(mitmModuleNetworkChanges)
final mitmModuleNetworkChangesProvider = MitmModuleNetworkChangesFamily._();

final class MitmModuleNetworkChangesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MitmNetworkChangeState>>,
          List<MitmNetworkChangeState>,
          FutureOr<List<MitmNetworkChangeState>>
        >
    with
        $FutureModifier<List<MitmNetworkChangeState>>,
        $FutureProvider<List<MitmNetworkChangeState>> {
  MitmModuleNetworkChangesProvider._({
    required MitmModuleNetworkChangesFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'mitmModuleNetworkChangesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mitmModuleNetworkChangesHash();

  @override
  String toString() {
    return r'mitmModuleNetworkChangesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MitmNetworkChangeState>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MitmNetworkChangeState>> create(Ref ref) {
    final argument = this.argument as int;
    return mitmModuleNetworkChanges(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MitmModuleNetworkChangesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mitmModuleNetworkChangesHash() =>
    r'7e61482361d5042964f37e52ac82351a1ca94839';

final class MitmModuleNetworkChangesFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<List<MitmNetworkChangeState>>, int> {
  MitmModuleNetworkChangesFamily._()
    : super(
        retry: null,
        name: r'mitmModuleNetworkChangesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MitmModuleNetworkChangesProvider call(int id) =>
      MitmModuleNetworkChangesProvider._(argument: id, from: this);

  @override
  String toString() => r'mitmModuleNetworkChangesProvider';
}

/// The module that last replaces each setting, for the setting's own page to
/// name; a module that only adds to a list leaves it the user's.

@ProviderFor(mitmTakeover)
final mitmTakeoverProvider = MitmTakeoverProvider._();

/// The module that last replaces each setting, for the setting's own page to
/// name; a module that only adds to a list leaves it the user's.

final class MitmTakeoverProvider
    extends
        $FunctionalProvider<
          AsyncValue<MitmTakeover>,
          MitmTakeover,
          FutureOr<MitmTakeover>
        >
    with $FutureModifier<MitmTakeover>, $FutureProvider<MitmTakeover> {
  /// The module that last replaces each setting, for the setting's own page to
  /// name; a module that only adds to a list leaves it the user's.
  MitmTakeoverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmTakeoverProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmTakeoverHash();

  @$internal
  @override
  $FutureProviderElement<MitmTakeover> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MitmTakeover> create(Ref ref) {
    return mitmTakeover(ref);
  }
}

String _$mitmTakeoverHash() => r'a83b53eaf59305ebfe0796882ed2762a8d309809';

@ProviderFor(mitmModuleNetwork)
final mitmModuleNetworkProvider = MitmModuleNetworkProvider._();

final class MitmModuleNetworkProvider
    extends
        $FunctionalProvider<
          AsyncValue<MitmNetwork>,
          MitmNetwork,
          FutureOr<MitmNetwork>
        >
    with $FutureModifier<MitmNetwork>, $FutureProvider<MitmNetwork> {
  MitmModuleNetworkProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmModuleNetworkProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmModuleNetworkHash();

  @$internal
  @override
  $FutureProviderElement<MitmNetwork> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MitmNetwork> create(Ref ref) {
    return mitmModuleNetwork(ref);
  }
}

String _$mitmModuleNetworkHash() => r'96894dbd2b87d101783008924454636f1e0cf8fe';

/// Null while the module's content is not on disk.

@ProviderFor(mitmModuleDetails)
final mitmModuleDetailsProvider = MitmModuleDetailsFamily._();

/// Null while the module's content is not on disk.

final class MitmModuleDetailsProvider
    extends
        $FunctionalProvider<
          AsyncValue<MitmModuleDetails?>,
          MitmModuleDetails?,
          FutureOr<MitmModuleDetails?>
        >
    with
        $FutureModifier<MitmModuleDetails?>,
        $FutureProvider<MitmModuleDetails?> {
  /// Null while the module's content is not on disk.
  MitmModuleDetailsProvider._({
    required MitmModuleDetailsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'mitmModuleDetailsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mitmModuleDetailsHash();

  @override
  String toString() {
    return r'mitmModuleDetailsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MitmModuleDetails?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MitmModuleDetails?> create(Ref ref) {
    final argument = this.argument as int;
    return mitmModuleDetails(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MitmModuleDetailsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mitmModuleDetailsHash() => r'cf57aa4f53ae75e9437310f1e5e37ce507d24852';

/// Null while the module's content is not on disk.

final class MitmModuleDetailsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MitmModuleDetails?>, int> {
  MitmModuleDetailsFamily._()
    : super(
        retry: null,
        name: r'mitmModuleDetailsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Null while the module's content is not on disk.

  MitmModuleDetailsProvider call(int id) =>
      MitmModuleDetailsProvider._(argument: id, from: this);

  @override
  String toString() => r'mitmModuleDetailsProvider';
}

/// A file that fails to parse fails again until it changes, which rebuilds
/// this anyway.

@ProviderFor(mitmModuleContent)
final mitmModuleContentProvider = MitmModuleContentFamily._();

/// A file that fails to parse fails again until it changes, which rebuilds
/// this anyway.

final class MitmModuleContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<MitmModuleContent?>,
          MitmModuleContent?,
          FutureOr<MitmModuleContent?>
        >
    with
        $FutureModifier<MitmModuleContent?>,
        $FutureProvider<MitmModuleContent?> {
  /// A file that fails to parse fails again until it changes, which rebuilds
  /// this anyway.
  MitmModuleContentProvider._({
    required MitmModuleContentFamily super.from,
    required int super.argument,
  }) : super(
         retry: _noRetry,
         name: r'mitmModuleContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mitmModuleContentHash();

  @override
  String toString() {
    return r'mitmModuleContentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MitmModuleContent?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MitmModuleContent?> create(Ref ref) {
    final argument = this.argument as int;
    return mitmModuleContent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MitmModuleContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mitmModuleContentHash() => r'8d05136558342f475dec4642a78405585a471968';

/// A file that fails to parse fails again until it changes, which rebuilds
/// this anyway.

final class MitmModuleContentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MitmModuleContent?>, int> {
  MitmModuleContentFamily._()
    : super(
        retry: _noRetry,
        name: r'mitmModuleContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A file that fails to parse fails again until it changes, which rebuilds
  /// this anyway.

  MitmModuleContentProvider call(int id) =>
      MitmModuleContentProvider._(argument: id, from: this);

  @override
  String toString() => r'mitmModuleContentProvider';
}

/// Why the Core cannot take each of a profile's rewrite rules, by rule ID;
/// disabled rules are checked too.

@ProviderFor(mitmRewriteIssues)
final mitmRewriteIssuesProvider = MitmRewriteIssuesFamily._();

/// Why the Core cannot take each of a profile's rewrite rules, by rule ID;
/// disabled rules are checked too.

final class MitmRewriteIssuesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, MitmRewriteIssue>>,
          Map<int, MitmRewriteIssue>,
          FutureOr<Map<int, MitmRewriteIssue>>
        >
    with
        $FutureModifier<Map<int, MitmRewriteIssue>>,
        $FutureProvider<Map<int, MitmRewriteIssue>> {
  /// Why the Core cannot take each of a profile's rewrite rules, by rule ID;
  /// disabled rules are checked too.
  MitmRewriteIssuesProvider._({
    required MitmRewriteIssuesFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'mitmRewriteIssuesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mitmRewriteIssuesHash();

  @override
  String toString() {
    return r'mitmRewriteIssuesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<int, MitmRewriteIssue>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<int, MitmRewriteIssue>> create(Ref ref) {
    final argument = this.argument as int;
    return mitmRewriteIssues(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MitmRewriteIssuesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mitmRewriteIssuesHash() => r'25f56810e07fb3173c9482d61a84b12bbb867c6e';

/// Why the Core cannot take each of a profile's rewrite rules, by rule ID;
/// disabled rules are checked too.

final class MitmRewriteIssuesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Map<int, MitmRewriteIssue>>, int> {
  MitmRewriteIssuesFamily._()
    : super(
        retry: null,
        name: r'mitmRewriteIssuesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Why the Core cannot take each of a profile's rewrite rules, by rule ID;
  /// disabled rules are checked too.

  MitmRewriteIssuesProvider call(int profileId) =>
      MitmRewriteIssuesProvider._(argument: profileId, from: this);

  @override
  String toString() => r'mitmRewriteIssuesProvider';
}

/// The size up to which the Core rewrites a body, or 0 while it runs no
/// rewrite rules.

@ProviderFor(mitmRewriteBodyLimit)
final mitmRewriteBodyLimitProvider = MitmRewriteBodyLimitProvider._();

/// The size up to which the Core rewrites a body, or 0 while it runs no
/// rewrite rules.

final class MitmRewriteBodyLimitProvider
    extends $FunctionalProvider<AsyncValue<int>, int, FutureOr<int>>
    with $FutureModifier<int>, $FutureProvider<int> {
  /// The size up to which the Core rewrites a body, or 0 while it runs no
  /// rewrite rules.
  MitmRewriteBodyLimitProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mitmRewriteBodyLimitProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mitmRewriteBodyLimitHash();

  @$internal
  @override
  $FutureProviderElement<int> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<int> create(Ref ref) {
    return mitmRewriteBodyLimit(ref);
  }
}

String _$mitmRewriteBodyLimitHash() =>
    r'6da8b5caf30d2a17f7888f83ef85d1e3e2255db7';
