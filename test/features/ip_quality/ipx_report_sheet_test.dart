import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/ip_quality/ip_quality.dart';
import 'package:fl_clash/features/ip_quality/ipx_report_view.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/ipx_report.dart';
import 'package:fl_clash/ui/fonts.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../../helpers/host_scaffold.dart';
import '../../helpers/test_app.dart';

const _ip = '185.220.101.1';

const _quality = IpQuality(
  ip: _ip,
  source: IpQualitySource.ipLocate,
  type: IpType.hosting,
  organization: 'Example Hosting',
  asn: 64500,
);

String _fixture(String name) =>
    File('test/fixtures/ipx_al/$name').readAsStringSync();

class _Fetch {
  _Fetch(this.bodies, {this.viaProxy = true});

  final Map<String, Object?> bodies;
  final bool viaProxy;
  final calls = <String>[];

  Future<IpxAnswer?> call(
    String url, {
    required Duration timeout,
    int? maxBody,
  }) async {
    calls.add(url);
    final body = switch (bodies[url]) {
      final Completer<String?> completer => await completer.future,
      final String body => body,
      _ => null,
    };
    return body == null ? null : IpxAnswer(body, viaProxy: viaProxy);
  }
}

/// The report of [_ip] reworked by [edit].
String _reportWith(void Function(Map<String, dynamic> report) edit) {
  final json =
      jsonDecode(_fixture('report_185.220.101.1.json')) as Map<String, dynamic>;
  edit(json);
  return jsonEncode(json);
}

Color? _colorOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

Widget _app(_Fetch fetch, {Locale locale = const Locale('en')}) => TestApp(
  locale: locale,
  overrides: [
    ipQualityProvider.overrideWith((_, _) async => _quality),
    ipxFetchProvider.overrideWithValue(fetch.call),
  ],
  child: HostScaffold(
    body: Builder(
      builder: (context) => GestureDetector(
        onTap: () => showIpQualitySheet(context, ip: _ip, countryCode: 'DE'),
        child: const SizedBox(width: 100, height: 40, child: Text('open')),
      ),
    ),
  ),
);

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('lays out the whole report', (tester) async {
    _useTallView(tester);
    final fetch = _Fetch({
      ipxAlReportUrl(_ip): _fixture('report_185.220.101.1.json'),
    });
    await tester.pumpWidget(_app(fetch));
    await _open(tester);

    expect(find.text('Health score'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('D · High risk'), findsOneWidget);
    // The card states the cap alone; type and origin have their rows.
    expect(find.text('Type cap 55'), findsOneWidget);
    expect(find.text('Data center'), findsOneWidget);
    expect(find.text('Native IP'), findsOneWidget);
    expect(find.text('IP origin'), findsOneWidget);
    expect(find.text('Registered DE · used in DE'), findsOneWidget);
    expect(find.text('DE · Brandenburg an der Havel'), findsOneWidget);
    expect(find.text('AS60729'), findsOneWidget);
    expect(find.text('Score breakdown'), findsOneWidget);
    expect(find.text('Full report on ipx.al'), findsOneWidget);
    expect(find.text('Data from ipx.al, for reference only'), findsOneWidget);
    expect(find.text('Queried through the current exit'), findsOneWidget);
    // The attribution starts where the section titles do.
    expect(
      tester.getTopLeft(find.text('Data from ipx.al, for reference only')).dx,
      tester.getTopLeft(find.text('Score breakdown')).dx,
    );
    expect(
      find.text('Relies on a third-party API; for reference only'),
      findsNothing,
    );

    // The address reads as body text in a monospaced face; red is for the
    // grade and the points.
    final address = tester.widget<Text>(find.text(_ip)).style;
    final context = tester.element(find.text(_ip));
    final error = context.colorScheme.error;
    expect(address?.color, isNot(error));
    expect(address?.fontFamily, const TextStyle().toJetBrainsMono.fontFamily);
    expect(_colorOf(tester, 'D · High risk'), error);
    expect(_colorOf(tester, '−40'), error);
    // The check that took nothing, last in the breakdown, in grey.
    expect(
      tester.widget<Text>(find.text('0').last).style?.color,
      context.colorScheme.onSurfaceVariant,
    );

    // Most points off first, the checks that took none last.
    final rows = [
      'Tor 出口',
      'DNSBL 命中 4/13',
      '同段 /24 有 133 个 IP 在风险库',
      '仅在垃圾注册名单',
      '仅 1 源标记为代理',
    ];
    final tops = [for (final row in rows) tester.getTopLeft(find.text(row)).dy];
    expect(tops, orderedEquals([...tops]..sort()));
    // The multi-source rows give way to the report.
    expect(find.text('Answered by'), findsNothing);
    expect(find.byType(SkeletonText), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows what is known while the report is on its way', (
    tester,
  ) async {
    _useTallView(tester);
    final report = Completer<String?>();
    final fetch = _Fetch({ipxAlReportUrl(_ip): report});
    await tester.pumpWidget(_app(fetch));
    await _open(tester);

    expect(find.text(_ip), findsOneWidget);
    expect(find.text('DE'), findsOneWidget);
    expect(find.text('Example Hosting'), findsOneWidget);
    expect(find.text('AS64500'), findsOneWidget);
    expect(find.byType(SkeletonText), findsWidgets);
    expect(find.text('Tor 出口'), findsNothing);

    report.complete(_fixture('report_185.220.101.1.json'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Tor 出口'), findsOneWidget);
    expect(find.byType(SkeletonText), findsNothing);
  });

  testWidgets('falls back to the earlier detail and offers ipx.al again', (
    tester,
  ) async {
    _useTallView(tester);
    final fetch = _Fetch({});
    await tester.pumpWidget(_app(fetch));
    await _open(tester);

    // The way back sits where the score would be.
    expect(find.text('Health score'), findsOneWidget);
    expect(find.text('Couldn’t get report'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Couldn’t get report')).dy,
      lessThan(tester.getTopLeft(find.text('Answered by')).dy),
    );
    expect(find.text('Answered by'), findsOneWidget);
    expect(find.text('ISP'), findsOneWidget);
    expect(find.text('Organization'), findsNothing);
    expect(find.text('Example Hosting'), findsOneWidget);
    expect(find.text('Data center'), findsOneWidget);
    expect(find.text('Data from ipx.al, for reference only'), findsNothing);
    expect(
      find.text('Relies on a third-party API; for reference only'),
      findsNothing,
    );

    final report = Completer<String?>();
    fetch.bodies[ipxAlReportUrl(_ip)] = report;
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pump();

    // A spinner stands in for the button until ipx.al answers, and the
    // header's refresh spins along, neither of them tappable.
    expect(find.widgetWithText(TextButton, 'Retry'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(IpxFailedItem),
        matching: find.byType(ActivityIndicator),
      ),
      findsOneWidget,
    );
    expect(find.text('Couldn’t get report'), findsOneWidget);
    final refresh = find.byTooltip('Check again');
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: refresh, matching: find.byType(IconButton)).first,
          )
          .onPressed,
      isNull,
    );
    await tester.tap(refresh, warnIfMissed: false);
    await tester.tap(find.byType(IpxFailedItem), warnIfMissed: false);
    await tester.pump();
    expect(
      fetch.calls.where((url) => url == ipxAlReportUrl(_ip)),
      hasLength(2),
    );

    report.complete(_fixture('report_185.220.101.1.json'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('D · High risk'), findsOneWidget);
    expect(find.text('Couldn’t get report'), findsNothing);
    expect(
      fetch.calls.where((url) => url == ipxAlReportUrl(_ip)),
      hasLength(2),
    );
  });

  testWidgets('the refresh spinner cannot be tapped while loading', (
    tester,
  ) async {
    _useTallView(tester);
    final report = Completer<String?>();
    final fetch = _Fetch({ipxAlReportUrl(_ip): report});
    await tester.pumpWidget(_app(fetch));
    await _open(tester);

    final refresh = find.byTooltip('Check again');
    final button = find
        .ancestor(of: refresh, matching: find.byType(IconButton))
        .first;
    expect(tester.widget<IconButton>(button).onPressed, isNull);
    expect(
      find.descendant(of: button, matching: find.byType(ActivityIndicator)),
      findsOneWidget,
    );
    await tester.tap(refresh, warnIfMissed: false);
    await tester.pump();
    expect(
      fetch.calls.where((url) => url == ipxAlReportUrl(_ip)),
      hasLength(1),
    );

    report.complete(_fixture('report_185.220.101.1.json'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.widget<IconButton>(button).onPressed, isNotNull);
  });

  testWidgets('reads unknown for what the report leaves out', (tester) async {
    _useTallView(tester);
    final fetch = _Fetch(viaProxy: false, {
      ipxAlReportUrl(_ip): _reportWith((report) {
        final health = report['health'] as Map<String, dynamic>
          ..remove('score')
          ..remove('ceiling')
          ..remove('ipType');
        (report['type'] as Map<String, dynamic>)['verdict'] = 'something new';
        (health['items'] as List).first.remove('pts');
      }),
    });
    await tester.pumpWidget(_app(fetch));
    await _open(tester);

    // No score, so no grade; no type ipx.al names, so none guessed.
    expect(find.text('Health score'), findsOneWidget);
    expect(find.textContaining('High risk'), findsNothing);
    expect(find.text('Type cap Unknown'), findsOneWidget);
    expect(find.text('Unknown'), findsAtLeastNWidgets(3));
    expect(find.text('Data center'), findsNothing);
    // A check that did not say what it took goes last.
    expect(
      tester.getTopLeft(find.text('Tor 出口')).dy,
      greaterThan(tester.getTopLeft(find.text('仅 1 源标记为代理')).dy),
    );
    // DIRECT: nothing claims the current exit.
    expect(find.text('Queried through the current exit'), findsNothing);
    expect(find.text('Data from ipx.al, for reference only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('asks ipx.al once per exit for the session', (tester) async {
    _useTallView(tester);
    final fetch = _Fetch({
      ipxAlReportUrl(_ip): _fixture('report_185.220.101.1.json'),
    });
    await tester.pumpWidget(_app(fetch));
    await _open(tester);
    await tester.tap(find.byTooltip('Check again'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      fetch.calls.where((url) => url == ipxAlReportUrl(_ip)),
      hasLength(1),
    );
  });

  testWidgets('keeps the Chinese copy', (tester) async {
    _useTallView(tester);
    final fetch = _Fetch({
      ipxAlReportUrl(_ip): _fixture('report_185.220.101.1.json'),
    });
    await tester.pumpWidget(_app(fetch, locale: const Locale('zh', 'CN')));
    await _open(tester);

    expect(find.text('健康分'), findsOneWidget);
    expect(find.text('D · 高风险'), findsOneWidget);
    expect(find.text('扣分明细'), findsOneWidget);
    expect(find.text('ipx.al 查看完整报告'), findsOneWidget);
    expect(find.text('类型上限 55'), findsOneWidget);
    expect(find.text('数据来自 ipx.al，仅供参考'), findsOneWidget);
    expect(find.text('经当前出口查询'), findsOneWidget);
  });
}
