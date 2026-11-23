// Renders the decryption status in a page bar to PNG for review.
// Off by default:
//   MITM_STATUS_SCREENSHOTS=<dir> flutter test \
//     test/views/mitm_status_screenshots_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_body.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/mitm_status.dart';
import 'package:fl_clash/views/connection/requests.dart';
import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_paths.dart';
import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

final _outDir = Platform.environment['MITM_STATUS_SCREENSHOTS'];
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _outDir == null || _outDir!.isEmpty
      ? 'set MITM_STATUS_SCREENSHOTS to an output directory'
      : null;
  late ProviderContainer container;
  final boundary = GlobalKey();

  setUpAll(() async {
    if (skip != null) return;
    WidgetsApp.debugAllowBannerOverride = false;
    final cjk = _collectionFaces(File(_cjkCollection).readAsBytesSync());
    // Body text is JetBrains Mono, falling back to the CJK family.
    for (final family in ['Roboto', 'PingFang SC']) {
      final loader = FontLoader(family);
      for (final face in cjk) {
        loader.addFont(Future.value(face));
      }
      await loader.load();
    }
    await (FontLoader('JetBrainsMono')..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/JetBrainsMono-Regular.ttf').readAsBytesSync(),
            ),
          ),
        ))
        .load();
    Directory(_outDir!).createSync(recursive: true);
    await useAppPaths(Directory.systemTemp.createTempSync('mitm_shots'));
  });

  setUp(() {
    container = ProviderContainer();
    globalState.container = container;
  });

  tearDown(() => container.dispose());

  Future<void> shoot(
    WidgetTester tester,
    String name,
    MitmIndicator indicator, {
    Size size = const Size(900, 200),
    Locale locale = const Locale('zh', 'CN'),
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(viewSizeProvider.notifier).value = size;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => TestApp(
              locale: locale,
              theme: watchAppTheme(ref, Brightness.light),
              darkTheme: watchAppTheme(ref, Brightness.dark),
              themeMode: brightness == Brightness.light
                  ? ThemeMode.light
                  : ThemeMode.dark,
              child: ScaffoldBarStatus(
                status: MitmStatusCapsule(
                  indicator: indicator,
                  onPressed: () {},
                ),
                child: Scaffold(
                  title: '代理',
                  actions: [
                    AppBarActionButton(
                      data: IconButtonData(
                        glyph: AppGlyphs.edit,
                        tooltip: '',
                        onPressed: () {},
                      ),
                    ),
                  ],
                  body: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(
        pixelRatio: tester.view.devicePixelRatio,
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File('$_outDir/$name.png').writeAsBytes(data!.buffer.asUint8List());
    });
  }

  const shots = {
    '01-decrypting': MitmIndicator.decrypting(),
    '01b-on': MitmIndicator.on(),
    '02-paused-indicator': MitmIndicator.paused(
      MitmPauseReason.indicatorPending,
    ),
    '03-paused-liveness': MitmIndicator.paused(MitmPauseReason.liveness),
    '04-paused-not-trusted': MitmIndicator.paused(MitmPauseReason.notTrusted),
    '05-paused-core-identity': MitmIndicator.paused(
      MitmPauseReason.coreIdentity,
    ),
    '06-paused-core-stopped': MitmIndicator.paused(MitmPauseReason.coreStopped),
    '07-unconfirmed': MitmIndicator.unconfirmed(),
    '20-paused-app-unavailable': MitmIndicator.paused(
      MitmPauseReason.appUnavailable,
    ),
    '20b-paused-sign-timeout': MitmIndicator.paused(
      MitmPauseReason.signTimeout,
    ),
    '20c-paused-leaf-unusable': MitmIndicator.paused(
      MitmPauseReason.leafUnusable,
    ),
  };
  for (final MapEntry(key: name, value: indicator) in shots.entries) {
    testWidgets(name, skip: skip != null, (tester) async {
      await shoot(tester, name, indicator);
    });
  }

  testWidgets('08-narrow-decrypting', skip: skip != null, (tester) async {
    await shoot(
      tester,
      '08-narrow-decrypting',
      const MitmIndicator.decrypting(),
      size: const Size(600, 200),
    );
  });

  // The request detail the capture fills: a decrypted connection's
  // requests, then one of them with its decoded response.
  testWidgets('10-requests-and-detail', skip: skip != null, (tester) async {
    const size = Size(900, 700);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final start = DateTime(2026, 11, 16, 21, 4, 5);
    final connection = TrackerInfo(
      id: 'connection-1',
      start: start,
      metadata: const Metadata(
        network: 'tcp',
        host: 'api.example.com',
        mitm: true,
      ),
      chains: const ['DIRECT'],
      rule: 'MATCH',
      rulePayload: '',
    );
    final exchange = MitmExchange(
      id: 7,
      start: start,
      duration: 182,
      ttfb: 96,
      method: 'POST',
      url: 'https://api.example.com/v1/items?page=2',
      proto: 'HTTP/1.1',
      status: 201,
      requestSize: 27,
      responseSize: 61,
      connection: connection.id,
      requestHeader: const {
        'Host': ['api.example.com'],
        'Content-Type': ['application/json'],
        'Content-Length': ['27'],
      },
      responseHeader: const {
        'Content-Type': ['application/json; charset=utf-8'],
        'Content-Encoding': ['gzip'],
      },
    );
    MitmExchangeSummary summary(MitmExchange e) => MitmExchangeSummary(
      id: e.id,
      start: e.start,
      duration: e.duration,
      method: e.method,
      url: e.url,
      status: e.status,
      requestSize: e.requestSize,
      responseSize: e.responseSize,
    );
    final list = MitmExchangeList(
      capturing: true,
      since: start,
      exchanges: [
        summary(exchange),
        summary(
          exchange.copyWith(
            id: 8,
            method: 'GET',
            url: 'https://api.example.com/v1/me',
            status: 200,
            duration: 64,
          ),
        ),
        MitmExchangeSummary(
          id: 9,
          start: start,
          method: 'GET',
          url: 'https://api.example.com/v1/feed',
          error: 'responseFailed',
          status: 200,
        ),
      ],
    );
    const contentType = 'application/json; charset=utf-8';
    final body = MitmBody(
      data: base64.encode(
        utf8.encode('{"id":42,"name":"示例","tags":["a","b"]}'),
      ),
    );
    final detail = ProviderContainer(
      overrides: [
        mitmExchangesProvider(connection.id).overrideWith((ref) async => list),
        mitmExchangeProvider(7).overrideWith((ref) async => exchange),
        mitmBodyProvider(
          7,
          response: true,
          contentType: contentType,
        ).overrideWith(
          (ref) async =>
              readMitmBody((body, contentType, grpcOverLimitNote: null)),
        ),
      ],
    );
    addTearDown(detail.dispose);
    globalState.container = detail;
    detail.listen(patchClashConfigProvider, (_, _) {});
    detail.read(viewSizeProvider.notifier).value = size;
    detail.read(patchClashConfigProvider.notifier).value =
        const PatchClashConfig(mitm: Mitm(enable: true, capture: true));
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: UncontrolledProviderScope(
          container: detail,
          child: Consumer(
            builder: (context, ref, _) => TestApp(
              locale: const Locale('zh', 'CN'),
              theme: watchAppTheme(ref, Brightness.light),
              themeMode: ThemeMode.light,
              homeBuilder: (child) => HostScaffold(body: child),
              child: SheetProvider(
                type: SheetType.page,
                child: TrackerInfoDetailView(trackerInfo: connection),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await File(
          '$_outDir/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
      });
    }

    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedControl<int>).last,
        matching: find.text(currentAppLocalizations.httpRequests),
      ),
    );
    await tester.pumpAndSettle();
    await capture('10-requests');
    await tester.tap(find.textContaining('/v1/items').first);
    await tester.pumpAndSettle();
    await capture('11-request-detail');
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedControl<int>).last,
        matching: find.text(currentAppLocalizations.response),
      ),
    );
    await tester.pumpAndSettle();
    await capture('12-request-detail-body');
  });

  // Each listed host's row says what decryption did; the plain row has no
  // mark. Rows are in arrival order, newest first.
  Future<void> shootRequests(
    WidgetTester tester,
    String name,
    Size size, {
    Brightness brightness = Brightness.light,
    String? openHost,
    double pixelRatio = 2,
    int filler = 0,
    double scroll = 0,
  }) async {
    tester.view.physicalSize = size * pixelRatio;
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    addTearDown(requests.dispose);
    globalState.container = requests;
    requests.read(viewSizeProvider.notifier).value = size;
    final start = DateTime(2026, 11, 16, 21, 4, 5);
    TrackerInfo row(
      String id,
      String host,
      String process, {
      String outcome = '',
      String pauseReason = '',
      bool mitm = false,
      int seconds = 0,
    }) => TrackerInfo(
      id: id,
      start: start.add(Duration(seconds: seconds)),
      upload: 1200 + seconds * 97,
      download: 18000 + seconds * 3100,
      metadata: Metadata(
        network: 'tcp',
        host: host,
        destinationIP: '93.184.215.14',
        destinationPort: '443',
        process: process,
        mitm: mitm,
      ),
      chains: const ['DIRECT'],
      rule: 'DomainSuffix',
      rulePayload: host,
      mitmOutcome: outcome,
      mitmPauseReason: pauseReason,
    );
    final notifier = requests.read(requestsProvider.notifier);
    notifier.value = FixedList<TrackerInfo>(500);
    for (final request in [
      row('1', 'api.example.com', 'Safari', mitm: true),
      row('2', 'cdn.example.net', 'Safari', seconds: 1),
      row('3', 'bank.example.com', 'Bank', outcome: 'refused', seconds: 2),
      row(
        '4',
        'pay.example.com',
        'curl',
        outcome: 'paused',
        pauseReason: 'signTimeout',
        seconds: 3,
      ),
      row('5', 'img.example.com', 'Chrome', outcome: 'http2Only', seconds: 4),
      row('6', 'www.example.org', 'Chrome', seconds: 5),
      row(
        '7',
        'old.example.com',
        'curl',
        outcome: 'upstreamCertificate',
        seconds: 6,
      ),
      row('8', 'api.example.com', 'Safari', mitm: true, seconds: 7),
      for (var i = 0; i < filler; i++)
        row('${9 + i}', 'host$i.example.com', 'Safari', seconds: 8 + i),
    ]) {
      notifier.addRequest(request);
    }
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: UncontrolledProviderScope(
          container: requests,
          child: Consumer(
            builder: (context, ref, _) => TestApp(
              locale: const Locale('zh', 'CN'),
              theme: watchAppTheme(ref, Brightness.light),
              darkTheme: watchAppTheme(ref, Brightness.dark),
              themeMode: brightness == Brightness.light
                  ? ThemeMode.light
                  : ThemeMode.dark,
              child: const RequestsView(initialFeed: RequestFeed.recent),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (scroll != 0) {
      final pointer = TestPointer(1, PointerDeviceKind.mouse)
        ..hover(size.center(Offset.zero));
      await tester.sendEventToBinding(pointer.scroll(Offset(0, scroll)));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    if (openHost != null) {
      await tester.tap(find.textContaining(openHost, findRichText: true).first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File('$_outDir/$name.png').writeAsBytes(data!.buffer.asUint8List());
    });
  }

  // 13 at 4x, cropped to the rows afterwards (13b) so the glyphs read.
  testWidgets('13-request-badges-table-4x', skip: skip != null, (tester) async {
    await shootRequests(
      tester,
      '13-request-badges-table-4x',
      const Size(1300, 560),
      pixelRatio: 4,
    );
  });

  testWidgets('13-request-badges-table', skip: skip != null, (tester) async {
    await shootRequests(
      tester,
      '13-request-badges-table',
      const Size(1300, 560),
    );
  });

  testWidgets('14-request-badges-list', skip: skip != null, (tester) async {
    await shootRequests(
      tester,
      '14-request-badges-list',
      const Size(600, 1100),
    );
  });

  testWidgets('15-request-badges-list-dark', skip: skip != null, (
    tester,
  ) async {
    await shootRequests(
      tester,
      '15-request-badges-list-dark',
      const Size(600, 1100),
      brightness: Brightness.dark,
    );
  });

  testWidgets('16-request-detail-handshake', skip: skip != null, (
    tester,
  ) async {
    await shootRequests(
      tester,
      '16-request-detail-handshake',
      const Size(600, 1100),
      openHost: 'bank.example.com',
    );
  });

  testWidgets('21-request-detail-paused', skip: skip != null, (tester) async {
    await shootRequests(
      tester,
      '21-request-detail-paused',
      const Size(600, 1100),
      openHost: 'pay.example.com',
    );
  });

  // Scrolled under the title bar, for setting beside the rules page.
  testWidgets('17-requests-scrolled', skip: skip != null, (tester) async {
    await shootRequests(
      tester,
      '17-requests-scrolled',
      const Size(700, 640),
      pixelRatio: 1,
      filler: 40,
      scroll: 300,
    );
  });

  // The decryption bar on the dashboard, and the requests page without it.
  Future<void> shootPage(
    WidgetTester tester,
    String name,
    Widget page, {
    Size size = const Size(1220, 760),
  }) async {
    mitmFeature = true;
    addTearDown(() => mitmFeature = false);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scoped = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        mitmIndicatorProvider.overrideWithValue(
          const MitmIndicator.decrypting(),
        ),
      ],
    );
    addTearDown(scoped.dispose);
    globalState.container = scoped;
    scoped.read(viewSizeProvider.notifier).value = size;
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: UncontrolledProviderScope(
          container: scoped,
          child: Consumer(
            builder: (context, ref, _) => TestApp(
              locale: const Locale('zh', 'CN'),
              theme: watchAppTheme(ref, Brightness.light),
              darkTheme: watchAppTheme(ref, Brightness.dark),
              themeMode: ThemeMode.light,
              child: page,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File('$_outDir/$name.png').writeAsBytes(data!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('18-dashboard-with-bar', skip: skip != null, (tester) async {
    await shootPage(
      tester,
      '18-dashboard-with-bar',
      const DashboardView(platform: SupportPlatform.MacOS),
    );
  });

  testWidgets('19-requests-without-bar', skip: skip != null, (tester) async {
    await shootPage(
      tester,
      '19-requests-without-bar',
      const RequestsView(initialFeed: RequestFeed.recent),
    );
  });

  testWidgets('09-dark-en-paused', skip: skip != null, (tester) async {
    await shoot(
      tester,
      '09-dark-en-paused',
      const MitmIndicator.paused(MitmPauseReason.liveness),
      locale: const Locale('en'),
      brightness: Brightness.dark,
    );
  });
}
