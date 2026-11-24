import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/connection/route_reason.dart';
import 'package:fl_clash/l10n/l10n_en.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/proxies/node_fields.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

final _l = AppLocalizationsEn();

const _udpNode = Proxy(name: 'udp', type: 'Vless', udp: true);
const _tcpNode = Proxy(name: 'tcp', type: 'Http', udp: false);

Group _group(String name, {bool? disableUdp, bool? udp, String? now}) => Group(
  type: GroupType.Selector,
  name: name,
  now: now,
  udp: udp,
  disableUdp: disableUdp,
  all: const [_udpNode, _tcpNode],
);

TrackerInfo _tracker({
  String rule = '',
  List<String> chains = const ['DIRECT'],
  String reason = '',
  List<UdpSkip> skipped = const [],
}) => TrackerInfo(
  id: 'id',
  start: DateTime.utc(2026),
  metadata: Metadata(routeReason: reason, udpSkipped: skipped),
  chains: chains,
  rule: rule,
  rulePayload: '',
);

void main() {
  group('node UDP', () {
    test('a missing field is unknown, never off', () {
      expect(
        nodeUdpOf(
          const Proxy(name: 'n', type: 'Vmess'),
          groups: const [],
          selectedMap: const {},
        ),
        NodeUdp.unknown,
      );
    });

    test('an action has no UDP state', () {
      expect(
        nodeUdpOf(
          const Proxy(name: 'REJECT', type: 'Reject'),
          groups: const [],
          selectedMap: const {},
        ),
        isNull,
      );
    });

    test('a group follows the selection the app just made', () {
      final group = _group('G', udp: true, now: 'udp');
      expect(
        groupUdpOf(group, groups: [group], selectedMap: const {'G': 'tcp'}),
        NodeUdp.disabled,
      );
      expect(
        groupUdpOf(group, groups: [group], selectedMap: const {'G': 'udp'}),
        NodeUdp.enabled,
      );
    });

    test("a group's own disable-udp outranks its selection", () {
      final group = _group('G', disableUdp: true, now: 'udp');
      expect(
        groupUdpOf(group, groups: [group], selectedMap: const {}),
        NodeUdp.disabledByGroup,
      );
    });

    testWidgets('the info tells off from unknown, which it leaves out', (
      tester,
    ) async {
      await tester.pumpWidget(
        const TestApp(
          wrapInProviderScope: true,
          locale: Locale('en'),
          child: NodeInfoView(
            proxy: Proxy(name: 'n', type: 'Trojan', tfo: true, mptcp: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_l.nodeFieldTfo), findsOneWidget);
      expect(find.text(_l.nodeFieldMptcp), findsOneWidget);
      expect(find.text(_l.nodeConfigDisabled), findsOneWidget);
      expect(find.text(_l.nodeFieldXudp), findsNothing);
      expect(find.text(_l.nodeStatusUnknown), findsOneWidget);
    });

    test('a row shows only what the config turns on', () {
      const proxy = Proxy(name: 'n', type: 'Ss', tfo: true, mptcp: false);
      expect(NodeField.onIn(proxy, udp: NodeUdp.unknown), [NodeField.tfo]);
      expect(NodeField.onIn(proxy, udp: NodeUdp.enabled), [
        NodeField.udp,
        NodeField.tfo,
      ]);
    });
  });

  group('route reason', () {
    const skip = UdpSkip(
      type: 'Domain',
      payload: 'a.test',
      adapter: 'Proxy',
      cause: 'unsupported',
    );

    test('a skipped rule is a note, never the rule shown', () {
      final reason = RouteReason(
        _tracker(reason: 'no-match', skipped: const [skip]),
      );
      expect(reason.exitLine(_l), _l.routeExitDirect);
      expect(reason.notes(_l), [
        _l.routeUdpSkippedUnsupported('Domain(a.test)', 'Proxy'),
        _l.routeNoMatch,
      ]);
      expect(reason.short(_l), _l.routeShortUdpSkipped);
    });

    test('each recorded reason reads as itself', () {
      for (final (recorded, note) in [
        ('mode-direct', _l.routeModeDirect),
        ('mode-global', _l.routeModeGlobal),
        ('internal', _l.routeInternal),
        ('', _l.routeReasonUnknown),
      ]) {
        expect(RouteReason(_tracker(reason: recorded)).notes(_l), [note]);
      }
    });

    test('a special proxy is not called internal', () {
      expect(RouteReason(_tracker(reason: 'special')).notes(_l), isEmpty);
    });

    test('an exit that was not recorded is unknown', () {
      expect(
        RouteReason(_tracker(chains: const [])).exitLine(_l),
        _l.routeExitUnknown,
      );
    });

    test('a rule that decided adds nothing', () {
      final reason = RouteReason(_tracker(rule: 'Match'));
      expect(reason.exitLine(_l), isNull);
      expect(reason.notes(_l), isEmpty);
    });
  });
}
