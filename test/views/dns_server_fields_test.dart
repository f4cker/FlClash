import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/dns.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

// One entry each, so a single checkbox empties a list.
const _dns = Dns(nameserver: ['1.1.1.1'], defaultNameserver: ['223.5.5.5']);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  Future<void> pumpView(
    WidgetTester tester, {
    bool appendSystemDns = false,
    Dns dns = _dns,
  }) async {
    const size = Size(1200, 1000);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).update((_) => size);
    container.listen(patchClashConfigProvider, (_, _) {});
    container.listen(networkSettingProvider, (_, _) {});
    container.read(patchClashConfigProvider.notifier).value = PatchClashConfig(
      dns: dns,
    );
    container
        .read(networkSettingProvider.notifier)
        .update((state) => state.copyWith(appendSystemDns: appendSystemDns));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: DnsView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Dns dns() => container.read(patchClashConfigProvider).dns;

  // Nameserver is a section's title as well.
  Future<void> tapRow(WidgetTester tester, String title) async {
    final row = find.text(title).last;
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(ListEditView), findsOneWidget, reason: title);
  }

  Future<List<String>> emptyAndSave(WidgetTester tester, String list) async {
    final l = currentAppLocalizations;
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (text, {wrapWidth}) => printed.add(text ?? '');
    addTearDown(() => debugPrint = original);
    await tapRow(tester, list);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.byTooltip(l.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l.save));
    await tester.pumpAndSettle();
    return printed;
  }

  testWidgets('Nameserver will not save empty without the system fallback', (
    tester,
  ) async {
    await pumpView(tester);
    final l = currentAppLocalizations;

    final printed = await emptyAndSave(tester, 'Nameserver');

    expect(printed, contains('[APP] banner: ${l.nameserverEmptyTip}'));
    expect(find.byType(ListEditView), findsOneWidget, reason: 'stays open');
    expect(dns().nameserver, _dns.nameserver);
  });

  testWidgets('with Append system DNS on, Nameserver saves empty', (
    tester,
  ) async {
    await pumpView(tester, appendSystemDns: true);

    await emptyAndSave(tester, 'Nameserver');

    expect(find.byType(ListEditView), findsNothing);
    expect(dns().nameserver, isEmpty);
  });

  testWidgets('Default Nameserver never saves empty', (tester) async {
    await pumpView(tester, appendSystemDns: true);
    final l = currentAppLocalizations;

    final printed = await emptyAndSave(tester, 'Default Nameserver');

    expect(printed, contains('[APP] banner: ${l.defaultNameserverEmptyTip}'));
    expect(dns().defaultNameserver, _dns.defaultNameserver);
  });

  testWidgets(
    'a DoH address is refused in Default Nameserver, as it is typed',
    (tester) async {
      await pumpView(tester);
      final l = currentAppLocalizations;
      await tester.tap(find.text('Default Nameserver'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(ListEditView),
          matching: find.byTooltip(l.add),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(PopupMenu), matching: find.text(l.add)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(EntryDialog<String>),
          matching: find.byType(TextFormField),
        ),
        'https://doh.pub/dns-query',
      );
      await tester.tap(find.text(l.confirm));
      await tester.pumpAndSettle();

      expect(find.text(l.defaultNameserverPureIpTip), findsOneWidget);
    },
  );

  testWidgets('rule filter mode is refused over a domain-style filter', (
    tester,
  ) async {
    await pumpView(tester, dns: _dns.copyWith(enhancedMode: DnsMode.fakeIp));
    final l = currentAppLocalizations;
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (text, {wrapWidth}) => printed.add(text ?? '');
    addTearDown(() => debugPrint = original);
    final row = find.text(l.fakeipFilterMode);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text(FakeIpFilterMode.rule.name).last);
    await tester.pumpAndSettle();

    expect(
      printed,
      contains(
        '[APP] banner: ${l.fakeIpFilterNotRulesTip(_dns.fakeIpFilter.first)}',
      ),
    );
    expect(dns().fakeIpFilterMode, FakeIpFilterMode.blacklist);

    await tester.tap(find.text(l.dnsMode));
    await tester.pumpAndSettle();
    await tester.tap(find.text('redir-host').last);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.text(FakeIpFilterMode.rule.name).last);
    await tester.pumpAndSettle();
    expect(dns().fakeIpFilterMode, FakeIpFilterMode.rule, reason: 'no fake-ip');
  });

  testWidgets('a rule filter flags the entries that are not rules', (
    tester,
  ) async {
    await pumpView(
      tester,
      dns: _dns.copyWith(
        enhancedMode: DnsMode.fakeIp,
        fakeIpFilterMode: FakeIpFilterMode.rule,
        fakeIpFilter: ['DOMAIN-SUFFIX,lan,real-ip', 'example.com'],
      ),
    );
    final l = currentAppLocalizations;
    await tapRow(tester, l.fakeipFilter);

    expect(find.text(l.fakeIpFilterRuleTip), findsOneWidget);
  });
}
