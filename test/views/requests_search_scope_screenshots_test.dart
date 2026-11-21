// Renders the recent requests searched, with the note on what the search
// covers, in Chinese, to PNG for review. Off by default:
//   HINTS_SHOTS=<dir> flutter test \
//     test/views/requests_search_scope_screenshots_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/connection/requests.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

final _outDir = Platform.environment['HINTS_SHOTS'];
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

TrackerInfo _tracker(int i) {
  final host = ['api.example.com', 'cdn.example.net', 'img.example.org'][i % 3];
  return TrackerInfo(
    id: '$i',
    upload: 1200 * i,
    download: 5400 * i,
    start: DateTime(2026, 11, 21, 10, 4, i % 60),
    metadata: Metadata(
      network: 'tcp',
      host: host,
      destinationIP: '203.0.113.${i % 200}',
      destinationPort: '443',
      process: i.isEven ? 'Safari' : 'curl',
    ),
    chains: const ['节点选择', 'HK 01'],
    rule: 'DOMAIN-SUFFIX',
    rulePayload: host,
  );
}

void main() {
  final skip = _outDir == null || _outDir!.isEmpty
      ? 'set HINTS_SHOTS to an output directory'
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
  });

  for (final (name, size) in [
    ('requests-search-scope-zh', const Size(900, 560)),
    ('requests-search-scope-zh-narrow', const Size(390, 640)),
  ]) {
    testWidgets(name, skip: skip != null, (tester) async {
      final container = ProviderContainer(
        overrides: [profilesProvider.overrideWith(TestProfiles.new)],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      final notifier = container.read(requestsProvider.notifier);
      notifier.value = FixedList<TrackerInfo>(500);
      for (var i = 0; i < 120; i++) {
        notifier.addRequest(_tracker(i));
      }
      container.read(viewSizeProvider.notifier).update((_) => size);
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
                child: const RequestsView(initialFeed: RequestFeed.recent),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byGlyph(AppGlyphs.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'api');
      await tester.pumpAndSettle();
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
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
