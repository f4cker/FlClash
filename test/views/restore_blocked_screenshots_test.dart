// Renders the restore-blocked dialog to PNG for review. Off by default:
//   RESTORE_BLOCKED_SCREENSHOTS=<dir> flutter test \
//     test/views/restore_blocked_screenshots_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/backup_and_restore.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart' show ThemeMode;

import '../helpers/test_app.dart';

final _outDir = Platform.environment['RESTORE_BLOCKED_SCREENSHOTS'];
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
      ? 'set RESTORE_BLOCKED_SCREENSHOTS to an output directory'
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
    required Locale locale,
    required RestoreBlockedException Function(AppLocalizations l10n) blocked,
  }) async {
    final container = ProviderContainer();
    globalState.container = container;
    const size = Size(480, 420);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final l10n = lookupAppLocalizations(locale);
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
              themeMode: ThemeMode.light,
              child: Center(
                child: RestoreBlockedDialog(blocked: blocked(l10n)),
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
    container.dispose();
  }

  RestoreBlockedException changed(AppLocalizations l10n) =>
      RestoreBlockedException(
        l10n.restoreBlockedMountStateChanged,
        reason: RestoreBlockedReason.mountStateChanged,
        profileIds: const [1, 2],
      );

  for (final locale in const [Locale('zh'), Locale('en')]) {
    final tag = locale.languageCode;
    testWidgets('changed-$tag', skip: skip != null, (tester) async {
      await shoot(
        tester,
        name: '01-mount-state-changed-$tag-light',
        locale: locale,
        blocked: changed,
      );
    });
  }
}
