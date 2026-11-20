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
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/glyph_finders.dart';
import '../../helpers/test_app.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:prism_ui/shapes/shapes.dart';
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
          // As the dashboard's top row holds it: its content's height,
          // which grows when the tags wrap.
          child: IntrinsicHeight(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 160),
              child: DashboardDensityScope(
                density: density,
                scale: 1,
                child: const CurrentOutboundCard(),
              ),
            ),
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

const _stamp = RouteStamp(
  coreEpoch: 1,
  routeVersion: 1,
  hostEpoch: 1,
  proxied: true,
);

/// The route after a node was picked.
const _movedStamp = RouteStamp(
  coreEpoch: 1,
  routeVersion: 2,
  hostEpoch: 1,
  proxied: true,
);

ProbeEntry<IpInfo> _fresh(String ip, {String country = 'GB'}) => ProbeEntry(
  phase: ProbePhase.fresh,
  value: IpInfo(ip: ip, countryCode: country),
  stamp: _stamp,
);

/// The route [_stamp] was taken on, still in use.
const _liveRoute = RouteState(
  coreEpoch: 1,
  routeVersion: 1,
  hostEpoch: 1,
  proxied: true,
  synced: true,
  live: true,
);

const _failedHere = ProbeEntry<IpInfo>(phase: ProbePhase.failed, stamp: _stamp);

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

  /// Every lookup started, by address.
  static final built = <String>[];

  @override
  IpxLookupState build(String ip) {
    built.add(ip);
    return answer;
  }

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
      routeTrackerProvider.overrideWithBuild((_, _) => route ?? _liveRoute),
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

Finder _badge() =>
    find.ancestor(of: _badgeShape(), matching: find.byType(PressRegion));

Finder _badgeShape() => find.byWidgetPredicate(
  (widget) =>
      widget is ShapeBadge && widget.shape == MaterialShapes.clover4Leaf,
);

/// Whether the badge takes a tap, as a screen reader sees it.
bool _badgeEnabled(WidgetTester tester) => tester
    .widget<Semantics>(
      find
          .ancestor(
            of: _badgeRegion(),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.button == true,
            ),
          )
          .first,
    )
    .properties
    .enabled!;

Finder _badgeRegion() => _badge();

/// A tooltip by its message, which the semantics tree need not carry.
Finder _tooltip(String message) => find.byWidgetPredicate(
  (widget) => widget is Tooltip && widget.message == message,
);

String _badgeTooltip(WidgetTester tester) => tester
    .widget<Tooltip>(
      find.ancestor(of: _badge(), matching: find.byType(Tooltip)).first,
    )
    .message;

Finder _ipRegion(String ip) =>
    find.ancestor(of: find.text(ip), matching: find.byType(PressRegion));

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CurrentOutboundCard)));

/// ipx.al answers nothing; every request is counted.
class _CountingFetch {
  final urls = <String>[];

  Future<IpxAnswer?> call(
    String url, {
    required Duration timeout,
    int? maxBody,
  }) async {
    urls.add(url);
    return null;
  }
}

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
    _FakeIpx.built.clear();
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
      expect(_badgeEnabled(tester), isFalse);
      await tester.pump(probeMoveSettleDuration);
      expect(probe.requests, hasLength(4));
      expect(find.byType(SkeletonPill), findsNothing);
      probe.answer();
      await tester.pumpAndSettle();
      expect(find.text(_ip), findsOneWidget);
      expect(_badgeEnabled(tester), isTrue);
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
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_ipApp(exit: _failedHere));
      await tester.pump();

      expect(find.text('Lookup failed'), findsOneWidget);
      expect(find.text('Tap the icon to retry'), findsOneWidget);
      expect(find.text('Not looked up'), findsNothing);
      // The globe in place of a country says the region is unknown, to the
      // eye and to a screen reader: it is no global exit.
      expect(
        _badgeTooltip(tester),
        'Lookup failed; tap to retry, Region unknown',
      );
      expect(
        find.semantics.byLabel('Lookup failed; tap to retry, Region unknown'),
        findsOne,
      );
      // Nothing is known of the exit's organization either; no dash stands in.
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      semantics.dispose();
    });

    testWidgets('waits for a lookup where none has answered on this route', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      // Failed with no lookup behind it: the route was lost, not asked.
      await tester.pumpWidget(
        _ipApp(exit: const ProbeEntry(phase: ProbePhase.failed)),
      );
      await tester.pump();

      expect(find.text('Not looked up'), findsOneWidget);
      expect(find.text('Lookup failed'), findsNothing);
      expect(find.text('Tap the icon to retry'), findsNothing);
      expect(find.byType(SkeletonPill), findsNothing);
      expect(
        _badgeTooltip(tester),
        'Not looked up; tap to look up, Region unknown',
      );
      expect(
        find.semantics.byLabel('Not looked up; tap to look up, Region unknown'),
        findsOne,
      );
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      expect(find.semantics.byLabel(RegExp('Lookup failed')), findsNothing);
      semantics.dispose();
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
      expect(_tooltip('Switch to proxy exit'), findsNothing);
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
      expect(_badgeEnabled(tester), isFalse);
      await tester.tap(_badge(), warnIfMissed: false);
      await tester.pump();
      expect(probe.refreshed, [routedOutbound]);
      // Off, it keeps keyboard focus, and activating it does nothing.
      final focus = Focus.of(
        tester.element(
          find.descendant(of: _badge(), matching: find.byType(Center)).first,
        ),
      );
      expect(focus.canRequestFocus, isTrue);
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(probe.refreshed, [routedOutbound]);
      expect(find.text(_ip), findsOneWidget);
      expect(find.text('Data center'), findsOneWidget);
      expect(find.text('TORSERVERS-NET'), findsOneWidget);
      expect(find.byType(SkeletonPill), findsNothing);
      expect(
        find.semantics.byLabel('Look up again, GB, Looking up now'),
        findsOne,
      );

      probe.settle(routedOutbound, _fresh(_ip));
      await tester.pumpAndSettle();
      expect(_badgeEnabled(tester), isTrue);
      expect(focus.hasFocus, isTrue);
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
      probe.settle(routedOutbound, _failedHere);
      await tester.pumpAndSettle();

      expect(find.text(_ip), findsOneWidget);
      expect(_badgeCode(tester), 'GB');
      expect(find.text('Data center'), findsOneWidget);
      expect(find.text('TORSERVERS-NET'), findsOneWidget);
      expect(find.text('Check failed'), findsNothing);
      const stale = 'Lookup failed, showing the last result; tap to retry';
      expect(find.semantics.byLabel('$stale, GB'), findsOne);
      expect(_badgeTooltip(tester), stale);
      expect(
        find.descendant(of: _badge(), matching: find.byGlyph(AppGlyphs.error)),
        findsOne,
      );
      // And it can be asked again.
      expect(_badgeEnabled(tester), isTrue);
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

    testWidgets('a screen reader can activate it', (tester) async {
      final probe = _ManualIps({
        routedOutbound: _fresh(_ip),
        directOutbound: _fresh(_localIp, country: 'HK'),
      });
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_ipApp(probe: () => probe));
      await tester.pump();

      final badge = find.semantics.byLabel('Look up again, GB');
      expect(badge, findsOne);
      expect(
        badge.evaluate().single,
        isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
      );
      // Named once: the tooltip does not repeat the label.
      expect(badge.evaluate().single.getSemanticsData().tooltip, isEmpty);
      tester.semantics.tap(badge);
      await tester.pump();
      expect(probe.refreshed, [routedOutbound]);
      final busy = find.semantics.byLabel('Look up again, GB, Looking up now');
      expect(
        busy.evaluate().single,
        isSemantics(isButton: true, isEnabled: false, hasTapAction: false),
      );
      semantics.dispose();
    });

    testWidgets('looks up the shown exit while the other one is under way', (
      tester,
    ) async {
      final probe = _ManualIps({
        routedOutbound: _fresh(_ip),
        directOutbound: const ProbeEntry(phase: ProbePhase.probing),
      });
      await tester.pumpWidget(_ipApp(probe: () => probe));
      await tester.pump();

      expect(_badgeEnabled(tester), isTrue);
      await tester.tap(_badge());
      await tester.pump();
      // The local lookup already out is left to finish on its own.
      expect(probe.refreshed, [routedOutbound]);
    });

    testWidgets('does not keep an address across a route change', (
      tester,
    ) async {
      final probe = _ManualIps({
        routedOutbound: _fresh(_ip),
        directOutbound: _fresh(_localIp, country: 'HK'),
      });
      await tester.pumpWidget(_ipApp(probe: () => probe));
      await tester.pump();

      // A failure from a route the card is not on yet says nothing about
      // this one: the exit waits for a lookup, and is not called failed.
      await tester.tap(_badge());
      await tester.pump();
      probe.settle(
        routedOutbound,
        const ProbeEntry(phase: ProbePhase.failed, stamp: _movedStamp),
      );
      await tester.pumpAndSettle();
      expect(find.text(_ip), findsNothing);
      expect(find.text('Not looked up'), findsOneWidget);
      expect(find.text('Lookup failed'), findsNothing);

      // Another node was picked, and the lookup through it failed: the old
      // node's address is not this exit's.
      _containerOf(tester)
          .read(routeTrackerProvider.notifier)
          .applySnapshot(
            const RouteSnapshot(coreEpoch: 1, routeVersion: 2, running: true),
          );
      await tester.pumpAndSettle();
      expect(find.text(_ip), findsNothing);
      expect(find.text('TORSERVERS-NET'), findsNothing);
      expect(find.text('Lookup failed'), findsOneWidget);
      expect(_badgeCode(tester), isNull);
      expect(
        _badgeTooltip(tester),
        'Lookup failed; tap to retry, Region unknown',
      );

      // Nor does a stale local address offer a switch.
      probe
        ..settle(routedOutbound, _fresh(_ip))
        ..settle(
          directOutbound,
          const ProbeEntry(phase: ProbePhase.failed, stamp: _movedStamp),
        );
      await tester.pumpAndSettle();
      expect(find.text(_ip), findsOneWidget);
      expect(_tooltip('Switch to local exit'), findsNothing);
      expect(tester.widget<PressRegion>(_ipRegion(_ip)).onTap, isNull);

      // A failure without a route to go by keeps nothing, and waits.
      probe.settle(routedOutbound, const ProbeEntry(phase: ProbePhase.failed));
      await tester.pumpAndSettle();
      expect(find.text('Not looked up'), findsOneWidget);
      expect(find.text('Lookup failed'), findsNothing);
    });

    testWidgets('asks for the report of the shown address only', (
      tester,
    ) async {
      final probe = _ManualIps({
        routedOutbound: _fresh(_ip),
        directOutbound: _fresh(_localIp, country: 'HK'),
      });
      await tester.pumpWidget(_ipApp(probe: () => probe));
      await tester.pump();
      expect(_FakeIpx.built, [_ip]);

      await tester.tap(find.text(_ip));
      await tester.pump();
      expect(_FakeIpx.built, [_ip]);
      expect(find.text('Not looked up'), findsOneWidget);
      expect(_badgeTooltip(tester), 'Not looked up; tap to look up');

      await tester.tap(_badge());
      await tester.pump();
      expect(probe.refreshed, [directOutbound]);
      expect(_FakeIpx.built, [_ip, _localIp]);
      probe.settle(directOutbound, _fresh(_localIp, country: 'HK'));
      await tester.pumpAndSettle();
      expect(find.text('HKBN'), findsOneWidget);
      expect(find.text('Residential'), findsOneWidget);
    });
  });

  group('the address', () {
    testWidgets('switches the country, chips and organization together', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_ipApp());
      await tester.pump();
      // The local exit's report was looked up before, from its badge.
      _containerOf(tester).read(ipxLookupProvider(_localIp));

      expect(_tooltip('Switch to local exit'), findsOneWidget);
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
      expect(_tooltip('Switch to proxy exit'), findsOneWidget);
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

    testWidgets('switches without asking anything, either way', (tester) async {
      final fetch = _CountingFetch();
      final quality = <String>[];
      late _RecordingIps probe;
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          overrides: [
            profilesProvider.overrideWithValue(const [_profile]),
            suspendProvider.overrideWithValue(false),
            runTimeProvider.overrideWith(_Running.new),
            outboundIpProbeProvider.overrideWith(
              () => probe = _RecordingIps(
                _fresh(_ip),
                _fresh(_localIp, country: 'HK'),
              ),
            ),
            ipxFetchProvider.overrideWithValue(fetch.call),
            ipQualityProvider.overrideWith((_, ip) {
              quality.add(ip);
              return Future.any(const []);
            }),
          ],
          child: _card(),
        ),
      );
      await tester.pumpAndSettle();
      // The exit the card opens on was looked up, as ever, on ipx.al alone:
      // the IP quality sources are never asked from the card.
      expect(fetch.urls, hasLength(2));
      expect(quality, isEmpty);
      final container = _containerOf(tester);
      expect(container.exists(ipxLookupProvider(_localIp)), isFalse);

      await tester.tap(find.text(_ip));
      await tester.pumpAndSettle();
      expect(find.text(_localIp), findsOneWidget);
      // Nothing cached about it: unknown, still, and nothing asked.
      expect(_badgeCode(tester), 'HK');
      expect(find.text('Not looked up'), findsOneWidget);
      expect(find.text('Unknown type'), findsNothing);
      expect(find.text('Local exit'), findsOneWidget);
      expect(find.byType(SkeletonPill), findsNothing);
      expect(find.byType(SkeletonText), findsNothing);
      // Its organization is not known for this address.
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      expect(_badgeEnabled(tester), isTrue);
      expect(fetch.urls, hasLength(2));
      expect(quality, isEmpty);
      expect(container.exists(ipxLookupProvider(_localIp)), isFalse);
      expect(container.exists(ipQualityProvider(_localIp)), isFalse);

      await tester.tap(find.text(_localIp));
      await tester.pumpAndSettle();
      expect(find.text(_ip), findsOneWidget);
      expect(_badgeCode(tester), 'GB');
      expect(fetch.urls, hasLength(2));
      expect(quality, isEmpty);
      expect(probe.refreshed, isEmpty);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byType(DashboardFitText));
        await tester.pumpAndSettle();
      }
      expect(fetch.urls, hasLength(2));
      expect(quality, isEmpty);
      expect(container.exists(ipxLookupProvider(_localIp)), isFalse);
      expect(probe.refreshed, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('opens a new session on the proxy exit', (tester) async {
      await tester.pumpWidget(_ipApp());
      await tester.pump();
      await tester.tap(find.text(_ip));
      await tester.pump();
      expect(find.text(_localIp), findsOneWidget);

      final runTime = _containerOf(tester).read(runTimeProvider.notifier);
      runTime.value = null;
      await tester.pump();
      expect(find.text('Not running'), findsOneWidget);
      expect(find.text(_localIp), findsOneWidget);
      runTime.value = 1000;
      await tester.pump();
      expect(find.text('Running'), findsOneWidget);
      expect(find.text(_ip), findsOneWidget);
      expect(find.text(_localIp), findsNothing);
    });

    testWidgets('after a switch, asks nothing until the badge is tapped', (
      tester,
    ) async {
      const nextIp = '198.51.100.7';
      final fetch = _CountingFetch();
      final probe = _ManualIps({
        routedOutbound: _fresh(_ip),
        directOutbound: _fresh(_localIp, country: 'HK'),
      });
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          overrides: [
            profilesProvider.overrideWithValue(const [_profile]),
            suspendProvider.overrideWithValue(false),
            runTimeProvider.overrideWith(_Running.new),
            routeTrackerProvider.overrideWithBuild((_, _) => _liveRoute),
            outboundIpProbeProvider.overrideWith(() => probe),
            ipxFetchProvider.overrideWithValue(fetch.call),
            ipQualityProvider.overrideWith((_, _) => Future.any(const [])),
          ],
          child: _card(),
        ),
      );
      await tester.pump();
      List<String> asked(String ip) =>
          fetch.urls.where((url) => url.contains(ip)).toList();
      // The exit the card opens on is asked about.
      expect(asked(_ip), isNotEmpty);
      final before = fetch.urls.length;

      await tester.tap(find.text(_ip));
      await tester.pump();
      // While the local exit is shown, the proxy exit moves to a new node.
      probe.settle(routedOutbound, _fresh(nextIp, country: 'NL'));
      await tester.pump();
      probe.settle(directOutbound, _fresh(_localIp, country: 'HK'));
      await tester.pump();
      expect(fetch.urls, hasLength(before));

      await tester.tap(find.text(_localIp));
      await tester.pump();
      expect(find.text(nextIp), findsOneWidget);
      expect(_badgeCode(tester), 'NL');
      expect(find.text('Not looked up'), findsOneWidget);
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.text('Lookup failed'), findsNothing);
      expect(fetch.urls, hasLength(before));
      expect(_containerOf(tester).exists(ipxLookupProvider(nextIp)), isFalse);

      // A later check of the shown exit asks nothing either.
      probe.settle(
        routedOutbound,
        const ProbeEntry(
          phase: ProbePhase.probing,
          previousValue: IpInfo(ip: nextIp, countryCode: 'NL'),
        ),
      );
      await tester.pump();
      probe.settle(routedOutbound, _fresh(nextIp, country: 'NL'));
      await tester.pump();
      expect(find.text('Not looked up'), findsOneWidget);
      expect(fetch.urls, hasLength(before));

      // The badge does.
      await tester.tap(_badge());
      await tester.pump();
      expect(asked(nextIp), isNotEmpty);
      final tapped = fetch.urls.length;

      // A new session opens on the proxy exit and asks about it again.
      final runTime = _containerOf(tester).read(runTimeProvider.notifier);
      runTime.value = null;
      await tester.pump();
      const newSessionIp = '192.0.2.44';
      probe.settle(routedOutbound, _fresh(newSessionIp, country: 'DE'));
      runTime.value = 1000;
      await tester.pump();
      expect(find.text(newSessionIp), findsOneWidget);
      expect(asked(newSessionIp), isNotEmpty);
      expect(fetch.urls.length, greaterThan(tapped));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final (country, code) in const [('HK', 'HK'), ('', null)]) {
      testWidgets('takes the country from the shown address\'s own lookup '
          '(${code ?? 'none'})', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _ipApp(local: _fresh(_localIp, country: country)),
        );
        await tester.pump();
        expect(_badgeCode(tester), 'GB');

        await tester.tap(find.text(_ip));
        await tester.pump();
        expect(find.text(_localIp), findsOneWidget);
        // Never the proxy exit's: without one of its own, it is unknown.
        expect(_badgeCode(tester), code);
        expect(
          _badgeTooltip(tester),
          code == null
              ? 'Not looked up; tap to look up, Region unknown'
              : 'Not looked up; tap to look up',
        );
        expect(find.semantics.byLabel(RegExp('GB')), findsNothing);
        expect(
          find.semantics.byLabel(
            'Not looked up; tap to look up, ${code ?? 'Region unknown'}',
          ),
          findsOne,
        );
        semantics.dispose();
      });
    }

    testWidgets('never asks the IP quality sources, not even from the badge', (
      tester,
    ) async {
      final lookups = <String>[];
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          overrides: [
            profilesProvider.overrideWithValue(const [_profile]),
            suspendProvider.overrideWithValue(false),
            runTimeProvider.overrideWith(_Running.new),
            routeTrackerProvider.overrideWithBuild((_, _) => _liveRoute),
            outboundIpProbeProvider.overrideWith(
              () => _RecordingIps(_fresh(_ip), _fresh(_localIp)),
            ),
            ipxLookupProvider(_ip).overrideWith(
              () => _FakeIpx(const IpxLookupState(phase: IpxPhase.failed)),
            ),
            ipQualityProvider.overrideWith((_, ip) async {
              lookups.add(ip);
              return _residential;
            }),
          ],
          child: _card(),
        ),
      );
      await tester.pump();
      await tester.pump();
      // ipx.al has no report: the card says so, as beta 3's did, and leaves
      // the IP quality sources to the detail sheet.
      expect(find.text('Couldn’t get the report'), findsOneWidget);
      expect(find.text('Residential'), findsNothing);
      expect(lookups, isEmpty);

      // The badge asks ipx.al again, and nothing else.
      await tester.tap(_badge());
      await tester.pump();
      expect(_FakeIpx.retries, 1);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(minutes: 1));
      }
      expect(lookups, isEmpty);
      expect(_containerOf(tester).exists(ipQualityProvider(_ip)), isFalse);
    });

    testWidgets('never reads an IP quality entry it did not ask for', (
      tester,
    ) async {
      final lookups = <String>[];
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          overrides: [
            profilesProvider.overrideWithValue(const [_profile]),
            suspendProvider.overrideWithValue(false),
            runTimeProvider.overrideWith(_Running.new),
            routeTrackerProvider.overrideWithBuild((_, _) => _liveRoute),
            outboundIpProbeProvider.overrideWith(
              () => _RecordingIps(_fresh(_ip), _fresh(_localIp, country: 'HK')),
            ),
            ipxLookupProvider(_ip).overrideWith(() => _FakeIpx(_done)),
            ipxLookupProvider(_localIp).overrideWith(
              () => _FakeIpx(const IpxLookupState(phase: IpxPhase.failed)),
            ),
            ipQualityProvider.overrideWith((ref, ip) async {
              lookups.add(ip);
              ref.keepAlive();
              return _residential;
            }),
          ],
          child: _card(),
        ),
      );
      await tester.pump();
      final container = _containerOf(tester);
      // The detail sheet looked the local address up, and is still open
      // in the background; then its entry is invalidated, as an expiry or a
      // refresh does. Nothing listening wants it back yet.
      container.read(ipxLookupProvider(_localIp));
      final sheet = container.listen(ipQualityProvider(_localIp), (_, _) {});
      await tester.pump();
      expect(lookups, [_localIp]);
      sheet.pause();
      container.invalidate(ipQualityProvider(_localIp));
      await tester.pump();
      expect(container.exists(ipQualityProvider(_localIp)), isTrue);
      expect(lookups, [_localIp]);

      await tester.tap(find.text(_ip));
      await tester.pump();
      await tester.pump();
      expect(find.text(_localIp), findsOneWidget);
      // Reading the invalidated entry would have sent the lookup again.
      expect(lookups, [_localIp]);
      sheet.close();
    });

    testWidgets(
      'announces only the lookups the user or the opening asked for',
      (tester) async {
        final probe = _ManualIps({});
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_ipApp(probe: () => probe));
        await tester.pump();
        tester.takeAnnouncements();
        List<String> said() =>
            tester.takeAnnouncements().map((a) => a.message).toList();

        // The session opens: its exit's first lookup is announced.
        probe.settle(
          routedOutbound,
          const ProbeEntry(phase: ProbePhase.probing),
        );
        await tester.pump();
        expect(said(), ['Looking up now']);
        probe.settle(routedOutbound, _fresh(_ip));
        await tester.pump();
        expect(said(), isEmpty);

        // The route moves and the probe checks the exit again on its own.
        probe.settle(
          routedOutbound,
          const ProbeEntry(
            phase: ProbePhase.probing,
            previousValue: IpInfo(ip: _ip, countryCode: 'GB'),
            stamp: _stamp,
          ),
        );
        await tester.pump();
        expect(said(), isEmpty);
        probe.settle(routedOutbound, _fresh(_ip));
        await tester.pump();
        expect(said(), isEmpty);

        // The badge asks.
        await tester.tap(_badge());
        await tester.pump();
        expect(said(), ['Looking up now']);
        probe.settle(routedOutbound, _fresh(_ip));
        await tester.pump();
        expect(said(), isEmpty);

        // And a background check after it is quiet again.
        probe.settle(
          routedOutbound,
          const ProbeEntry(
            phase: ProbePhase.probing,
            previousValue: IpInfo(ip: _ip, countryCode: 'GB'),
            stamp: _stamp,
          ),
        );
        await tester.pump();
        expect(said(), isEmpty);
        semantics.dispose();
      },
    );

    testWidgets('shows the last result of a failure only from its own route', (
      tester,
    ) async {
      const movedRoute = RouteState(
        coreEpoch: 1,
        routeVersion: 2,
        hostEpoch: 1,
        proxied: true,
        synced: true,
        live: true,
      );
      // The lookup on the new route failed, still carrying the address the
      // old route found.
      await tester.pumpWidget(
        _ipApp(
          route: movedRoute,
          exit: const ProbeEntry(
            phase: ProbePhase.failed,
            previousValue: IpInfo(ip: _ip, countryCode: 'GB'),
            stamp: _movedStamp,
          ),
        ),
      );
      await tester.pump();

      expect(find.text(_ip), findsNothing);
      expect(find.text('TORSERVERS-NET'), findsNothing);
      expect(find.text('Lookup failed'), findsOneWidget);
      expect(
        _badgeTooltip(tester),
        'Lookup failed; tap to retry, Region unknown',
      );
      expect(
        find.descendant(of: _badge(), matching: find.byGlyph(AppGlyphs.error)),
        findsNothing,
      );
    });

    testWidgets('announces a lookup and its failure, nothing else', (
      tester,
    ) async {
      final probe = _ManualIps({
        routedOutbound: _fresh(_ip),
        directOutbound: _fresh(_localIp, country: 'HK'),
      });
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_ipApp(probe: () => probe));
      await tester.pump();
      tester.takeAnnouncements();

      await tester.tap(find.text(_ip));
      await tester.pump();
      expect(tester.takeAnnouncements(), isEmpty);

      await tester.tap(_badge());
      await tester.pump();
      expect(tester.takeAnnouncements().map((a) => a.message), [
        'Looking up now',
      ]);
      probe.settle(
        directOutbound,
        const ProbeEntry(phase: ProbePhase.failed, stamp: _stamp),
      );
      await tester.pump();
      expect(tester.takeAnnouncements().map((a) => a.message), [
        'Lookup failed, showing the last result; tap to retry',
      ]);
      final badge = find.semantics.byLabel(RegExp('^Lookup failed'));
      expect(
        badge.evaluate().single.getSemanticsData().flagsCollection.isLiveRegion,
        isFalse,
      );
      // The address names its switch once, as a hint, not again as a tooltip.
      final address = find.semantics
          .byLabel(RegExp('^Local public IP'))
          .evaluate()
          .single
          .getSemanticsData();
      expect(address.hint, 'Switch to proxy exit');
      expect(address.tooltip, isEmpty);
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

        expect(_tooltip('Switch to local exit'), findsNothing);
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
