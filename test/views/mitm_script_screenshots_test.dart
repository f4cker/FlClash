// Renders the scripts page, its dialogs, the modules list and the scripts
// a request ran to PNG for review, light and dark. Off by default:
//   MITM_SCRIPT_SCREENSHOTS=<dir> flutter test \
//     test/views/mitm_script_screenshots_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/common/mitm_script.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/connection/mitm_script_hits.dart';
import 'package:fl_clash/features/mitm/rewrite.dart';
import 'package:fl_clash/features/mitm/script.dart';
import 'package:fl_clash/features/mitm/script_dialogs.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/mitm_module_confirm.dart';
import 'package:fl_clash/views/config/mitm_modules.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_paths.dart';
import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

final _outDir = Platform.environment['MITM_SCRIPT_SCREENSHOTS'];
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

MitmScript _script(
  int id,
  String line, {
  bool enabled = true,
  String? url,
  String? pending,
  String? error,
  MitmUpdateFailure? failure,
}) => MitmScript(
  id: id,
  profileId: 1,
  line: line,
  enabled: enabled,
  url: url,
  source: url ?? 'checkin.js',
  file: 's$id.js',
  pendingFile: pending,
  checkedAt: DateTime.now().subtract(const Duration(hours: 3)),
  error: error,
  failure: failure,
);

final _scripts = [
  _script(
    1,
    r'签名 = type=http-request,pattern=^https://api\.example\.com/v1/,'
    'script-path=s1.js',
    url: 'https://cdn.example.net/scripts/sign.js',
  ),
  _script(
    2,
    r'去广告 = type=http-response,pattern=^https://api\.example\.com/v1/feed,'
    'requires-body=1,script-path=s2.js',
    url: 'https://cdn.example.net/scripts/feed.js',
    pending: 's2.next.js',
  ),
  _script(
    3,
    r'签到 = type=http-response,pattern=^https://m\.shop\.example\.org/,'
    'requires-body=1,script-path=s3.js',
    enabled: false,
  ),
  _script(
    4,
    r'会员 = type=http-response,pattern=^https://api\.example\.com/vip,'
    'requires-body=1,script-path=s4.js',
    url: 'https://raw.example.io/x/vip.js',
    error: 'HTTP 404',
    failure: MitmUpdateFailure.check,
  ),
  _script(
    5,
    r'比价 = type=http-response,pattern=^https://item\.example\.com/,'
    'requires-body=1,script-path=s5.js',
    url: 'https://raw.example.io/x/price.js',
    error: 'HTTP 404',
    failure: MitmUpdateFailure.load,
  ),
];

const _module = r'''
#!name=去广告合集
#!desc=去除常见 App 的开屏与信息流广告
[MITM]
hostname = %APPEND% api.example.com, ads.example.net, *.track.example.org, -skip.example.net
[URL Rewrite]
^https://ads\.example\.net/splash - reject
^https://ads\.example\.net/banner - reject-img
[Body Rewrite]
http-response ^https://api\.example\.com/v1/feed "ads":\[[^\]]*\] "ads":[]
[Script]
信息流 = type=http-response,pattern=^https://api\.example\.com/v1/feed,requires-body=1,script-path=https://cdn.example.net/feed.js
[Rule]
DOMAIN-SUFFIX,ads.example.net,REJECT
DOMAIN,track.example.net,REJECT
IP-CIDR,203.0.113.0/24,REJECT,no-resolve
DOMAIN-SUFFIX,video.example.com,Media
DOMAIN-SUFFIX,stream.example.com,Netflix
DOMAIN-KEYWORD,adservice,REJECT
DOMAIN,stats.example.net,DIRECT
[General]
skip-proxy = example.com
''';

const _updated = r'''
#!name=去广告合集
#!desc=去除常见 App 的开屏与信息流广告
[MITM]
hostname = %APPEND% api.example.com, ads.example.net, cdn.ads.example.com
[URL Rewrite]
^https://ads\.example\.net/splash - reject
^https://ads\.example\.net/banner - reject-img
[Body Rewrite]
http-response ^https://api\.example\.com/v1/feed "ads":\[[^\]]*\] "ads":[]
[Script]
信息流 = type=http-response,pattern=^https://api\.example\.com/v1/feed,requires-body=1,script-path=https://cdn.example.net/feed.js
开屏 = type=http-response,pattern=^https://cdn\.ads\.example\.com/,requires-body=1,script-path=https://cdn.example.net/splash.js
[Rule]
DOMAIN-SUFFIX,ads.example.net,REJECT
DOMAIN,track.example.net,REJECT
IP-CIDR,203.0.113.0/24,REJECT,no-resolve
DOMAIN-SUFFIX,video.example.com,Media
DOMAIN-SUFFIX,stream.example.com,Netflix
DOMAIN-SUFFIX,adx.example.org,REJECT
''';

const _before = '''
const body = JSON.parse(\$response.body);
body.ads = [];
if (body.banner) {
  delete body.banner;
}
const keep = ["items", "next"];
for (const key of Object.keys(body)) {
  if (!keep.includes(key)) delete body[key];
}
console.log("cleaned");
\$done({ body: JSON.stringify(body) });
''';

const _after = '''
const body = JSON.parse(\$response.body);
body.ads = [];
body.splash = null;
if (body.banner) {
  delete body.banner;
}
const keep = ["items", "next"];
for (const key of Object.keys(body)) {
  if (!keep.includes(key)) delete body[key];
}
console.log("cleaned", Object.keys(body).length);
\$done({ body: JSON.stringify(body) });
''';

const _paste = r'''[Script]
签名 = type=http-request,pattern=^https://api\.example\.com/v2/,script-path=https://cdn.example.net/sign2.js
商城 = type=http-response,pattern=^https://m\.shop\.example\.org/,requires-body=1,script-path=https://cdn.example.net/shop.js
每日 = type=cron,cronexp=0 8 * * *,script-path=https://cdn.example.net/daily.js''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _outDir == null || _outDir!.isEmpty
      ? 'set MITM_SCRIPT_SCREENSHOTS to an output directory'
      : null;
  final boundary = GlobalKey();
  late Database testDatabase;

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
    await useAppPaths(Directory.systemTemp.createTempSync('script_shots'));
  });

  setUp(() {
    testDatabase = Database(NativeDatabase.memory());
    database = testDatabase;
  });

  tearDown(() => testDatabase.close());

  Future<void> settle(WidgetTester tester, [int frames = 8]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

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

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required Brightness brightness,
    Size size = const Size(760, 900),
    List<MitmScript>? scripts,
    List<MitmModule> modules = const [],
    bool decrypting = true,
    bool pushed = false,
  }) async {
    mitmFeature = true;
    addTearDown(() => mitmFeature = false);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await database.profilesDao.putAll([
        const Profile(id: 1, autoUpdateDuration: Duration.zero).toCompanion(),
      ]);
      await database.batch(
        (b) => database.mitmScriptsDao.setProfileWithBatch(
          1,
          b,
          scripts ?? _scripts,
        ),
      );
      await database.mitmModulesDao.putAll([
        for (final module in modules) module.toCompanion(),
      ]);
    });
    final content = parseMitmModule(_module, resources: const {});
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
        for (final module in modules)
          mitmModuleDetailsProvider(module.id).overrideWith(
            (ref) async => (
              content: content,
              issues: const <MitmList, Map<String, String>>{},
            ),
          ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.listen(patchClashConfigProvider, (_, _) {});
    container.listen(currentProfileIdProvider, (_, _) {});
    container.listen(profileSettingsProvider, (_, _) {});
    container.read(profileSettingsProvider.notifier).value = {
      'proxy-groups': [
        {'name': '节点选择'},
        {'name': 'Media'},
      ],
    };
    container.read(viewSizeProvider.notifier).value = size;
    container.read(currentProfileIdProvider.notifier).value = 1;
    container.read(patchClashConfigProvider.notifier).value = PatchClashConfig(
      mitm: Mitm(
        enable: decrypting,
        capture: true,
        hostname: const ['api.example.com', 'cdn.example.net'],
      ),
    );
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
              homeBuilder: (child) => HostScaffold(body: child),
              child: pushed ? const SizedBox.shrink() : child,
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settle(tester);
    if (pushed) {
      unawaited(
        globalState.navigatorKey.currentState!.push(
          HostPageRoute<void>(builder: (_) => child),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await settle(tester, 10);
    }
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  BuildContext host(WidgetTester tester) =>
      globalState.navigatorKey.currentContext!;

  final modules = [
    MitmModule(
      id: 1,
      name: '去广告合集',
      description: '去除常见 App 的开屏与信息流广告',
      url: 'https://raw.example.io/modules/ads.sgmodule',
      lastUpdateTime: DateTime.now().subtract(const Duration(days: 2)),
      order: 0,
      scripts: 1,
      pendingTime: DateTime.now(),
    ),
    MitmModule(
      id: 2,
      name: '我的调试',
      enabled: false,
      lastUpdateTime: DateTime.now(),
      order: 1,
    ),
    MitmModule(
      id: 3,
      name: '比价助手',
      url: 'https://raw.example.io/modules/price.sgmodule',
      lastUpdateTime: DateTime.now().subtract(const Duration(days: 9)),
      order: 2,
      error: 'HTTP 503',
      failure: MitmUpdateFailure.check,
    ),
    MitmModule(
      id: 4,
      name: '跳过开屏',
      url: 'https://raw.example.io/modules/splash.sgmodule',
      lastUpdateTime: DateTime.now().subtract(const Duration(days: 30)),
      order: 3,
      error: 'HTTP 404',
      failure: MitmUpdateFailure.load,
    ),
  ];

  for (final brightness in Brightness.values) {
    final tone = brightness == Brightness.light ? 'light' : 'dark';

    testWidgets('sm-entry-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        size: const Size(600, 300),
        modules: modules,
        Builder(
          builder: (context) => ListView(
            children: [
              generateSection(
                title: context.appLocalizations.mitmRewriteAndScripts,
                items: const [
                  MitmRewriteEntryItem(),
                  MitmScriptEntryItem(),
                  MitmModulesItem(),
                ],
              ),
            ],
          ),
        ),
      );
      await capture(tester, 'sm-entry-$tone');
      await done(tester);
    });

    testWidgets('sm-scripts-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        modules: modules,
        pushed: true,
        const MitmScriptView(),
      );
      await capture(tester, 'sm-scripts-$tone');
      await done(tester);
    });

    testWidgets('sm-scripts-off-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        decrypting: false,
        pushed: true,
        size: const Size(760, 560),
        const MitmScriptView(),
      );
      await capture(tester, 'sm-scripts-off-$tone');
      await done(tester);
    });

    testWidgets('sm-scripts-empty-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        scripts: const [],
        pushed: true,
        size: const Size(760, 600),
        const MitmScriptView(),
      );
      await capture(tester, 'sm-scripts-empty-$tone');
      await done(tester);
    });

    testWidgets('sm-add-$tone', skip: skip != null, (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async =>
            call.method == 'Clipboard.getData' ? {'text': _paste} : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pump(
        tester,
        brightness: brightness,
        pushed: true,
        const MitmScriptView(),
      );
      await tester.tap(find.byKey(MitmScriptView.addKey));
      await settle(tester, 12);
      await capture(tester, 'sm-add-$tone');
      await tester.tap(
        find.text(currentAppLocalizations.mitmContinue),
        warnIfMissed: false,
      );
      await settle(tester, 8);
      await capture(tester, 'sm-add-confirm-$tone');
      await done(tester);
    });

    testWidgets('sm-add-url-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        pushed: true,
        const MitmScriptView(),
      );
      unawaited(
        showMitmScriptAddDialog(
          host(tester),
          profileId: 1,
          initialText: 'https://cdn.example.net/scripts/price.js',
        ),
      );
      await settle(tester, 12);
      await capture(tester, 'sm-add-url-$tone');
      await done(tester);
    });

    testWidgets('sm-update-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        pushed: true,
        const MitmScriptView(),
      );
      unawaited(
        showMitmUpdateDialog(
          host(tester),
          name: '去广告',
          subtitle: '2 小时前检查到新版',
          before: _before.trim(),
          after: _after.trim(),
          onAdopt: () async {},
        ),
      );
      await settle(tester, 10);
      await capture(tester, 'sm-update-$tone');
      await done(tester);
    });

    testWidgets('sm-module-update-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        modules: modules,
        pushed: true,
        const MitmModulesView(),
      );
      unawaited(
        showMitmUpdateDialog(
          host(tester),
          name: '去广告合集',
          subtitle: '10 分钟前检查到新版',
          before: _module.trim(),
          after: _updated.trim(),
          summary: MitmModuleChangeSummary(
            change: mitmModuleChange(
              previewMitmModule(_module),
              previewMitmModule(_updated),
            ),
          ),
          onAdopt: () async {},
        ),
      );
      await settle(tester, 10);
      await capture(tester, 'sm-module-update-$tone');
      await done(tester);
    });

    testWidgets('sm-module-detail-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        modules: modules,
        pushed: true,
        size: const Size(760, 1500),
        const MitmModuleView(id: 1),
      );
      await capture(tester, 'sm-module-detail-$tone');
      await done(tester);
    });

    testWidgets('sm-module-detail-checking-$tone', skip: skip != null, (
      tester,
    ) async {
      await pump(
        tester,
        brightness: brightness,
        modules: modules,
        pushed: true,
        size: const Size(760, 500),
        const MitmModuleView(id: 1),
      );
      globalState.container
          .read(updatingKeysProvider.notifier)
          .start(modules.first.updatingKey);
      await settle(tester, 4);
      await capture(tester, 'sm-module-detail-checking-$tone');
      await done(tester);
    });

    testWidgets('sm-modules-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        modules: modules,
        pushed: true,
        size: const Size(760, 600),
        const MitmModulesView(),
      );
      await capture(tester, 'sm-modules-$tone');
      await done(tester);
    });

    testWidgets('sm-module-confirm-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        pushed: true,
        size: const Size(760, 1000),
        const MitmModulesView(),
      );
      unawaited(
        showMitmModuleConfirmDialog(
          host(tester),
          content: previewMitmModule(_module),
          name: '去广告合集',
          source: 'raw.example.io',
          onImport: (_, _) async {},
        ),
      );
      await settle(tester, 10);
      await capture(tester, 'sm-module-confirm-$tone');
      await done(tester);
    });

    Future<void> hits(
      WidgetTester tester,
      String name,
      List<MitmAction> actions,
    ) async {
      final exchange = MitmExchange(
        id: 7,
        start: DateTime(2026, 11, 18, 10, 4, 5),
        method: 'GET',
        url: 'https://api.example.com/v1/feed',
        status: 200,
        actions: actions,
      );
      await pump(
        tester,
        brightness: brightness,
        size: const Size(640, 560),
        modules: modules,
        ListView(
          padding: const EdgeInsets.all(16),
          children: [MitmScriptHitsSection(exchange: exchange)],
        ),
      );
      await capture(tester, '$name-$tone');
      await done(tester);
    }

    testWidgets('sm-detail-$tone', skip: skip != null, (tester) async {
      await hits(tester, 'sm-detail', const [
        MitmAction(
          kind: mitmScriptKind,
          phase: 'request',
          detail: '签名',
          rule: 's1',
          tookNs: 4000000,
          requests: [
            MitmScriptRequest(
              method: 'GET',
              url: 'https://api.example.com/token',
              status: 200,
              tookNs: 38000000,
            ),
          ],
        ),
        MitmAction(
          kind: mitmScriptKind,
          phase: 'response',
          detail: '信息流',
          rule: 'm1.0',
          tookNs: 38000000,
          logs: [
            MitmScriptLog(level: 'log', text: 'items 24'),
            MitmScriptLog(level: 'warn', text: 'banner missing'),
            MitmScriptLog(level: 'log', text: 'ads removed: 3'),
            MitmScriptLog(level: 'error', text: 'splash: unexpected shape'),
            MitmScriptLog(level: 'log', text: 'keep items, next'),
            MitmScriptLog(level: 'log', text: 'size 2048 -> 1730'),
            MitmScriptLog(level: 'log', text: 'cleaned 2'),
          ],
        ),
      ]);
    });

    testWidgets('sm-detail-failed-$tone', skip: skip != null, (tester) async {
      await hits(tester, 'sm-detail-failed', const [
        MitmAction(
          kind: mitmScriptKind,
          phase: 'response',
          detail: '去广告',
          rule: 's2',
          skipped: 'scriptTimeout',
        ),
        MitmAction(
          kind: mitmScriptKind,
          phase: 'response',
          detail: '会员',
          rule: 's4',
          skipped: 'scriptError',
          error: "TypeError: cannot read property 'vip' of undefined",
        ),
      ]);
    });
  }
}
