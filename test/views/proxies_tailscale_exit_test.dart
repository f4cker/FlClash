import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/card.dart';
import 'package:fl_clash/views/proxies/list.dart';
import 'package:fl_clash/views/views.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart' show BuildContextExtension;

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import 'tailscale_fixtures.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    TailscaleExitReport report, {
    Set<String> unfold = const {'国际媒体', 'Tailscale 出口'},
  }) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final groups = tsExitGroups();
    final profile = Profile.normal().copyWith(unfoldSet: unfold);
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        currentGroupsStateProvider.overrideWithValue(
          GroupsState(value: groups),
        ),
        groupsProvider.overrideWithValue(groups),
        tailscaleExitRuntimeProvider.overrideWithBuild((_, _) async => report),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(900, 1000));
    container.listen(tailscaleExitRuntimeProvider, (_, _) {});
    await container.read(tailscaleExitRuntimeProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('zh', 'CN'), child: ProxiesView()),
      ),
    );
    container
        .read(proxiesStyleSettingProvider.notifier)
        .update((state) => state.copyWith(type: ProxiesType.list));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  Finder card(String group, String proxy) => find.byWidgetPredicate(
    (widget) =>
        widget is ProxyCard &&
        widget.groupName == group &&
        widget.proxy.name == proxy,
  );

  testWidgets('the exit group is the last option and the last group', (
    tester,
  ) async {
    await pump(tester, tsExitReport());

    final headers = tester
        .widgetList<ListHeader>(find.byType(ListHeader))
        .map((header) => header.group.name);
    expect(headers.last, 'Tailscale 出口');
    final options = tester
        .widgetList<ProxyCard>(
          find.byWidgetPredicate(
            (widget) => widget is ProxyCard && widget.groupName == '国际媒体',
          ),
        )
        .map((card) => card.proxy.name);
    expect(options.last, 'Tailscale 出口');
    expect(
      find.descendant(
        of: card('Tailscale 出口', tsExitMember),
        matching: find.text('Tailscale 出口'),
      ),
      findsOneWidget,
    );
    expect(find.text('不可用'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('the Core\'s order is kept, the exit group last', () async {
    Map<String, Object> group(String name, List<String> all) => {
      'name': name,
      'type': 'Selector',
      'now': all.first,
      'all': all,
    };
    final groups = await buildGroups(
      ComputeGroupsState(
        proxiesData: ProxiesData(
          all: const ['GLOBAL', '国际媒体', '全球手动', 'Tailscale 出口'],
          proxies: {
            'GLOBAL': group('GLOBAL', ['国际媒体', '全球手动']),
            '国际媒体': group('国际媒体', ['全球手动', 'DIRECT', 'Tailscale 出口']),
            '全球手动': group('全球手动', ['DIRECT', 'Tailscale 出口']),
            'Tailscale 出口': group('Tailscale 出口', [tsExitMember]),
            'DIRECT': {'name': 'DIRECT', 'type': 'Direct'},
            tsExitMember: {'name': tsExitMember, 'type': 'Tailscale'},
          },
        ),
        sortType: ProxiesSortType.none,
        delayMap: const {},
        selectedMap: const {},
        defaultTestUrl: '',
      ),
    );
    expect(groups.map((group) => group.name).last, 'Tailscale 出口');
    expect(groups[1].all.map((proxy) => proxy.name).last, 'Tailscale 出口');
  });

  testWidgets('an unavailable exit reads 不可用 in the error colour', (
    tester,
  ) async {
    await pump(
      tester,
      tsExitReport(
        state: TailscaleExitState.unavailable,
        reason: TailscaleExitReason.offline,
      ),
    );

    for (final (group, proxy) in [
      ('国际媒体', 'Tailscale 出口'),
      ('Tailscale 出口', tsExitMember),
    ]) {
      final label = find.descendant(
        of: card(group, proxy),
        matching: find.text('不可用'),
      );
      expect(label, findsOneWidget);
      expect(
        tester.widget<Text>(label).style?.color,
        tester.element(label).colorScheme.error,
      );
    }
    expect(
      find.descendant(of: card('国际媒体', 'DIRECT'), matching: find.text('不可用')),
      findsNothing,
    );
  });

  testWidgets('choosing a node of the exit group keeps it by account', (
    tester,
  ) async {
    final container = await pump(tester, tsExitReport());

    await tester.tap(card('Tailscale 出口', tsExitMember));
    await tester.pump(const Duration(milliseconds: 10));

    final selected = container.read(profilesProvider).single.selectedMap;
    expect(selected['Tailscale 出口'], tsExitMember);
    expect(selected[tailscaleExitSelectionKey], 'm1');
    debouncer.cancel((FunctionTag.changeProxy, 'Tailscale 出口'));
  });
}
