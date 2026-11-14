/// Session-only approval. Persisted revision is advanced only by a successful
/// full Core setup, never by this gate or a live patch.
class CompositionReviewGate {
  bool cancelled = false;
  String? approvedFingerprint;

  bool suppressed({required bool automatic}) => automatic && cancelled;
  bool approves(String fingerprint) => approvedFingerprint == fingerprint;
  void approve(String fingerprint) {
    cancelled = false;
    approvedFingerprint = fingerprint;
  }

  void cancel() {
    cancelled = true;
    approvedFingerprint = null;
  }
}

/// Review settings only; outbounds, rule bodies, provider URLs, credentials,
/// and MITM material must not be printed into a migration dialog.
Map<String, Object?> compositionReviewValues(Map config) {
  const omitted = {
    'proxies',
    'proxy-groups',
    'proxy-providers',
    'rule-providers',
    'rules',
    'sub-rules',
    'listeners',
    'tunnels',
    'mitm',
    'ss-config',
    'vmess-config',
    'tuic-server',
    'tailscale',
  };
  final result = <String, Object?>{};
  void visit(String path, Object? value) {
    final lower = path.toLowerCase();
    if (lower.contains('secret') ||
        lower.contains('password') ||
        lower.contains('token') ||
        lower.contains('authentication') ||
        lower.contains('private-key') ||
        lower.contains('certificate')) {
      result[path] =
          value == null || value == '' || value is List && value.isEmpty
          ? value
          : '••••';
    } else if (value is Map && value.isNotEmpty && path != 'hosts') {
      for (final entry in value.entries) {
        visit('$path.${entry.key}', entry.value);
      }
    } else {
      result[path] = value;
    }
  }

  for (final entry in config.entries) {
    if (!omitted.contains(entry.key)) visit('${entry.key}', entry.value);
  }
  return result;
}
