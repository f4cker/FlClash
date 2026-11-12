// Renders the setting-source dialog and rows to PNG for review. Off by
// default:
//   PAGE_SOURCE_SCREENSHOTS=<dir> flutter test test/views/page_source_screenshots_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/host_scaffold.dart';
import '../helpers/preferences.dart';
import '../helpers/test_app.dart';

final _outDir = Platform.environment['PAGE_SOURCE_SCREENSHOTS'];
const _cjkCollection = '/System/Library/Fonts/Hiragino Sans GB.ttc';
const _ratio = 1568 / 1054;

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

const PagePriorityChanges _fixtureChanges = (
  pageRows: [
    PageSourceRow(
      key: PageConfigKey.tunEnable,
      pageValue: true,
      fileValue: false,
    ),
    PageSourceRow(
      key: PageConfigKey.logLevel,
      pageValue: 'error',
      fileValue: 'silent',
    ),
    PageSourceRow(
      key: PageConfigKey.findProcessMode,
      pageValue: 'off',
      fileValue: 'always',
    ),
    PageSourceRow(
      key: PageConfigKey.mixedPort,
      pageValue: 7890,
      fileValue: 7893,
    ),
    PageSourceRow(
      key: PageConfigKey.allowLan,
      pageValue: true,
      fileValue: configKeyMissing,
    ),
  ],
  hiddenRows: [
    HiddenOverrideRow(
      path: 'profile.store-selected',
      oldValue: false,
      newValue: true,
    ),
    HiddenOverrideRow(
      path: 'skip-auth-prefixes',
      oldValue: [],
      newValue: ['127.0.0.1/8'],
    ),
    HiddenOverrideRow(
      path: 'tun.dns-hijack',
      oldValue: ['any:53'],
      newValue: configKeyMissing,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _outDir == null || _outDir!.isEmpty
      ? 'set PAGE_SOURCE_SCREENSHOTS to an output directory'
      : null;
  final boundary = GlobalKey();

  setUpAll(() async {
    if (skip != null) {
      return;
    }
    WidgetsApp.debugAllowBannerOverride = false;
    final loader = FontLoader('Roboto');
    for (final face in _collectionFaces(
      File(_cjkCollection).readAsBytesSync(),
    )) {
      loader.addFont(Future.value(face));
    }
    await loader.load();
    Directory(_outDir!).createSync(recursive: true);
  });
  tearDownAll(() => WidgetsApp.debugAllowBannerOverride = true);

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required Size size,
    required Widget child,
    void Function(ProviderContainer container)? prepare,
  }) async {
    await mockPreferences();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    prepare?.call(container);
    container.read(viewSizeProvider.notifier).update((_) => size);
    tester.view.physicalSize = size * _ratio;
    tester.view.devicePixelRatio = _ratio;
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
              child: HostScaffold(body: child),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: _ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File('$_outDir/$name.png').writeAsBytes(data!.buffer.asUint8List());
    });
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('01-dialog', skip: skip != null, (tester) async {
    await shoot(
      tester,
      '01-dialog',
      size: const Size(1054, 980),
      child: Center(
        child: AlertDialog(
          title: '确认设置来源',
          actions: [
            TextButton(onPressed: () {}, child: const Text('取消')),
            TextButton(onPressed: () {}, child: const Text('应用')),
          ],
          child: const PageSourceRows(changes: _fixtureChanges, choices: {}),
        ),
      ),
    );
  });

  testWidgets('02-rows', skip: skip != null, (tester) async {
    await shoot(
      tester,
      '02-rows',
      size: const Size(1054, 300),
      prepare: (container) {
        container
            .read(patchClashConfigProvider.notifier)
            .value = const PatchClashConfig(
          tun: Tun(enable: true),
          followKeys: {PageConfigKey.tunEnable},
        );
        container.read(profileSettingsProvider.notifier).value = const {
          'log-level': 'silent',
          'tun': {'enable': false, 'stack': 'mixed'},
        };
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: generateSection(
          title: '页面设置与基础配置',
          items: const [LogLevelItem(), TUNItem()],
        ),
      ),
    );
  });
}
