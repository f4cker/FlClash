// Renders the dashboard's status card to PNG for review, light and dark,
// in each of its states. Off by default:
//   STATUS_CARD_SCREENSHOTS=<dir> flutter test \
//     test/views/status_card_screenshots_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/ipx_al.dart';
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
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/widgets/current_outbound.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';

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

ProbeEntry<IpInfo> _fresh(String ip, String country) => ProbeEntry(
  phase: ProbePhase.fresh,
  value: IpInfo(ip: ip, countryCode: country),
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
  }) async {
    tester.view.physicalSize = const Size(614, 226) * 2;
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
      outboundIpProbeProvider.overrideWith(() => ips),
      for (final ip in [_exitIp, _localIp])
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
              locale: const Locale('zh', 'CN'),
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
                  child: SizedBox(
                    width: 574,
                    child: IntrinsicHeight(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 160),
                        child: const DashboardDensityScope(
                          density: DashboardDensity.standard,
                          scale: 1,
                          child: CurrentOutboundCard(),
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
      await tester.tap(find.text(_exitIp));
      await settle(tester);
      await capture(tester, 'local-$tone');
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
      ips.settle(routedOutbound, const ProbeEntry(phase: ProbePhase.failed));
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
          routedOutbound: const ProbeEntry(phase: ProbePhase.failed),
          directOutbound: _fresh(_localIp, 'HK'),
        },
      );
      await capture(tester, 'lookup-failed-$tone');
    });

    testWidgets('not-running-$tone', skip: skip != null, (tester) async {
      await pump(tester, brightness: brightness, entries: both, running: false);
      await capture(tester, 'not-running-$tone');
    });
  }
}
