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

String _$mitmCaHash() => r'89e78c2f90b7de26e8dc4520149b5a32ce0e14b0';

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

/// Answers the Core's `mitmSign` with a leaf for a host on the user's own
/// list, or with why not; the Core passes the connection through on a refusal.

@ProviderFor(MitmSignAction)
final mitmSignActionProvider = MitmSignActionProvider._();

/// Answers the Core's `mitmSign` with a leaf for a host on the user's own
/// list, or with why not; the Core passes the connection through on a refusal.
final class MitmSignActionProvider
    extends $NotifierProvider<MitmSignAction, void> {
  /// Answers the Core's `mitmSign` with a leaf for a host on the user's own
  /// list, or with why not; the Core passes the connection through on a refusal.
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

String _$mitmSignActionHash() => r'd4866af3e0400e32b5dcd3d89b543eb188a7c8ad';

/// Answers the Core's `mitmSign` with a leaf for a host on the user's own
/// list, or with why not; the Core passes the connection through on a refusal.

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

String _$mitmTrustStateHash() => r'6bbafa5264b279e1456e095e5373d72097b83d8a';

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

String _$mitmBodyHash() => r'90ff0f16d18c09f299e2d872bca7b490b91cb25c';

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
    r'2665dded42e187044c2fb182a068363bdfc0279c';

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

String _$mitmModuleDetailsHash() => r'6b9db3a033630264f42c3b032bff07974e45d6c2';

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

/// Why the Core cannot take each of a profile's rewrite rules, by rule ID;
/// disabled rules are checked too.

@ProviderFor(mitmRewriteIssues)
final mitmRewriteIssuesProvider = MitmRewriteIssuesFamily._();

/// Why the Core cannot take each of a profile's rewrite rules, by rule ID;
/// disabled rules are checked too.

final class MitmRewriteIssuesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<int, String>>,
          Map<int, String>,
          FutureOr<Map<int, String>>
        >
    with $FutureModifier<Map<int, String>>, $FutureProvider<Map<int, String>> {
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
  $FutureProviderElement<Map<int, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<int, String>> create(Ref ref) {
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

String _$mitmRewriteIssuesHash() => r'6c74d4cb4c32ea29703001716f66bd44cea6d86c';

/// Why the Core cannot take each of a profile's rewrite rules, by rule ID;
/// disabled rules are checked too.

final class MitmRewriteIssuesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Map<int, String>>, int> {
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
