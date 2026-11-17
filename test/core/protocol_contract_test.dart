import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/core/event.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/core/spill.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingCoreHandler extends CoreHandlerInterface {
  final Map<CoreMethod, Object?> calls = {};

  @override
  Future<CoreLifecycleResult> start() async => const CoreLifecycleResult(
    revision: 1,
    outcome: CoreLifecycleOutcome.applied,
  );

  @override
  Future<CoreLifecycleResult> restart() => start();

  @override
  Future<CoreLifecycleResult> stop() => start();

  @override
  Future<CoreLifecycleResult> close() => start();

  @override
  Future<Object?> invokeMethod({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
    CoreResultModel? model,
  }) async {
    calls[method] = arguments;
    final result = switch (method) {
      CoreMethod.coreInitialized => true,
      CoreMethod.trafficCurrent ||
      CoreMethod.trafficTotal => {'up': 12, 'down': 34},
      CoreMethod.proxyTestDelay => {
        'name': 'DIRECT',
        'url': 'https://example.com',
        'value': 42,
      },
      CoreMethod.connectionList => {
        'connections': [
          {
            'id': 'connection-1',
            'metadata': {'network': 'tcp'},
            'upload': 0,
            'download': 0,
            'start': '2024-01-01',
            'chains': ['DIRECT'],
            'rule': 'DIRECT',
            'rulePayload': '',
          },
        ],
      },
      CoreMethod.providerList => [
        {
          'name': 'provider-1',
          'type': 'Proxy',
          'count': 1,
          'vehicle-type': 'HTTP',
          'update-at': '2024-01-01T00:00:00.000Z',
        },
      ],
      CoreMethod.providerGet => {
        'name': 'provider-1',
        'type': 'Proxy',
        'count': 1,
        'vehicle-type': 'HTTP',
        'update-at': '2024-01-01T00:00:00.000Z',
      },
      CoreMethod.configRead => {
        'mode': 'rule',
        'rule': ['MATCH,DIRECT'],
      },
      CoreMethod.profileOutbounds => {
        'proxies': [
          {'name': 'a', 'type': 'ss'},
        ],
        'proxy-groups': <Object>[],
      },
      CoreMethod.proxyDefinition
          when arguments is Map && arguments['name'] == 'a' =>
        {
          'name': 'a',
          'type': 'ss',
          'plugin-opts': {'mode': 'websocket'},
        },
      CoreMethod.profileBuild => '/home/responses/1.yaml',
      CoreMethod.profileBase => {
        'config': {'mode': 'rule', 'rule': null},
        'digest': 'abc',
        'match-rules': ['MATCH,DIRECT'],
        'proxies': 2,
        'proxy-groups': 1,
        'rules': 3,
      },
      CoreMethod.coreMemory => {
        'rss': 2048,
        'heap-inuse': 1024,
        'heap-idle': 256,
        'stack-inuse': 64,
        'runtime-other': 32,
      },
      CoreMethod.proxySelect => {'message': '', 'changed': true},
      CoreMethod.ruleSetCompile => {'behavior': 'ipcidr', 'format': 'text'},
      CoreMethod.ruleSetDump => '/home/responses/2.yaml',
      CoreMethod.ruleLookup => <String, Object?>{},
      CoreMethod.configDecrypt => 'mode: rule',
      CoreMethod.connectionCount => 3,
      CoreMethod.proxyValidate || CoreMethod.filterValidate => [
        {'index': 1, 'message': 'missing closing )'},
      ],
      CoreMethod.mitmValidate => {
        'url-rewrite': [
          {'index': 1, 'message': 'unknown type "x"'},
        ],
      },
      CoreMethod.mitmCertificate => {
        'pem': '-----BEGIN CERTIFICATE-----',
        'fingerprint': 'AB:CD',
        'subject': 'FlClash CA 0000ABCD',
        'not-before': '2026-10-20T00:00:00Z',
        'not-after': '2036-10-22T00:00:00Z',
      },
      CoreMethod.mitmIssueCertificate => '-----BEGIN CERTIFICATE-----',
      CoreMethod.mitmExchanges => {
        'capturing': true,
        'since': '2026-10-28T00:00:00Z',
        'exchanges': [
          {
            'id': 7,
            'start': '2026-10-28T00:00:01Z',
            'pending': true,
            'duration': 12,
            'method': 'GET',
            'url': 'https://a.test/x',
            'status': 0,
            'request-size': 0,
            'response-size': 0,
          },
        ],
      },
      CoreMethod.tailscaleNodes => [_tailscaleNode],
      CoreMethod.tailscaleStart => _tailscaleNode,
      CoreMethod.tailscaleStatus => {
        'node': _tailscaleNode,
        'auth-url-ready': false,
        'have-node-key': true,
        'self': {
          'id': 'n1',
          'host-name': 'mac',
          'user-id': '7',
          'addresses': ['100.64.0.1'],
          'tags': <String>[],
          'online': true,
          'key-expiry': '2027-01-01T00:00:00Z',
        },
        'login-user': {'id': '7', 'login-name': 'me@example.test'},
        'tailnet': {'name': 'example.test', 'magic-dns-suffix': 'x.ts.net'},
        'users': {
          '7': {'id': '7', 'login-name': 'me@example.test'},
        },
        'peers': [
          {
            'id': 'n2',
            'user-id': '8',
            'alt-sharer-user-id': '9',
            'addresses': ['100.64.0.2'],
            'tags': <String>[],
            'exit-node-option': true,
          },
        ],
        'prefs': {'exit-node-id': 'n2', 'accept-routes': true},
        'health': <String>[],
      },
      CoreMethod.tailscaleLogin => {
        'generation': 3,
        'state': 'NeedsLogin',
        'auth-url': 'https://login.tailscale.com/a/x',
        'pending': false,
      },
      CoreMethod.tailscaleLogout => {
        'generation': 3,
        'state': 'NeedsLogin',
        'outcome': 'unknown',
        'server-confirmed': false,
        'identity-cleared': true,
        'error': {'code': 'tailscale_logout_failed', 'message': 'x'},
      },
      CoreMethod.tailscaleSetPrefs => {
        'generation': 3,
        'outcome': 'not-running',
      },
      CoreMethod.tailscaleMigrateLegacy => {
        'generation': 3,
        'migration': _tailscaleMigration,
        'node': _tailscaleNode,
        'reapply-required': true,
        'outcome': 'failed',
        'target-untouched': true,
        'archive-intact': false,
        'stage': 'claim',
        'error': {'code': 'tailscale_migrate_failed', 'message': 'x'},
      },
      CoreMethod.routeWatch => {
        'core-epoch': 1,
        'route-version': 0,
        'running': true,
      },
      CoreMethod.routeCheck => {
        'core-epoch': 1,
        'route-version': 3,
        'held': [true, false],
      },
      _ => null,
    };
    return model == null ? result : model(result);
  }
}

class _FailingConfigCoreHandler extends _RecordingCoreHandler {
  @override
  Future<Object?> invokeMethod({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
    CoreResultModel? model,
  }) async {
    if (method == CoreMethod.configRead) {
      throw const CoreMethodException(
        code: 'core_error',
        message: 'config not found',
        details: {'path': '/missing.yaml'},
      );
    }
    return super.invokeMethod(
      method: method,
      arguments: arguments,
      timeout: timeout,
      model: model,
    );
  }
}

class _EmptyConfigCoreHandler extends _RecordingCoreHandler {
  @override
  Future<Object?> invokeMethod({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
    CoreResultModel? model,
  }) async {
    if (method == CoreMethod.configRead) {
      return null;
    }
    return super.invokeMethod(
      method: method,
      arguments: arguments,
      timeout: timeout,
      model: model,
    );
  }
}

const _tailscaleNode = {
  'profile-id': 42,
  'name': 'ts',
  'generation': 3,
  'control-url': 'https://controlplane.tailscale.com',
  'hostname': 'mac',
  'state-dir-mode': 'derived',
  'started': true,
  'backend-state': 'Running',
  'logged-out': false,
  'has-identity': true,
  'auth-key': false,
  'ephemeral': false,
  'overridable': true,
  'settings': {
    'exit-node': {'value': '100.64.0.2', 'source': 'override'},
    'accept-routes': {'value': true, 'source': 'provider'},
  },
  'warnings': ['legacy-shared-state-present'],
  'legacy': {
    'login-name': 'old@example.test',
    'display-name': 'Old',
    'tailnet': 'example.test',
    'control-url': 'https://controlplane.tailscale.com',
    'fingerprint': 'f1',
    'eligibility': 'control-mismatch',
    'offer-token': 't1',
  },
};

const _tailscaleMigration = {
  'fingerprint': 'f1',
  'profile-id': 42,
  'name': 'ts',
  'control-url': 'https://controlplane.tailscale.com',
};

void main() {
  test('method call keeps structured arguments', () async {
    final fixture =
        json.decode(
              await File('test/fixtures/core_protocol.json').readAsString(),
            )
            as Map<String, dynamic>;
    final call = CoreMethodCall.fromJson(
      Map<String, Object?>.from(fixture['methodCall'] as Map),
    );

    expect(call.method, CoreMethod.configUpdate);
    expect(call.arguments, isA<Map<String, dynamic>>());
    expect((call.arguments as Map)['mixed-port'], 7890);
    expect(call.toJson(), containsPair('arguments', call.arguments));
    expect(call.toJson(), isNot(contains('data')));
  });

  test('the Dart and Go method tables name the same methods', () async {
    final protocol = await File('core/protocol.go').readAsString();
    final goNames = {
      for (final match in RegExp(
        r'^\s*\w+Method\s+CoreMethod\s*=\s*"([^"]+)"',
        multiLine: true,
      ).allMatches(protocol))
        match.group(1)!,
    };

    expect(goNames, isNotEmpty);
    expect({for (final method in CoreMethod.values) method.wireName}, goNames);
  });

  test('the legacy eligibilities and outcomes match the Go names', () async {
    final source = [
      await File('core/tailscale.go').readAsString(),
      await File('core/tailscale_legacy.go').readAsString(),
    ].join();
    String? valueOf(String name) =>
        RegExp('$name\\s*=\\s*"([a-z-]+)"').firstMatch(source)?.group(1);
    const eligibilities = {
      'tailscaleLegacyEligible': TailscaleLegacyEligibility.eligible,
      'tailscaleLegacyHasIdentity': TailscaleLegacyEligibility.hasIdentity,
      'tailscaleLegacyControlMismatch':
          TailscaleLegacyEligibility.controlMismatch,
      'tailscaleLegacyInUse': TailscaleLegacyEligibility.inUse,
      'tailscaleLegacyMigrated': TailscaleLegacyEligibility.migrated,
      'tailscaleLegacyNotIsolated': TailscaleLegacyEligibility.notIsolated,
      'tailscaleLegacyDirInUse': TailscaleLegacyEligibility.dirInUse,
      'tailscaleLegacyUnreadable': TailscaleLegacyEligibility.unreadable,
      'tailscaleLegacyUnconfirmed': TailscaleLegacyEligibility.unconfirmed,
    };
    expect(eligibilities.values.toSet(), TailscaleLegacyEligibility.values);
    for (final MapEntry(:key, :value) in eligibilities.entries) {
      expect(valueOf(key), isNotNull, reason: key);
      final decoded = TailscaleLegacyIdentity.fromJson({
        'eligibility': valueOf(key),
      });
      expect(decoded.eligibility, value, reason: key);
    }
    const outcomes = {
      'tailscaleMigrateMigrated': TailscaleMigrateOutcome.migrated,
      'tailscaleMigrateFailed': TailscaleMigrateOutcome.failed,
      'tailscaleMigrateUnknown': TailscaleMigrateOutcome.unknown,
    };
    for (final MapEntry(:key, :value) in outcomes.entries) {
      final decoded = TailscaleMigrateResult.fromJson(
        json.decode(
              json.encode({
                'generation': 1,
                'outcome': valueOf(key),
                'migration': _tailscaleMigration,
                'node': _tailscaleNode,
              }),
            )
            as Map<String, Object?>,
      );
      expect(decoded.outcome, value, reason: key);
    }
  });

  test('the Dart and Go event tables name the same events', () async {
    final protocol = await File('core/protocol.go').readAsString();
    final goNames = {
      for (final match in RegExp(
        r'^\s*\w+Message\s+MessageType\s*=\s*"([^"]+)"',
        multiLine: true,
      ).allMatches(protocol))
        match.group(1)!,
    };

    expect(goNames, contains('tailscaleState'));
    expect({
      for (final type in CoreEventType.values)
        if (type != CoreEventType.crash) type.name,
    }, goNames);
  });

  test('a Tailscale action names its node by name and generation', () async {
    final handler = _RecordingCoreHandler();
    const node = TailscaleNodeRef(name: 'ts', generation: 3);

    final nodes = await handler.getTailscaleNodes();
    final status = await handler.getTailscaleStatus(node);
    await handler.startTailscale(node);
    final login = await handler.loginTailscale(node, reauth: true);
    final logout = await handler.logoutTailscale(node);
    final prefs = await handler.setTailscalePrefs(node, exitNode: '');
    final migrated = await handler.migrateTailscaleLegacy(
      node,
      offerToken: 't1',
    );

    expect(nodes.single.ref, node);
    expect(nodes.single.stateDirMode, TailscaleStateDirMode.derived);
    expect(nodes.single.backendState, TailscaleBackendState.running);
    expect(nodes.single.legacySharedStatePresent, isTrue);
    expect(nodes.single.legacy?.loginName, 'old@example.test');
    expect(nodes.single.legacy?.migratedTo, isNull);
    expect(
      nodes.single.legacy?.eligibility,
      TailscaleLegacyEligibility.controlMismatch,
    );
    expect(nodes.single.legacy?.offerToken, 't1');
    expect(
      nodes.single.settings.exitNode,
      const TailscaleExitNodeSetting(
        value: '100.64.0.2',
        source: TailscaleSettingSource.override,
      ),
    );
    expect(
      nodes.single.settings.acceptRoutes.source,
      TailscaleSettingSource.provider,
    );
    for (final method in [
      CoreMethod.tailscaleStatus,
      CoreMethod.tailscaleStart,
      CoreMethod.tailscaleLogout,
    ]) {
      expect(handler.calls[method], {'name': 'ts', 'generation': 3});
    }
    expect(handler.calls[CoreMethod.tailscaleMigrateLegacy], {
      'name': 'ts',
      'generation': 3,
      'offer-token': 't1',
    });
    expect(handler.calls[CoreMethod.tailscaleLogin], {
      'name': 'ts',
      'generation': 3,
      'reauth': true,
    });
    expect(handler.calls[CoreMethod.tailscaleSetPrefs], {
      'name': 'ts',
      'generation': 3,
      'exit-node': '',
    });
    expect(status.loginUser?.id, '7');
    expect(status.self?.keyExpiry, DateTime.utc(2027));
    expect(status.peers.single.altSharerUserId, '9');
    expect(status.prefs?.acceptRoutes, isTrue);
    expect(login.authUrl, 'https://login.tailscale.com/a/x');
    expect(login.state, TailscaleBackendState.needsLogin);
    expect(logout.outcome, TailscaleLogoutOutcome.unknown);
    expect(logout.error?.code, 'tailscale_logout_failed');
    expect(prefs.outcome, TailscalePrefsOutcome.notRunning);
    expect(migrated.reapplyRequired, isTrue);
    expect(migrated.outcome, TailscaleMigrateOutcome.failed);
    expect(migrated.targetUntouched, isTrue);
    expect(migrated.archiveIntact, isFalse);
    expect(migrated.stage, TailscaleMigrateStage.claim);
    expect(migrated.error?.code, 'tailscale_migrate_failed');
    expect(
      migrated.migration,
      const TailscaleLegacyMigration(
        fingerprint: 'f1',
        profileId: 42,
        name: 'ts',
        controlUrl: 'https://controlplane.tailscale.com',
      ),
    );
    expect(migrated.node.legacy?.fingerprint, 'f1');
  });

  test('a Tailscale state event decodes, and an unknown state stays one', () {
    final events = coreEventsFromData([
      {
        'type': 'tailscaleState',
        'data': {
          'name': 'ts',
          'generation': 3,
          'state': 'NeedsMachineAuth',
          'auth-url-ready': false,
        },
      },
    ]);
    final event = TailscaleStateEvent.fromJson(
      Map<String, Object?>.from(events.single.data as Map),
    );

    expect(event.state, TailscaleBackendState.needsMachineAuth);
    expect(
      TailscaleStateEvent.fromJson({
        'name': 'ts',
        'generation': 3,
        'state': 'Later',
      }).state,
      TailscaleBackendState.unknown,
    );
  });

  test('the setup payload carries the panel records of the profile', () {
    const setup = TailscaleSetup(
      profileId: 42,
      configSource: TailscaleSettingSource.profile,
      nodes: [
        TailscaleNodeSetup(name: 'a', exitNode: ''),
        TailscaleNodeSetup(name: 'b', loggedOut: true),
      ],
      legacyMigration: TailscaleLegacyMigration(fingerprint: 'f1', name: 'b'),
      managed: [
        TailscaleManagedSetup(
          id: 'm1',
          name: 'tailscale-m1',
          acceptRoutes: true,
          attached: true,
        ),
        TailscaleManagedSetup(id: 'm2', loggedOut: true),
      ],
    );
    final sent = json.decode(
      json.encode(
        const SetupParams(
          selectedMap: {},
          options: CoreOptions(testUrl: 'test'),
          tailscale: setup,
        ).toJson(),
      ),
    );

    expect((sent as Map)['tailscale'], {
      'profile-id': 42,
      'config-source': 'profile',
      'nodes': [
        {'name': 'a', 'control-url': '', 'exit-node': '', 'logged-out': false},
        {'name': 'b', 'control-url': '', 'logged-out': true},
      ],
      'legacy-migration': {
        'fingerprint': 'f1',
        'profile-id': 0,
        'name': 'b',
        'control-url': '',
      },
      'managed': [
        {
          'id': 'm1',
          'name': 'tailscale-m1',
          'control-url': '',
          'accept-routes': true,
          'logged-out': false,
          'attached': true,
        },
        {
          'id': 'm2',
          'name': '',
          'control-url': '',
          'logged-out': true,
          'attached': false,
        },
      ],
      'managed-unknown': false,
    });
  });

  test('core interface sends structured request parameters', () async {
    final handler = _RecordingCoreHandler();

    await handler.init(const InitParams(homeDir: '/tmp/flclash', version: 35));
    await handler.setupConfig(
      const SetupParams(
        selectedMap: {'GLOBAL': 'DIRECT'},
        options: CoreOptions(testUrl: 'test'),
      ),
    );
    final switched = await handler.changeProxy(
      const ChangeProxyParams(groupName: 'GLOBAL', proxyName: 'DIRECT'),
    );
    expect(switched, const ChangeProxyResult(changed: true));
    final route = await handler.watchRoute(true);
    expect(route, const RouteSnapshot(coreEpoch: 1, running: true));
    final check = await handler.checkRoutes(
      const CheckRoutesParams(
        routes: [
          [RouteHit(host: 'example.com:443', proxy: 'DIRECT', exit: 'x')],
          [],
        ],
      ),
    );
    expect(
      check,
      const RouteCheck(coreEpoch: 1, routeVersion: 3, held: [true, false]),
    );
    await handler.sideLoadExternalProvider(providerName: 'provider', data: 'x');
    await handler.testDelay(
      const TestDelayParams(
        proxyName: 'DIRECT',
        testUrl: 'https://example.com',
        timeout: 8000,
      ),
    );
    await handler.clearEffect(42);
    await handler.getTraffic(true);
    await handler.closeConnection('connection-1');
    await handler.updateGeoData('GeoIp');

    for (final method in CoreMethod.values) {
      if (handler.calls[method] case final Object arguments) {
        expect(arguments, isA<Map>(), reason: method.wireName);
      }
    }
    expect(handler.calls[CoreMethod.coreInit], {
      'home-dir': '/tmp/flclash',
      'version': 35,
    });
    expect(json.decode(json.encode(handler.calls[CoreMethod.configSetup])), {
      'selected-map': {'GLOBAL': 'DIRECT'},
      'options': {
        'test-url': 'test',
        'skip-cert-verify': false,
        'delay-test-timeout': defaultDelayTestTimeout,
        'mitm-capture': false,
      },
    });
    expect(handler.calls[CoreMethod.routeWatch], {'watch': true});
    expect(json.decode(json.encode(handler.calls[CoreMethod.routeCheck])), {
      'routes': [
        [
          {'host': 'example.com:443', 'proxy': 'DIRECT', 'exit': 'x'},
        ],
        <Object?>[],
      ],
    });
    expect(handler.calls[CoreMethod.providerSideLoad], {
      'name': 'provider',
      'data': 'x',
    });
    expect(handler.calls[CoreMethod.proxyTestDelay], {
      'proxy-name': 'DIRECT',
      'test-url': 'https://example.com',
      'timeout': 8000,
    });
    expect(handler.calls[CoreMethod.profileClearEffect], {'profile-id': 42});
    expect(handler.calls[CoreMethod.trafficCurrent], {'only-proxy': true});
    expect(handler.calls[CoreMethod.connectionClose], {'id': 'connection-1'});
    expect(handler.calls[CoreMethod.geoUpdate], {'type': 'GeoIp'});
  });

  test('a list validation reads only the entries the Core refuses', () async {
    final handler = _RecordingCoreHandler();

    final filters = await handler.validateFilters(['hk`jp', '(hk']);
    final proxies = await handler.validateProxies([
      {'name': 'a'},
      {'name': 'b'},
    ]);

    expect(handler.calls[CoreMethod.filterValidate], {
      'filters': ['hk`jp', '(hk'],
    });
    expect(filters, {1: 'missing closing )'});
    expect(proxies, {1: 'missing closing )'});
  });

  test('validateMitm sends the section and reads issues by list', () async {
    final handler = _RecordingCoreHandler();
    const rules = MitmRules(urlRewrite: ['^a _ reject', '^b c x']);

    final issues = await handler.validateMitm(rules);

    expect(handler.calls[CoreMethod.mitmValidate], rules.toJson());
    expect(issues, {
      MitmList.urlRewrite: {1: 'unknown type "x"'},
    });
  });

  test('MITM settings are sent on their own, null for off', () async {
    final handler = _RecordingCoreHandler();
    const setup = {
      'enable': true,
      'hostname': ['a.example'],
    };

    await handler.updateMitm(setup);
    expect(handler.calls[CoreMethod.mitmUpdate], {'setup': setup});

    await handler.updateMitm(null);
    expect(handler.calls[CoreMethod.mitmUpdate], {'setup': null});
  });

  test('captured requests are listed by connection and read by id', () async {
    final handler = _RecordingCoreHandler();

    final list = await handler.getMitmExchanges('connection-1');
    final cleared = await handler.getMitmExchange(7);

    expect(handler.calls[CoreMethod.mitmExchanges], {'id': 'connection-1'});
    expect(handler.calls[CoreMethod.mitmExchange], {'id': 7});
    expect(list.capturing, isTrue);
    expect(list.since, DateTime.utc(2026, 10, 28));
    expect(list.exchanges.single.pending, isTrue);
    expect(cleared, isNull);
  });

  test('the MITM certificate is read, and a missing answer fails', () async {
    final handler = _RecordingCoreHandler();

    final certificate = await handler.getMitmCertificate();

    expect(certificate?.subject, 'FlClash CA 0000ABCD');
    expect(certificate?.notAfter, DateTime.utc(2036, 10, 22));
    await expectLater(
      handler.generateMitmCertificate(),
      throwsA(
        isA<CoreMethodException>().having(
          (error) => error.code,
          'code',
          'empty_result',
        ),
      ),
    );
  });

  test('a check leaf is signed for the host it names', () async {
    final handler = _RecordingCoreHandler();

    final pem = await handler.issueMitmCertificate('check.invalid');

    expect(pem, '-----BEGIN CERTIFICATE-----');
    expect(handler.calls[CoreMethod.mitmIssueCertificate], {
      'host': 'check.invalid',
    });
  });

  test('a command answers nothing and a query answers its result', () async {
    final handler = _RecordingCoreHandler();

    await handler.forceGc();
    await handler.closeConnections();

    expect(await handler.isInit, isTrue);
    expect(await handler.validateConfig('/config.yaml'), isNull);
    expect(handler.calls[CoreMethod.configValidate], {'path': '/config.yaml'});
  });

  test('rule lookup sends request process and source metadata', () async {
    final core = _RecordingCoreHandler();
    await core.lookupRule(
      const RuleLookupParams(host: 'example.test', port: 443, network: 'tcp'),
      metadata: const Metadata(
        process: 'browser',
        processPath: '/app/browser',
        sourceIP: '192.0.2.5',
        sourcePort: '51234',
      ),
    );
    final args = core.calls[CoreMethod.ruleLookup] as Map;
    expect(args['process'], 'browser');
    expect(args['processPath'], '/app/browser');
    expect(args['sourceIP'], '192.0.2.5');
    expect(args['sourcePort'], 51234);
    expect(args['port'], 443);
    expect(args['network'], 'tcp');
  });

  test('dumpRuleSet sends the rule set path', () async {
    final handler = _RecordingCoreHandler();

    expect(await handler.dumpRuleSet('/rules.mrs'), '/home/responses/2.yaml');

    expect(handler.calls[CoreMethod.ruleSetDump], {'path': '/rules.mrs'});
  });

  test('decryptConfig sends the path and the age key', () async {
    final handler = _RecordingCoreHandler();

    await handler.decryptConfig('/profile.yaml', 'AGE-SECRET-KEY-1A');

    expect(handler.calls[CoreMethod.configDecrypt], {
      'path': '/profile.yaml',
      'age-secret-key': 'AGE-SECRET-KEY-1A',
    });
  });

  test(
    'compileRuleSet names a cached file and reads what the Core found',
    () async {
      final handler = _RecordingCoreHandler();

      final info = await handler.compileRuleSet(
        'abc',
        url: 'https://example.com/r.list',
      );

      expect(handler.calls[CoreMethod.ruleSetCompile], {
        'name': 'abc',
        'url': 'https://example.com/r.list',
      });
      expect(info, (
        behavior: RuleProviderBehavior.ipcidr,
        format: RuleProviderFormat.text,
      ));
    },
  );

  test('event contract accepts batches and legacy single events', () async {
    final fixture =
        json.decode(
              await File('test/fixtures/core_protocol.json').readAsString(),
            )
            as Map<String, dynamic>;
    final call = CoreMethodCall.fromJson(
      Map<String, Object?>.from(fixture['eventCall'] as Map),
    );

    final events = coreEventsFromData(call.arguments);
    expect(events, hasLength(2));
    expect(events.first.type, CoreEventType.loaded);
    expect(events.last.type, CoreEventType.delay);

    final legacy = coreEventsFromData({'type': 'loaded', 'data': 'provider-b'});
    expect(legacy.single.data, 'provider-b');
  });

  test('event contract decodes the dns query the Core sends', () {
    final events = coreEventsFromData([
      {
        'type': 'dns',
        'data': {
          'domain': 'www.example.com',
          'type': 'A',
          'initiator': 'app',
          'answers': ['93.184.216.34'],
          'rcode': 'NOERROR',
          'delay': 0,
          'time': '2026-09-18T12:30:01.123456789+08:00',
        },
      },
      {
        'type': 'dns',
        'data': {
          'domain': 'missing.test',
          'type': 'AAAA',
          'initiator': 'unknown-initiator',
          'upstream': 'tls://1.1.1.1:853',
          'cached': true,
          'answers': <String>[],
          'error': 'i/o timeout',
          'delay': 5000,
          'time': '2026-09-18T04:30:02Z',
        },
      },
    ]);

    expect(events.map((event) => event.type), [
      CoreEventType.dns,
      CoreEventType.dns,
    ]);
    final queries = [
      for (final event in events)
        DnsQuery.fromJson(Map<String, Object?>.from(event.data as Map)),
    ];
    expect(queries.first.initiator, DnsQueryInitiator.app);
    expect(queries.first.upstream, isEmpty);
    expect(queries.first.cached, isFalse);
    expect(queries.first.answers, ['93.184.216.34']);
    expect(
      queries.first.time.toUtc(),
      DateTime.utc(2026, 9, 18, 4, 30, 1, 123, 456),
    );
    expect(queries.first.isFailed, isFalse);
    expect(queries.last.initiator, isNull);
    expect(queries.last.upstream, 'tls://1.1.1.1:853');
    expect(queries.last.cached, isTrue);
    expect(queries.last.rcode, isEmpty);
    expect(queries.last.isFailed, isTrue);
  });

  test('event contract skips malformed entries without dropping the batch', () {
    final events = coreEventsFromData([
      {'type': 'loaded', 'data': 'provider-a'},
      {'type': 'invalid-event', 'data': null},
      {'type': 'loaded', 'data': 'provider-b'},
    ]);

    expect(events.map((event) => event.data), ['provider-a', 'provider-b']);
  });

  test('core interface converts structured method results', () async {
    final handler = _RecordingCoreHandler();

    expect(await handler.getTraffic(false), const Traffic(up: 12, down: 34));
    expect(
      await handler.getTotalTraffic(false),
      const Traffic(up: 12, down: 34),
    );
    expect(
      await handler.testDelay(
        const TestDelayParams(
          proxyName: 'DIRECT',
          testUrl: 'https://example.com',
          timeout: 8000,
        ),
      ),
      const Delay(name: 'DIRECT', url: 'https://example.com', value: 42),
    );
    expect(
      await handler.getConnectionsWith((connections) => connections.single.id),
      'connection-1',
    );
    expect(await handler.getConnectionCount(), 3);
    expect((await handler.getExternalProviders()).single.name, 'provider-1');
    expect(
      (await handler.getExternalProvider('provider-1'))?.name,
      'provider-1',
    );
    expect(await handler.readConfig('/config.yaml'), {
      'mode': 'rule',
      'rule': ['MATCH,DIRECT'],
    });
    final memory = await handler.getMemoryStats();
    expect(memory.rss, 2048);
    expect(memory.runtimeTotal, 1024 + 256 + 64 + 32);
  });

  test('getProfileBase sends the path and reads what the Core kept', () async {
    final handler = _RecordingCoreHandler();

    final base = await handler.getProfileBase('/profiles/1.yaml');

    expect(handler.calls[CoreMethod.profileBase], {'path': '/profiles/1.yaml'});
    expect(
      base,
      const ProfileBase(
        config: {'mode': 'rule', 'rule': null},
        digest: 'abc',
        matchRules: ['MATCH,DIRECT'],
        proxies: 2,
        proxyGroups: 1,
        rules: 3,
      ),
    );
  });

  test('the outbounds and the built profile cross as plain JSON', () async {
    final handler = _RecordingCoreHandler();
    const base = SetupBase(path: '/profiles/1.yaml', overlay: 'mode: rule');

    final outbounds = await handler.getProfileOutbounds('/profiles/1.yaml');
    final built = await handler.buildProfile(base: base);

    expect(handler.calls[CoreMethod.profileOutbounds], {
      'path': '/profiles/1.yaml',
    });
    expect(outbounds['proxies'], [
      {'name': 'a', 'type': 'ss'},
    ]);
    expect(handler.calls[CoreMethod.profileBuild], base.toJson());
    expect(built, '/home/responses/1.yaml');

    const mounts = MountSetup(
      target: 1,
      revision: 'r',
      sources: [MountSource(id: 2, label: 'A', path: '/profiles/2.yaml')],
    );
    await handler.buildProfile(base: base, mounts: mounts);
    expect(handler.calls[CoreMethod.profileBuild], {
      ...base.toJson(),
      'mounts': mounts.toJson(),
    });
    await handler.buildProfile(config: 'proxies: []\n', mounts: mounts);
    expect(handler.calls[CoreMethod.profileBuild], {
      'config': 'proxies: []\n',
      'mounts': mounts.toJson(),
    });
  });

  test('a proxy definition crosses as a nested mapping or null', () async {
    final handler = _RecordingCoreHandler();

    final definition = await handler.getProxyDefinition('a');
    final missing = await handler.getProxyDefinition('from-provider');

    expect(handler.calls[CoreMethod.proxyDefinition], {
      'name': 'from-provider',
    });
    expect(definition, {
      'name': 'a',
      'type': 'ss',
      'plugin-opts': {'mode': 'websocket'},
    });
    expect(missing, isNull);
  });

  test('setupConfig names a base only when the Core applies one', () async {
    final handler = _RecordingCoreHandler();
    const params = SetupParams(
      selectedMap: {},
      options: CoreOptions(testUrl: 'test'),
    );
    Object? sent() =>
        json.decode(json.encode(handler.calls[CoreMethod.configSetup]));

    await handler.setupConfig(params);
    expect(sent(), isNot(contains('base')));

    await handler.setupConfig(
      params.copyWith(
        base: const SetupBase(path: '/profiles/1.yaml', overlay: 'mode: rule'),
      ),
    );
    expect((sent()! as Map)['base'], {
      'path': '/profiles/1.yaml',
      'overlay': 'mode: rule',
    });
  });

  test('readConfig preserves structured core errors', () async {
    final handler = _FailingConfigCoreHandler();

    await expectLater(
      handler.readConfig('/missing.yaml'),
      throwsA(
        isA<CoreMethodException>()
            .having((error) => error.code, 'code', 'core_error')
            .having((error) => error.details, 'details', {
              'path': '/missing.yaml',
            }),
      ),
    );
  });

  test('readConfig rejects empty transport results', () async {
    final handler = _EmptyConfigCoreHandler();

    await expectLater(
      handler.readConfig('/config.yaml'),
      throwsA(
        isA<CoreMethodException>().having(
          (error) => error.code,
          'code',
          'empty_result',
        ),
      ),
    );
  });

  test('method response separates result and structured errors', () async {
    final fixture =
        json.decode(
              await File('test/fixtures/core_protocol.json').readAsString(),
            )
            as Map<String, dynamic>;
    final success = CoreMethodResponse.fromJson(
      Map<String, Object?>.from(fixture['successResponse'] as Map),
    );
    final structured = CoreMethodResponse.fromJson(
      Map<String, Object?>.from(fixture['structuredResponse'] as Map),
    );
    final failure = CoreMethodResponse.fromJson(
      Map<String, Object?>.from(fixture['errorResponse'] as Map),
    );
    final spilled = CoreMethodResponse.fromJson(
      Map<String, Object?>.from(fixture['spilledResponse'] as Map),
    );

    expect(success.unwrap<Object?>(), isNull);
    expect(success.toJson(), containsPair('result', null));
    expect(structured.result, isA<Map>());
    expect(structured.result, isNot(isA<String>()));
    expect(structured.unwrap<Map<String, dynamic>>()?['up'], 12);
    expect(
      () => failure.unwrap<Object?>(),
      throwsA(
        isA<CoreMethodException>()
            .having((error) => error.code, 'code', 'core_error')
            .having((error) => error.message, 'message', 'config not found'),
      ),
    );
    expect(failure.toJson(), contains('error'));
    expect(failure.toJson(), isNot(contains('code')));
    expect(failure.file, isNull);
    expect(failure.toJson(), isNot(contains('file')));
    expect(spilled.file, '/home/responses/1234.json');
    expect(spilled.toJson(), containsPair('file', '/home/responses/1234.json'));
  });
}
