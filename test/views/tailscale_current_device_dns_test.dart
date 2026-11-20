import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/tailscale/address_menu.dart';
import 'package:fl_clash/views/tailscale/device_card.dart';
import 'package:fl_clash/views/tailscale/state.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import 'tailscale_fixtures.dart';

const _host = 'work-mac';
const _dns = 'work-mac-1.example-net.ts.net';
const _short = 'work-mac-1';
const _ipv4 = '100.101.7.58';
const _ipv6 = 'fd7a:115c:a1e0::6b01:73a';
const _missing = 'Address not provided';

TailscaleStatus _status({
  String? dnsName = '$_dns.',
  bool enabled = true,
  List<String> addresses = const [_ipv4, _ipv6],
}) {
  final status = tsConnectedStatus();
  final selfJson = status.self!.toJson()..remove('dns-name');
  return status.copyWith(
    self: TailscalePeer.fromJson({
      ...selfJson,
      'dns-name': ?dnsName,
    }).copyWith(hostName: _host, addresses: addresses),
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
  late int logouts;

  setUp(() {
    copied = [];
    logouts = 0;
  });

  Future<void> pumpCard(
    WidgetTester tester, {
    required TailscaleStatus? status,
    TailscaleNode? node,
    TailscalePhase phase = TailscalePhase.connected,
    double width = 800,
    double height = 900,
    String locale = 'en',
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    void noop() {}
    await tester.pumpWidget(
      TestApp(
        includeNavigatorKey: false,
        locale: Locale(locale),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TailscaleDeviceCard(
              node: node ?? status?.node ?? tsConnectedNode,
              phase: phase,
              status: status,
              actions: TailscaleCardActions(
                onLogin: noop,
                onRelogin: noop,
                onReopen: noop,
                onRead: noop,
                onLogout: () => logouts++,
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

  Finder entry() => find.text('Copy address');

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(entry());
    await tester.pumpAndSettle();
  }

  Finder row(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_AddressRow',
    ),
  );

  Finder popover() => find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_AddressPopover',
  );

  test('the short name is the first label of the DNS name only', () {
    expect(tailscaleShortDnsName(_dns), _short);
    expect(tailscaleShortDnsName(null), isNull);
    expect(tailscaleShortDnsName(''), isNull);
  });

  testWidgets('closed, the card shows the large IPv4 and no other address', (
    tester,
  ) async {
    await pumpCard(tester, status: _status());

    expect(find.text(_ipv4), findsOneWidget);
    expect(entry(), findsOneWidget);
    expect(find.text(_ipv6), findsNothing);
    expect(find.text(_dns), findsNothing);
    expect(find.text(_short), findsNothing);
    expect(find.byTooltip('Copy name'), findsNothing);
    expect(find.byTooltip('Copy address'), findsNothing);
    // The device name in the meta row stays the host name.
    expect(find.text(_host), findsOneWidget);
    final ipv4 = tester.getRect(find.text(_ipv4));
    final button = tester.getRect(entry());
    expect(button.left, greaterThan(ipv4.right));
    expect(
      tester.getSize(find.byType(TailscaleAddressMenu)).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('the menu lists short name, DNS name, IPv6, IPv4 in order', (
    tester,
  ) async {
    await pumpCard(tester, status: _status());
    await openMenu(tester);

    final labels = ['Short hostname', 'Full DNS name', 'IPv6', 'IPv4'];
    final tops = [
      for (final label in labels) tester.getTopLeft(find.text(label)).dy,
    ];
    expect(tops, [...tops]..sort());
    expect(find.text(_short), findsOneWidget);
    expect(find.text(_dns), findsOneWidget);
    expect(find.text(_ipv6), findsOneWidget);
    // The card's IPv4 and the row's.
    expect(find.text(_ipv4), findsNWidgets(2));
    for (final label in labels) {
      expect(tester.getSize(row(label)).height, greaterThanOrEqualTo(56));
    }
    expect(tester.takeException(), isNull);
  });

  for (final (label, value) in [
    ('Short hostname', _short),
    ('Full DNS name', _dns),
    ('IPv6', _ipv6),
    ('IPv4', _ipv4),
  ]) {
    testWidgets('$label copies its full value and closes the menu', (
      tester,
    ) async {
      await pumpCard(tester, status: _status());
      await openMenu(tester);

      await tester.tap(row(label));
      await tester.pumpAndSettle();

      expect(copied, [value]);
      expect(find.text('Short hostname'), findsNothing);
    });
  }

  testWidgets('the short name never comes from the host name', (tester) async {
    await pumpCard(tester, status: _status());
    await openMenu(tester);

    await tester.tap(row('Short hostname'));
    expect(copied, [_short]);
    expect(copied.single, isNot(_host));
  });

  for (final name in <String?>[null, '', '.']) {
    testWidgets('a missing DNS name ($name) disables both name rows', (
      tester,
    ) async {
      await pumpCard(tester, status: _status(dnsName: name));
      await openMenu(tester);

      expect(find.text(_missing), findsNWidgets(2));
      expect(find.textContaining('not-a-fallback.test'), findsNothing);
      // The device name in the meta row only, never in the menu.
      expect(find.text(_host), findsOneWidget);
      await tester.tap(row('Short hostname'), warnIfMissed: false);
      await tester.tap(row('Full DNS name'), warnIfMissed: false);
      await tester.pump();
      expect(copied, isEmpty);
      // Still open: a disabled row does nothing.
      expect(find.text('IPv6'), findsOneWidget);
      await tester.tap(row('IPv4'));
      expect(copied, [_ipv4]);
    });
  }

  testWidgets('MagicDNS off disables both name rows', (tester) async {
    await pumpCard(tester, status: _status(enabled: false));
    await openMenu(tester);

    expect(find.text(_dns), findsNothing);
    expect(find.text(_short), findsNothing);
    expect(find.text(_missing), findsNWidgets(2));
  });

  testWidgets('no IPv6 address disables its row', (tester) async {
    await pumpCard(tester, status: _status(addresses: const [_ipv4]));
    await openMenu(tester);

    expect(find.text(_missing), findsOneWidget);
    await tester.tap(row('IPv6'), warnIfMissed: false);
    expect(copied, isEmpty);
  });

  testWidgets('an IPv6-only device disables IPv4, never copying IPv6 there', (
    tester,
  ) async {
    await pumpCard(tester, status: _status(addresses: const [_ipv6]));
    // The headline still shows the one address there is.
    expect(find.text(_ipv6), findsOneWidget);
    await openMenu(tester);

    expect(find.text(_ipv6), findsNWidgets(2));
    expect(find.text(_missing), findsOneWidget);
    expect(
      find.descendant(of: row('IPv4'), matching: find.text(_missing)),
      findsOneWidget,
    );
    await tester.tap(row('IPv4'), warnIfMissed: false);
    await tester.pump();
    expect(copied, isEmpty);
    await tester.tap(row('IPv6'));
    expect(copied, [_ipv6]);
  });

  test('the strict IPv4 accessor has no IPv6 fallback', () {
    final self = _status(addresses: const [_ipv6]).self;
    expect(tailscaleIpv4Of(self), isNull);
    expect(tailscaleAddressOf(self), _ipv6);
    expect(tailscaleIpv4Of(_status().self), _ipv4);
  });

  testWidgets('rows read as one button with category and full value', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpCard(tester, status: _status(dnsName: null));
    await openMenu(tester);

    for (final (label, value) in [('IPv6', _ipv6), ('IPv4', _ipv4)]) {
      final node = tester.getSemantics(
        find.bySemanticsLabel('Copy $label, $value'),
      );
      expect(
        node,
        matchesSemantics(
          label: 'Copy $label, $value',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
    }
    // A row with nothing to copy reads as text: no button, no action.
    for (final label in ['Short hostname', 'Full DNS name']) {
      final node = tester.getSemantics(
        find.bySemanticsLabel('$label, Unavailable'),
      );
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(find.bySemanticsLabel(RegExp('Copy $label')), findsNothing);
    }
    // The visible placeholder never doubles as the spoken state.
    expect(find.bySemanticsLabel(RegExp(_missing)), findsNothing);
    semantics.dispose();
  });

  testWidgets('the separator of a disabled row follows the locale', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpCard(tester, status: _status(dnsName: null), locale: 'zh');
    await tester.tap(find.text('复制地址'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('短主机名，不可用'), findsOneWidget);
    expect(find.bySemanticsLabel('复制IPv4，$_ipv4'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Tab reaches the button, Enter opens, Tab and Enter copy', (
    tester,
  ) async {
    await pumpCard(tester, status: _status());

    bool inButton() {
      final focused = FocusManager.instance.primaryFocus?.context;
      return focused != null &&
          find
              .ancestor(
                of: find.byElementPredicate((element) => element == focused),
                matching: find.byType(TailscaleAddressMenu),
              )
              .evaluate()
              .isNotEmpty;
    }

    for (var i = 0; i < 6 && !inButton(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(inButton(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(popover(), findsOneWidget);
    // Into the menu: the first row, then the second.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(copied, [_dns]);
    expect(popover(), findsNothing);
    expect(inButton(), isTrue);
  });

  testWidgets('Tab skips a disabled row', (tester) async {
    await pumpCard(tester, status: _status(dnsName: null));
    await openMenu(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(copied, [_ipv6]);
  });

  testWidgets('a long IPv6 wraps whole in a narrow menu', (tester) async {
    const ipv6 = '2001:db8:1234:5678:9abc:def0:1234:5678';
    await pumpCard(
      tester,
      status: _status(addresses: const [_ipv4, ipv6]),
      width: 320,
    );
    await openMenu(tester);

    expect(tester.takeException(), isNull);
    final paragraph = tester.renderObject<RenderParagraph>(find.text(ipv6));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.text.toPlainText(), ipv6);
    expect(
      tester.getRect(find.text(ipv6)).right,
      lessThanOrEqualTo(tester.getRect(popover()).right),
    );
    await tester.tap(row('IPv6'));
    expect(copied, [ipv6]);
  });

  testWidgets('Escape closes the menu and focus returns to the button', (
    tester,
  ) async {
    await pumpCard(tester, status: _status());
    await openMenu(tester);
    expect(find.text('IPv6'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('IPv6'), findsNothing);
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(focused, isNotNull);
    expect(
      find.ancestor(
        of: find.byElementPredicate((element) => element == focused),
        matching: find.byType(TailscaleAddressMenu),
      ),
      findsOneWidget,
    );
    expect(copied, isEmpty);
  });

  testWidgets('a tap outside closes the menu without copying', (tester) async {
    await pumpCard(tester, status: _status());
    await openMenu(tester);

    await tester.tapAt(const Offset(4, 880));
    await tester.pumpAndSettle();

    expect(find.text('IPv6'), findsNothing);
    expect(copied, isEmpty);
  });

  for (final width in [320.0, 393.0]) {
    testWidgets('at $width the open menu fits and wraps long names whole', (
      tester,
    ) async {
      final long = '${'long-device-name-' * 6}example-net.ts.net';
      await pumpCard(
        tester,
        status: _status(dnsName: '$long.'),
        width: width,
        height: 1000,
      );
      await openMenu(tester);

      expect(tester.takeException(), isNull);
      final menu = tester.getRect(popover());
      expect(menu.width, lessThanOrEqualTo(width - 32));
      expect(menu.left, greaterThanOrEqualTo(16));
      expect(menu.right, lessThanOrEqualTo(width - 16));
      final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.getSize(find.text(long)).height, greaterThan(20));
      await tester.tap(row('Full DNS name'));
      expect(copied, [long]);
    });
  }

  testWidgets('the menu is never wider than 360', (tester) async {
    await pumpCard(tester, status: _status(), width: 1200);
    await openMenu(tester);

    final menu = tester.getRect(popover());
    expect(menu.width, 360);
  });

  testWidgets('reauth shows the IPv4 without a way to copy', (tester) async {
    await pumpCard(
      tester,
      status: _status(),
      phase: TailscalePhase.needsReauth,
    );

    expect(find.text(_ipv4), findsOneWidget);
    expect(entry(), findsNothing);
    expect(find.text(_dns), findsNothing);
  });

  for (final phase in [
    TailscalePhase.stopped,
    TailscalePhase.signedOut,
    TailscalePhase.unconfirmed,
  ]) {
    testWidgets('$phase shows no address block', (tester) async {
      await pumpCard(tester, status: _status(), phase: phase);

      expect(entry(), findsNothing);
      expect(find.text(_ipv4), findsNothing);
    });
  }

  testWidgets('unbound status and missing self show no address block', (
    tester,
  ) async {
    for (final status in [null, _status().copyWith(self: null)]) {
      await pumpCard(tester, status: status);

      expect(entry(), findsNothing);
      expect(copied, isEmpty);
    }
  });

  testWidgets('logout sits at the header end, beside the title', (
    tester,
  ) async {
    await pumpCard(tester, status: _status());

    final logout = find.text('Log out of this node');
    expect(logout, findsOneWidget);
    final title = tester.getRect(find.text('This device'));
    final button = tester.getRect(logout);
    expect(button.left, greaterThan(title.right));
    expect((button.center.dy - title.center.dy).abs(), lessThan(12));
    expect(button.top, lessThan(tester.getRect(find.text(_ipv4)).top));
    // At the end of the row, not right after the tags.
    expect(
      tester.getRect(find.byKey(const ValueKey('ts-logout'))).right,
      moreOrLessEquals(
        tester
            .getRect(find.byKey(const ValueKey('ts-current-device-header')))
            .right,
      ),
    );
    await tester.tap(logout);
    expect(logouts, 1);
  });

  testWidgets('switching statuses never keeps the previous names', (
    tester,
  ) async {
    await pumpCard(tester, status: _status());
    await openMenu(tester);
    expect(find.text(_dns), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    const nextName = 'other-device.other-net.test';
    final nextNode = tsConnectedNode.copyWith(name: 'ts-other', generation: 4);
    await pumpCard(
      tester,
      status: _status(dnsName: nextName).copyWith(node: nextNode),
    );
    await openMenu(tester);
    expect(find.text(_dns), findsNothing);
    expect(find.text(nextName), findsOneWidget);
    expect(find.text('other-device'), findsOneWidget);
  });
}
