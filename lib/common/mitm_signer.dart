import 'dart:convert';

import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/services.dart';

enum MitmCoreStatus { verified, failed, none }

/// Whether the Core the app talks to is the one the helper started with the
/// pinned identity. Anything but [verified] and the app signs nothing for it.
@immutable
class MitmCoreIdentity {
  const MitmCoreIdentity._(this.status, [this.stage]);

  const MitmCoreIdentity.failed([String? stage])
    : this._(MitmCoreStatus.failed, stage);

  static const verified = MitmCoreIdentity._(MitmCoreStatus.verified);
  static const none = MitmCoreIdentity._(MitmCoreStatus.none);

  final MitmCoreStatus status;

  final String? stage;

  static MitmCoreIdentity parse(Object? value) => switch (value) {
    'verified' => verified,
    'none' => none,
    final String text when text.startsWith('failed:') =>
      MitmCoreIdentity.failed(text.substring('failed:'.length)),
    _ => const MitmCoreIdentity.failed(),
  };

  @override
  bool operator ==(Object other) =>
      other is MitmCoreIdentity &&
      other.status == status &&
      other.stage == stage;

  @override
  int get hashCode => Object.hash(status, stage);

  @override
  String toString() => stage == null ? status.name : '${status.name}:$stage';
}

/// The Core's `mitmSign` event: a host and the DER SPKI of its own key.
class MitmSignRequest {
  const MitmSignRequest({
    required this.reqId,
    required this.host,
    required this.spki,
  });

  factory MitmSignRequest.fromJson(Map<String, Object?> json) {
    return MitmSignRequest(
      reqId: (json['reqId'] as num).toInt(),
      host: json['host'] as String,
      spki: base64.decode(json['spki'] as String),
    );
  }

  final int reqId;
  final String host;
  final Uint8List spki;
}

class MitmSignResult {
  const MitmSignResult({this.cert, this.ca, this.error, this.coreIdentity});

  final Uint8List? cert;
  final Uint8List? ca;
  final String? error;

  /// On a refused Core, the app's own account of why; never sent on.
  final String? coreIdentity;

  bool get refusedCore => error == 'coreIdentity';

  Map<String, Object?> toJson(int reqId) => {
    'reqId': reqId,
    if (cert case final cert?) 'cert': base64.encode(cert),
    if (ca case final ca?) 'ca': base64.encode(ca),
    'error': ?error,
  };
}

class MitmSigner {
  const MitmSigner([this._channel = const MethodChannel(channelName)]);

  static const channelName = 'com.layoute.flash/mitm_signer';

  final MethodChannel _channel;

  static MitmCertificate _certificate(Map<Object?, Object?> data) {
    DateTime time(String key) =>
        DateTime.fromMillisecondsSinceEpoch(data[key] as int, isUtc: true);
    return MitmCertificate(
      pem: data['pem'] as String,
      fingerprint: data['fingerprint'] as String,
      subject: data['subject'] as String,
      notBefore: time('notBefore'),
      notAfter: time('notAfter'),
    );
  }

  Future<MitmCertificate?> certificate() async {
    final data = await _channel.invokeMethod<Map<Object?, Object?>>(
      'certificate',
    );
    return data == null ? null : _certificate(data);
  }

  Future<MitmCertificate> generate() async {
    return _certificate(
      (await _channel.invokeMethod<Map<Object?, Object?>>('generate'))!,
    );
  }

  Future<void> delete() => _channel.invokeMethod<void>('delete');

  Future<MitmCoreIdentity> coreIdentity() async {
    return MitmCoreIdentity.parse(
      await _channel.invokeMethod<String>('coreIdentity'),
    );
  }

  /// [hostnames] is the user's list; the signer matches [host] against it
  /// again rather than trusting the Core's match.
  Future<MitmSignResult> sign({
    required String host,
    required Uint8List spki,
    required List<String> hostnames,
  }) async {
    final data = await _channel.invokeMethod<Map<Object?, Object?>>('sign', {
      'host': host,
      'spki': spki,
      'hostnames': hostnames,
    });
    return MitmSignResult(
      cert: data?['cert'] as Uint8List?,
      ca: data?['ca'] as Uint8List?,
      error: data?['error'] as String? ?? (data == null ? 'signFailed' : null),
      coreIdentity: data?['identity'] as String?,
    );
  }

  Future<String> checkCertificate() async {
    return (await _channel.invokeMethod<String>('checkCertificate'))!;
  }
}
