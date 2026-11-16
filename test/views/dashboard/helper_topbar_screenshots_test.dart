// Renders the dashboard bar's helper capsule and popover to PNG for review.
// Off by default:
//   HELPER_TOPBAR_SCREENSHOTS=<dir> flutter test \
//     test/views/dashboard/helper_topbar_screenshots_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/widgets/live_status.dart';
import 'package:fl_clash/views/dashboard/widgets/mac_helper_status.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/desktop/macos_helper_install_test.dart'
    show InstallNative, makeMaintenance;
import '../../helpers/test_app.dart';

final _outDir = Platform.environment['HELPER_TOPBAR_SCREENSHOTS'];
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
      ? 'set HELPER_TOPBAR_SCREENSHOTS to an output directory'
      : null;
  late ProviderContainer container;
  late InstallNative native;
  late MacHelperMaintenance flow;
  final boundary = GlobalKey();

  setUpAll(() async {
    if (skip != null) return;
    // The debug banner would cover the Core button in the corner.
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

  setUp(() {
    container = ProviderContainer();
    globalState.container = container;
    container.listen(patchClashConfigProvider, (_, _) {});
    container.listen(networkSettingProvider, (_, _) {});
    native = InstallNative();
    flow = makeMaintenance(native);
  });

  tearDown(() {
    flow.dispose();
    container.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(900, 520),
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
              child: Scaffold(
                title: '仪表盘',
                actions: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MacHelperBarStatus(
                        maintenance: flow,
                        version: '0.9.15-dev.2 (2026111602)',
                      ),
                      LiveStatusButton(separateCore: true, maintenance: flow),
                    ],
                  ),
                ],
                body: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
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
  }

  /// Ends with the helper ready so the start-up wait timers clear.
  Future<void> finish(WidgetTester tester) async {
    native.state = 'enabled';
    await flow.recheck();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  const capsules = {
    '01-update': 'migrationRequired',
    '02-allow': 'notRegistered',
    '03-starting': 'unavailable',
    '04-not-ready': 'migrationIncomplete',
    '05-failed-check': 'signingRequired',
  };
  for (final MapEntry(key: name, value: code) in capsules.entries) {
    testWidgets(name, skip: skip != null, (tester) async {
      native.state = code;
      await flow.check();
      await pump(tester);
      await shoot(tester, name);
      await finish(tester);
    });
  }

  testWidgets('06-allow-popover', skip: skip != null, (tester) async {
    native.state = 'notRegistered';
    await flow.check();
    await pump(tester);
    await tester.tap(find.byType(MacHelperCapsule));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await shoot(tester, '06-allow-popover');
    await finish(tester);
  });

  testWidgets('07-ready-core-running', skip: skip != null, (tester) async {
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    native.state = 'enabled';
    await flow.check();
    await pump(tester);
    await shoot(tester, '07-ready-core-running');
    await tester.tap(find.byType(MacHelperCapsule));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await shoot(tester, '08-ready-helper-popover');
    await finish(tester);
  });

  testWidgets('09-narrow-allow', skip: skip != null, (tester) async {
    native.state = 'notRegistered';
    await flow.check();
    await pump(tester, size: const Size(600, 420));
    await shoot(tester, '09-narrow-allow');
    await finish(tester);
  });

  testWidgets('10-failed-check-dark-en', skip: skip != null, (tester) async {
    native.state = 'signingRequired';
    await flow.check();
    await pump(tester, locale: const Locale('en'), brightness: Brightness.dark);
    await tester.tap(find.byType(MacHelperCapsule));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await shoot(tester, '10-failed-check-dark-en');
    await finish(tester);
  });

  testWidgets('11-disabled-popover', skip: skip != null, (tester) async {
    native.statusAnswer = {
      'code': 'requiresApproval',
      'previouslyEnabled': true,
    };
    await flow.check();
    await pump(tester);
    await tester.tap(find.byType(MacHelperCapsule));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await shoot(tester, '11-disabled-popover');
    await finish(tester);
  });

  testWidgets('00-icon-closeup', skip: skip != null, (tester) async {
    // The helper glyph beside its neighbours, at 24, 17 and 13 points.
    await pump(tester, size: const Size(420, 140));
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: Container(
          color: const Color(0xFFFFFFFF),
          padding: const EdgeInsets.all(12),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                for (final size in [48.0, 24.0, 17.0])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      spacing: 16,
                      children: [
                        for (final (glyph, color) in [
                          (AppGlyphs.helperDaemon, const Color(0xFF8A5100)),
                          (AppGlyphs.helperDaemon, const Color(0xFFBA1A1A)),
                          (AppGlyphs.helperDaemon, const Color(0xFF1E7B34)),
                          (AppGlyphs.settings, const Color(0xFF1D1B20)),
                          (AppGlyphs.sync, const Color(0xFF1D1B20)),
                          (AppGlyphs.shieldAlert, const Color(0xFFBA1A1A)),
                        ])
                          GlyphIcon(glyph, size: size, color: color),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await shoot(tester, '00-icon-closeup');
  });
}
