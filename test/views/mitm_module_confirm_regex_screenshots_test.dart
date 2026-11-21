// Renders the module import sheet with one rule whose pattern the Core
// rejects and one it could not check, in Chinese, to PNG for review. Off by
// default:
//   HINTS_SHOTS=<dir> flutter test \
//     test/views/mitm_module_confirm_regex_screenshots_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_script.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/mitm_module_confirm.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_paths.dart';
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

const _module = r'''
#!name=去广告
#!desc=去除开屏广告
[MITM]
hostname = %APPEND% ads.example.net
[URL Rewrite]
^https://ads\.example\.net/(?!keep)splash - reject
^http(s://ads\.example\.net/banner - reject-img
[Body Rewrite]
http-response ^https://api\.example\.com/v1/feed "ads":\[[^\]]*\] "ads":[]
''';

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
    await useAppPaths(Directory.systemTemp.createTempSync('regex_shots'));
  });

  for (final (name, size, open, pending) in [
    ('regex-hint-confirm-zh-checking', const Size(560, 760), false, true),
    ('regex-hint-confirm-zh', const Size(560, 760), false, false),
    ('regex-hint-confirm-zh-details', const Size(560, 860), true, false),
  ]) {
    testWidgets(name, skip: skip != null, (tester) async {
      final db = Database(NativeDatabase.memory());
      database = db;
      addTearDown(db.close);
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => database.profilesDao.putAll([
          const Profile(id: 1, autoUpdateDuration: Duration.zero).toCompanion(),
        ]),
      );
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(
            () => TestProfiles([
              const Profile(
                id: 1,
                label: '日常',
                autoUpdateDuration: Duration.zero,
              ),
            ]),
          ),
          // The Core rejects the second URL rule and says nothing of the
          // body rule.
          mitmRewriteValidatorProvider.overrideWithValue(
            (_) async => pending
                ? Completer<Never>().future
                : {
                    MitmList.urlRewrite: {
                      1: const MitmRewriteIssue(
                        kind: 'urlRegex',
                        message:
                            'invalid URL regex: error parsing regexp: '
                            'missing closing ): `^http(s://ads\\.example\\.net/banner`',
                      ),
                    },
                    MitmList.headerRewrite: const {},
                    MitmList.mapLocal: const {},
                  },
          ),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.listen(patchClashConfigProvider, (_, _) {});
      container.listen(currentProfileIdProvider, (_, _) {});
      container.read(currentProfileIdProvider.notifier).value = 1;
      container.read(patchClashConfigProvider.notifier).value =
          const PatchClashConfig(mitm: Mitm(enable: true));
      container.read(viewSizeProvider.notifier).update((_) => size);
      loadAppLocalizations(const Locale('zh', 'CN'));
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
                child: const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        showMitmModuleConfirmDialog(
          tester.element(find.byType(SizedBox).first),
          content: previewMitmModule(_module),
          name: '去广告',
          source: 'raw.example.io',
          onImport: (_, _) async {},
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (open) {
        await tester.tap(
          find.text(currentAppLocalizations.viewOriginalError).first,
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
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
      await tester.pump(mitmModuleRewriteCheckTimeout);
    });
  }
}
