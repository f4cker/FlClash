// Renders the dashboard's status card to PNG for review, light and dark,
// in each of its states. Off by default:
//   STATUS_CARD_SCREENSHOTS=<dir> flutter test \
//     test/views/status_card_screenshots_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/common/service_probe.dart'
    show directOutbound, routedOutbound;
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/ipx_report.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/widgets/current_outbound.dart';
import 'package:fl_clash/views/dashboard/widgets/ip_detail_tag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

final _outDir = Platform.environment['STATUS_CARD_SCREENSHOTS'];
const _cjkCollection = '/System/Library/Fonts/Hiragino Sans GB.ttc';

List<ByteData> _collectionFaces(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final faces = <ByteData>[];
  for (var face = 0; face < data.getUint32(8); face++) {
    final header = data.getUint32(12 + face * 4);
    final tables = data.getUint16(header + 4);
    final out = BytesBuilder()..add(bytes.sublist(header, header + 12));
    final body = BytesBuilder();
    var at = 12 + tables * 16;
    for (var i = 0; i < tables; i++) {
      final entry = header + 12 + i * 16;
      final offset = data.getUint32(entry + 8);
      final length = data.getUint32(entry + 12);
      final record = ByteData(16)
        ..setUint32(0, data.getUint32(entry))
        ..setUint32(4, data.getUint32(entry + 4))
        ..setUint32(8, at)
        ..setUint32(12, length);
      out.add(record.buffer.asUint8List());
      final padded = (length + 3) & ~3;
      body
        ..add(bytes.sublist(offset, offset + length))
        ..add(Uint8List(padded - length));
      at += padded;
    }
    out.add(body.takeBytes());
    faces.add(ByteData.sublistView(out.takeBytes()));
  }
  return faces;
}

const _exitIp = '204.136.11.10';
const _localIp = '58.152.33.18';

/// The proxy exit after another node is picked.
const _nextIp = '185.220.101.4';

const _exitReport = IpxReport(
  ip: _exitIp,
  score: 62,
  type: IpxIpType.hosting,
  nativity: IpxNativity.native,
  countryCode: 'US',
  city: 'Los Angeles',
  organization: 'Sharktech',
);

const _localReport = IpxReport(
  ip: _localIp,
  score: 88,
  type: IpxIpType.residential,
  nativity: IpxNativity.native,
  countryCode: 'HK',
  city: 'Hong Kong',
  organization: 'HKBN',
);

class _Ips extends OutboundIpProbe {
  _Ips(this.initial);

  final Map<String, ProbeEntry<IpInfo>> initial;

  @override
  RoutedProbeState<String, IpInfo> build() => RoutedProbeState(initial);

  @override
  void watch(String target) {}

  @override
  void unwatch(String target) {}

  @override
  void refresh(Iterable<String> targets) {}

  void settle(String target, ProbeEntry<IpInfo> entry) {
    state = RoutedProbeState({...state.entries, target: entry});
  }
}

class _Ipx extends IpxLookup {
  @override
  IpxLookupState build(String ip) => IpxLookupState(
    phase: IpxPhase.done,
    report: ip == _exitIp ? _exitReport : _localReport,
  );

  @override
  void reload() {}
}

class _Running extends RunTime {
  @override
  int? build() => (97 * 3600 + 23 * 60 + 18) * 1000;
}

const _stamp = RouteStamp(
  coreEpoch: 1,
  routeVersion: 1,
  hostEpoch: 1,
  proxied: true,
);

const _route = RouteState(
  coreEpoch: 1,
  routeVersion: 1,
  hostEpoch: 1,
  proxied: true,
  synced: true,
  live: true,
);

ProbeEntry<IpInfo> _fresh(String ip, String country) => ProbeEntry(
  phase: ProbePhase.fresh,
  value: IpInfo(ip: ip, countryCode: country),
  stamp: _stamp,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _outDir == null || _outDir!.isEmpty
      ? 'set STATUS_CARD_SCREENSHOTS to an output directory'
      : null;
  final boundary = GlobalKey();

  setUpAll(() async {
    if (skip != null) return;
    WidgetsApp.debugAllowBannerOverride = false;
    final cjk = _collectionFaces(File(_cjkCollection).readAsBytesSync());
    for (final family in ['Roboto', 'PingFang SC']) {
      final loader = FontLoader(family);
      for (final face in cjk) {
        loader.addFont(Future.value(face));
      }
      await loader.load();
    }
    // As on a Mac, for the shots that run as one: the system face for
    // Latin and Cyrillic, PingFang SC (here Hiragino) behind it.
    final system = FontLoader('.AppleSystemUIFont');
    for (final face in _collectionFaces(
      File('/System/Library/Fonts/HelveticaNeue.ttc').readAsBytesSync(),
    )) {
      system.addFont(Future.value(face));
    }
    await system.load();
    // The detail sheet's address is in the app's own monospaced face.
    final mono = FontLoader('JetBrainsMono')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/JetBrainsMono-Regular.ttf').readAsBytesSync(),
          ),
        ),
      );
    await mono.load();
    Directory(_outDir!).createSync(recursive: true);
  });

  Future<void> capture(WidgetTester tester, String name) async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File('$_outDir/$name.png').writeAsBytes(data!.buffer.asUint8List());
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<_Ips> pump(
    WidgetTester tester, {
    required Brightness brightness,
    required Map<String, ProbeEntry<IpInfo>> entries,
    bool running = true,
    Size view = const Size(614, 226),
    double width = 574,
    DashboardDensity density = DashboardDensity.standard,
    double textScale = 1,
    Locale locale = const Locale('zh', 'CN'),
  }) async {
    tester.view.physicalSize = view * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ips = _Ips(entries);
    final overrides = <Override>[
      profilesProvider.overrideWithValue(const [
        Profile(id: 1, autoUpdateDuration: Duration.zero),
      ]),
      suspendProvider.overrideWithValue(false),
      if (running) runTimeProvider.overrideWith(_Running.new),
      routeTrackerProvider.overrideWithBuild((_, _) => _route),
      outboundIpProbeProvider.overrideWith(() => ips),
      for (final ip in [_exitIp, _localIp, _nextIp])
        ipxLookupProvider(ip).overrideWith(_Ipx.new),
      ipQualityProvider.overrideWith((_, _) => Future.any(const [])),
    ];
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    globalState.container = container;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => TestApp(
              locale: locale,
              includeNavigatorKey: false,
              theme: watchAppTheme(ref, Brightness.light),
              darkTheme: watchAppTheme(ref, Brightness.dark),
              themeMode: brightness == Brightness.light
                  ? ThemeMode.light
                  : ThemeMode.dark,
              // As the dashboard's top row: its content's height, 160 at
              // least.
              child: HostScaffold(
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: IntrinsicHeight(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: 160 * textScale,
                          ),
                          child: Builder(
                            builder: (context) => MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                textScaler: TextScaler.linear(textScale),
                              ),
                              child: DashboardDensityScope(
                                density: density,
                                // As the dashboard does: the card
                                // grows with the text.
                                scale: math.max(1, textScale),
                                child: const CurrentOutboundCard(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return ips;
  }

  final both = {
    routedOutbound: _fresh(_exitIp, 'US'),
    directOutbound: _fresh(_localIp, 'HK'),
  };

  for (final brightness in Brightness.values) {
    final tone = brightness == Brightness.light ? 'light' : 'dark';

    testWidgets('proxy-$tone', skip: skip != null, (tester) async {
      await pump(tester, brightness: brightness, entries: both);
      await capture(tester, 'proxy-$tone');
    });

    testWidgets('local-$tone', skip: skip != null, (tester) async {
      await pump(tester, brightness: brightness, entries: both);
      // Its report was looked up before, from the badge.
      ProviderScope.containerOf(
        tester.element(find.byType(CurrentOutboundCard)),
      ).read(ipxLookupProvider(_localIp));
      await tester.tap(find.text(_exitIp));
      await settle(tester);
      await capture(tester, 'local-$tone');
    });

    testWidgets('local-uncached-$tone', skip: skip != null, (tester) async {
      await pump(tester, brightness: brightness, entries: both);
      // Nothing cached about the local exit: the switch asks for nothing.
      await tester.tap(find.text(_exitIp));
      await settle(tester);
      await capture(tester, 'local-uncached-$tone');
    });

    testWidgets('local-uncached-no-country-$tone', skip: skip != null, (
      tester,
    ) async {
      await pump(
        tester,
        brightness: brightness,
        entries: {
          routedOutbound: _fresh(_exitIp, 'US'),
          // The lookup found the address but no country for it.
          directOutbound: _fresh(_localIp, ''),
        },
      );
      await tester.tap(find.text(_exitIp));
      await settle(tester);
      await capture(tester, 'local-uncached-no-country-$tone');
    });

    testWidgets('pending-query-$tone', skip: skip != null, (tester) async {
      final ips = await pump(tester, brightness: brightness, entries: both);
      // Switched to the local exit, the proxy one moves to another node;
      // back on it, its new address waits for the badge.
      ProviderScope.containerOf(
        tester.element(find.byType(CurrentOutboundCard)),
      ).read(ipxLookupProvider(_localIp));
      await tester.tap(find.text(_exitIp));
      await settle(tester);
      ips.settle(routedOutbound, _fresh(_nextIp, 'NL'));
      await settle(tester);
      await tester.tap(find.text(_localIp));
      await settle(tester);
      await capture(tester, 'pending-query-$tone');
    });

    testWidgets('pending-address-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        entries: {
          // Failed with no lookup behind it: the route was lost, not asked.
          routedOutbound: const ProbeEntry(phase: ProbePhase.failed),
          directOutbound: _fresh(_localIp, 'HK'),
        },
      );
      await capture(tester, 'pending-address-$tone');
    });

    testWidgets('querying-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        entries: {
          routedOutbound: const ProbeEntry(
            phase: ProbePhase.probing,
            previousValue: IpInfo(ip: _exitIp, countryCode: 'US'),
          ),
          directOutbound: _fresh(_localIp, 'HK'),
        },
      );
      await capture(tester, 'querying-$tone');
    });

    testWidgets('failed-with-old-values-$tone', skip: skip != null, (
      tester,
    ) async {
      final ips = await pump(tester, brightness: brightness, entries: both);
      ips.settle(
        routedOutbound,
        const ProbeEntry(phase: ProbePhase.failed, stamp: _stamp),
      );
      await settle(tester);
      await capture(tester, 'failed-with-old-values-$tone');
    });

    testWidgets('no-local-candidate-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        entries: {
          routedOutbound: _fresh(_exitIp, 'US'),
          directOutbound: const ProbeEntry(phase: ProbePhase.failed),
        },
      );
      // Nothing to switch to: the tap leaves the proxy exit in place.
      await tester.tap(find.text(_exitIp));
      await settle(tester);
      await capture(tester, 'no-local-candidate-$tone');
    });

    testWidgets('lookup-failed-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        entries: {
          routedOutbound: const ProbeEntry(
            phase: ProbePhase.failed,
            stamp: _stamp,
          ),
          directOutbound: _fresh(_localIp, 'HK'),
        },
      );
      await capture(tester, 'lookup-failed-$tone');
    });

    testWidgets('not-running-$tone', skip: skip != null, (tester) async {
      await pump(tester, brightness: brightness, entries: both, running: false);
      await capture(tester, 'not-running-$tone');
    });

    // The type and quality tags that open the shown exit's IP detail.
    testWidgets('tags-narrow-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        entries: both,
        view: const Size(380, 300),
        width: 340,
        density: DashboardDensity.mobile,
      );
      await capture(tester, 'tags-narrow-$tone');
    });

    testWidgets('tags-hover-$tone', skip: skip != null, (tester) async {
      await pump(tester, brightness: brightness, entries: both);
      // As on a Mac, where a pointer hovers.
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('机房')));
      await settle(tester);
      await capture(tester, 'tags-hover-$tone');
    });

    testWidgets('tags-focus-$tone', skip: skip != null, (tester) async {
      await pump(tester, brightness: brightness, entries: both);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      Focus.of(tester.element(find.text('机房'))).requestFocus();
      await settle(tester);
      await capture(tester, 'tags-focus-$tone');
    });

    testWidgets('detail-sheet-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        entries: both,
        view: const Size(614, 900),
      );
      await tester.tap(find.text('机房'));
      await settle(tester);
      await capture(tester, 'detail-sheet-$tone');
    });

    testWidgets('detail-sheet-not-queried-$tone', skip: skip != null, (
      tester,
    ) async {
      await pump(
        tester,
        brightness: brightness,
        entries: both,
        view: const Size(614, 900),
      );
      // The local exit was never looked up: its detail has nothing yet.
      await tester.tap(find.text(_exitIp));
      await settle(tester);
      await tester.tap(find.byType(IpDetailTag).first);
      await settle(tester);
      await capture(tester, 'detail-sheet-not-queried-$tone');
    });
  }

  for (final brightness in Brightness.values) {
    final tone = brightness == Brightness.light ? 'light' : 'dark';
    for (final (name, density, view, width) in const [
      ('desktop', DashboardDensity.standard, Size(780, 300), 740.0),
      ('narrow', DashboardDensity.mobile, Size(380, 340), 340.0),
    ]) {
      testWidgets('tags-large-text-$name-$tone', skip: skip != null, (
        tester,
      ) async {
        await pump(
          tester,
          brightness: brightness,
          entries: both,
          view: view,
          width: width,
          density: density,
          textScale: 1.3,
        );
        await capture(tester, 'tags-large-text-$name-$tone');
      });
    }

    // The longest translations, on the compact desktop card (a 1000 wide
    // window), local exit with its three chips: the card grows rather than
    // cut a tag.
    for (final language in ['fr', 'ru']) {
      for (final local in [false, true]) {
        final exit = local ? 'local' : 'proxy';
        testWidgets('long-$language-$exit-$tone', skip: skip != null, (
          tester,
        ) async {
          // As on a Mac, for its system face (see setUpAll).
          debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
          addTearDown(() => debugDefaultTargetPlatformOverride = null);
          await pump(
            tester,
            brightness: brightness,
            entries: both,
            view: const Size(510, 300),
            width: 470,
            density: DashboardDensity.compact,
            locale: Locale(language),
          );
          if (local) {
            ProviderScope.containerOf(
              tester.element(find.byType(CurrentOutboundCard)),
            ).read(ipxLookupProvider(_localIp));
            await tester.tap(find.text(_exitIp));
            await settle(tester);
          }
          expect(tester.takeException(), isNull);
          await capture(tester, 'long-$language-$exit-$tone');
        });
      }
    }
  }

  for (final (name, size) in const [
    ('normal', Size(1220, 824)),
    ('compact', Size(1000, 824)),
  ]) {
    testWidgets('dashboard-full-$name-light', skip: skip != null, (
      tester,
    ) async {
      // Cached files go to a scratch directory of the test's own.
      final cache = Directory.systemTemp.createTempSync('status-card-');
      addTearDown(() => cache.deleteSync(recursive: true));
      const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pathProvider,
        (_) async => cache.path,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          pathProvider,
          null,
        ),
      );
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(
            () => TestProfiles(const [
              Profile(id: 1, autoUpdateDuration: Duration.zero),
            ]),
          ),
          suspendProvider.overrideWithValue(false),
          runTimeProvider.overrideWith(_Running.new),
          outboundIpProbeProvider.overrideWith(() => _Ips(both)),
          for (final ip in [_exitIp, _localIp])
            ipxLookupProvider(ip).overrideWith(_Ipx.new),
          ipQualityProvider.overrideWith((_, _) => Future.any(const [])),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = size;
      // As in use: the Core is up, so the header shows no failure.
      container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: UncontrolledProviderScope(
            container: container,
            child: Consumer(
              builder: (context, ref, _) => TestApp(
                locale: const Locale('zh', 'CN'),
                includeNavigatorKey: false,
                theme: watchAppTheme(ref, Brightness.light),
                darkTheme: watchAppTheme(ref, Brightness.dark),
                themeMode: ThemeMode.light,
                child: const HostScaffold(
                  body: DashboardView(platform: SupportPlatform.MacOS),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await capture(tester, 'dashboard-full-$name-light');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 11));
    });
  }
}
