import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';

const _direct = 'DIRECT';

/// Why a connection went where it did, read only from what the Core recorded
/// when it was routed; nothing is filled in from today's groups or mode.
class RouteReason {
  const RouteReason(this.info);

  final TrackerInfo info;

  Metadata get _metadata => info.metadata;

  String? get _exit => info.chains.firstOrNull;

  bool get _noRule => info.rule.isEmpty;

  String? exitLine(AppLocalizations l) {
    if (!_noRule) return null;
    return switch (_exit) {
      null || '' => l.routeExitUnknown,
      _direct => l.routeExitDirect,
      _ => null,
    };
  }

  List<String> notes(AppLocalizations l) {
    return [
      for (final skip in _metadata.udpSkipped)
        switch (skip.cause) {
          'disabled' => l.routeUdpSkippedDisabled(_ruleOf(skip), skip.adapter),
          _ => l.routeUdpSkippedUnsupported(_ruleOf(skip), skip.adapter),
        },
      if (_noRule && _exit == _direct)
        ?switch (_metadata.routeReason) {
          'no-match' => l.routeNoMatch,
          'mode-direct' => l.routeModeDirect,
          'mode-global' => l.routeModeGlobal,
          'internal' => l.routeInternal,
          // A special proxy is not taken as internal, so no reason is given.
          'special' => null,
          _ => l.routeReasonUnknown,
        },
    ];
  }

  String short(AppLocalizations l) {
    if (_metadata.udpSkipped.isNotEmpty) return l.routeShortUdpSkipped;
    return switch (_metadata.routeReason) {
      'no-match' => l.routeShortNoMatch,
      'mode-direct' => l.routeShortModeDirect,
      'mode-global' => l.routeShortModeGlobal,
      'internal' => l.routeShortInternal,
      _ => l.routeShortNoRule,
    };
  }

  static String _ruleOf(UdpSkip skip) =>
      skip.payload.isEmpty ? skip.type : '${skip.type}(${skip.payload})';
}
