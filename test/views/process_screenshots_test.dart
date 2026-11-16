// Renders the request list and detail with process info to PNG for review.
// Off by default:
//   PROCESS_SCREENSHOTS=<dir> flutter test test/views/process_screenshots_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/host_scaffold.dart';
import '../helpers/preferences.dart';
import '../helpers/test_app.dart';

final _outDir = Platform.environment['PROCESS_SCREENSHOTS'];
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

Future<void> _loadFont(String family, List<ByteData> fonts) async {
  final loader = FontLoader(family);
  for (final font in fonts) {
    loader.addFont(Future.value(font));
  }
  await loader.load();
}

/// A stand-in app icon: a rounded tile, not any real app's artwork.
Future<Uint8List> _placeholderIcon({
  Color top = const Color(0xFF5B8DEF),
  Color bottom = const Color(0xFF2F5BD3),
}) async {
  const side = 64.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final tile = RRect.fromRectAndRadius(
    const Rect.fromLTWH(4, 4, side - 8, side - 8),
    const Radius.circular(13),
  );
  canvas.drawRRect(
    tile,
    Paint()
      ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(0, side), [
        top,
        bottom,
      ]),
  );
  canvas.drawCircle(
    const Offset(side / 2, side / 2),
    14,
    Paint()..color = const Color(0xFFFFFFFF),
  );
  final image = await recorder.endRecording().toImage(64, 64);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

const _browserHelper =
    '/Applications/Example Browser.app/Contents/Frameworks/Example Browser '
    'Framework.framework/Helpers/Example Browser Helper.app/Contents/MacOS/'
    'Example Browser Helper';

TrackerInfo _info(String id, String host, Metadata metadata, int minute) =>
    TrackerInfo(
      id: id,
      start: DateTime(2026, 11, 12, 15, minute, 8),
      metadata: metadata.copyWith(
        network: 'tcp',
        host: host,
        destinationIP: '203.0.113.${10 + minute}',
        destinationPort: '443',
      ),
      chains: const ['Node A', 'Proxy'],
      rule: 'DOMAIN-SUFFIX',
      rulePayload: host,
      upload: 2048,
      download: 81920,
    );

final _app = _info(
  'a',
  'www.example.com',
  const Metadata(
    process: 'Example Browser Helper',
    processPath: _browserHelper,
    sourceIP: '127.0.0.1',
    sourcePort: '51234',
  ),
  1,
);
final _cli = _info(
  'b',
  'git.example.net',
  const Metadata(
    process: 'ssh',
    processPath: '/usr/bin/ssh',
    sourceIP: '127.0.0.1',
    sourcePort: '50022',
  ),
  2,
);
final _unknown = _info(
  'c',
  'api.example.org',
  const Metadata(sourceIP: '198.18.0.1', sourcePort: '50100'),
  3,
);

const _apsd =
    '/System/Library/PrivateFrameworks/ApplePushService.framework/apsd';
const _uuHelper = '/Library/PrivilegedHelperTools/com.example.vpn.helper';

final _push = _info(
  'd',
  'courier.push.apple.com',
  const Metadata(process: 'apsd', processPath: _apsd, sourceIP: '127.0.0.1'),
  4,
);
final _downloads = _info(
  'e',
  'swcdn.apple.com',
  const Metadata(
    process: 'nsurlsessiond',
    processPath: '/usr/libexec/nsurlsessiond',
    sourceIP: '127.0.0.1',
  ),
  5,
);
final _daemon = _info(
  'f',
  'api.example.net',
  const Metadata(
    process: 'com.example.vpn.helper',
    processPath: _uuHelper,
    sourceIP: '127.0.0.1',
  ),
  6,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _outDir == null || _outDir!.isEmpty
      ? 'set PROCESS_SCREENSHOTS to an output directory'
      : null;
  late ProviderContainer container;
  late ProcessApps previous;
  Uint8List? icon;
  Uint8List? featureIcon;
  Uint8List? daemonIcon;

  setUpAll(() async {
    if (skip != null) {
      return;
    }
    await _loadFont(
      'Roboto',
      _collectionFaces(File(_cjkCollection).readAsBytesSync()),
    );
    await _loadFont('JetBrainsMono', [
      ByteData.sublistView(
        File('assets/fonts/JetBrainsMono-Regular.ttf').readAsBytesSync(),
      ),
    ]);
    Directory(_outDir!).createSync(recursive: true);
  });

  setUp(() async {
    await mockPreferences();
    container = ProviderContainer();
    globalState.container = container;
    previous = processApps;
  });

  tearDown(() {
    processApps.dispose();
    processApps = previous;
    container.dispose();
  });

  final boundary = GlobalKey();

  Future<void> seed(WidgetTester tester) async {
    icon ??= await tester.runAsync(_placeholderIcon);
    featureIcon ??= await tester.runAsync(
      () => _placeholderIcon(
        top: const Color(0xFFFF6B6B),
        bottom: const Color(0xFFE03131),
      ),
    );
    daemonIcon ??= await tester.runAsync(
      () => _placeholderIcon(
        top: const Color(0xFF63E6BE),
        bottom: const Color(0xFF0CA678),
      ),
    );
    processApps = ProcessApps(
      lookupApps: true,
      invoke: (_) async => null,
      readLocalAddresses: () async => {'127.0.0.1', '198.18.0.1'},
    );
    processApps.seed(
      lookups: {
        _browserHelper: AppLookup.app(
          MacApp(
            bundleId: 'com.example.browser',
            name: 'Example Browser',
            bundlePath: '/Applications/Example Browser.app',
            icon: icon,
          ),
        ),
        '/usr/bin/ssh': AppLookup.none,
        _apsd: AppLookup.service(
          ServiceMatch(SystemService.pushNotifications, icon: featureIcon),
        ),
        '/usr/libexec/nsurlsessiond': const AppLookup.service(
          ServiceMatch(SystemService.backgroundDownloads),
        ),
        _uuHelper: AppLookup.app(
          MacApp(
            bundleId: 'com.example.vpn',
            name: 'Example VPN',
            bundlePath: '/Applications/Example VPN.app',
            icon: daemonIcon,
            launchdLabel: 'com.example.vpn.helper',
          ),
        ),
      },
      local: {'127.0.0.1', '198.18.0.1'},
    );
  }

  Future<void> pump(WidgetTester tester, Size size, Widget child) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => TestApp(
              locale: const Locale('zh', 'CN'),
              theme: watchAppTheme(ref, Brightness.light),
              darkTheme: watchAppTheme(ref, Brightness.dark),
              themeMode: ThemeMode.light,
              homeBuilder: (child) => HostScaffold(body: child),
              child: child,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final element = tester.element(find.byType(HostScaffold));
    await tester.runAsync(() async {
      for (final image in find.byType(Image).evaluate()) {
        final provider = (image.widget as Image).image;
        await precacheImage(provider, element);
      }
    });
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> shoot(WidgetTester tester, String name) async {
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
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('01-list', (tester) async {
    await seed(tester);
    await pump(
      tester,
      const Size(520, 420),
      SizedBox(
        width: 520,
        height: 420,
        child: TrackerInfoList(
          padding: const EdgeInsets.all(16),
          trackerInfos: [_app, _cli, _unknown],
          detailTitle: '请求详情',
        ),
      ),
    );
    await shoot(tester, '01-list');
  }, skip: skip != null);

  testWidgets('02-detail-app', (tester) async {
    await seed(tester);
    await pump(
      tester,
      const Size(480, 760),
      SizedBox(
        width: 480,
        height: 760,
        child: SheetProvider(
          type: SheetType.page,
          child: TrackerInfoDetailView(trackerInfo: _app),
        ),
      ),
    );
    await shoot(tester, '02-detail-app');
  }, skip: skip != null);

  testWidgets('03-table', (tester) async {
    await seed(tester);
    await pump(
      tester,
      const Size(1000, 260),
      SizedBox(
        width: 1000,
        height: 260,
        child: Builder(
          builder: (context) => RecordTableFrame<TrackerInfo>(
            tableId: 'process-shot',
            items: [_app, _cli, _unknown],
            columnsOf: (width) =>
                trackerInfoColumns(context, width: width, isLive: false),
            builder: (context, table, items) => TrackerInfoList(
              trackerInfos: items,
              table: table,
              detailTitle: '请求详情',
            ),
          ),
        ),
      ),
    );
    await shoot(tester, '03-table');
  }, skip: skip != null);

  testWidgets('04-sources', (tester) async {
    await seed(tester);
    await pump(
      tester,
      const Size(560, 720),
      SizedBox(
        width: 560,
        height: 720,
        child: TrackerInfoList(
          padding: const EdgeInsets.all(16),
          trackerInfos: [_app, _push, _downloads, _daemon, _cli, _unknown],
          detailTitle: '请求详情',
        ),
      ),
    );
    await shoot(tester, '04-sources');
  }, skip: skip != null);

  testWidgets('05-detail-service', (tester) async {
    await seed(tester);
    await pump(
      tester,
      const Size(480, 760),
      SizedBox(
        width: 480,
        height: 760,
        child: SheetProvider(
          type: SheetType.page,
          child: TrackerInfoDetailView(trackerInfo: _downloads),
        ),
      ),
    );
    await shoot(tester, '05-detail-service');
  }, skip: skip != null);

  testWidgets('06-table-sources', (tester) async {
    await seed(tester);
    await pump(
      tester,
      const Size(1000, 330),
      SizedBox(
        width: 1000,
        height: 330,
        child: Builder(
          builder: (context) => RecordTableFrame<TrackerInfo>(
            tableId: 'process-shot-sources',
            items: [_app, _push, _downloads, _daemon, _unknown],
            columnsOf: (width) =>
                trackerInfoColumns(context, width: width, isLive: false),
            builder: (context, table, items) => TrackerInfoList(
              trackerInfos: items,
              table: table,
              detailTitle: '请求详情',
            ),
          ),
        ),
      ),
    );
    await shoot(tester, '06-table-sources');
  }, skip: skip != null);
}
