// Renders the exit IP detail with the ipx.al report to PNG for review.
// Off by default:
//   IPX_SCREENSHOTS=<dir> flutter test test/views/ipx_report_screenshots_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/ip_quality/ip_quality.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/ipx_report.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_paths.dart';
import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';

final _outDir = Platform.environment['IPX_SCREENSHOTS'];
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

String _fixture(String name) =>
    File('test/fixtures/ipx_al/$name').readAsStringSync();

/// What /api/me tells of the same address, as ipx.al's report has it.
String _brief(String report) {
  final json = jsonDecode(report) as Map<String, dynamic>;
  final location = json['location'] as Map<String, dynamic>;
  return jsonEncode({
    'ip': json['ip'],
    'country': location['country'],
    'city': location['city'],
    'asn': json['asn'],
    'org': json['org'],
  });
}

enum _Stage {
  loading('1-loading'),
  partial('2-partial'),
  full('3-full'),
  failure('4-failure'),
  // Retry tapped on the failure, ipx.al not yet answered.
  retrying('4b-retrying');

  const _Stage(this.file);

  final String file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _outDir == null || _outDir!.isEmpty
      ? 'set IPX_SCREENSHOTS to an output directory'
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
    await (FontLoader('JetBrainsMono')..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/JetBrainsMono-Regular.ttf').readAsBytesSync(),
            ),
          ),
        ))
        .load();
    Directory(_outDir!).createSync(recursive: true);
    await useAppPaths(Directory.systemTemp.createTempSync('ipx_shots'));
  });

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required IpQuality quality,
    required String report,
    required String countryCode,
    required _Stage stage,
    Brightness brightness = Brightness.light,
    Size size = const Size(1100, 1400),
  }) async {
    final ip = quality.ip;
    var reportCalls = 0;
    Future<IpxAnswer?> fetch(String url, {required timeout, maxBody}) {
      if (url == ipxAlMeUrl) {
        return stage == _Stage.loading
            ? Completer<IpxAnswer?>().future
            : Future.value(IpxAnswer(_brief(_fixture(report))));
      }
      reportCalls++;
      return switch (stage) {
        _Stage.full => Future.value(
          IpxAnswer(_fixture(report), viaProxy: true),
        ),
        _Stage.failure => Future.value(null),
        _Stage.retrying when reportCalls == 1 => Future.value(null),
        _ => Completer<IpxAnswer?>().future,
      };
    }

    final container = ProviderContainer(
      overrides: [
        ipQualityProvider.overrideWith((_, _) async => quality),
        ipxFetchProvider.overrideWithValue(fetch),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
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
              locale: const Locale('zh', 'CN'),
              theme: watchAppTheme(ref, Brightness.light),
              darkTheme: watchAppTheme(ref, Brightness.dark),
              themeMode: brightness == Brightness.light
                  ? ThemeMode.light
                  : ThemeMode.dark,
              child: HostScaffold(
                body: Builder(
                  builder: (context) => GestureDetector(
                    onTap: () => showIpQualitySheet(
                      context,
                      ip: ip,
                      countryCode: countryCode,
                    ),
                    child: const SizedBox(
                      width: 100,
                      height: 40,
                      child: Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (stage == _Stage.retrying) {
      await tester.tap(find.text('重试'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
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

  const tor = IpQuality(
    ip: '185.220.101.1',
    source: IpQualitySource.ipQuery,
    type: IpType.hosting,
    organization: 'TORSERVERS-NET Stiftung Erneuerbare Freiheit',
    asn: 60729,
    isTor: true,
  );
  const google = IpQuality(
    ip: '8.8.8.8',
    source: IpQualitySource.ipApiCom,
    type: IpType.hosting,
    organization: 'Google LLC',
    asn: 15169,
  );
  for (final brightness in Brightness.values) {
    final theme = brightness.name;
    for (final stage in _Stage.values) {
      testWidgets('$theme-${stage.name}', skip: skip != null, (tester) async {
        await shoot(
          tester,
          'ipx-$theme-${stage.file}',
          quality: tor,
          report: 'report_185.220.101.1.json',
          countryCode: 'DE',
          stage: stage,
          brightness: brightness,
        );
      });
    }
    testWidgets('$theme-full-hosting', skip: skip != null, (tester) async {
      await shoot(
        tester,
        'ipx-$theme-5-full-hosting',
        quality: google,
        report: 'report_8.8.8.8.json',
        countryCode: 'US',
        stage: _Stage.full,
        brightness: brightness,
      );
    });
  }
}
