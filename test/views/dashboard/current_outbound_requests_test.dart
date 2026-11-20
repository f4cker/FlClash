import 'dart:async';

import 'package:fl_clash/common/service_probe.dart'
    show directOutbound, routedOutbound;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/ipx_report.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/views/dashboard/widgets/current_outbound.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:prism_ui/shapes/shapes.dart';

import '../../helpers/host_scaffold.dart';
import '../../helpers/test_app.dart';

// Every request the status card can lead to, counted where it leaves the
// app: the address probe's lookup through the Core, ipx.al through the
// Core, and the IP quality sources. The probe itself is the real one, with
// its own settling, throttling and retries; only the lookup is stubbed.

const _exitIp = '203.0.113.9';
const _localIp = '58.152.33.18';

const _profile = Profile(id: 1, autoUpdateDuration: Duration.zero);

const _route = RouteState(
  coreEpoch: 1,
  routeVersion: 1,
  hostEpoch: 1,
  proxied: true,
  synced: true,
  live: true,
);

/// Well past every settle window, throttle and retry the probe keeps.
const _longAfter = Duration(seconds: 30);

class _CountingIps extends OutboundIpProbe {
  /// Every address lookup sent, by target.
  final asked = <String>[];

  /// While set, lookups stay out until it completes.
  Completer<void>? hold;

  @override
  Future<Map<String, ProbeAnswer<IpInfo>>> probe(
    String target,
    RouteState route,
  ) async {
    asked.add(target);
    if (hold case final gate?) {
      await gate.future;
    }
    final proxied = target == routedOutbound && route.proxied;
    return {
      target: ProbeAnswer(
        value: IpInfo(
          ip: proxied ? _exitIp : _localIp,
          countryCode: proxied ? 'DE' : 'HK',
        ),
        coreEpoch: route.coreEpoch,
        routeVersion: route.routeVersion,
      ),
    };
  }

  @override
  Future<RouteCheck> checkRoutes(List<List<RouteHit>> routes) async {
    final route = ref.read(routeTrackerProvider);
    return RouteCheck(
      coreEpoch: route.coreEpoch,
      routeVersion: route.routeVersion,
      held: [for (final _ in routes) true],
    );
  }
}

class _Running extends RunTime {
  @override
  int? build() => 1000;
}

class _Requests {
  final ipx = <String>[];
  final quality = <String>[];

  Future<IpxAnswer?> fetch(
    String url, {
    required Duration timeout,
    int? maxBody,
  }) async {
    ipx.add(url);
    // ipx.al has nothing, so the IP quality sources stand in.
    return null;
  }
}

Widget _app(_CountingIps probe, _Requests requests) => TestApp(
  locale: const Locale('en'),
  overrides: [
    profilesProvider.overrideWithValue(const [_profile]),
    suspendProvider.overrideWithValue(false),
    runTimeProvider.overrideWith(_Running.new),
    routeTrackerProvider.overrideWithBuild((_, _) => _route),
    outboundIpProbeProvider.overrideWith(() => probe),
    ipxFetchProvider.overrideWithValue(requests.fetch),
    ipQualityProvider.overrideWith((_, ip) async {
      requests.quality.add(ip);
      return const IpQuality(
        ip: _exitIp,
        source: IpQualitySource.ipLocate,
        type: IpType.hosting,
      );
    }),
  ],
  child: const HostScaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 600,
        height: 208,
        child: DashboardDensityScope(
          density: DashboardDensity.standard,
          scale: 1,
          child: CurrentOutboundCard(),
        ),
      ),
    ),
  ),
);

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CurrentOutboundCard)));

Finder _badge() => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) =>
        widget is ShapeBadge && widget.shape == MaterialShapes.clover4Leaf,
  ),
  matching: find.byType(PressRegion),
);

/// Lets every timer the probe keeps run out, and what they set off land.
Future<void> _later(WidgetTester tester) async {
  await tester.pump(_longAfter);
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}

/// The shown address, whichever exit it is.
String _shown(WidgetTester tester) =>
    tester.widget<DashboardFitText>(find.byType(DashboardFitText)).text;

void main() {
  group('the status card', () {
    testWidgets('sends nothing when the address is tapped, either way', (
      tester,
    ) async {
      final probe = _CountingIps();
      final requests = _Requests();
      await tester.pumpWidget(_app(probe, requests));
      await _later(tester);
      expect(_shown(tester), _exitIp);
      // Opening: both addresses, and the report of the shown exit only.
      expect(probe.asked..sort(), [routedOutbound, directOutbound]);
      expect(requests.ipx, isNotEmpty);
      expect(requests.ipx.where((url) => url.contains(_localIp)), isEmpty);
      expect(requests.quality, [_exitIp]);

      Future<void> expectNoneSent(Future<void> Function() act) async {
        final asked = probe.asked.length;
        final ipx = requests.ipx.length;
        final quality = requests.quality.length;
        await act();
        expect(probe.asked, hasLength(asked), reason: 'address lookups');
        expect(requests.ipx, hasLength(ipx), reason: 'ipx.al');
        expect(requests.quality, hasLength(quality), reason: 'IP quality');
        await _later(tester);
        expect(probe.asked, hasLength(asked), reason: 'address lookups later');
        expect(requests.ipx, hasLength(ipx), reason: 'ipx.al later');
        expect(
          requests.quality,
          hasLength(quality),
          reason: 'IP quality later',
        );
      }

      Future<void> tapAddress() async {
        await tester.tap(find.byType(DashboardFitText));
        await tester.pump();
      }

      // The local exit has nothing cached about it; the proxy exit has.
      await expectNoneSent(() async {
        for (var i = 0; i < 6; i++) {
          await tapAddress();
          expect(_shown(tester), i.isEven ? _localIp : _exitIp);
        }
      });

      // The local exit's report asked for on its badge: that asks.
      await tapAddress();
      expect(_shown(tester), _localIp);
      final quality = requests.quality.length;
      await tester.tap(_badge());
      await _later(tester);
      expect(requests.quality, hasLength(quality + 1));

      // Now both have their reports in hand; switching still asks nothing.
      await expectNoneSent(() async {
        for (var i = 0; i < 6; i++) {
          await tapAddress();
          await tester.pump(const Duration(seconds: 3));
        }
      });

      // A background check after a network change is under way: taps
      // switch between what is shown and add nothing to it.
      final hold = probe.hold = Completer<void>();
      final before = probe.asked.length;
      _containerOf(tester).read(routeTrackerProvider.notifier).bumpHostEpoch();
      await tester.pump(const Duration(seconds: 1));
      expect(probe.asked, hasLength(before + 2));
      await expectNoneSent(() async {
        for (var i = 0; i < 6; i++) {
          await tapAddress();
          expect(_shown(tester), i.isEven ? _exitIp : _localIp);
        }
        hold.complete();
        probe.hold = null;
        await tester.pump();
        for (var i = 0; i < 4; i++) {
          await tapAddress();
        }
      });
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('still finds both addresses on open and on every move', (
      tester,
    ) async {
      final probe = _CountingIps();
      final requests = _Requests();
      await tester.pumpWidget(_app(probe, requests));
      await _later(tester);
      final counts = <List<String>>[];
      void take() {
        counts.add([...probe.asked]..sort());
        probe.asked.clear();
      }

      take();
      final tracker = _containerOf(tester).read(routeTrackerProvider.notifier);
      // The Core restarted.
      tracker.applySnapshot(
        const RouteSnapshot(coreEpoch: 2, routeVersion: 1, running: true),
      );
      await _later(tester);
      take();
      // The network changed under the host.
      tracker.bumpHostEpoch();
      await _later(tester);
      take();
      // Proxying stopped.
      tracker.applySnapshot(
        const RouteSnapshot(coreEpoch: 2, routeVersion: 1, running: false),
      );
      await _later(tester);
      take();
      // And started again.
      tracker.applySnapshot(
        const RouteSnapshot(coreEpoch: 2, routeVersion: 1, running: true),
      );
      await _later(tester);
      take();

      const both = [routedOutbound, directOutbound];
      expect(counts, [both, both, both, both, both]);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
