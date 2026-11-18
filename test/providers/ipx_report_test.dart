import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/ipx_report.dart';
import 'package:fl_clash/providers/route_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

const _ip = '8.8.8.8';
const _other = '185.220.101.1';

String _fixture(String name) =>
    File('test/fixtures/ipx_al/$name').readAsStringSync();

String _me(String ip) => _fixture('me.json').replaceAll('198.51.100.20', ip);

/// Answers each url from [bodies]; a [Completer] holds the answer back.
class _FakeFetch {
  _FakeFetch(this.bodies);

  final Map<String, Object?> bodies;
  final calls = <String>[];
  final maxBodies = <String, int?>{};

  Future<IpxAnswer?> call(
    String url, {
    required Duration timeout,
    int? maxBody,
  }) async {
    calls.add(url);
    maxBodies[url] = maxBody;
    final body = switch (bodies[url]) {
      final Completer<String?> completer => await completer.future,
      final String body => body,
      _ => null,
    };
    return body == null ? null : IpxAnswer(body, viaProxy: true);
  }
}

class _MockCore extends Mock implements CoreHandlerInterface {}

ProviderContainer _container(_FakeFetch fetch) {
  final container = ProviderContainer(
    overrides: [ipxFetchProvider.overrideWithValue(fetch.call)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<IpxLookupState> _settled(ProviderContainer container, String ip) async {
  final sub = container.listen(ipxLookupProvider(ip), (_, _) {});
  addTearDown(sub.close);
  for (
    var i = 0;
    i < 20 && container.read(ipxLookupProvider(ip)).isLoading;
    i++
  ) {
    await Future<void>.delayed(Duration.zero);
  }
  return container.read(ipxLookupProvider(ip));
}

void main() {
  setUpAll(() => registerFallbackValue(const OutboundIpParams(timeout: 0)));

  test('fills in the brief, then the report', () async {
    final report = Completer<String?>();
    final fetch = _FakeFetch({
      ipxAlMeUrl: _me(_ip),
      ipxAlReportUrl(_ip): report,
    });
    final container = _container(fetch);
    container.listen(ipxLookupProvider(_ip), (_, _) {});

    expect(container.read(ipxLookupProvider(_ip)).phase, IpxPhase.loading);
    await Future<void>.delayed(Duration.zero);
    final partial = container.read(ipxLookupProvider(_ip));
    expect(partial.phase, IpxPhase.partial);
    expect(partial.brief?.city, 'Irvine');
    expect(partial.report, isNull);

    report.complete(_fixture('report_8.8.8.8.json'));
    await Future<void>.delayed(Duration.zero);
    final done = container.read(ipxLookupProvider(_ip));
    expect(done.phase, IpxPhase.done);
    expect(done.report?.score, 55);
    expect(done.brief?.city, 'Irvine');
    expect(done.viaProxy, isTrue);
    expect(fetch.maxBodies[ipxAlReportUrl(_ip)], ipxReportMaxBody);
  });

  test('keeps a report per exit address for the session', () async {
    final fetch = _FakeFetch({
      ipxAlMeUrl: _me(_ip),
      ipxAlReportUrl(_ip): _fixture('report_8.8.8.8.json'),
      ipxAlReportUrl(_other): _fixture('report_185.220.101.1.json'),
    });
    final container = _container(fetch);

    expect((await _settled(container, _ip)).report?.ip, _ip);
    expect((await _settled(container, _other)).report?.ip, _other);
    // Opening the detail again, and asking it to retry, keep what came.
    container.read(ipxLookupProvider(_ip).notifier).retry();
    expect((await _settled(container, _ip)).report?.score, 55);

    expect(
      fetch.calls.where((url) => url == ipxAlReportUrl(_ip)),
      hasLength(1),
    );
    expect(
      fetch.calls.where((url) => url == ipxAlReportUrl(_other)),
      hasLength(1),
    );
  });

  test('ignores a brief of another exit', () async {
    final report = Completer<String?>();
    final fetch = _FakeFetch({
      ipxAlMeUrl: _me(_other),
      ipxAlReportUrl(_ip): report,
    });
    final container = _container(fetch);
    container.listen(ipxLookupProvider(_ip), (_, _) {});
    await Future<void>.delayed(Duration.zero);

    expect(container.read(ipxLookupProvider(_ip)).phase, IpxPhase.loading);
    expect(container.read(ipxLookupProvider(_ip)).brief, isNull);
    report.complete(null);
  });

  for (final (name, body) in [
    ('no answer', null),
    ('a page that is no report', '<!doctype html><title>429</title>'),
    ('a cut-off report', _fixture('report_8.8.8.8.json').substring(0, 4096)),
    ('a report of another address', _fixture('report_185.220.101.1.json')),
  ]) {
    test('fails quietly on $name, and asks again on retry', () async {
      final fetch = _FakeFetch({
        ipxAlMeUrl: _me(_ip),
        ipxAlReportUrl(_ip): body,
      });
      final container = _container(fetch);

      final failed = await _settled(container, _ip);
      expect(failed.phase, IpxPhase.failed);
      expect(failed.report, isNull);

      final report = Completer<String?>();
      fetch.bodies[ipxAlReportUrl(_ip)] = report;
      container.read(ipxLookupProvider(_ip).notifier).retry();
      // The fallback stays up while ipx.al is asked again, once.
      final retrying = container.read(ipxLookupProvider(_ip));
      expect(retrying.phase, IpxPhase.failed);
      expect(retrying.retrying, isTrue);
      expect(retrying.isLoading, isTrue);
      container.read(ipxLookupProvider(_ip).notifier).retry();
      container.read(ipxLookupProvider(_ip).notifier).reload();
      expect(
        fetch.calls.where((url) => url == ipxAlReportUrl(_ip)),
        hasLength(2),
      );

      report.complete(_fixture('report_8.8.8.8.json'));
      expect((await _settled(container, _ip)).phase, IpxPhase.done);
    });
  }

  test('starts over from the skeletons on reload', () async {
    final fetch = _FakeFetch({ipxAlMeUrl: _me(_ip)});
    final container = _container(fetch);
    expect((await _settled(container, _ip)).phase, IpxPhase.failed);

    container.read(ipxLookupProvider(_ip).notifier).reload();
    expect(container.read(ipxLookupProvider(_ip)).phase, IpxPhase.loading);
    expect((await _settled(container, _ip)).phase, IpxPhase.failed);
  });

  group('ipxFetch', () {
    late _MockCore core;

    ProviderContainer build({required bool live, required bool proxied}) {
      core = _MockCore();
      final container = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          routeTrackerProvider.overrideWithBuild(
            (_, _) => RouteState(live: live, proxied: proxied, synced: true),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('asks the Core through the routed exit', () async {
      final container = build(live: true, proxied: true);
      when(() => core.outboundIp(any())).thenAnswer(
        (_) async => const OutboundIpResult(
          body: '{"ip":"8.8.8.8"}',
          chains: ['HK 01', 'Auto', 'Proxy'],
        ),
      );

      final answer = await container.read(ipxFetchProvider)(
        ipxAlReportUrl(_ip),
        timeout: ipxReportTimeout,
        maxBody: ipxReportMaxBody,
      );

      expect(answer?.body, '{"ip":"8.8.8.8"}');
      expect(answer?.viaProxy, isTrue);
      final params =
          verify(() => core.outboundIp(captureAny())).captured.single
              as OutboundIpParams;
      expect(params.proxyName, routedOutbound);
      expect(params.urls, [ipxAlReportUrl(_ip)]);
      expect(params.timeout, ipxReportTimeout.inMilliseconds);
      expect(params.maxBody, ipxReportMaxBody);
      expect(params.toJson()['max-body'], ipxReportMaxBody);
    });

    test('goes direct when not proxying, and answers null on errors', () async {
      final container = build(live: true, proxied: false);
      when(() => core.outboundIp(any())).thenAnswer(
        (_) async => const OutboundIpResult(error: probeErrorTimeout),
      );

      expect(
        await container.read(ipxFetchProvider)(
          ipxAlMeUrl,
          timeout: ipxBriefTimeout,
        ),
        isNull,
      );
      final params =
          verify(() => core.outboundIp(captureAny())).captured.single
              as OutboundIpParams;
      expect(params.proxyName, directOutbound);
      expect(params.toJson().containsKey('max-body'), isFalse);

      when(() => core.outboundIp(any())).thenThrow(StateError('gone'));
      expect(
        await container.read(ipxFetchProvider)(
          ipxAlMeUrl,
          timeout: ipxBriefTimeout,
        ),
        isNull,
      );
    });

    for (final (name, chains) in [
      ('a rule picked DIRECT', [directOutbound]),
      ('the Core named no route', <String>[]),
    ]) {
      test('claims no proxy exit when $name', () async {
        final container = build(live: true, proxied: true);
        when(
          () => core.outboundIp(any()),
        ).thenAnswer((_) async => OutboundIpResult(body: '{}', chains: chains));

        final answer = await container.read(ipxFetchProvider)(
          ipxAlMeUrl,
          timeout: ipxBriefTimeout,
        );

        expect(answer?.body, '{}');
        expect(answer?.viaProxy, isFalse);
      });
    }

    test('does not ask without a live route', () async {
      final container = build(live: false, proxied: true);

      expect(
        await container.read(ipxFetchProvider)(
          ipxAlMeUrl,
          timeout: ipxBriefTimeout,
        ),
        isNull,
      );
      verifyNever(() => core.outboundIp(any()));
    });
  });
}
