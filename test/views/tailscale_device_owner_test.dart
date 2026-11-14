import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/tailscale/state.dart';
import 'package:fl_clash/views/tailscale/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/preferences.dart';
import '../helpers/test_app.dart';
import 'tailscale_devices_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(mockPreferences);

  Finder rowOf(String name) => find
      .ancestor(of: find.text(name), matching: find.byType(MouseRegion))
      .first;

  Finder inRow(String name, Finder matching) =>
      find.descendant(of: rowOf(name), matching: matching);

  Future<void> pump(
    WidgetTester tester,
    TailscaleStatus status, {
    Locale locale = const Locale('zh', 'CN'),
    double width = 1000,
  }) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TestApp(
        locale: locale,
        child: DevicesHarness(status: status),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  for (final locale in [const Locale('zh', 'CN'), const Locale('en')]) {
    testWidgets('unknown owner shows only the actual tailnet name in $locale', (
      tester,
    ) async {
      const network = 'Example team';
      await pump(tester, devicesStatus(network: network), locale: locale);

      expect(inRow('office-hk', find.text(network)), findsOneWidget);
      expect(inRow('office-hk', find.byTooltip(network)), findsOneWidget);
      expect(
        inRow(
          'office-hk',
          find.textContaining(RegExp('未知|Unknown|网络|Network')),
        ),
        findsNothing,
      );
      expect(inRow('office-hk', find.byType(TailscaleAvatar)), findsNothing);
      expect(inRow('office-hk', find.byType(Image)), findsNothing);
      expect(
        inRow(
          'office-hk',
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == network,
          ),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('a user avatar is not used as a tailnet avatar', (tester) async {
    final status =
        devicesStatus(peers: [devicesPeers()[2].copyWith(userId: '')]).copyWith(
          loginUser: devicesAlice.copyWith(
            profilePicUrl: 'https://example.com/user-avatar.png',
          ),
        );
    await pump(tester, status);

    expect(inRow('office-hk', find.text('alice@example.com')), findsOneWidget);
    expect(inRow('office-hk', find.byType(TailscaleAvatar)), findsNothing);
    expect(inRow('office-hk', find.byType(Image)), findsNothing);
  });

  testWidgets('known users, signed-in owner, and tags keep their rendering', (
    tester,
  ) async {
    final tagged = devicesPeers().first.copyWith(
      id: 'tagged',
      hostName: 'tagged-device',
      tags: ['tag:server'],
    );
    await pump(tester, devicesStatus(peers: [...devicesPeers(), tagged]));

    expect(inRow('studio-mac', find.text('我')), findsOneWidget);
    expect(
      inRow('studio-mac', find.byTooltip('Alice · alice@example.com')),
      findsOneWidget,
    );
    expect(inRow('studio-mac', find.byType(TailscaleAvatar)), findsOneWidget);
    expect(inRow('nas-sg', find.text('bob@example.com')), findsOneWidget);
    expect(
      inRow('nas-sg', find.byTooltip('Bob · bob@example.com')),
      findsOneWidget,
    );
    expect(inRow('nas-sg', find.byType(TailscaleAvatar)), findsOneWidget);
    expect(inRow('tagged-device', find.text('tag:server')), findsOneWidget);
  });

  for (final tailnet in [
    null,
    const TailscaleTailnet(),
    const TailscaleTailnet(name: '  '),
  ]) {
    testWidgets('unknown owner with $tailnet does not invent an identity', (
      tester,
    ) async {
      final status = devicesStatus().copyWith(tailnet: tailnet);
      await pump(tester, status);

      expect(
        inRow(
          'office-hk',
          find.textContaining(RegExp('未知|Unknown|网络|Network')),
        ),
        findsNothing,
      );
      expect(inRow('office-hk', find.text('')), findsOneWidget);
      expect(inRow('office-hk', find.byType(TailscaleAvatar)), findsNothing);
      expect(tester.takeException(), isNull);
      final devices = tailscaleDevicesOf(status);
      expect(
        devices.singleWhere((device) => device.peer.id == 'p3').owner,
        isA<TailscaleOwnerUnknown>(),
      );
      expect(
        filterTailscaleDevices(
          devices,
          ownerKey: 'unknown',
        ).map((device) => device.peer.id),
        ['p3'],
      );
    });
  }

  testWidgets('long tailnet names ellipsize in a narrow owner column', (
    tester,
  ) async {
    final network = List.filled(12, 'Example team').join(' ');
    await pump(tester, devicesStatus(network: network), width: 520);

    final name = inRow('office-hk', find.text(network));
    expect(name, findsOneWidget);
    final text = tester.widget<Text>(name);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.getSize(name).width, lessThan(150));
    expect(inRow('office-hk', find.byTooltip(network)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
