// Renders the localized MITM script/rewrite error display to PNG for review:
// a dialog's error bar (a script that does not load) and a page banner (a
// rewrite change the Core refused), each collapsed and with 查看原始错误
// opened, in zh light, en dark and ru light. Off by default:
//   MITM_ERROR_SCREENSHOTS=<dir> flutter test \
//     test/views/mitm_error_screenshots_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_rewrite.dart';
import 'package:fl_clash/core/method.dart' show CoreMethodException;
import 'package:fl_clash/features/mitm/rewrite_dialogs.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/mount.dart'
    show MountBanner, MountBannerLevel;
import 'package:fl_clash/views/rules/rule_edit_dialogs.dart' show RuleEditFrame;
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

final _outDir = Platform.environment['MITM_ERROR_SCREENSHOTS'];
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

// As core/mitm_script.go and the Core's update path word them: raw text the
// app never translates.
const _syntax = MitmRewriteIssue(
  section: 'script',
  kind: 'scriptSyntax',
  args: ['SyntaxError: (anonymous): Line 3:14 Unexpected token )'],
  message:
      'script does not compile: SyntaxError: (anonymous): Line 3:14 '
      'Unexpected token ) (and 2 more errors)',
);
const _maxSize = MitmRewriteIssue(
  section: 'script',
  kind: 'scriptMaxSize',
  args: ['"10k"'],
  message: 'max-size must be a number of bytes, got "10k"',
);
// The Core names the file the app stored the script under.
const _unreadable = MitmRewriteIssue(
  section: 'script',
  kind: 'scriptUnreadable',
  args: ['3f9a0c51e2b7d4a6.js'],
  message: 'script file 3f9a0c51e2b7d4a6.js cannot be read',
);
const _tooLarge = MitmRewriteIssue(
  section: 'script',
  kind: 'scriptTooLarge',
  args: ['3f9a0c51e2b7d4a6.js'],
  message: 'script file 3f9a0c51e2b7d4a6.js is over 8 MiB',
);
const _refused = CoreMethodException(
  code: 'internal',
  message:
      'mitm.update: body-rewrite rule 4: regexp: Compile(`(?<=id)\\d+`): '
      'error parsing regexp: invalid or unsupported Perl syntax: `(?<`',
);

class _Errors extends StatelessWidget {
  const _Errors();

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final syntax = mitmIssueError(l, _syntax);
    final maxSize = mitmIssueError(l, _maxSize);
    final unreadable = mitmScriptCannotLoadError(l, '签到.js', _unreadable);
    // No name the user knows to give: the words name no file.
    final tooLarge = mitmIssueError(l, _tooLarge);
    final refused = mitmRewriteNotAppliedError(l, _refused);
    return ColoredBox(
      color: context.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            MountBanner(
              level: MountBannerLevel.error,
              lines: [refused.text],
              raw: refused.raw,
            ),
            MountBanner(
              level: MountBannerLevel.error,
              lines: [l.mitmScriptCannotLoad('签到.js', maxSize.text)],
              raw: maxSize.raw,
            ),
            MountBanner(
              level: MountBannerLevel.error,
              lines: [unreadable.text],
              raw: unreadable.raw,
            ),
            MountBanner(
              level: MountBannerLevel.error,
              lines: [tooLarge.text],
              raw: tooLarge.raw,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: RuleEditFrame(
                  title: l.mitmScripts,
                  subtitle: '签到.js',
                  width: 520,
                  primaryLabel: l.save,
                  onPrimary: () {},
                  error: l.mitmScriptCannotLoad('签到.js', syntax.text),
                  errorRaw: syntax.raw,
                  children: const [SizedBox(height: 40)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _outDir == null || _outDir!.isEmpty
      ? 'set MITM_ERROR_SCREENSHOTS to an output directory'
      : null;
  final boundary = GlobalKey();

  setUpAll(() async {
    if (skip != null) return;
    WidgetsApp.debugAllowBannerOverride = false;
    final cjk = _collectionFaces(File(_cjkCollection).readAsBytesSync());
    // Drawn as on macOS: SF for the system face (Hiragino would draw
    // Cyrillic full width), Hiragino standing in for PingFang SC.
    await (FontLoader('.AppleSystemUIFont')..addFont(
          Future.value(
            ByteData.sublistView(
              File('/System/Library/Fonts/SFNS.ttf').readAsBytesSync(),
            ),
          ),
        ))
        .load();
    final cjkLoader = FontLoader('PingFang SC');
    for (final face in cjk) {
      cjkLoader.addFont(Future.value(face));
    }
    await cjkLoader.load();
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

  const variants = [
    ('zh-light', Locale('zh', 'CN'), Brightness.light, Size(600, 900)),
    ('en-dark', Locale('en'), Brightness.dark, Size(600, 900)),
    ('ru-light', Locale('ru'), Brightness.light, Size(600, 900)),
    // The narrowest a dialog gets, for the long Russian lines to wrap.
    ('ru-narrow', Locale('ru'), Brightness.light, Size(360, 1100)),
  ];
  for (final (name, locale, brightness, size) in variants) {
    testWidgets('errors-$name', skip: skip != null, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      globalState.container = container;
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
                child: const _Errors(),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      final l = lookupAppLocalizations(locale);
      final toggles = find.text(l.viewOriginalError);
      expect(toggles, findsNWidgets(5));
      expect(find.textContaining('SyntaxError'), findsNothing);
      expect(find.textContaining('3f9a0c51'), findsNothing);
      await capture(tester, '$name-collapsed');
      for (var i = 0; i < 5; i++) {
        await tester.tap(toggles.at(i));
        await settle(tester);
      }
      expect(find.textContaining('SyntaxError'), findsOneWidget);
      expect(find.textContaining('3f9a0c51'), findsNWidgets(2));
      await capture(tester, '$name-expanded');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
