// Renders the rewrite page, its dialogs, the request marks and the request
// detail to PNG for review, light and dark. Off by default:
//   MITM_REWRITE_SCREENSHOTS=<dir> flutter test \
//     test/views/mitm_rewrite_screenshots_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_body.dart';
import 'package:fl_clash/common/mitm_trust.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/core/spill.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/features/mitm/rewrite.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/mitm.dart';
import 'package:fl_clash/views/connection/requests.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../helpers/app_paths.dart';
import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

final _outDir = Platform.environment['MITM_REWRITE_SCREENSHOTS'];
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

const _rules = [
  MitmRewrite(
    id: 1,
    section: MitmList.urlRewrite,
    line: r'^https?:\/\/ad\.example\.com - reject',
  ),
  MitmRewrite(
    id: 2,
    section: MitmList.urlRewrite,
    line: r'^https?:\/\/track\.example\.com - reject-img',
  ),
  MitmRewrite(
    id: 3,
    section: MitmList.urlRewrite,
    line: r'^https:\/\/example\.com\/old https://example.com/new 302',
  ),
  MitmRewrite(
    id: 4,
    section: MitmList.headerRewrite,
    line: r'http-request ^https:\/\/api\.example\.com header-add X-Debug 1',
  ),
  MitmRewrite(
    id: 5,
    section: MitmList.headerRewrite,
    line: r'http-response ^https:\/\/api\.example\.com header-del Set-Cookie',
    enabled: false,
  ),
  MitmRewrite(
    id: 6,
    section: MitmList.bodyRewrite,
    line:
        r'http-response ^https:\/\/api\.example\.com\/v1\/feed '
        r'"ads":\[[^\]]*\] "ads":[]',
  ),
  MitmRewrite(
    id: 7,
    section: MitmList.mapLocal,
    line:
        r'^https:\/\/cdn\.example\.com\/config\.json '
        r'data-type=text data="{}" status-code=200',
  ),
  MitmRewrite(
    id: 8,
    section: MitmList.urlRewrite,
    line: r'^https:\/\/broken\.example\.com\/( https://x 999',
  ),
];

const _issues = {
  8: MitmRewriteIssue(
    kind: 'urlType',
    args: ['"999"'],
    message: 'unknown URL rewrite type "999"',
  ),
};

const _pasted = '''# 广告与跟踪
[URL Rewrite]

^https?:\\/\\/ads\\.example\\.net - reject
^https:\\/\\/a\\.example\\.net\\/v1 https://b.example.net/v1 307
[Header Rewrite]
http-request ^https:\\/\\/a\\.example\\.net header-replace User-Agent Flash
[Body Rewrite]
http-response ^https:\\/\\/a\\.example\\.net\\/( "x" "y"''';

/// The Core's parse, faked: each section line names the list of the rule
/// lines after it; a line with an unclosed group is an error.
class _ParseCore extends CoreHandlerInterface {
  @override
  Future<Object?> invokeMethod({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
    CoreResultModel? model,
  }) async {
    if (method != CoreMethod.mitmRewriteParse) return null;
    final text = (arguments! as Map)['text'] as String;
    var section = 'url-rewrite';
    final rules = <Map<String, Object?>>[];
    final issues = <Map<String, Object?>>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('[')) {
        section = switch (line) {
          '[Header Rewrite]' => 'header-rewrite',
          '[Body Rewrite]' => 'body-rewrite',
          '[Map Local]' => 'map-local',
          _ => 'url-rewrite',
        };
        continue;
      }
      if (line.contains(r'\/(') || line.endsWith(' 999')) {
        issues.add(
          line.endsWith(' 999')
              ? {
                  'section': section,
                  'line': i + 1,
                  'kind': 'urlType',
                  'args': ['"999"'],
                  'message': 'unknown URL rewrite type "999"',
                }
              : {
                  'section': section,
                  'line': i + 1,
                  'kind': 'urlRegex',
                  'message':
                      'invalid URL regex: error parsing regexp: missing '
                      'closing ): `^https:\\/\\/a\\.example\\.net\\/(`',
                },
        );
        continue;
      }
      rules.add({'section': section, 'line': line, 'number': i + 1});
    }
    return {'rules': rules, 'issues': issues};
  }

  @override
  Future<CoreLifecycleResult> start() => throw UnimplementedError();

  @override
  Future<CoreLifecycleResult> restart() => throw UnimplementedError();

  @override
  Future<CoreLifecycleResult> stop() => throw UnimplementedError();

  @override
  Future<CoreLifecycleResult> close() => throw UnimplementedError();
}

/// The rules, held in memory; a commit waits on [commit] or fails.
class _Rewrites extends ProfileMitmRewrites {
  _Rewrites(this.rules, {this.hang = false, this.fail = false});

  final List<MitmRewrite> rules;
  final bool hang;
  final bool fail;

  @override
  Stream<List<MitmRewrite>> build(int profileId) => Stream.value(rules);

  @override
  Future<void> commit(List<MitmRewrite> rewrites) async {
    if (hang) return Completer<void>().future;
    if (fail) throw Exception('database is locked');
    state = AsyncData(rewrites);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _outDir == null || _outDir!.isEmpty
      ? 'set MITM_REWRITE_SCREENSHOTS to an output directory'
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
    await useAppPaths(Directory.systemTemp.createTempSync('rewrite_shots'));
  });

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

  /// Pumps [child] over a container with the rules and the faked Core.
  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget child, {
    required Brightness brightness,
    Size size = const Size(760, 900),
    List<MitmRewrite> rules = _rules,
    Map<int, MitmRewriteIssue> issues = _issues,
    bool decrypting = true,
    bool hang = false,
    bool fail = false,
    List<Override> overrides = const [],
    bool host = true,
  }) async {
    // The rewrite page is a second-level page, opened from the decryption
    // page: pushed over it, it has the bar's back button as in the app.
    final pushed = child is MitmRewriteView;
    mitmFeature = true;
    addTearDown(() => mitmFeature = false);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
        profileMitmRewritesProvider(
          1,
        ).overrideWith(() => _Rewrites(rules, hang: hang, fail: fail)),
        mitmRewriteIssuesProvider(1).overrideWith((ref) async => issues),
        mitmRewriteBodyLimitProvider.overrideWith((ref) async => 1 << 20),
        coreHandlerProvider.overrideWithValue(
          CoreController.scoped(_ParseCore()),
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.listen(patchClashConfigProvider, (_, _) {});
    container.listen(currentProfileIdProvider, (_, _) {});
    container.read(viewSizeProvider.notifier).value = size;
    container.read(currentProfileIdProvider.notifier).value = 1;
    container.read(patchClashConfigProvider.notifier).value = PatchClashConfig(
      mitm: Mitm(enable: decrypting, capture: true),
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
              homeBuilder: host
                  ? (child) => HostScaffold(body: child)
                  : (child) => child,
              child: pushed ? const SizedBox.shrink() : child,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    if (pushed) {
      unawaited(
        globalState.navigatorKey.currentState!.push(
          HostPageRoute<void>(builder: (_) => child),
        ),
      );
      await settle(tester, 10);
    }
    return container;
  }

  Future<void> scroll(WidgetTester tester, Finder scrollable) async {
    await tester.drag(scrollable, const Offset(0, -260));
    await settle(tester, 6);
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  }

  for (final brightness in Brightness.values) {
    final tone = brightness == Brightness.light ? 'light' : 'dark';

    testWidgets('rw-entry-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        size: const Size(600, 260),
        Builder(
          builder: (context) => ListView(
            children: [
              generateSection(
                title: context.appLocalizations.mitmRewriteAndScripts,
                items: const [MitmRewriteEntryItem()],
              ),
            ],
          ),
        ),
      );
      await capture(tester, 'rw-entry-$tone');
      await done(tester);
    });

    testWidgets('rw-list-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        hang: true,
        const MitmRewriteView(),
      );
      await capture(tester, 'rw-list-$tone');
      // A switch turned while the Core takes the rules waits on it.
      await tester.tap(find.byType(Switch).at(2));
      await settle(tester, 3);
      await capture(tester, 'rw-list-pending-$tone');
      await done(tester);
    });

    testWidgets('rw-invalid-$tone', skip: skip != null, (tester) async {
      await pump(tester, brightness: brightness, const MitmRewriteView());
      final row = find.textContaining('broken', findRichText: true).first;
      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(row);
      await settle(tester, 12);
      await tester.tap(
        find.text(currentAppLocalizations.viewOriginalError),
      );
      await settle(tester, 3);
      await capture(tester, 'rw-invalid-$tone');
      await done(tester);
    });

    testWidgets('blur-rewrite-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        size: const Size(760, 560),
        const MitmRewriteView(),
      );
      await scroll(tester, find.byType(Scrollable).last);
      await capture(tester, 'blur-rewrite-$tone');
      await done(tester);
    });

    // The decryption page scrolled up under its bar.
    testWidgets('scrolled-decryption-$tone', skip: skip != null, (
      tester,
    ) async {
      await pump(
        tester,
        brightness: brightness,
        size: const Size(760, 380),
        host: false,
        const MitmView(isAndroid: false),
        overrides: [
          mitmTrustStoreProvider.overrideWithValue(_ReadyStore()),
          mitmSignerProvider.overrideWithValue(null),
        ],
      );
      await scroll(tester, find.byType(Scrollable).first);
      await capture(tester, 'scrolled-decryption-$tone');
      await done(tester);
    });

    testWidgets('rw-toggle-failed-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        fail: true,
        const MitmRewriteView(),
      );
      await tester.tap(find.byType(Switch).at(2));
      await settle(tester, 3);
      await capture(tester, 'rw-toggle-failed-$tone');
      await done(tester);
    });

    testWidgets('rw-off-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        decrypting: false,
        const MitmRewriteView(),
      );
      await capture(tester, 'rw-off-$tone');
      await done(tester);
    });

    testWidgets('rw-empty-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        rules: const [],
        issues: const {},
        const MitmRewriteView(),
      );
      await capture(tester, 'rw-empty-$tone');
      await done(tester);
    });

    testWidgets('rw-paste-$tone', skip: skip != null, (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async =>
            call.method == 'Clipboard.getData' ? {'text': _pasted} : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pump(tester, brightness: brightness, const MitmRewriteView());
      await tester.tap(find.byKey(MitmRewriteView.pasteKey));
      await settle(tester, 12);
      await capture(tester, 'rw-paste-$tone');
      await done(tester);
    });

    testWidgets('rw-edit-$tone', skip: skip != null, (tester) async {
      await pump(tester, brightness: brightness, const MitmRewriteView());
      final row = find.textContaining('track', findRichText: true).first;
      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(row);
      await settle(tester, 12);
      await capture(tester, 'rw-edit-$tone');
      await done(tester);
    });

    testWidgets('rw-reveal-$tone', skip: skip != null, (tester) async {
      await pump(
        tester,
        brightness: brightness,
        const MitmRewriteView(revealRule: 6),
      );
      await settle(tester, 3);
      await capture(tester, 'rw-reveal-$tone');
      await done(tester);
    });

    testWidgets('rw-reqlist-$tone', skip: skip != null, (tester) async {
      final start = DateTime(2026, 11, 18, 10, 4, 5);
      TrackerInfo row(
        String id,
        String host,
        int seconds, {
        MitmConnectionRewrite? rewrite,
        bool mitm = true,
      }) => TrackerInfo(
        id: id,
        start: start.add(Duration(seconds: seconds)),
        upload: 1200 + seconds * 97,
        download: 18000 + seconds * 3100,
        metadata: Metadata(
          network: 'tcp',
          host: host,
          destinationIP: '93.184.215.14',
          destinationPort: '443',
          process: 'Safari',
          mitm: mitm,
        ),
        chains: const ['DIRECT'],
        rule: 'DomainSuffix',
        rulePayload: host,
        mitmRewrite: rewrite,
      );
      final container = await pump(
        tester,
        brightness: brightness,
        size: const Size(600, 640),
        host: false,
        const SizedBox.shrink(),
      );
      final notifier = container.read(requestsProvider.notifier);
      notifier.value = FixedList<TrackerInfo>(500);
      for (final request in [
        row(
          '1',
          'api.example.com',
          0,
          rewrite: const MitmConnectionRewrite(applied: true),
        ),
        row('2', 'cdn.example.net', 1, mitm: false),
        row(
          '3',
          'api.example.com',
          2,
          rewrite: const MitmConnectionRewrite(applied: true, failed: true),
        ),
        row('4', 'www.example.org', 3),
        row(
          '5',
          'ad.example.com',
          4,
          rewrite: const MitmConnectionRewrite(applied: true),
        ),
        for (var i = 6; i < 26; i++)
          row('$i', 'host$i.example.org', i, mitm: i.isEven),
      ]) {
        notifier.addRequest(request);
      }
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
                child: const RequestsView(initialFeed: RequestFeed.recent),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      await capture(tester, 'rw-reqlist-$tone');
      await scroll(tester, find.byType(Scrollable).first);
      await capture(tester, 'blur-requests-$tone');
      await done(tester);
    });

    Future<void> detail(
      WidgetTester tester,
      String name,
      MitmExchange exchange, {
      bool before = false,
    }) async {
      final connection = TrackerInfo(
        id: 'connection-1',
        start: exchange.start,
        metadata: const Metadata(
          network: 'tcp',
          host: 'api.example.com',
          mitm: true,
        ),
        chains: const ['DIRECT'],
        rule: 'MATCH',
        rulePayload: '',
      );
      const contentType = 'application/json; charset=utf-8';
      MitmBody json(String text) =>
          MitmBody(data: base64.encode(utf8.encode(text)));
      await pump(
        tester,
        brightness: brightness,
        size: const Size(760, 820),
        SheetProvider(
          type: SheetType.page,
          child: TrackerInfoDetailView(trackerInfo: connection),
        ),
        overrides: [
          mitmExchangesProvider(connection.id).overrideWith(
            (ref) async => MitmExchangeList(
              capturing: true,
              since: exchange.start,
              exchanges: [
                MitmExchangeSummary(
                  id: exchange.id,
                  start: exchange.start,
                  method: exchange.method,
                  url: exchange.url,
                  status: exchange.status,
                  duration: exchange.duration,
                  responseSize: exchange.responseSize,
                  rewritten: exchange.rewritten,
                  rewriteSkipped: exchange.rewriteSkipped,
                ),
              ],
            ),
          ),
          mitmExchangeProvider(
            exchange.id,
          ).overrideWith((ref) async => exchange),
          mitmBodyProvider(
            exchange.id,
            response: true,
            contentType: contentType,
          ).overrideWith(
            (ref) async => readMitmBody((
              json('{"items":[1,2,3],"ads":[]}'),
              contentType,
              grpcOverLimitNote: null,
            )),
          ),
          mitmBodyProvider(
            exchange.id,
            response: true,
            contentType: contentType,
            original: true,
          ).overrideWith(
            (ref) async => readMitmBody((
              json('{"items":[1,2,3],"ads":[{"id":9,"img":"a.png"}]}'),
              contentType,
              grpcOverLimitNote: null,
            )),
          ),
        ],
      );
      final l = currentAppLocalizations;
      Future<void> tab(String label) async {
        await tester.tap(
          find.descendant(
            of: find.byType(SegmentedControl<int>).last,
            matching: find.text(label),
          ),
        );
        await settle(tester, 4);
      }

      await tab(l.httpRequests);
      await tester.tap(find.textContaining('/v1/feed').first);
      await settle(tester);
      await capture(tester, '$name-$tone');
      if (name == 'rw-detail') {
        await scroll(tester, find.byType(Scrollable).last);
        await capture(tester, 'scrolled-detail-$tone');
        await tester.drag(find.byType(Scrollable).last, const Offset(0, 600));
        await settle(tester, 6);
      }
      if (before) {
        await tab(l.response);
        await capture(tester, '$name-after-$tone');
        await tester.tap(find.text(l.mitmRewriteBefore));
        await settle(tester, 4);
        await capture(tester, '$name-before-$tone');
      }
      await done(tester);
    }

    final exchange = MitmExchange(
      id: 7,
      start: DateTime(2026, 11, 18, 10, 4, 5),
      duration: 182,
      ttfb: 96,
      method: 'GET',
      url: 'https://api.example.com/v1/feed',
      proto: 'HTTP/2.0',
      status: 200,
      responseSize: 27,
      connection: 'connection-1',
      requestHeader: const {
        'Host': ['api.example.com'],
        'X-Debug': ['1'],
      },
      responseHeader: const {
        'Content-Type': ['application/json; charset=utf-8'],
      },
      rewritten: true,
    );

    testWidgets('rw-detail-$tone', skip: skip != null, (tester) async {
      await detail(
        tester,
        'rw-detail',
        exchange.copyWith(
          actions: const [
            MitmAction(
              kind: 'header-rewrite',
              phase: 'request',
              detail: 'header-add',
              rule: '4',
              tookNs: 200000,
            ),
            MitmAction(
              kind: 'body-rewrite',
              phase: 'response',
              detail: 'body',
              rule: '6',
              tookNs: 1300000,
            ),
          ],
          originalRequestHeader: const {
            'Host': ['api.example.com'],
          },
          originalResponseBody: true,
        ),
        before: true,
      );
    });

    testWidgets('rw-detail-failed-$tone', skip: skip != null, (tester) async {
      await detail(
        tester,
        'rw-detail-failed',
        exchange.copyWith(
          rewritten: false,
          rewriteSkipped: true,
          actions: const [
            MitmAction(
              kind: 'body-rewrite',
              phase: 'response',
              rule: '6',
              skipped: 'oversize',
            ),
          ],
        ),
      );
    });
  }
}

class _ReadyStore implements MitmTrustStore {
  @override
  Future<MitmTrustCheck> check(
    MitmCertificate ca,
    Future<String> Function() issueLeaf,
  ) async => const MitmTrustCheck(MitmTrust.ready);

  @override
  Future<MitmInstallOutcome> install(MitmCertificate ca) async =>
      MitmInstallOutcome.installed;

  @override
  Future<MitmRemoveOutcome> remove(MitmCertificate ca) async =>
      MitmRemoveOutcome.removed;
}
