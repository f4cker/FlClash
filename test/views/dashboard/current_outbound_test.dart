import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/common/service_probe.dart'
    show directOutbound, routedOutbound;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/ipx_report.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/views/dashboard/widgets/current_outbound.dart';
import 'package:fl_clash/widgets/widgets.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/glyph_finders.dart';
import '../../helpers/test_app.dart';
import 'package:prism_ui/prism_ui.dart';
import '../../helpers/host_scaffold.dart';

const _ip = '203.0.113.9';

const _profile = Profile(id: 1, autoUpdateDuration: Duration.zero);

const _residential = IpQuality(
  ip: _ip,
  source: IpQualitySource.ipLocate,
  type: IpType.residential,
  organization: 'Example Broadband',
  asn: 64500,
);

class _RecordingSetupAction extends SetupAction {
  final requests = <bool>[];

  @override
  Future<bool> setRunning(bool running, {bool initialize = false}) {
    requests.add(running);
    ref.read(runTimeProvider.notifier).value = running ? 1 : null;
    return Future.value(true);
  }
}

class _Ips extends OutboundIpProbe {
  @override
  RoutedProbeState<String, IpInfo> build() => const RoutedProbeState({
    routedOutbound: ProbeEntry(
      phase: ProbePhase.fresh,
      value: IpInfo(ip: _ip, countryCode: 'GB'),
    ),
  });

  @override
  void watch(String target) {}

  @override
  void unwatch(String target) {}
}

Widget _card({DashboardDensity density = DashboardDensity.standard}) =>
    HostScaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: density.isDesktop ? 600 : 380,
          height: density.isDesktop ? 208 : null,
          child: DashboardDensityScope(
            density: density,
            scale: 1,
            child: const CurrentOutboundCard(),
          ),
        ),
      ),
    );

Widget _app(
  Future<IpQuality> Function(Ref ref, String ip) quality, {
  DashboardDensity density = DashboardDensity.standard,
  bool root = false,
}) {
  return TestApp(
    locale: const Locale('en'),
    overrides: [
      profilesProvider.overrideWithValue(const [_profile]),
      suspendProvider.overrideWithValue(false),
      rootAccessProvider.overrideWith((_) async => root),
      outboundIpProbeProvider.overrideWithBuild(
        (_, _) => const RoutedProbeState({
          routedOutbound: ProbeEntry(
            phase: ProbePhase.fresh,
            value: IpInfo(ip: _ip, countryCode: 'GB'),
          ),
        }),
      ),
      ipQualityProvider.overrideWith(quality),
    ],
    child: _card(density: density),
  );
}

const _localIp = '58.152.33.18';

const _localReport = IpxReport(
  ip: _localIp,
  score: 88,
  type: IpxIpType.residential,
  nativity: IpxNativity.native,
  countryCode: 'HK',
  city: 'Hong Kong',
  organization: 'HKBN',
);

const _report = IpxReport(
  ip: _ip,
  score: 35,
  type: IpxIpType.hosting,
  nativity: IpxNativity.native,
  countryCode: 'DE',
  city: 'Brandenburg',
  organization: 'TORSERVERS-NET',
);

ProbeEntry<IpInfo> _fresh(String ip, {String country = 'GB'}) => ProbeEntry(
  phase: ProbePhase.fresh,
  value: IpInfo(ip: ip, countryCode: country),
);

class _RecordingIps extends OutboundIpProbe {
  _RecordingIps(this.exit, this.local);

  final ProbeEntry<IpInfo> exit;
  final ProbeEntry<IpInfo> local;
  final refreshed = <String>[];

  @override
  RoutedProbeState<String, IpInfo> build() =>
      RoutedProbeState({routedOutbound: exit, directOutbound: local});

  @override
  void watch(String target) {}

  @override
  void unwatch(String target) {}

  @override
  void refresh(Iterable<String> targets) => refreshed.addAll(targets);
}

class _ControlledIps extends OutboundIpProbe {
  final requests = <(String, Completer<Map<String, ProbeAnswer<IpInfo>>>)>[];

  @override
  Future<Map<String, ProbeAnswer<IpInfo>>> probe(
    String target,
    RouteState route,
  ) {
    final result = Completer<Map<String, ProbeAnswer<IpInfo>>>();
    requests.add((target, result));
    return result.future;
  }

  void answer() {
    for (final (target, request) in requests) {
      if (!request.isCompleted) {
        request.complete({
          target: ProbeAnswer(
            value: IpInfo(
              ip: target == routedOutbound ? _ip : _localIp,
              countryCode: 'GB',
            ),
            coreEpoch: 1,
            routeVersion: 1,
          ),
        });
      }
    }
  }
}

class _FakeIpx extends IpxLookup {
  _FakeIpx(this.answer);

  final IpxLookupState answer;
  static var retries = 0;

  @override
  IpxLookupState build(String ip) => answer;

  @override
  void reload() {}

  @override
  void retry() => retries++;
}

class _Running extends RunTime {
  @override
  int? build() => 1000;
}

class _Hidden extends AppSetting {
  @override
  AppSettingProps build() => const AppSettingProps(hideIp: true);
}

/// A probe the test moves by hand; [refresh] marks the targets as looked up
/// again, keeping what they showed, as the real one does.
class _ManualIps extends OutboundIpProbe {
  _ManualIps(this.initial);

  final Map<String, ProbeEntry<IpInfo>> initial;
  final refreshed = <String>[];

  @override
  RoutedProbeState<String, IpInfo> build() => RoutedProbeState(initial);

  @override
  void watch(String target) {}

  @override
  void unwatch(String target) {}

  @override
  void refresh(Iterable<String> targets) {
    refreshed.addAll(targets);
    final entries = Map.of(state.entries);
    for (final target in targets) {
      entries[target] = ProbeEntry(
        phase: ProbePhase.probing,
        value: entries[target]?.value,
      );
    }
    state = RoutedProbeState(entries);
  }

  void settle(String target, ProbeEntry<IpInfo> entry) {
    state = RoutedProbeState({...state.entries, target: entry});
  }
}

const _done = IpxLookupState(phase: IpxPhase.done, report: _report);
const _localDone = IpxLookupState(phase: IpxPhase.done, report: _localReport);

Widget _ipApp({
  ProbeEntry<IpInfo>? exit,
  ProbeEntry<IpInfo>? local,
  IpxLookupState lookup = _done,
  IpxLookupState localLookup = _localDone,
  bool running = true,
  bool hideIp = false,
  OutboundIpProbe Function()? probe,
  RouteState? route,
  DashboardDensity density = DashboardDensity.standard,
  SetupAction Function()? setup,
}) {
  final exitEntry = exit ?? _fresh(_ip);
  final localEntry = local ?? _fresh(_localIp, country: 'HK');
  return TestApp(
    locale: const Locale('en'),
    overrides: [
      profilesProvider.overrideWithValue(const [_profile]),
      suspendProvider.overrideWithValue(false),
      if (route != null)
        routeTrackerProvider.overrideWithBuild((_, _) => route),
      if (running) runTimeProvider.overrideWith(_Running.new),
      if (hideIp) appSettingProvider.overrideWith(_Hidden.new),
      if (setup != null) setupActionProvider.overrideWith(setup),
      outboundIpProbeProvider.overrideWith(
        probe ?? () => _RecordingIps(exitEntry, localEntry),
      ),
      ipQualityProvider.overrideWith((_, _) async => _residential),
      ipxLookupProvider(_ip).overrideWith(() => _FakeIpx(lookup)),
      ipxLookupProvider(_localIp).overrideWith(() => _FakeIpx(localLookup)),
    ],
    child: _card(density: density),
  );
}

Finder _badge() => find.byTooltip('Look up again');

Finder _badgeRegion() =>
    find.descendant(of: _badge(), matching: find.byType(PressRegion));

Finder _ipRegion(String ip) =>
    find.ancestor(of: find.text(ip), matching: find.byType(PressRegion));

String? _badgeCode(WidgetTester tester) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: _badge(), matching: find.byType(Text)),
  );
  return texts.map((text) => text.data).firstOrNull;
}

void main() {
  setUp(() {
    mitmFeature = true;
    _FakeIpx.retries = 0;
    addTearDown(() => mitmFeature = false);
  });

  testWidgets(
    'unchanged network refresh never replaces the IP or report with skeletons',
    (tester) async {
      final probe = _ControlledIps();
      await tester.pumpWidget(
        _ipApp(
          probe: () => probe,
          route: const RouteState(
            coreEpoch: 1,
            routeVersion: 1,
            hostEpoch: 1,
            proxied: true,
            synced: true,
            live: true,
          ),
        ),
      );
      await tester.pump();
      probe.answer();
      await tester.pumpAndSettle();
      expect(find.text(_ip), findsOneWidget);
      expect(find.text('TORSERVERS-NET'), findsOneWidget);
      expect(find.byType(SkeletonPill), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CurrentOutboundCard)),
      );
      for (var i = 0; i < 3; i++) {
        container.read(routeTrackerProvider.notifier).bumpHostEpoch();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text(_ip), findsOneWidget);
        expect(find.text('TORSERVERS-NET'), findsOneWidget);
        expect(find.byType(SkeletonPill), findsNothing);
        expect(
          container.read(outboundIpProbeProvider).valueOf(routedOutbound),
          isNull,
        );
      }
      expect(probe.requests, hasLength(2));
      // Only the badge says a lookup is out: it is off until it lands.
      expect(tester.widget<PressRegion>(_badgeRegion()).onTap, isNull);
      await tester.pump(probeMoveSettleDuration);
      expect(probe.requests, hasLength(4));
      expect(find.byType(SkeletonPill), findsNothing);
      probe.answer();
      await tester.pumpAndSettle();
      expect(find.text(_ip), findsOneWidget);
      expect(tester.widget<PressRegion>(_badgeRegion()).onTap, isNotNull);
      expect(find.byType(SkeletonPill), findsNothing);
      await tester.pump(const Duration(minutes: 1));
      expect(probe.requests, hasLength(4));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  group('root access', () {
    if (rsFeature) {
      testWidgets('fades in a border and names it only to a screen reader', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_app((_, _) async => _residential, root: true));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        final midway = tester.widget<DashboardCard>(find.byType(DashboardCard));
        expect(midway.side.color.a, inExclusiveRange(0, 1));

        await tester.pump(commonDuration);

        final card = tester.widget<DashboardCard>(find.byType(DashboardCard));
        expect(card.side.color.a, closeTo(1, 0.01));
        expect(find.text('Root'), findsNothing);
        expect(find.bySemanticsLabel(RegExp('Status Root')), findsOneWidget);
        semantics.dispose();
      });
    }

    testWidgets('leaves the card plain without it', (tester) async {
      await tester.pumpWidget(_app((_, _) async => _residential));
      await tester.pump(commonDuration);

      final card = tester.widget<DashboardCard>(find.byType(DashboardCard));
      expect(card.side, BorderSide.none);
    });
  });

  group('the restored layout', () {
    testWidgets('shows the country, the address, its chips and the cells', (
      tester,
    ) async {
      await tester.pumpWidget(_ipApp());
      await tester.pump();

      expect(find.text('Running'), findsOneWidget);
      expect(_badgeCode(tester), 'GB');
      expect(find.text(_ip), findsOneWidget);
      expect(find.text('Data center'), findsOneWidget);
      expect(find.text('Quality Poor'), findsOneWidget);
      expect(find.text('Run time'), findsOneWidget);
      expect(find.text('Organization'), findsOneWidget);
      expect(find.text('TORSERVERS-NET'), findsOneWidget);
      // One address at a time: the local one waits behind the switch.
      expect(find.text(_localIp), findsNothing);
      expect(find.text('Local exit'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final density in [
      DashboardDensity.standard,
      DashboardDensity.compact,
      DashboardDensity.mobile,
    ]) {
      testWidgets('keeps two separate tap targets of at least 44 '
          '(${density.name})', (tester) async {
        await tester.pumpWidget(_ipApp(density: density));
        await tester.pump();

        final badge = tester.getRect(_badgeRegion());
        final ip = tester.getRect(_ipRegion(_ip));
        final chips = tester
            .getRect(find.text('Data center'))
            .expandToInclude(tester.getRect(find.text('Quality Poor')));
        expect(badge.width, greaterThanOrEqualTo(44));
        expect(badge.height, greaterThanOrEqualTo(44));
        expect(ip.width, greaterThanOrEqualTo(44));
        expect(ip.height, greaterThanOrEqualTo(44));
        expect(badge.overlaps(ip), isFalse);
        expect(ip.overlaps(chips), isFalse);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('masks a hidden address', (tester) async {
      await tester.pumpWidget(_ipApp(hideIp: true));
      await tester.pump();

      expect(find.text(ipMask), findsOneWidget);
      expect(find.text(_ip), findsNothing);
    });

    testWidgets('says so in place of the address when the lookup fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        _ipApp(exit: const ProbeEntry(phase: ProbePhase.failed)),
      );
      await tester.pump();

      expect(find.text('Check failed'), findsOneWidget);
      expect(find.text('Tap the icon to retry'), findsOneWidget);
    });

    testWidgets('tells a failed report apart from a failed lookup', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          overrides: [
            profilesProvider.overrideWithValue(const [_profile]),
            suspendProvider.overrideWithValue(false),
            runTimeProvider.overrideWith(_Running.new),
            outboundIpProbeProvider.overrideWith(
              () => _RecordingIps(_fresh(_ip), _fresh(_localIp)),
            ),
            ipQualityProvider.overrideWith(
              (_, _) => Future<IpQuality>.error(StateError('down')),
            ),
            ipxLookupProvider(_ip).overrideWith(
              () => _FakeIpx(const IpxLookupState(phase: IpxPhase.failed)),
            ),
          ],
          child: _card(),
        ),
      );
      await tester.pump();
      await tester.pump();

      // The address stands; only the report about it is missing.
      expect(find.text(_ip), findsOneWidget);
      expect(find.text('Couldn’t get the report'), findsOneWidget);
      expect(find.text('Check failed'), findsNothing);
    });

    testWidgets('falls back to the IP quality sources without a report', (
      tester,
    ) async {
      await tester.pumpWidget(
        _ipApp(lookup: const IpxLookupState(phase: IpxPhase.failed)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Residential'), findsOneWidget);
      expect(find.text('Example Broadband'), findsOneWidget);
    });

    testWidgets('shows the local address while Flash is not running', (
      tester,
    ) async {
      await tester.pumpWidget(_ipApp(running: false));
      await tester.pump();

      expect(find.text('Not running'), findsOneWidget);
      expect(find.text(_localIp), findsOneWidget);
      expect(_badgeCode(tester), 'HK');
      // There is no proxy exit to switch to, so nothing says which it is.
      expect(find.text('Local exit'), findsNothing);
      expect(find.byTooltip('Switch to proxy exit'), findsNothing);
    });
  });

  group('the country badge', () {
    testWidgets('looks the shown address up again, once at a time', (
      tester,
    ) async {
      final probe = _ManualIps({
        routedOutbound: _fresh(_ip),
        directOutbound: _fresh(_localIp, country: 'HK'),
      });
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_ipApp(probe: () => probe));
      await tester.pump();

      expect(find.semantics.byLabel(RegExp('^Look up again, GB')), findsOne);
      await tester.tap(_badge());
      await tester.tap(_badge(), warnIfMissed: false);
      await tester.pump();
      expect(probe.refreshed, [routedOutbound]);

      // Under way: the badge turns and is off; the rest of the card stays.
      expect(tester.widget<PressRegion>(_badgeRegion()).onTap, isNull);
      await tester.tap(_badge(), warnIfMissed: false);
      await tester.pump();
      expect(probe.refreshed, [routedOutbound]);
      expect(find.text(_ip), findsOneWidget);
      expect(find.text('Data center'), findsOneWidget);
      expect(find.text('TORSERVERS-NET'), findsOneWidget);
      expect(find.byType(SkeletonPill), findsNothing);
      expect(find.semantics.byLabel(RegExp('Looking up')), findsOne);

      probe.settle(routedOutbound, _fresh(_ip));
      await tester.pumpAndSettle();
      expect(tester.widget<PressRegion>(_badgeRegion()).onTap, isNotNull);
      semantics.dispose();
    });

    testWidgets('a failed lookup keeps what was shown', (tester) async {
      final probe = _ManualIps({
        routedOutbound: _fresh(_ip),
        directOutbound: _fresh(_localIp, country: 'HK'),
      });
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_ipApp(probe: () => probe));
      await tester.pump();

      await tester.tap(_badge());
      await tester.pump();
      probe.settle(routedOutbound, const ProbeEntry(phase: ProbePhase.failed));
      await tester.pumpAndSettle();

      expect(find.text(_ip), findsOneWidget);
      expect(_badgeCode(tester), 'GB');
      expect(find.text('Data center'), findsOneWidget);
      expect(find.text('TORSERVERS-NET'), findsOneWidget);
      expect(find.text('Check failed'), findsNothing);
      expect(find.semantics.byLabel(RegExp('Lookup failed')), findsOne);
      // And it can be asked again.
      expect(tester.widget<PressRegion>(_badgeRegion()).onTap, isNotNull);
      await tester.tap(_badge());
      await tester.pump();
      expect(probe.refreshed, [routedOutbound, routedOutbound]);
      semantics.dispose();
    });

    testWidgets('asks again for a failed report and the missing other exit', (
      tester,
    ) async {
      late _RecordingIps probe;
      await tester.pumpWidget(
        _ipApp(
          lookup: const IpxLookupState(phase: IpxPhase.failed),
          probe: () => probe = _RecordingIps(
            _fresh(_ip),
            const ProbeEntry(phase: ProbePhase.failed),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(_badge());
      await tester.pump();
      expect(
        probe.refreshed,
        unorderedEquals([routedOutbound, directOutbound]),
      );
      expect(_FakeIpx.retries, 1);
    });
  });

  group('the address', () {
    testWidgets('switches the country, chips and organization together', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_ipApp());
      await tester.pump();

      expect(find.byTooltip('Switch to local exit'), findsOneWidget);
      expect(find.semantics.byLabel('Exit IP, $_ip'), findsNothing);
      expect(find.semantics.byLabel(RegExp('^Exit IP, $_ip')), findsOne);
      await tester.tap(find.text(_ip));
      await tester.pump();

      expect(find.text(_localIp), findsOneWidget);
      expect(find.text(_ip), findsNothing);
      expect(_badgeCode(tester), 'HK');
      expect(find.text('Residential'), findsOneWidget);
      expect(find.text('Quality Excellent'), findsOneWidget);
      expect(find.text('HKBN'), findsOneWidget);
      expect(find.text('Data center'), findsNothing);
      expect(find.text('TORSERVERS-NET'), findsNothing);
      expect(find.text('Local exit'), findsOneWidget);
      expect(find.byTooltip('Switch to proxy exit'), findsOneWidget);
      expect(
        find.semantics.byLabel(RegExp('^Local public IP, $_localIp')),
        findsOne,
      );

      await tester.tap(find.text(_localIp));
      await tester.pump();
      expect(find.text(_ip), findsOneWidget);
      expect(_badgeCode(tester), 'GB');
      expect(find.text('TORSERVERS-NET'), findsOneWidget);
      expect(find.text('Local exit'), findsNothing);
      semantics.dispose();
    });

    for (final local in const [
      ProbeEntry<IpInfo>(phase: ProbePhase.probing),
      ProbeEntry<IpInfo>(phase: ProbePhase.failed),
    ]) {
      testWidgets('does nothing while the local exit is ${local.phase.name}', (
        tester,
      ) async {
        late _RecordingIps probe;
        await tester.pumpWidget(
          _ipApp(probe: () => probe = _RecordingIps(_fresh(_ip), local)),
        );
        await tester.pump();

        expect(find.byTooltip('Switch to local exit'), findsNothing);
        expect(tester.widget<PressRegion>(_ipRegion(_ip)).onTap, isNull);
        await tester.tap(find.text(_ip));
        await tester.pump();

        expect(find.text(_ip), findsOneWidget);
        expect(_badgeCode(tester), 'GB');
        expect(find.text('Local exit'), findsNothing);
        expect(probe.refreshed, isEmpty);
      });
    }

    testWidgets('keeps the start button out of both', (tester) async {
      await tester.pumpWidget(_ipApp(setup: _RecordingSetupAction.new));
      await tester.pump();
      final action =
          ProviderScope.containerOf(
                tester.element(find.byType(CurrentOutboundCard)),
              ).read(setupActionProvider.notifier)
              as _RecordingSetupAction;

      await tester.tap(_badge());
      await tester.pump();
      await tester.tap(find.text(_ip));
      await tester.pump();
      await tester.tap(find.text(_localIp));
      await tester.pump();
      expect(action.requests, isEmpty);

      await tester.tap(find.byTooltip('Stop'));
      await tester.pump();
      expect(action.requests, [false]);
    });
  });

  group('the start button', () {
    late ProviderContainer container;

    ProviderContainer containerWith({
      List<Profile> profiles = const [_profile],
      bool suspended = false,
    }) => ProviderContainer(
      overrides: [
        initProvider.overrideWithBuild((_, _) => true),
        profilesProvider.overrideWithValue(profiles),
        outboundIpProbeProvider.overrideWith(_Ips.new),
        ipQualityProvider.overrideWith((_, _) async => _residential),
        setupActionProvider.overrideWith(_RecordingSetupAction.new),
        suspendProvider.overrideWithValue(suspended),
      ],
    );

    tearDown(() => container.dispose());

    Future<void> pumpCard(
      WidgetTester tester, {
      DashboardDensity density = DashboardDensity.standard,
      bool glass = false,
    }) async {
      globalState.container = container;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            child: LiquidGlassScope(
              enabled: glass,
              child: _card(density: density),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Finder startButton() =>
        find.byWidgetPredicate((widget) => widget is PressRegion).last;

    testWidgets('dispatches each toggle through the shared running state', (
      tester,
    ) async {
      container = containerWith();
      container.read(runTimeProvider.notifier).value = 1;
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await pumpCard(tester);
      final action =
          container.read(setupActionProvider.notifier) as _RecordingSetupAction;

      await tester.tap(startButton());
      expect(action.requests, [false]);
      expect(container.read(isStartProvider), isFalse);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Start'), findsOneWidget);

      await tester.tap(startButton());
      expect(action.requests, [false, true]);
      expect(container.read(isStartProvider), isTrue);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Stop'), findsOneWidget);
    });

    testWidgets('a suspended tunnel swaps in the Wi-Fi off glyph and says so', (
      tester,
    ) async {
      container = containerWith(suspended: true);
      container.read(runTimeProvider.notifier).value = 1;
      await pumpCard(tester);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(CurrentOutboundCard));
      expect(
        find.byTooltip(context.appLocalizations.suspended),
        findsOneWidget,
      );
      expect(find.text(context.appLocalizations.suspended), findsOneWidget);
      expect(find.byGlyph(AppGlyphs.wifiOff), findsOneWidget);
    });

    testWidgets('swells under a press and on glass bends within its shape', (
      tester,
    ) async {
      container = containerWith();
      container.read(runTimeProvider.notifier).value = 1;
      await pumpCard(tester, glass: true);
      await tester.pumpAndSettle();
      final glass = tester.widget<LiquidGlass>(
        find.descendant(of: startButton(), matching: find.byType(LiquidGlass)),
      );
      expect(glass.clipper, isNotNull);

      final press = find.descendant(
        of: startButton(),
        matching: find.byType(ElasticPress),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(startButton()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.renderObject(press).debugLayer, isA<TransformLayer>());
      await gesture.cancel();
      await tester.pumpAndSettle();
    });

    testWidgets('is off without a profile', (tester) async {
      container = containerWith(profiles: const []);
      await pumpCard(tester, density: DashboardDensity.mobile);

      final toggle = tester.widget<PressRegion>(startButton());
      expect(toggle.onTap, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('rests without pulsing while no Core can answer', (tester) async {
    // The Core never connected (the helper cannot start it): the route is
    // not live and the probe never launches.
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('en'),
        overrides: [
          profilesProvider.overrideWithValue(const [_profile]),
          suspendProvider.overrideWithValue(false),
        ],
        child: _card(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Not running'), findsOneWidget);
    // The placeholders stay where they are, but hold still: no frame is due.
    expect(find.byType(SkeletonPill), findsWidgets);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
