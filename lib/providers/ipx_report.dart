import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'core.dart';
import 'route_state.dart';

part 'generated/ipx_report.g.dart';

/// Fetches [url] through the exit the dashboard shows and answers its raw
/// body, or null for anything short of a usable answer.
typedef IpxFetch =
    Future<String?> Function(
      String url, {
      required Duration timeout,
      int? maxBody,
    });

const ipxBriefTimeout = Duration(seconds: 4);

/// A first report takes ipx.al about three to four seconds to put together.
const ipxReportTimeout = Duration(seconds: 10);

/// A report runs to about 10 KiB.
const ipxReportMaxBody = 32 << 10;

/// The Core's outbound-IP probe, aimed like the card's own lookup: through
/// whatever the rules pick while proxying, and direct otherwise. ipx.al thus
/// sees the exit, never the device behind it.
@Riverpod(keepAlive: true)
IpxFetch ipxFetch(Ref ref) {
  return (url, {required timeout, maxBody}) async {
    final route = ref.read(routeTrackerProvider);
    if (!route.live) {
      return null;
    }
    try {
      final result = await ref
          .read(coreHandlerProvider)
          .outboundIp(
            OutboundIpParams(
              proxyName: route.proxied ? routedOutbound : directOutbound,
              urls: [url],
              timeout: timeout.inMilliseconds,
              maxBody: maxBody,
            ),
          );
      if (result.error != null || result.body.isEmpty) {
        return null;
      }
      return result.body;
    } catch (error) {
      commonPrint.log(
        'ipx.al fetch failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  };
}

enum IpxPhase {
  loading,

  /// `/api/me` answered for this address; the report is still on its way.
  partial,
  done,

  /// No report: the detail falls back to what the card already knows.
  failed,
}

@immutable
class IpxLookupState {
  const IpxLookupState({
    this.phase = IpxPhase.loading,
    this.brief,
    this.report,
  });

  final IpxPhase phase;
  final IpxBrief? brief;
  final IpxReport? report;

  bool get isLoading => phase == IpxPhase.loading || phase == IpxPhase.partial;

  @override
  bool operator ==(Object other) =>
      other is IpxLookupState &&
      other.phase == phase &&
      other.brief == brief &&
      other.report == report;

  @override
  int get hashCode => Object.hash(phase, brief, report);
}

/// The ipx.al report of one exit address, asked for the first time the
/// detail is opened and kept for the session; only a failure is asked again.
@Riverpod(keepAlive: true)
class IpxLookup extends _$IpxLookup {
  int _run = 0;

  @override
  IpxLookupState build(String ip) {
    unawaited(_query(++_run));
    return const IpxLookupState();
  }

  /// A report already in hand stays: ipx.al caches it for hours anyway.
  void retry() {
    if (state.phase != IpxPhase.failed) {
      return;
    }
    state = const IpxLookupState();
    unawaited(_query(++_run));
  }

  bool _current(int run) => ref.mounted && run == _run;

  Future<void> _query(int run) async {
    final fetch = ref.read(ipxFetchProvider);
    unawaited(
      fetch(ipxAlMeUrl, timeout: ipxBriefTimeout).then((body) {
        if (body == null || !_current(run)) {
          return;
        }
        final brief = _tryParse(() => IpxBrief.parse(body));
        // Another exit answered: the route moved under the card.
        if (brief == null || brief.ip != ip) {
          return;
        }
        if (state.phase == IpxPhase.loading) {
          state = IpxLookupState(phase: IpxPhase.partial, brief: brief);
        }
      }),
    );
    final body = await fetch(
      ipxAlReportUrl(ip),
      timeout: ipxReportTimeout,
      maxBody: ipxReportMaxBody,
    );
    if (!_current(run)) {
      return;
    }
    final report = body == null ? null : _tryParse(() => IpxReport.parse(body));
    if (report == null || report.ip != ip) {
      commonPrint.log(
        'ipx.al report unavailable for this exit',
        logLevel: LogLevel.warning,
      );
      state = IpxLookupState(phase: IpxPhase.failed, brief: state.brief);
      return;
    }
    state = IpxLookupState(
      phase: IpxPhase.done,
      brief: state.brief,
      report: report,
    );
  }
}

T? _tryParse<T>(T Function() parse) {
  try {
    return parse();
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}
