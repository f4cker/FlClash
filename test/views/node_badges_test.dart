import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/connection/route_reason.dart';
import 'package:fl_clash/features/features.dart';
import 'package:fl_clash/l10n/l10n_en.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/proxies/node_fields.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/host_scaffold.dart';
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
  String payload = '',
  List<String> chains = const ['DIRECT'],
  String reason = '',
  List<UdpSkip> skipped = const [],
}) => TrackerInfo(
  id: 'id',
  start: DateTime.utc(2026),
  metadata: Metadata(routeReason: reason, udpSkipped: skipped),
  chains: chains,
  rule: rule,
  rulePayload: payload,
);

void main() {
  group('node UDP', () {
    test('a missing field is unknown, never off', () {
      expect(
        nodeUdpOf(
          const Proxy(name: 'n', type: 'Vmess'),
          groups: const [],
          selectedMap: const {},
        )?.state,
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
        groupUdpOf(
          group,
          groups: [group],
          selectedMap: const {'G': 'tcp'},
        ).state,
        NodeUdp.disabled,
      );
      expect(
        groupUdpOf(
          group,
          groups: [group],
          selectedMap: const {'G': 'udp'},
        ).state,
        NodeUdp.enabled,
      );
    });

    test("a group's own disable-udp outranks its selection", () {
      final group = _group('G', disableUdp: true, now: 'udp');
      expect(groupUdpOf(group, groups: [group], selectedMap: const {}), (
        state: NodeUdp.disabledByGroup,
        by: 'G',
      ));
    });

    test('a nested group that disables UDP is the one named', () {
      final inner = _group('HK', disableUdp: true, now: 'udp');
      const outer = Group(
        type: GroupType.Selector,
        name: 'Streaming',
        now: 'HK',
        all: [Proxy(name: 'HK', type: 'Selector')],
      );
      expect(groupUdpOf(outer, groups: [outer, inner], selectedMap: const {}), (
        state: NodeUdp.disabledByGroup,
        by: 'HK',
      ));
    });

    test('a row shows only what the config turns on', () {
      const proxy = Proxy(name: 'n', type: 'Shadowsocks', tfo: true);
      expect(NodeField.onIn(proxy, udp: NodeUdp.unknown), [NodeField.tfo]);
      expect(NodeField.onIn(proxy, udp: NodeUdp.enabled), [
        NodeField.udp,
        NodeField.tfo,
      ]);
    });

    test('a group that disables UDP drops all that carries it', () {
      const proxy = Proxy(
        name: 'n',
        type: 'Vless',
        udp: true,
        xudp: true,
        tfo: true,
      );
      expect(NodeField.onIn(proxy, udp: NodeUdp.enabled, udpOff: true), [
        NodeField.tfo,
      ]);
    });

    test('a switch the protocol does not read is unknown, not off', () {
      const trojan = Proxy(name: 't', type: 'Trojan', uot: true, xudp: false);
      expect(NodeField.uot.switchOf(trojan), isNull);
      expect(NodeField.xudp.switchOf(trojan), isNull);
      const vless = Proxy(name: 'v', type: 'Vless', xudp: false, smux: true);
      expect(NodeField.xudp.switchOf(vless), isFalse);
      expect(NodeField.smux.switchOf(vless), isTrue);
      // On from config stands even where the table does not expect it.
      const anytls = Proxy(name: 'a', type: 'AnyTLS', smux: true);
      expect(NodeField.smux.switchOf(anytls), isTrue);
    });

    Future<void> pumpInfo(
      WidgetTester tester,
      Proxy proxy, {
      List<Group> groups = const [],
      String? groupName,
    }) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(groupsProvider.notifier).value = groups;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            locale: const Locale('en'),
            child: NodeInfoView(proxy: proxy, groupName: groupName),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the info lists only what the protocol reads', (tester) async {
      await pumpInfo(
        tester,
        const Proxy(
          name: 'n',
          type: 'Trojan',
          udp: false,
          uot: true,
          xudp: false,
          tfo: true,
          mptcp: false,
          smux: false,
        ),
      );
      expect(find.text(_l.nodeFieldUdp), findsOneWidget);
      expect(find.text(_l.nodeFieldTfo), findsOneWidget);
      expect(find.text(_l.nodeFieldMptcp), findsOneWidget);
      expect(find.text(_l.nodeFieldSmux), findsOneWidget);
      expect(find.text(_l.nodeFieldXudp), findsNothing);
      expect(find.text(_l.nodeFieldUot), findsNothing);
      expect(find.text(_l.nodeConfigDisabled), findsNWidgets(3));
    });

    testWidgets('UDP unknown is said, not left out', (tester) async {
      await pumpInfo(tester, const Proxy(name: 'n', type: 'Vmess'));
      expect(find.text(_l.nodeStatusUnknown), findsOneWidget);
    });

    testWidgets('a group that disables UDP is set apart from the node', (
      tester,
    ) async {
      const group = Group(
        type: GroupType.Selector,
        name: 'G',
        disableUdp: true,
        all: [_udpNode],
      );
      await pumpInfo(tester, _udpNode, groups: [group], groupName: 'G');
      expect(find.text(_l.nodeConfigEnabled), findsOneWidget);
      expect(find.text(_l.nodeFieldThisGroup), findsOneWidget);
      expect(find.text(_l.nodeGroupDisablesUdp), findsOneWidget);
    });
  });

  group('fold', () {
    ({int shown, bool more}) fold(int count, double width) => foldNodeFields(
      count: count,
      width: width,
      label: 40,
      icon: 16,
      gap: 6,
      plus: (_) => 14,
    );

    test('shows three at most and folds the rest into +N', () {
      expect(fold(5, 500), (shown: 3, more: true));
      expect(fold(3, 500), (shown: 3, more: false));
    });

    test('icons fold before +N, and +N before the protocol', () {
      // 40 + 2 * 22 + 20 = 104: two icons and +3.
      expect(fold(5, 104), (shown: 2, more: true));
      expect(fold(5, 60), (shown: 0, more: true));
      expect(fold(5, 59), (shown: 0, more: false));
      expect(fold(5, 30), (shown: 0, more: false));
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
      expect(reason.exit(_l), _l.routeExitDirect);
      expect(reason.notesTitle(_l), _l.routeReasonTitle);
      expect(reason.notes(_l), [
        _l.routeUdpSkippedUnsupported('Domain(a.test)', 'Proxy'),
        _l.routeNoMatch,
      ]);
      expect(reason.short(_l), _l.routeShortUdpSkipped);
    });

    test('the group that disabled UDP is named, not only the target', () {
      final notes = RouteReason(
        _tracker(
          skipped: const [
            UdpSkip(
              type: 'Domain',
              payload: 'a.test',
              adapter: 'Streaming',
              refused: 'HK',
              cause: 'disabled',
            ),
            UdpSkip(
              type: 'Match',
              adapter: 'HK',
              refused: 'HK',
              cause: 'disabled',
            ),
          ],
          reason: 'no-match',
        ),
      ).notes(_l);
      expect(notes.take(2), [
        _l.routeUdpSkippedDisabledBy('Domain(a.test)', 'Streaming', 'HK'),
        _l.routeUdpSkippedDisabled('Match', 'HK'),
      ]);
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

    test('global mode through a proxy names the exit and the mode', () {
      final reason = RouteReason(
        _tracker(reason: 'mode-global', chains: const ['HK 01', 'GLOBAL']),
      );
      expect(reason.exit(_l), 'HK 01');
      expect(reason.notes(_l), [_l.routeModeGlobalProxy]);
      expect(reason.short(_l), _l.routeShortModeGlobal);
    });

    test('a special proxy is not called internal', () {
      expect(RouteReason(_tracker(reason: 'special')).notes(_l), isEmpty);
    });

    test('an exit that was not recorded is unknown, with no reason', () {
      final reason = RouteReason(_tracker(chains: const []));
      expect(reason.exit(_l), _l.routeExitUnknown);
      expect(reason.notes(_l), isEmpty);
    });

    test('a rule that decided adds nothing', () {
      final reason = RouteReason(_tracker(rule: 'Match'));
      expect(reason.exit(_l), isNull);
      expect(reason.notes(_l), isEmpty);
    });

    testWidgets('details show the rule that hit, the skipped one apart', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          wrapInProviderScope: true,
          locale: const Locale('en'),
          homeBuilder: (child) => HostScaffold(body: child),
          child: SheetProvider(
            type: SheetType.page,
            child: TrackerInfoDetailView(
              trackerInfo: _tracker(
                rule: 'DomainSuffix',
                payload: 'test',
                chains: const ['HK 01'],
                skipped: const [skip],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('DomainSuffix(test)'), findsOneWidget);
      expect(find.text(_l.routeSkippedTitle), findsOneWidget);
      expect(
        find.text(_l.routeUdpSkippedUnsupported('Domain(a.test)', 'Proxy')),
        findsOneWidget,
      );
      expect(find.text('Domain(a.test)'), findsNothing);
      expect(find.text(_l.routeExitTitle), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('details put the exit and the reason in rows of their own', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestApp(
          wrapInProviderScope: true,
          locale: const Locale('en'),
          homeBuilder: (child) => HostScaffold(body: child),
          child: SheetProvider(
            type: SheetType.page,
            child: TrackerInfoDetailView(
              trackerInfo: _tracker(reason: 'no-match'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(_l.routeExitTitle), findsOneWidget);
      expect(find.text(_l.routeExitDirect), findsOneWidget);
      expect(find.text(_l.routeReasonTitle), findsOneWidget);
      expect(find.text(_l.routeNoMatch), findsOneWidget);
      expect(find.text(_l.rule), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
