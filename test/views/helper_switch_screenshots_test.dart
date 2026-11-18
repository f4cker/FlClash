// Renders the helper card while it switches to the new helper after an app
// update (and the "taking longer" card it falls back to) to PNG for review.
// Off by default:
//   HELPER_SWITCH_SCREENSHOTS=<dir> flutter test \
//     test/views/helper_switch_screenshots_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/test_app.dart';

final _outDir = Platform.environment['HELPER_SWITCH_SCREENSHOTS'];
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

final class _Native implements MacHelperNativeApi {
  Map<Object?, Object?> answer = const {};

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async => answer;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _outDir == null || _outDir!.isEmpty
      ? 'set HELPER_SWITCH_SCREENSHOTS to an output directory'
      : null;
  final boundary = GlobalKey();

  setUpAll(() async {
    if (skip != null) return;
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

  Future<void> shoot(
    WidgetTester tester, {
    required String name,
    required Map<Object?, Object?> answer,
    required Brightness brightness,
    bool timeOut = false,
  }) async {
    final container = ProviderContainer();
    globalState.container = container;
    final native = _Native()..answer = answer;
    final flow = MacHelperMaintenance(
      MacHelperClient(native: native, safeMode: () => false),
      stop: () async => const CoreLifecycleResult(
        revision: 1,
        outcome: CoreLifecycleOutcome.applied,
      ),
      startTimeout: const Duration(hours: 1),
      startPoll: const Duration(hours: 1),
      stalePoll: const Duration(hours: 1),
      switchPoll: const Duration(hours: 1),
      switchWindow: timeOut ? Duration.zero : const Duration(hours: 1),
    );
    await tester.runAsync(() async {
      await flow.check();
      if (timeOut) await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    const size = Size(520, 220);
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
              themeMode: brightness == Brightness.light
                  ? ThemeMode.light
                  : ThemeMode.dark,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: MacHelperCard(maintenance: flow),
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
    await tester.pumpWidget(const SizedBox.shrink());
    flow.dispose();
    container.dispose();
  }

  const switching = {'code': 'staleHelper', 'retiring': true};
  const stale = {
    'code': 'staleHelper',
    'retiring': true,
    'detail':
        'helper reply rejected by the app\'s verification: '
        'failed:cdhash running=aa bundled=bb',
  };
  for (final brightness in Brightness.values) {
    testWidgets('switching-${brightness.name}', skip: skip != null, (
      tester,
    ) async {
      await shoot(
        tester,
        name: '01-switching-${brightness.name}',
        answer: switching,
        brightness: brightness,
      );
    });
    testWidgets('timed-out-${brightness.name}', skip: skip != null, (
      tester,
    ) async {
      await shoot(
        tester,
        name: '02-timed-out-${brightness.name}',
        answer: stale,
        brightness: brightness,
        timeOut: true,
      );
    });
  }
}
