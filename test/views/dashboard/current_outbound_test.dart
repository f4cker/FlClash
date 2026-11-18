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

const _report = IpxReport(
  ip: _ip,
  score: 35,
  type: IpxIpType.hosting,
  nativity: IpxNativity.native,
  countryCode: 'DE',
  city: 'Brandenburg',
  organization: 'TORSERVERS-NET',
);

ProbeEntry<IpInfo> _fresh(String ip) => ProbeEntry(
  phase: ProbePhase.fresh,
  value: IpInfo(ip: ip, countryCode: 'GB'),
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

class _FakeIpx extends IpxLookup {
  _FakeIpx(this.answer);

  final IpxLookupState answer;

  @override
  IpxLookupState build(String ip) => answer;

  @override
  void reload() {}

  @override
  void retry() {}
}

class _Running extends RunTime {
  @override
  int? build() => 1000;
}

class _Hidden extends AppSetting {
  @override
  AppSettingProps build() => const AppSettingProps(hideIp: true);
}

Widget _ipApp({
  ProbeEntry<IpInfo>? exit,
  ProbeEntry<IpInfo>? local,
  IpxLookupState lookup = const IpxLookupState(
    phase: IpxPhase.done,
    report: _report,
  ),
  bool running = true,
  bool hideIp = false,
  OutboundIpProbe Function()? probe,
}) {
  final exitEntry = exit ?? _fresh(_ip);
  final localEntry = local ?? _fresh(_localIp);
  return TestApp(
    locale: const Locale('en'),
    overrides: [
      profilesProvider.overrideWithValue(const [_profile]),
      suspendProvider.overrideWithValue(false),
      if (running) runTimeProvider.overrideWith(_Running.new),
      if (hideIp) appSettingProvider.overrideWith(_Hidden.new),
      outboundIpProbeProvider.overrideWith(
        probe ?? () => _RecordingIps(exitEntry, localEntry),
      ),
      ipQualityProvider.overrideWith((_, _) async => _residential),
      if (exitEntry.value case final info?)
        ipxLookupProvider(info.ip).overrideWith(() => _FakeIpx(lookup)),
    ],
    child: _card(),
  );
}

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    mitmFeature = true;
    addTearDown(() => mitmFeature = false);
  });

  group('root access', () {
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

    testWidgets('leaves the card plain without it', (tester) async {
      await tester.pumpWidget(_app((_, _) async => _residential));
      await tester.pump(commonDuration);

      final card = tester.widget<DashboardCard>(find.byType(DashboardCard));
      expect(card.side, BorderSide.none);
    });
  });

  group('the exit row', () {
    testWidgets('shows the address, its grade, verdicts and network', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_ipApp());
      await tester.pump();

      expect(find.text('Exit'), findsOneWidget);
      expect(find.text(_ip), findsOneWidget);
      expect(find.text('35 · C'), findsOneWidget);
      expect(find.text('Data center'), findsOneWidget);
      expect(find.text('Native'), findsOneWidget);
      expect(find.text('TORSERVERS-NET · 🇩🇪 DE Brandenburg'), findsOneWidget);
      expect(find.textContaining('Running · 00:00:'), findsOneWidget);
      expect(find.text('Runtime'), findsNothing);
      expect(
        find.semantics.byLabel(
          'Exit IP, $_ip, Health score 35, grade C, Data center, Native, '
          'TORSERVERS-NET, DE Brandenburg',
        ),
        findsOne,
      );
      semantics.dispose();
    });

    testWidgets('opens the full report titled as the exit', (tester) async {
      _useTallView(tester);
      await tester.pumpWidget(_ipApp());
      await tester.pump();

      await tester.tap(find.text(_ip));
      await tester.pumpAndSettle();

      expect(find.text('Exit IP'), findsOneWidget);
    });

    testWidgets('holds the place of both rows while they load', (tester) async {
      await tester.pumpWidget(
        _ipApp(
          exit: const ProbeEntry(phase: ProbePhase.probing),
          local: const ProbeEntry(phase: ProbePhase.probing),
        ),
      );
      await tester.pump();

      final widths = [
        for (final pill in tester.widgetList<SkeletonPill>(
          find.byType(SkeletonPill),
        ))
          pill.width,
      ];
      expect(widths, [120, 44, 180, 110]);
      expect(find.text('Same as exit'), findsNothing);
    });

    testWidgets('says so and offers a retry when the lookup fails', (
      tester,
    ) async {
      late _RecordingIps probe;
      await tester.pumpWidget(
        _ipApp(
          exit: const ProbeEntry(phase: ProbePhase.failed),
          probe: () => probe = _RecordingIps(
            const ProbeEntry(phase: ProbePhase.failed),
            const ProbeEntry(
              phase: ProbePhase.fresh,
              value: IpInfo(ip: _localIp, countryCode: 'HK'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Lookup failed'), findsOneWidget);
      expect(find.text('Couldn’t look up the exit IP'), findsOneWidget);
      // Not the report's failure: there is no address to report on.
      expect(find.text('Couldn’t get the report'), findsNothing);
      // The other row goes on regardless.
      expect(find.text(_localIp), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(probe.refreshed, [routedOutbound]);
    });

    testWidgets('has no exit while Flash is not running', (tester) async {
      await tester.pumpWidget(_ipApp(running: false, local: _fresh(_ip)));
      await tester.pump();

      expect(find.text('—'), findsOneWidget);
      expect(
        find.text('Flash isn’t running, so there’s no exit'),
        findsOneWidget,
      );
      expect(find.text('Not running'), findsOneWidget);
      // Nothing to compare against: never inferred.
      expect(find.text('Same as exit'), findsNothing);
    });

    testWidgets('names its network by ASN without an organization', (
      tester,
    ) async {
      await tester.pumpWidget(
        _ipApp(
          lookup: const IpxLookupState(
            phase: IpxPhase.done,
            report: IpxReport(ip: _ip, score: 90, asn: 64500),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('90 · A+'), findsOneWidget);
      expect(find.text('AS64500 · 🇬🇧 GB'), findsOneWidget);
    });

    testWidgets('keeps the address when only the report failed', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _ipApp(lookup: const IpxLookupState(phase: IpxPhase.failed)),
      );
      await tester.pump();

      expect(find.text(_ip), findsOneWidget);
      expect(find.text('🇬🇧 GB'), findsOneWidget);
      expect(find.text('Couldn’t get the report'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // Not the address lookup's failure.
      expect(find.text('Lookup failed'), findsNothing);
      expect(find.text('Couldn’t look up the exit IP'), findsNothing);
      expect(
        find.semantics.byLabel(
          RegExp('^Exit IP, $_ip, .*Couldn’t get the report\$'),
        ),
        findsOne,
      );
      semantics.dispose();
    });

    testWidgets('a long IPv6 address loses its middle', (tester) async {
      const v6 = '2001:0db8:85a3:0000:0000:8a2e:0370:7334';
      await tester.pumpWidget(
        _ipApp(
          exit: _fresh(v6),
          lookup: const IpxLookupState(phase: IpxPhase.failed),
        ),
      );
      await tester.pump();

      final shown = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? '')
          .firstWhere((text) => text.contains('…'));
      expect(shown, startsWith('2001:'));
      expect(shown, endsWith('7334'));
      expect(tester.takeException(), isNull);
    });
  });

  group('the flag before the place', () {
    test('comes from a two-letter code', () {
      expect(flagOf('DE'), '🇩🇪');
      expect(flagOf('hk'), '🇭🇰');
    });

    test('is left out for anything else', () {
      expect(flagOf(null), isNull);
      expect(flagOf(''), isNull);
      expect(flagOf('D'), isNull);
      expect(flagOf('DEU'), isNull);
      expect(flagOf('1A'), isNull);
    });

    testWidgets('is left out of the line when the code is not one', (
      tester,
    ) async {
      await tester.pumpWidget(
        _ipApp(
          exit: const ProbeEntry(
            phase: ProbePhase.fresh,
            value: IpInfo(ip: _ip, countryCode: 'ZZZ'),
          ),
          lookup: const IpxLookupState(phase: IpxPhase.failed),
        ),
      );
      await tester.pump();

      expect(find.text('ZZZ'), findsOneWidget);
    });
  });

  group('the local row', () {
    testWidgets('says it matches the exit only when both are equal', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_ipApp(local: _fresh(_ip)));
      await tester.pump();

      expect(find.text('Local'), findsOneWidget);
      expect(find.text('Same as exit'), findsOneWidget);
      expect(find.semantics.byLabel('Local public IP, $_ip'), findsOne);
      semantics.dispose();
    });

    testWidgets('leaves a different address alone', (tester) async {
      await tester.pumpWidget(_ipApp());
      await tester.pump();

      expect(find.text(_localIp), findsOneWidget);
      expect(find.text('Same as exit'), findsNothing);
    });

    testWidgets('copies the address and ticks for a moment', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(_ipApp());
      await tester.pump();

      await tester.tap(find.byTooltip('Copy local public IP'));
      await tester.pump();
      expect(copied, _localIp);
      expect(find.byGlyph(AppGlyphs.check), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byGlyph(AppGlyphs.check), findsNothing);
      expect(find.byGlyph(AppGlyphs.copy), findsOneWidget);
    });

    testWidgets('fails on its own, without a copy button', (tester) async {
      await tester.pumpWidget(
        _ipApp(local: const ProbeEntry(phase: ProbePhase.failed)),
      );
      await tester.pump();

      expect(find.text('Lookup failed'), findsOneWidget);
      expect(find.text(_ip), findsOneWidget);
      expect(find.byTooltip('Copy local public IP'), findsNothing);
    });

    testWidgets('hidden addresses are masked and cannot be copied', (
      tester,
    ) async {
      await tester.pumpWidget(_ipApp(hideIp: true));
      await tester.pump();

      expect(find.text(_ip), findsNothing);
      expect(find.text(_localIp), findsNothing);
      expect(find.text(ipMask), findsNWidgets(2));
      expect(find.byTooltip('Copy local public IP'), findsNothing);
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
