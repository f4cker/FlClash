import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/tailscale/device_card.dart';
import 'package:fl_clash/views/tailscale/state.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import 'tailscale_fixtures.dart';

const _dns = 'current-device.example-net.test';

TailscaleStatus _status({String? dnsName = _dns, bool enabled = true}) {
  final status = tsConnectedStatus();
  final selfJson = status.self!.toJson()..remove('dns-name');
  return status.copyWith(
    self: TailscalePeer.fromJson({...selfJson, 'dns-name': ?dnsName}),
    tailnet: TailscaleTailnet(
      name: 'example-net.test',
      magicDnsSuffix: 'not-a-fallback.test',
      magicDnsEnabled: enabled,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> copied;

  setUp(() {
    copied = [];
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    required TailscaleStatus? status,
    TailscaleNode? node,
    TailscalePhase phase = TailscalePhase.connected,
    double width = 800,
    bool stale = false,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    void noop() {}
    await tester.pumpWidget(
      TestApp(
        includeNavigatorKey: false,
        locale: const Locale('en'),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TailscaleDeviceCard(
              node: node ?? status?.node ?? tsConnectedNode,
              phase: phase,
              status: status,
              stale: stale,
              actions: TailscaleCardActions(
                onLogin: noop,
                onRelogin: noop,
                onReopen: noop,
                onRead: noop,
                onLogout: noop,
                onRetryStart: noop,
                onGoToProfiles: noop,
                onCopy: copied.add,
                onMigrate: noop,
                onRecheckLegacy: noop,
              ),
              legacyView: TailscaleLegacyView.hidden,
              legacyState: const TailscaleLegacyState(),
              now: tsNow,
              wide: width >= 560,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows supplied self DNS below both addresses and copies it', (
    tester,
  ) async {
    final status = _status();
    await pumpCard(tester, status: status);

    expect(find.text(_dns), findsOneWidget);
    expect(find.text(status.self!.hostName), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(_dns)).dy,
      greaterThan(tester.getTopLeft(find.text(status.self!.addresses.last)).dy),
    );
    await tester.tap(find.byTooltip('Copy name'));
    expect(copied, [_dns]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removes the terminal dot for display and copy', (tester) async {
    await pumpCard(tester, status: _status(dnsName: '$_dns.'));

    expect(find.text(_dns), findsOneWidget);
    expect(find.text('$_dns.'), findsNothing);
    await tester.tap(find.byTooltip('Copy name'));
    expect(copied, [_dns]);
  });

  testWidgets('long DNS ellipsizes at phone width but copies the full name', (
    tester,
  ) async {
    final name = '${'long-device-name-' * 8}example-net.test';
    await pumpCard(tester, status: _status(dnsName: '$name.'), width: 320);

    final text = tester.widget<Text>(find.text(name));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
    expect(paragraph.didExceedMaxLines, isTrue);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Copy name'));
    expect(copied, [name]);
  });

  for (final name in <String?>[null, '', '.']) {
    testWidgets('missing or empty DNS ($name) never synthesizes a name', (
      tester,
    ) async {
      await pumpCard(tester, status: _status(dnsName: name));

      expect(find.byTooltip('Copy name'), findsNothing);
      expect(find.text(_dns), findsNothing);
      expect(find.textContaining('not-a-fallback.test'), findsNothing);
      expect(copied, isEmpty);
    });
  }

  testWidgets('disabled MagicDNS hides supplied DNS and its copy action', (
    tester,
  ) async {
    await pumpCard(tester, status: _status(enabled: false));

    expect(find.text(_dns), findsNothing);
    expect(find.byTooltip('Copy name'), findsNothing);
  });

  testWidgets('missing tailnet does not enable MagicDNS', (tester) async {
    await pumpCard(tester, status: _status().copyWith(tailnet: null));

    expect(find.text(_dns), findsNothing);
    expect(find.byTooltip('Copy name'), findsNothing);
  });

  for (final phase in [
    TailscalePhase.stopped,
    TailscalePhase.signedOut,
    TailscalePhase.unconfirmed,
  ]) {
    testWidgets('$phase hides DNS even if a status still has a name', (
      tester,
    ) async {
      await pumpCard(tester, status: _status(), phase: phase);

      expect(find.text(_dns), findsNothing);
      expect(find.byTooltip('Copy name'), findsNothing);
    });
  }

  testWidgets('unbound status and missing self never fabricate DNS', (
    tester,
  ) async {
    for (final status in [null, _status().copyWith(self: null)]) {
      await pumpCard(tester, status: status);

      expect(find.text(_dns), findsNothing);
      expect(find.byTooltip('Copy name'), findsNothing);
      expect(copied, isEmpty);
    }
  });

  testWidgets('missing addresses preserve the address block gate', (
    tester,
  ) async {
    final status = _status();
    await pumpCard(
      tester,
      status: status.copyWith(self: status.self!.copyWith(addresses: [])),
    );

    expect(find.text(_dns), findsNothing);
    expect(find.byTooltip('Copy name'), findsNothing);
  });

  testWidgets('reauth shows DNS without allowing copy', (tester) async {
    await pumpCard(
      tester,
      status: _status(),
      phase: TailscalePhase.needsReauth,
    );

    expect(find.text(_dns), findsOneWidget);
    expect(find.byTooltip('Copy name'), findsNothing);
    await tester.tap(find.text(_dns));
    expect(copied, isEmpty);
  });

  testWidgets('stale read keeps the passed status and existing copy policy', (
    tester,
  ) async {
    await pumpCard(tester, status: _status(), stale: true);

    expect(find.text(_dns), findsOneWidget);
    await tester.tap(find.byTooltip('Copy name'));
    expect(copied, [_dns]);
  });

  testWidgets('switching statuses never reuses the previous account name', (
    tester,
  ) async {
    await pumpCard(tester, status: _status());
    expect(find.text(_dns), findsOneWidget);

    const nextName = 'other-device.other-net.test';
    final nextNode = tsConnectedNode.copyWith(name: 'ts-other', generation: 4);
    await pumpCard(
      tester,
      status: _status(dnsName: nextName).copyWith(node: nextNode),
    );
    expect(find.text(_dns), findsNothing);
    expect(find.text(nextName), findsOneWidget);
    await tester.tap(find.byTooltip('Copy name'));
    expect(copied, [nextName]);

    await pumpCard(
      tester,
      status: _status(dnsName: null).copyWith(node: nextNode),
    );
    expect(find.text(nextName), findsNothing);
    expect(find.byTooltip('Copy name'), findsNothing);

    await pumpCard(tester, status: null, node: tsConnectedNode);
    expect(find.text(_dns), findsNothing);
    expect(find.text(nextName), findsNothing);
    expect(find.byTooltip('Copy name'), findsNothing);
  });
}
