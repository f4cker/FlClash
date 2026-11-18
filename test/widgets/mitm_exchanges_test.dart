import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_body.dart';
import 'package:fl_clash/common/mitm_rewrite.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';
import '../helpers/host_scaffold.dart';

final _start = DateTime.utc(2026, 10, 28, 0, 0, 5);

final _decrypted = TrackerInfo(
  id: 'connection-1',
  start: _start,
  metadata: const Metadata(network: 'tcp', host: 'a.test', mitm: true),
  chains: const ['DIRECT'],
  rule: 'MATCH',
  rulePayload: '',
);

final _exchange = MitmExchange(
  id: 7,
  start: _start,
  duration: 35,
  ttfb: 20,
  method: 'GET',
  url: 'https://a.test/new?x=1',
  originalUrl: 'https://a.test/old?x=1',
  proto: 'HTTP/2.0',
  status: 200,
  responseSize: 2048,
  connection: 'connection-1',
  requestHeader: const {
    'Host': ['a.test'],
  },
  responseHeader: const {
    'X-Upstream': ['yes'],
  },
  actions: const [
    MitmAction(kind: 'url-rewrite', detail: 'header'),
    MitmAction(kind: 'script', phase: 'response', detail: 'sign'),
  ],
);

MitmExchangeSummary _summary(MitmExchange exchange) => MitmExchangeSummary(
  id: exchange.id,
  start: exchange.start,
  pending: exchange.pending,
  duration: exchange.duration,
  method: exchange.method,
  proto: exchange.proto,
  url: exchange.url,
  status: exchange.status,
  responseSize: exchange.responseSize,
);

Future<ProviderContainer> _pumpDetail(
  WidgetTester tester, {
  required MitmExchangeList list,
  Exception? listError,
  Exception? bodyError,
  MitmExchange? exchange,
  bool capture = true,
  MitmBody responseBody = const MitmBody(),
  MitmBody originalResponseBody = const MitmBody(),
  List<MitmModule> modules = const [],
  bool inSheet = false,
}) async {
  final contentType = mitmHeaderValue(
    (exchange ?? _exchange).responseHeader,
    'Content-Type',
  );
  final container = ProviderContainer(
    overrides: [
      mitmExchangesProvider(
        _decrypted.id,
      ).overrideWith((ref) async => listError == null ? list : throw listError),
      mitmExchangeProvider(7).overrideWith((ref) async => exchange),
      mitmBodyProvider(
        7,
        response: true,
        contentType: contentType,
      ).overrideWith(
        (ref) async => bodyError == null
            ? readMitmBody((responseBody, contentType))
            : throw bodyError,
      ),
      mitmBodyProvider(
        7,
        response: true,
        contentType: contentType,
        original: true,
      ).overrideWith(
        (ref) async => readMitmBody((originalResponseBody, contentType)),
      ),
      mitmModulesProvider.overrideWith(() => _Modules(modules)),
    ],
  );
  addTearDown(container.dispose);
  container.listen(patchClashConfigProvider, (_, _) {});
  container.read(patchClashConfigProvider.notifier).value = PatchClashConfig(
    mitm: Mitm(enable: true, capture: capture),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TestApp(
        homeBuilder: (child) => HostScaffold(body: child),
        child: inSheet
            ? Builder(
                builder: (context) => GestureDetector(
                  onTap: () =>
                      showTrackerInfoDetail(context, _decrypted, 'Detail'),
                  child: const Text('open'),
                ),
              )
            : SheetProvider(
                type: SheetType.page,
                child: TrackerInfoDetailView(trackerInfo: _decrypted),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _Modules extends MitmModules {
  _Modules(this.modules);

  final List<MitmModule> modules;

  @override
  Stream<List<MitmModule>> build() => Stream.value(modules);
}

Finder _inMenu(Finder finder) =>
    find.descendant(of: find.byType(PopupMenu), matching: finder);

Future<void> _openRequest(WidgetTester tester) async {
  await _openTab(tester, currentAppLocalizations.httpRequests);
  await tester.tap(find.text('GET /new?x=1'));
  await tester.pumpAndSettle();
}

Future<void> _openBarMenu(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(MitmExchangeView),
      matching: find.byGlyph(AppGlyphs.more),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _tab(String label) => find.descendant(
  of: find.byType(SegmentedControl<int>).last,
  matching: find.text(label),
);

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(_tab(label));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) {
  return tester.scrollUntilVisible(
    finder,
    100,
    scrollable: find.byType(Scrollable).last,
  );
}

void main() {
  testWidgets('a request opens as a page of its connection\'s sheet', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      list: MitmExchangeList(capturing: true, exchanges: [_summary(_exchange)]),
      exchange: _exchange,
      inSheet: true,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final pages = Navigator.of(
      tester.element(find.byType(TrackerInfoDetailView)),
    );
    expect(pages.widget, isA<SheetPagesNavigator>());

    await _openRequest(tester);

    final request = find.byType(MitmExchangeView);
    expect(ModalRoute.of(tester.element(request)), isA<PagedSheetRoute>());
    expect(Navigator.of(tester.element(request)), same(pages));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a read that fails says so rather than showing no requests', (
    tester,
  ) async {
    final container = await _pumpDetail(
      tester,
      list: const MitmExchangeList(),
      listError: Exception('core gone'),
    );

    await _openTab(tester, currentAppLocalizations.httpRequests);

    expect(find.textContaining('core gone'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('a body that fails says so beside its headers', (tester) async {
    final container = await _pumpDetail(
      tester,
      list: MitmExchangeList(capturing: true, exchanges: [_summary(_exchange)]),
      exchange: _exchange,
      bodyError: Exception('body gone'),
    );

    await _openRequest(tester);
    await _openTab(tester, currentAppLocalizations.response);

    expect(find.text('X-Upstream'), findsOneWidget);
    expect(find.textContaining('body gone'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('a decrypted connection lists its requests in a tab of their '
      'own, and a request opens on tabs too', (tester) async {
    await _pumpDetail(
      tester,
      list: MitmExchangeList(
        capturing: true,
        since: _start.subtract(const Duration(minutes: 1)),
        exchanges: [
          _summary(_exchange),
          MitmExchangeSummary(
            id: 8,
            start: _start,
            pending: true,
            method: 'POST',
            url: 'https://a.test/upload',
          ),
        ],
      ),
      exchange: _exchange,
    );
    final appLocalizations = currentAppLocalizations;

    expect(find.text(appLocalizations.basicInfo), findsOneWidget);
    expect(find.text('GET /new?x=1'), findsNothing);

    await _openTab(tester, appLocalizations.httpRequests);

    expect(find.text(appLocalizations.basicInfo), findsNothing);
    expect(find.text('GET /new?x=1'), findsOneWidget);
    // Each request names its protocol beside its status.
    expect(find.text('200 · h2'), findsOneWidget);
    expect(find.text('35 ms'), findsOneWidget);
    expect(find.text('POST /upload'), findsOneWidget);
    expect(find.text(appLocalizations.inProgress), findsOneWidget);
    expect(find.text(appLocalizations.httpRequestsMissing), findsNothing);

    await tester.tap(find.text('GET /new?x=1'));
    await tester.pumpAndSettle();

    expect(find.text('X-Upstream'), findsNothing);
    // The rewrite hit leads, under its own section; a rule no longer in
    // the profile says so rather than offer to show it.
    expect(
      find.text(
        '${appLocalizations.mitmRewriteAppliedTitle} · '
        '${appLocalizations.mitmRewriteHitCount(1)}',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text(appLocalizations.mitmRewriteActUrl), findsOneWidget);
    expect(find.text(appLocalizations.mitmRewriteRuleRemoved), findsOneWidget);
    expect(find.text(appLocalizations.mitmRewriteViewInList), findsNothing);
    expect(find.text(appLocalizations.mitmRewritePassedThrough), findsNothing);
    // Scripts follow, in a section of their own.
    expect(find.text(appLocalizations.mitmScriptsRan(1)), findsOneWidget);
    expect(find.text('sign', findRichText: true), findsOneWidget);
    expect(find.text(appLocalizations.mitmScriptGroupResponse), findsOneWidget);
    await _scrollTo(tester, find.text('https://a.test/old?x=1'));
    expect(find.text('HTTP/2.0'), findsOneWidget);

    await _openTab(tester, appLocalizations.request);
    expect(find.text('Host'), findsOneWidget);
    expect(find.text('X-Upstream'), findsNothing);

    await _openTab(tester, appLocalizations.response);
    expect(find.text('X-Upstream'), findsOneWidget);
    expect(find.text('yes'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('with capture off a decrypted connection shows its overview '
      'alone', (tester) async {
    await _pumpDetail(tester, list: const MitmExchangeList(), capture: false);

    expect(find.byType(SegmentedControl<int>), findsNothing);
    expect(find.text(currentAppLocalizations.basicInfo), findsOneWidget);
    expect(find.text(currentAppLocalizations.httpRequests), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a connection made before capture says its list may be short', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      list: MitmExchangeList(
        capturing: true,
        since: _start.add(const Duration(minutes: 1)),
      ),
    );
    await _openTab(tester, currentAppLocalizations.httpRequests);

    expect(
      find.text(currentAppLocalizations.httpRequestsMissing),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a connection says when the Core is not capturing', (
    tester,
  ) async {
    await _pumpDetail(tester, list: const MitmExchangeList());
    await _openTab(tester, currentAppLocalizations.httpRequests);

    expect(find.text(currentAppLocalizations.httpCaptureOff), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a request the Core no longer keeps says so', (tester) async {
    await _pumpDetail(
      tester,
      list: MitmExchangeList(
        capturing: true,
        since: _start,
        exchanges: [_summary(_exchange)],
      ),
    );
    await _openTab(tester, currentAppLocalizations.httpRequests);

    await tester.tap(find.text('GET /new?x=1'));
    await tester.pumpAndSettle();

    expect(
      find.text(currentAppLocalizations.httpRequestCleared),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a request still waiting on its answer says so under '
      'Response', (tester) async {
    final waiting = _exchange.copyWith(
      pending: true,
      status: 0,
      responseSize: 0,
      responseHeader: const {},
    );
    await _pumpDetail(
      tester,
      list: MitmExchangeList(
        capturing: true,
        since: _start,
        exchanges: [_summary(waiting)],
      ),
      exchange: waiting,
    );
    await _openTab(tester, currentAppLocalizations.httpRequests);
    await tester.tap(find.text('GET /new?x=1'));
    await tester.pumpAndSettle();
    await _openTab(tester, currentAppLocalizations.response);

    final detail = find.byType(MitmExchangeView);
    expect(
      find.descendant(of: detail, matching: find.byType(NullStatus)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: detail,
        matching: find.text(currentAppLocalizations.inProgress),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  Future<Finder> openResponse(
    WidgetTester tester, {
    required String contentType,
    required MitmBody body,
  }) async {
    final exchange = _exchange.copyWith(
      responseHeader: {
        'Content-Type': [contentType],
      },
    );
    await _pumpDetail(
      tester,
      list: MitmExchangeList(
        capturing: true,
        since: _start,
        exchanges: [_summary(exchange)],
      ),
      exchange: exchange,
      responseBody: body,
    );
    await _openTab(tester, currentAppLocalizations.httpRequests);
    await tester.tap(find.text('GET /new?x=1'));
    await tester.pumpAndSettle();
    await _openTab(tester, currentAppLocalizations.response);
    return find.byType(MitmExchangeView);
  }

  testWidgets('a rule not applied or failed says why, passed on only once '
      'over', (tester) async {
    final l = currentAppLocalizations;
    Future<void> open(MitmExchange exchange) async {
      await _pumpDetail(
        tester,
        list: MitmExchangeList(
          capturing: true,
          since: _start,
          exchanges: [_summary(exchange)],
        ),
        exchange: exchange,
      );
      await _openRequest(tester);
    }

    // Too big is what the message is, not an error: not applied.
    const oversize = MitmAction(
      kind: 'body-rewrite',
      phase: 'response',
      skipped: 'oversize',
    );
    final notApplied = l.mitmRewriteNotAppliedTitle(l.mitmRewriteSkipOversize);
    await open(_exchange.copyWith(actions: const [oversize]));
    expect(find.text(notApplied, findRichText: true), findsOneWidget);
    expect(find.text(l.mitmRewritePassedThrough), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await open(_exchange.copyWith(actions: const [oversize], error: 'reset'));
    expect(find.text(notApplied, findRichText: true), findsOneWidget);
    expect(find.text(l.mitmRewritePassedThrough), findsNothing);

    // A body that could not be decoded is a failure.
    await tester.pumpWidget(const SizedBox.shrink());
    const broken = MitmAction(
      kind: 'body-rewrite',
      phase: 'response',
      skipped: 'decodeFailed',
    );
    await open(_exchange.copyWith(actions: const [broken]));
    expect(
      find.text(
        l.mitmRewriteFailedTitle(mitmRewriteSkipText(l, 'decodeFailed')),
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an applied rule says it matched until the request is over, '
      'then applied with its time', (tester) async {
    final l = currentAppLocalizations;
    const hit = MitmAction(
      kind: 'body-rewrite',
      phase: 'response',
      detail: 'body',
      tookNs: 1300000,
    );
    Future<void> open(MitmExchange exchange) async {
      await _pumpDetail(
        tester,
        list: MitmExchangeList(
          capturing: true,
          since: _start,
          exchanges: [_summary(exchange)],
        ),
        exchange: exchange,
      );
      await _openRequest(tester);
    }

    await open(_exchange.copyWith(actions: const [hit], pending: true));
    expect(
      find.textContaining(l.mitmRewriteMatchedTitle, findRichText: true),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await open(_exchange.copyWith(actions: const [hit]));
    expect(
      find.textContaining(l.mitmRewriteAppliedTitle, findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('1.3\u00a0ms'), findsOneWidget);
    expect(mitmRewriteTookText(hit.copyWith(tookNs: 0)), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a side the rules changed shows as it came on request', (
    tester,
  ) async {
    final l = currentAppLocalizations;
    final exchange = _exchange.copyWith(
      actions: const [MitmAction(kind: 'body-rewrite', phase: 'response')],
      originalResponseHeader: const {
        'X-Upstream': ['no'],
      },
      originalResponseBody: true,
    );
    await _pumpDetail(
      tester,
      list: MitmExchangeList(
        capturing: true,
        since: _start,
        exchanges: [_summary(exchange)],
      ),
      exchange: exchange,
      responseBody: MitmBody(data: base64Encode(utf8.encode('after'))),
      originalResponseBody: MitmBody(data: base64Encode(utf8.encode('before'))),
    );
    await _openRequest(tester);
    await _openTab(tester, l.request);
    // Only a side the rules changed offers its original.
    expect(find.text(l.mitmRewriteBefore), findsNothing);

    await _openTab(tester, l.response);
    expect(find.text('yes'), findsOneWidget);
    expect(find.textContaining('after'), findsWidgets);

    await tester.tap(find.text(l.mitmRewriteBefore));
    await tester.pumpAndSettle();
    expect(find.text('no'), findsOneWidget);
    expect(find.text('yes'), findsNothing);
    expect(find.textContaining('before'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a finished request shows its body, and says when only its '
      'start was kept', (tester) async {
    final detail = await openResponse(
      tester,
      contentType: 'application/json; charset=utf-8',
      body: MitmBody(
        data: base64Encode(utf8.encode('{"ok":1}')),
        truncated: true,
      ),
    );

    expect(
      find.descendant(of: detail, matching: find.text('{\n  "ok": 1\n}')),
      findsOneWidget,
    );
    expect(
      find.text(currentAppLocalizations.httpBodyTruncated),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a body that is not text opens its bytes on a page of its own', (
    tester,
  ) async {
    final detail = await openResponse(
      tester,
      contentType: 'application/octet-stream',
      body: MitmBody(data: base64Encode([0, 1, 2, 3]), truncated: true),
    );

    await tester.tap(
      find.descendant(
        of: detail,
        matching: find.text(currentAppLocalizations.binaryData),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('000000  00 01 02 03'), findsOneWidget);
    expect(
      find.text(currentAppLocalizations.httpBodyTruncated),
      findsAtLeastNWidgets(1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a text body also offers its bytes', (tester) async {
    final detail = await openResponse(
      tester,
      contentType: 'text/plain',
      body: MitmBody(data: base64Encode(utf8.encode('hi'))),
    );

    expect(
      find.descendant(
        of: detail,
        matching: find.text(currentAppLocalizations.hex),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a row in the list long-presses to the same menu', (
    tester,
  ) async {
    final exchange = _exchange.copyWith(responseSize: 7);
    await _pumpDetail(
      tester,
      list: MitmExchangeList(
        capturing: true,
        since: _start,
        exchanges: [_summary(exchange)],
      ),
      exchange: exchange,
    );
    await _openTab(tester, currentAppLocalizations.httpRequests);
    await tester.longPress(find.text('GET /new?x=1'));
    await tester.pumpAndSettle();

    for (final label in [
      currentAppLocalizations.copyLink,
      currentAppLocalizations.copyAsCurl,
      currentAppLocalizations.copyRequest,
      currentAppLocalizations.copyResponse,
      currentAppLocalizations.copyResponseBody,
      currentAppLocalizations.exportHar,
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a request copies as cURL once told what it carries', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pumpDetail(
      tester,
      list: MitmExchangeList(
        capturing: true,
        since: _start,
        exchanges: [_summary(_exchange)],
      ),
      exchange: _exchange,
    );
    await _openRequest(tester);
    final l10n = currentAppLocalizations;

    Future<void> copy() async {
      await _openBarMenu(tester);
      await tester.tap(_inMenu(find.text(l10n.copyAsCurl)));
      await tester.pumpAndSettle();
    }

    await copy();
    expect(find.text(l10n.httpExportPrivateTitle), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text(l10n.copyAsCurl).last);
      for (var i = 0; i < 50 && copied.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(copied, [startsWith("curl 'https://a.test/new?x=1'")]);

    await tester.runAsync(() async {
      await copy();
      for (var i = 0; i < 50 && copied.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.text(l10n.httpExportPrivateTitle), findsNothing);
    expect(copied, hasLength(2));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a rule goes to a new module or one the user wrote, and only '
      'an answered request maps locally', (tester) async {
    final now = DateTime.utc(2026);
    final waiting = _exchange.copyWith(pending: true, status: 0);
    for (final exchange in [_exchange, waiting]) {
      await _pumpDetail(
        tester,
        list: MitmExchangeList(
          capturing: true,
          since: _start,
          exchanges: [_summary(exchange)],
        ),
        exchange: exchange,
        modules: [
          MitmModule(id: 1, name: 'Mine', lastUpdateTime: now),
          MitmModule(
            id: 2,
            name: 'Subscribed',
            url: 'https://a.test/m',
            lastUpdateTime: now,
          ),
        ],
      );
      await _openRequest(tester);
      await _openBarMenu(tester);
      final l10n = currentAppLocalizations;
      expect(
        _inMenu(find.text(l10n.mitmAddMapLocalRule)),
        exchange.pending ? findsNothing : findsOneWidget,
      );
      await tester.tap(_inMenu(find.text(l10n.mitmAddRejectRule)));
      await tester.pumpAndSettle();
      expect(_inMenu(find.text(l10n.mitmNewModule)), findsOneWidget);
      expect(_inMenu(find.text('Mine')), findsOneWidget);
      expect(_inMenu(find.text('Subscribed')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a refresh that brings the same requests rebuilds nothing', (
    tester,
  ) async {
    final list = MitmExchangeList(
      capturing: true,
      since: _start,
      exchanges: [_summary(_exchange)],
    );
    final container = await _pumpDetail(tester, list: list);
    await _openTab(tester, currentAppLocalizations.httpRequests);

    var rebuilds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is MitmExchangesView) rebuilds++;
    };
    try {
      container.invalidate(mitmExchangesProvider(_decrypted.id));
      await tester.pumpAndSettle();
    } finally {
      debugOnRebuildDirtyWidget = null;
    }
    expect(rebuilds, 0);
    expect(find.text('GET /new?x=1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a decrypted connection is marked in its row', (tester) async {
    await tester.pumpWidget(
      TestApp(
        wrapInProviderScope: true,
        homeBuilder: (child) => HostScaffold(body: child),
        child: TrackerInfoItem(trackerInfo: _decrypted, detailTitle: 'detail'),
      ),
    );
    await tester.pump();

    expect(find.byGlyph(MitmBadge.decrypted.glyph), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('a request that did not complete says why in words', () {
    final l = lookupAppLocalizations(const Locale('en'));
    expect(mitmExchangeErrorText(l, 'noResponse'), 'No response received');
    expect(mitmExchangeErrorText(l, 'responseFailed'), 'Response interrupted');
    expect(
      mitmExchangeErrorText(l, 'stopped'),
      'Request stopped because decryption settings changed',
    );
    expect(
      mitmExchangeErrorText(l, 'somethingNew'),
      'Request did not complete',
    );
  });

  test('the filter that keeps decrypted requests is named for them', () {
    final facet = trackerInfoFacets.firstWhere(
      (facet) => facet.kind == RecordFacetKind.mitm,
    );
    expect(facet.label('MITM'), currentAppLocalizations.mitmBadgeDecrypted);
  });

  test('a handshake alert is named without guessing its cause', () {
    final zh = lookupAppLocalizations(const Locale('zh'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(zh.mitmBadgeHandshakeFailed, '客户端握手失败');
    expect(zh.mitmOutcomeRefused, '客户端在握手时发出了警报，原因无法确定。');
    expect(en.mitmBadgeHandshakeFailed, 'Client handshake failed');
    expect(
      en.mitmOutcomeRefused,
      'The client sent an alert during the handshake. The cause is unknown.',
    );
    expect(zh.mitmBadgePassedThrough, '未解密 · 原样放行');
    expect(zh.mitmBadgeFailed, '解密失败');
  });

  testWidgets('each row marks what decryption did with a glyph only', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    TrackerInfo row(String id, {String outcome = '', bool mitm = false}) =>
        _decrypted.copyWith(
          id: id,
          mitmOutcome: outcome,
          metadata: Metadata(network: 'tcp', host: '$id.test', mitm: mitm),
        );
    const passed = (
      'Not decrypted · passed through',
      'Not decrypted, passed through',
      MitmBadge.passedThrough,
    );
    const failed = ('Decryption failed', 'Decryption failed', MitmBadge.failed);
    final cases = <TrackerInfo, (String, String, MitmBadge)?>{
      row('plain'): null,
      row('ok', mitm: true): ('Decrypted', 'Decrypted', MitmBadge.decrypted),
      row('late', mitm: true, outcome: 'http1Failed'): (
        'Decrypted',
        'Decrypted',
        MitmBadge.decrypted,
      ),
      row('paused', outcome: 'paused'): passed,
      row('hello', outcome: 'unsupportedHello'): passed,
      row('sni', outcome: 'missingSNI'): passed,
      row('h2', outcome: 'http2Only'): passed,
      row('alert', outcome: 'refused'): (
        'Client handshake failed',
        'Client handshake failed',
        MitmBadge.handshakeFailed,
      ),
      row('cert', outcome: 'upstreamCertificate'): failed,
      row('client', outcome: 'clientFailed'): failed,
      // Decrypted by the Core's word: never also called passed through.
      row('both', mitm: true, outcome: 'http2Only'): (
        'Decrypted',
        'Decrypted',
        MitmBadge.decrypted,
      ),
      // No word from the Core, or one it never sends: no claim at all.
      row('unknown', outcome: 'protocolUnsupported'): null,
    };
    for (final MapEntry(key: info, value: want) in cases.entries) {
      await tester.pumpWidget(
        TestApp(
          wrapInProviderScope: true,
          homeBuilder: (child) => HostScaffold(body: child),
          child: TrackerInfoItem(trackerInfo: info, detailTitle: 'detail'),
        ),
      );
      await tester.pump();
      expect(find.byType(RecordLabel), findsNothing, reason: info.id);
      final icon = find.byType(MitmBadgeIcon);
      if (want == null) {
        expect(
          find.descendant(of: icon, matching: find.byType(GlyphIcon)),
          findsNothing,
          reason: info.id,
        );
        continue;
      }
      final (tooltip, spoken, badge) = want;
      expect(MitmBadge.of(info), badge, reason: info.id);
      final glyph = tester.widget<GlyphIcon>(
        find.descendant(of: icon, matching: find.byType(GlyphIcon)),
      );
      expect(glyph.glyph, badge.glyph, reason: info.id);
      expect(glyph.size, 14);
      expect(find.text(tooltip), findsNothing, reason: info.id);
      expect(
        tester
            .widget<Tooltip>(
              find.descendant(of: icon, matching: find.byType(Tooltip)),
            )
            .message,
        tooltip,
      );
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(spoken))),
        findsWidgets,
        reason: info.id,
      );
    }

    final context = tester.element(find.byType(TrackerInfoItem));
    expect(MitmBadge.passedThrough.color(context), const Color(0xFF8E8C94));
    expect(MitmBadge.handshakeFailed.color(context), const Color(0xFFB25E00));
    semantics.dispose();

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'an unsupported protocol says why, and passed through only when the Core said so',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final requests = container.read(requestsProvider.notifier);
      TrackerInfo base(String id) => _decrypted.copyWith(
        id: id,
        mitmOutcome: '',
        metadata: Metadata(network: 'tcp', host: '$id.test'),
      );
      requests.addRequest(base('confirmed'));
      requests.addRequest(base('unconfirmed'));
      requests.addRequest(base('unknown'));
      // The Core reports http2Only as it relays the connection untouched.
      requests.setMitmOutcome('confirmed', 'http2Only');
      requests.setMitmOutcome('unknown', 'protocolUnsupported');
      final state = container.read(requestsProvider);
      TrackerInfo byId(String id) => state.list.firstWhere((r) => r.id == id);
      expect(byId('confirmed').mitmOutcome, 'http2Only');
      expect(MitmBadge.of(byId('confirmed')), MitmBadge.passedThrough);
      expect(MitmBadge.of(byId('unconfirmed')), isNull);
      expect(byId('unknown').mitmOutcome, '');
      expect(MitmBadge.of(byId('unknown')), isNull);

      for (final (locale, reason, passed) in [
        (const Locale('zh'), '当前连接使用的协议不支持解密。', '未解密 · 原样放行'),
        (
          const Locale('en'),
          "This connection uses a protocol that can't be decrypted.",
          'Not decrypted · passed through',
        ),
      ]) {
        final l = lookupAppLocalizations(locale);
        expect(l.mitmOutcomeHTTP1Unsupported, reason);
        expect(l.mitmBadgePassedThrough, passed);
      }
      final zh = lookupAppLocalizations(const Locale('zh'));
      expect(zh.mitmHttp2, 'HTTP/2 解密');
      expect(zh.mitmHttp2Desc, '关闭后，仅解密 HTTP/1.1 连接；仅支持 HTTP/2 的连接不会解密。');
      final en = lookupAppLocalizations(const Locale('en'));
      expect(en.mitmHttp2, 'Decrypt HTTP/2');
      expect(
        en.mitmHttp2Desc,
        "When off, only HTTP/1.1 connections are decrypted; connections that support only HTTP/2 won't be decrypted.",
      );

      // The detail names the reason; the glyph's words say passed through.
      for (final (info, passedThrough) in [
        (byId('confirmed'), true),
        (byId('unconfirmed'), false),
      ]) {
        await tester.pumpWidget(
          TestApp(
            wrapInProviderScope: true,
            homeBuilder: (child) => HostScaffold(body: child),
            child: TrackerInfoItem(trackerInfo: info, detailTitle: 'detail'),
          ),
        );
        await tester.pump();
        final tooltips = tester
            .widgetList<Tooltip>(find.byType(Tooltip))
            .map((t) => t.message);
        expect(
          tooltips.contains('Not decrypted · passed through'),
          passedThrough,
          reason: info.id,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
