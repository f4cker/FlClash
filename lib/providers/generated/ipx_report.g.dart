// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../ipx_report.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The Core's outbound-IP probe, aimed like the card's own lookup: through
/// whatever the rules pick while proxying, and direct otherwise. ipx.al thus
/// sees the exit, never the device behind it.

@ProviderFor(ipxFetch)
final ipxFetchProvider = IpxFetchProvider._();

/// The Core's outbound-IP probe, aimed like the card's own lookup: through
/// whatever the rules pick while proxying, and direct otherwise. ipx.al thus
/// sees the exit, never the device behind it.

final class IpxFetchProvider
    extends $FunctionalProvider<IpxFetch, IpxFetch, IpxFetch>
    with $Provider<IpxFetch> {
  /// The Core's outbound-IP probe, aimed like the card's own lookup: through
  /// whatever the rules pick while proxying, and direct otherwise. ipx.al thus
  /// sees the exit, never the device behind it.
  IpxFetchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ipxFetchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ipxFetchHash();

  @$internal
  @override
  $ProviderElement<IpxFetch> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IpxFetch create(Ref ref) {
    return ipxFetch(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IpxFetch value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IpxFetch>(value),
    );
  }
}

String _$ipxFetchHash() => r'437a24da248d130f69225a38b8a0719e78cbbc00';

/// The ipx.al report of one exit address, asked for the first time the
/// detail is opened and kept for the session; only a failure is asked again.

@ProviderFor(IpxLookup)
final ipxLookupProvider = IpxLookupFamily._();

/// The ipx.al report of one exit address, asked for the first time the
/// detail is opened and kept for the session; only a failure is asked again.
final class IpxLookupProvider
    extends $NotifierProvider<IpxLookup, IpxLookupState> {
  /// The ipx.al report of one exit address, asked for the first time the
  /// detail is opened and kept for the session; only a failure is asked again.
  IpxLookupProvider._({
    required IpxLookupFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'ipxLookupProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ipxLookupHash();

  @override
  String toString() {
    return r'ipxLookupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  IpxLookup create() => IpxLookup();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IpxLookupState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IpxLookupState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IpxLookupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ipxLookupHash() => r'0eb6730d6810c1b014e5c2a315883542fa705dcc';

/// The ipx.al report of one exit address, asked for the first time the
/// detail is opened and kept for the session; only a failure is asked again.

final class IpxLookupFamily extends $Family
    with
        $ClassFamilyOverride<
          IpxLookup,
          IpxLookupState,
          IpxLookupState,
          IpxLookupState,
          String
        > {
  IpxLookupFamily._()
    : super(
        retry: null,
        name: r'ipxLookupProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The ipx.al report of one exit address, asked for the first time the
  /// detail is opened and kept for the session; only a failure is asked again.

  IpxLookupProvider call(String ip) =>
      IpxLookupProvider._(argument: ip, from: this);

  @override
  String toString() => r'ipxLookupProvider';
}

/// The ipx.al report of one exit address, asked for the first time the
/// detail is opened and kept for the session; only a failure is asked again.

abstract class _$IpxLookup extends $Notifier<IpxLookupState> {
  late final _$args = ref.$arg as String;
  String get ip => _$args;

  IpxLookupState build(String ip);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<IpxLookupState, IpxLookupState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<IpxLookupState, IpxLookupState>,
              IpxLookupState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
