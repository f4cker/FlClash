import 'dart:convert';

import 'package:fl_clash/models/core.dart';
import 'package:flutter/foundation.dart' show immutable;

const mitmCaMark = '[MITM CA]';

const mitmCaPassphraseKey = 'mitmCaPassphrase';

/// Base64 PKCS#12; prints as [mitmCaMark] and never echoes a bad value.
@immutable
class MitmCaP12 {
  MitmCaP12(this.base64) {
    if (!_valid(base64)) {
      throw const FormatException('Invalid $mitmCaMark');
    }
  }

  final String base64;

  static final _base64 = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');

  static bool _valid(String value) =>
      value.isNotEmpty && value.length % 4 == 0 && _base64.hasMatch(value);

  static MitmCaP12? fromJsonValue(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Invalid $mitmCaMark');
    return MitmCaP12(value);
  }

  static String? toJsonValue(MitmCaP12? value) => value?.base64;

  List<int> get bytes => const Base64Decoder().convert(base64);

  @override
  bool operator ==(Object other) =>
      other is MitmCaP12 && other.base64 == base64;

  @override
  int get hashCode => base64.hashCode;

  @override
  String toString() => mitmCaMark;
}

@immutable
class MitmCaSecret {
  const MitmCaSecret({
    required this.p12,
    required this.passphrase,
    required this.fingerprint,
  });

  final MitmCaP12 p12;
  final String passphrase;
  final String fingerprint;

  Map<String, Object?> toCoreJson() => {
    'p12': p12.base64,
    'passphrase': passphrase,
    'fingerprint': fingerprint,
  };

  @override
  String toString() => mitmCaMark;
}

@immutable
class MitmCaState {
  const MitmCaState({
    this.loaded = false,
    this.fingerprint,
    this.leaseMillis = 0,
  });

  factory MitmCaState.fromJson(Map<String, Object?> json) => MitmCaState(
    loaded: json['loaded'] == true,
    fingerprint: json['fingerprint'] as String?,
    leaseMillis: (json['lease-millis'] as num?)?.toInt() ?? 0,
  );

  final bool loaded;
  final String? fingerprint;
  final int leaseMillis;

  bool leasedFor(String fingerprint) =>
      loaded && this.fingerprint == fingerprint && leaseMillis > 0;

  @override
  bool operator ==(Object other) =>
      other is MitmCaState &&
      other.loaded == loaded &&
      other.fingerprint == fingerprint &&
      other.leaseMillis == leaseMillis;

  @override
  int get hashCode => Object.hash(loaded, fingerprint, leaseMillis);

  @override
  String toString() => 'MitmCaState($loaded, $fingerprint, $leaseMillis)';
}

/// An older Core answers the PEM alone, without the lease's check id.
@immutable
class MitmCheckLeaf {
  const MitmCheckLeaf({required this.pem, this.check});

  static MitmCheckLeaf fromCore(Object data) => switch (data) {
    final String pem => MitmCheckLeaf(pem: pem),
    {'pem': final String pem} => MitmCheckLeaf(
      pem: pem,
      check: (data as Map)['check'] as String?,
    ),
    _ => throw const FormatException('Invalid check leaf'),
  };

  final String pem;
  final String? check;
}

@immutable
class MitmGeneratedCa {
  const MitmGeneratedCa({
    required this.p12,
    required this.passphrase,
    required this.certificate,
  });

  factory MitmGeneratedCa.fromJson(Map<String, Object?> json) {
    try {
      return MitmGeneratedCa(
        p12: MitmCaP12(json['p12'] as String),
        passphrase: json['passphrase'] as String,
        certificate: MitmCertificate.fromJson(json),
      );
    } catch (_) {
      throw const FormatException('Invalid $mitmCaMark');
    }
  }

  final MitmCaP12 p12;
  final String passphrase;
  final MitmCertificate certificate;

  @override
  String toString() => mitmCaMark;
}

enum RestoreMitmCaChange {
  kept,
  same,
  // The local CA, if any, stays on this Mac as the old CA.
  replaced,
  damaged,
}

@immutable
class RestoreMitmCa {
  const RestoreMitmCa(this.change, {this.local, this.backup});

  final RestoreMitmCaChange change;
  final MitmCertificate? local;
  final MitmCertificate? backup;
}
