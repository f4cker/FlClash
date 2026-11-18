// Renders the grouped sidebar and the dashboard's status card to PNG for
// review, light and dark. Off by default:
//   NAV_IPCARD_SCREENSHOTS=<dir> flutter test \
//     test/views/nav_ipcard_screenshots_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/common/service_probe.dart'
    show directOutbound, routedOutbound;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/app_manager.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/ipx_report.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/widgets/current_outbound.dart';
import 'package:fl_clash/views/navigation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';

final _outDir = Platform.environment['NAV_IPCARD_SCREENSHOTS'];
const _cjkCollection = '/System/Library/Fonts/Hiragino Sans GB.ttc';
const _emojiCollection = '/System/Library/Fonts/Apple Color Emoji.ttc';

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

const _exitIp = '185.220.101.1';
const _localIp = '58.152.33.18';

const _report = IpxReport(
  ip: _exitIp,
  score: 35,
  type: IpxIpType.hosting,
  nativity: IpxNativity.native,
  countryCode: 'DE',
  city: 'Brandenburg',
  organization: 'TORSERVERS-NET',
);

const _directReport = IpxReport(
  ip: _localIp,
  score: 88,
  type: IpxIpType.residential,
  nativity: IpxNativity.native,
  countryCode: 'HK',
  city: 'Hong Kong',
  organization: 'HKBN',
);

class _Ips extends OutboundIpProbe {
  _Ips(this.entries);

  final Map<String, ProbeEntry<IpInfo>> entries;

  @override
  RoutedProbeState<String, IpInfo> build() => RoutedProbeState(entries);

  @override
  void watch(String target) {}

  @override
  void unwatch(String target) {}
}

class _Ipx extends IpxLookup {
  @override
  IpxLookupState build(String ip) => IpxLookupState(
    phase: IpxPhase.done,
    report: ip == _exitIp ? _report : _directReport,
  );

  @override
  void reload() {}
}

/// ipx.al gave nothing back about the address.
class _IpxFailed extends IpxLookup {
  @override
  IpxLookupState build(String ip) =>
      const IpxLookupState(phase: IpxPhase.failed);

  @override
  void reload() {}
}

class _Running extends RunTime {
  @override
  int? build() => (2 * 3600 + 14 * 60 + 5) * 1000;
}

ProbeEntry<IpInfo> _fresh(String ip, String country) => ProbeEntry(
  phase: ProbePhase.fresh,
  value: IpInfo(ip: ip, countryCode: country),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _outDir == null || _outDir!.isEmpty
      ? 'set NAV_IPCARD_SCREENSHOTS to an output directory'
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
    // The flag before the exit's place.
    final emoji = FontLoader('Apple Color Emoji');
    for (final face in _collectionFaces(
      File(_emojiCollection).readAsBytesSync(),
    )) {
      emoji.addFont(Future.value(face));
    }
    await emoji.load();
    await (FontLoader('JetBrainsMono')..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/JetBrainsMono-Regular.ttf').readAsBytesSync(),
            ),
          ),
        ))
        .load();
    Directory(_outDir!).createSync(recursive: true);
  });

  setUp(() {
    mitmFeature = true;
    navigationPort = navigation;
    addTearDown(() {
      mitmFeature = false;
      navigationPort = null;
    });
  });

  Future<void> settle(WidgetTester tester, [int frames = 8]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

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

  // The test has no system fallback to find the flag's glyphs in.
  ThemeData withEmoji(ThemeData theme) => theme.copyWith(
    fontFamilyFallback: [...?theme.fontFamilyFallback, 'Apple Color Emoji'],
  );

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget child, {
    required Brightness brightness,
    required Size size,
    List<Override> overrides = const [],
    void Function(ProviderContainer container)? prepare,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    globalState.container = container;
    container.listen(patchClashConfigProvider, (_, _) {});
    // Desktop width, so the sidebar shows, though only its strip is drawn.
    container.read(viewSizeProvider.notifier).value = Size(1200, size.height);
    prepare?.call(container);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => TestApp(
              locale: const Locale('zh', 'CN'),
              includeNavigatorKey: false,
              theme: withEmoji(watchAppTheme(ref, Brightness.light)),
              darkTheme: withEmoji(watchAppTheme(ref, Brightness.dark)),
              themeMode: brightness == Brightness.light
                  ? ThemeMode.light
                  : ThemeMode.dark,
              child: child,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return container;
  }

  List<Override> sidebarOverrides() => [
    navigationItemsStateProvider.overrideWith(
      (_) => NavigationItemsState(
        value: navigation.getItems(
          openLogs: true,
          hasProxies: true,
          showRules: true,
        ),
      ),
    ),
    navigationBadgesProvider.overrideWithValue(const {
      PageLabel.resources: SidebarBadge(count: 2),
      PageLabel.mitmRewrite: SidebarBadge(error: true),
      PageLabel.mitmScripts: SidebarBadge(count: 3),
      PageLabel.mitmModules: SidebarBadge(count: 1),
    }),
  ];

  void decrypting(ProviderContainer container) => container
      .read(patchClashConfigProvider.notifier)
      .update(
        (state) => state.copyWith(mitm: state.mitm.copyWith(enable: true)),
      );

  const sidebarSize = Size(300, 820);
  const sidebar = HostScaffold(
    body: AppSidebarContainer(child: SizedBox.expand()),
  );

  Widget card() => const HostScaffold(
    body: Padding(
      padding: EdgeInsets.all(20),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 600,
          height: 176,
          child: DashboardDensityScope(
            density: DashboardDensity.standard,
            scale: 1,
            child: CurrentOutboundCard(),
          ),
        ),
      ),
    ),
  );

  List<Override> cardOverrides(
    Map<String, ProbeEntry<IpInfo>> entries, {
    bool running = true,
    bool reportFailed = false,
  }) => [
    profilesProvider.overrideWithValue(const [
      Profile(id: 1, autoUpdateDuration: Duration.zero),
    ]),
    suspendProvider.overrideWithValue(false),
    if (running) runTimeProvider.overrideWith(_Running.new),
    outboundIpProbeProvider.overrideWith(() => _Ips(entries)),
    for (final ip in [_exitIp, _localIp])
      ipxLookupProvider(
        ip,
      ).overrideWith(reportFailed ? _IpxFailed.new : _Ipx.new),
    ipQualityProvider.overrideWith((_, _) => Future.any(const [])),
  ];

  for (final brightness in Brightness.values) {
    final tone = brightness == Brightness.light ? 'light' : 'dark';

    testWidgets('sidebar-expanded-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        sidebar,
        brightness: brightness,
        size: sidebarSize,
        overrides: sidebarOverrides(),
        prepare: decrypting,
      );
      await capture(tester, 'sidebar-expanded-$tone');
    });

    testWidgets('sidebar-collapsed-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        sidebar,
        brightness: brightness,
        size: sidebarSize,
        overrides: sidebarOverrides(),
        prepare: (container) => container
            .read(appSettingProvider.notifier)
            .update(
              (state) => state.copyWith(
                sidebarCollapsedGroups: const {
                  'routing': true,
                  'decryption': true,
                  'debug': true,
                },
              ),
            ),
      );
      await capture(tester, 'sidebar-collapsed-$tone');
    });

    testWidgets('sidebar-narrow-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        sidebar,
        brightness: brightness,
        size: sidebarSize,
        overrides: sidebarOverrides(),
        prepare: (container) {
          decrypting(container);
          container
              .read(appSettingProvider.notifier)
              .update((state) => state.copyWith(sidebarExpanded: false));
        },
      );
      await capture(tester, 'sidebar-narrow-$tone');
    });

    testWidgets('card-normal-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        card(),
        brightness: brightness,
        size: const Size(640, 216),
        overrides: cardOverrides({
          routedOutbound: _fresh(_exitIp, 'DE'),
          directOutbound: _fresh(_localIp, 'HK'),
        }),
      );
      await capture(tester, 'card-normal-$tone');
    });

    testWidgets('card-same-as-exit-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        card(),
        brightness: brightness,
        size: const Size(640, 216),
        overrides: cardOverrides({
          routedOutbound: _fresh(_localIp, 'HK'),
          directOutbound: _fresh(_localIp, 'HK'),
        }),
      );
      await capture(tester, 'card-same-as-exit-$tone');
    });

    testWidgets('card-lookup-failed-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        card(),
        brightness: brightness,
        size: const Size(640, 216),
        overrides: cardOverrides({
          routedOutbound: const ProbeEntry(phase: ProbePhase.failed),
          directOutbound: const ProbeEntry(phase: ProbePhase.failed),
        }),
      );
      await capture(tester, 'card-lookup-failed-$tone');
    });

    testWidgets('card-report-failed-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        card(),
        brightness: brightness,
        size: const Size(640, 216),
        overrides: cardOverrides({
          routedOutbound: _fresh(_exitIp, 'DE'),
          directOutbound: _fresh(_localIp, 'HK'),
        }, reportFailed: true),
      );
      await capture(tester, 'card-report-failed-$tone');
    });

    testWidgets('sidebar-themed-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        sidebar,
        brightness: brightness,
        size: sidebarSize,
        overrides: [
          ...sidebarOverrides(),
          themeSettingProvider.overrideWithBuild(
            (_, _) => const ThemeProps(primaryColor: 0xFF34C759),
          ),
        ],
        // One group closed beside open ones: the heading's badge and the
        // rows' on one line, all in the theme's green.
        prepare: (container) {
          decrypting(container);
          container
              .read(appSettingProvider.notifier)
              .update(
                (state) => state.copyWith(
                  sidebarCollapsedGroups: const {
                    'routing': true,
                    'decryption': false,
                    'debug': true,
                  },
                ),
              );
        },
      );
      await capture(tester, 'sidebar-themed-$tone');
    });

    testWidgets('card-not-running-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        card(),
        brightness: brightness,
        size: const Size(640, 216),
        overrides: cardOverrides({
          routedOutbound: _fresh(_localIp, 'HK'),
          directOutbound: _fresh(_localIp, 'HK'),
        }, running: false),
      );
      await capture(tester, 'card-not-running-$tone');
    });

    testWidgets('card-loading-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        card(),
        brightness: brightness,
        size: const Size(640, 216),
        overrides: cardOverrides({
          routedOutbound: const ProbeEntry(phase: ProbePhase.probing),
          directOutbound: const ProbeEntry(phase: ProbePhase.probing),
        }),
      );
      await capture(tester, 'card-loading-$tone');
    });
  }
}
