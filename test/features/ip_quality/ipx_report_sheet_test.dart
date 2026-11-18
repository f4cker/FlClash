import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/ip_quality/ip_quality.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/ipx_report.dart';
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
  _Fetch(this.bodies);

  final Map<String, Object?> bodies;
  final calls = <String>[];

  Future<String?> call(String url, {required Duration timeout, int? maxBody}) {
    calls.add(url);
    return switch (bodies[url]) {
      final Completer<String?> completer => completer.future,
      final String body => Future.value(body),
      _ => Future.value(null),
    };
  }
}

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
    expect(find.text('Type cap 55'), findsOneWidget);
    expect(find.text('Data center'), findsNWidgets(2));
    expect(find.text('Native IP'), findsNWidgets(2));
    expect(find.text('Registered DE · used in DE'), findsOneWidget);
    expect(find.text('DE · Brandenburg an der Havel'), findsOneWidget);
    expect(find.text(_ip), findsOneWidget);
    expect(find.text('AS60729'), findsOneWidget);
    expect(find.text('Score breakdown'), findsOneWidget);
    expect(find.text('Tor 出口'), findsOneWidget);
    expect(find.text('−40'), findsOneWidget);
    expect(find.text('−15'), findsOneWidget);
    expect(find.text('Full report on ipx.al'), findsOneWidget);
    expect(
      find.text(
        'Report by ipx.al, an unofficial API, asked through the current '
        'exit. For reference only.',
      ),
      findsOneWidget,
    );
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

    expect(find.text('Health score'), findsNothing);
    expect(find.text('Answered by'), findsOneWidget);
    expect(find.text('Example Hosting'), findsOneWidget);
    expect(find.text('Data center'), findsOneWidget);
    expect(find.text('Get the ipx.al report'), findsOneWidget);
    expect(find.textContaining('fail'), findsNothing);

    fetch.bodies[ipxAlReportUrl(_ip)] = _fixture('report_185.220.101.1.json');
    await tester.tap(find.text('Get the ipx.al report'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Health score'), findsOneWidget);
    expect(find.text('Get the ipx.al report'), findsNothing);
    expect(
      fetch.calls.where((url) => url == ipxAlReportUrl(_ip)),
      hasLength(2),
    );
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
  });
}
