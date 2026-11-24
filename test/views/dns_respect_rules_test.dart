import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/dns.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

const _profileId = 1;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  Future<void> pumpView(
    WidgetTester tester, {
    Dns dns = const Dns(),
    bool profile = false,
    Size size = const Size(1200, 1000),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(
          () => TestProfiles([
            Profile(
              id: _profileId,
              type: ProfileType.custom,
              autoUpdateDuration: Duration.zero,
              overrides: ProfileOverrides(
                dns: dns,
                dnsOverrideKeys: {DnsOverrideKey.respectRules},
              ),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).update((_) => size);
    container.listen(patchClashConfigProvider, (_, _) {});
    container.read(patchClashConfigProvider.notifier).value = PatchClashConfig(
      dns: dns,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: profile ? DnsView.profile(_profileId) : const DnsView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Dns dns() => container.read(patchClashConfigProvider).dns;

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('turning it on without a Proxy Server Nameserver asks for one '
      'and stays off', (tester) async {
    await pumpView(tester);
    final l = currentAppLocalizations;

    await tapText(tester, l.respectRules);

    expect(dns().respectRules, isFalse);
    expect(find.text(l.dnsRespectRulesNeedsProxyServer), findsOneWidget);
    expect(find.text(l.dnsRespectRulesUnmetWarning), findsNothing);

    await tapText(tester, l.cancel);
    expect(find.text(l.dnsRespectRulesNeedsProxyServer), findsNothing);
    expect(dns(), const Dns());
  });

  testWidgets('the prompt fills it from Nameserver and turns on, '
      'in one deliberate tap', (tester) async {
    await pumpView(tester);
    final l = currentAppLocalizations;
    await tapText(tester, l.respectRules);

    expect(find.text(l.dnsUseNameserverForProxyServerDesc), findsOneWidget);
    await tapText(tester, l.dnsUseNameserverForProxyServer);

    expect(dns().respectRules, isTrue);
    expect(dns().proxyServerNameserver, defaultDns.nameserver);
    expect(find.text(l.dnsRespectRulesNeedsProxyServer), findsNothing);
    expect(find.text(l.dnsRespectRulesUnmetWarning), findsNothing);
  });

  testWidgets('the prompt takes them to the list, and turns on once it '
      'holds a server', (tester) async {
    await pumpView(tester);
    final l = currentAppLocalizations;
    await tapText(tester, l.respectRules);

    await tapText(tester, l.dnsFillProxyServerNameserver);
    expect(find.byType(ListEditView), findsOneWidget);
    Navigator.of(
      tester.element(find.byType(ListEditView)),
    ).pop(['tls://1.1.1.1']);
    await tester.pumpAndSettle();

    expect(dns().proxyServerNameserver, ['tls://1.1.1.1']);
    expect(dns().respectRules, isTrue);
    expect(find.text(l.dnsRespectRulesNeedsProxyServer), findsNothing);
  });

  testWidgets('nothing reads as on until a non-empty list is saved', (
    tester,
  ) async {
    await pumpView(tester, dns: const Dns(nameserver: []));
    final l = currentAppLocalizations;
    await tapText(tester, l.respectRules);
    expect(find.text(l.dnsUseNameserverForProxyServer), findsNothing);
    expect(find.text(l.dnsUseNameserverForProxyServerDesc), findsNothing);

    for (final result in <Object?>[null, <String>[]]) {
      await tapText(tester, l.dnsFillProxyServerNameserver);
      Navigator.of(tester.element(find.byType(ListEditView))).pop(result);
      await tester.pumpAndSettle();

      expect(dns().respectRules, isFalse);
      expect(find.text(l.dnsRespectRulesNeedsProxyServer), findsOneWidget);
      expect(find.text(l.dnsRespectRulesUnmetWarning), findsNothing);
    }
  });

  testWidgets('the prompt opens under the switch, in a row when wide', (
    tester,
  ) async {
    await pumpView(tester);
    final l = currentAppLocalizations;
    await tapText(tester, l.respectRules);

    final prompt = tester.getRect(find.text(l.dnsRespectRulesNeedsProxyServer));
    final row = tester.getRect(find.text(l.respectRules));
    expect(prompt.top, greaterThan(row.bottom));
    final next = tester.getRect(find.text('Prefer H3'));
    expect(prompt.bottom, lessThan(next.top));

    final fill = tester.getRect(find.text(l.dnsFillProxyServerNameserver));
    final copy = tester.getRect(find.text(l.dnsUseNameserverForProxyServer));
    final cancel = tester.getRect(find.text(l.cancel));
    expect(fill.top, copy.top);
    expect(fill.left, lessThan(copy.left));
    expect(copy.left, lessThan(cancel.left));
  });

  testWidgets('narrow with large text, each button takes a row, whole', (
    tester,
  ) async {
    await pumpView(tester, size: const Size(360, 800), textScale: 2);
    final l = currentAppLocalizations;
    await tester.ensureVisible(find.text(l.respectRules));
    await tapText(tester, l.respectRules);

    final labels = [
      l.dnsFillProxyServerNameserver,
      l.dnsUseNameserverForProxyServer,
      l.cancel,
    ];
    final rects = [
      for (final label in labels) tester.getRect(find.text(label)),
    ];
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].top, greaterThanOrEqualTo(rects[i - 1].bottom));
    }
    for (final label in labels) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      expect(paragraph.size.width, lessThanOrEqualTo(360), reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('with a Proxy Server Nameserver it simply turns on', (
    tester,
  ) async {
    await pumpView(
      tester,
      dns: const Dns(proxyServerNameserver: ['tls://1.1.1.1']),
    );
    final l = currentAppLocalizations;

    await tapText(tester, l.respectRules);

    expect(dns().respectRules, isTrue);
    expect(find.text(l.dnsRespectRulesNeedsProxyServer), findsNothing);
  });

  testWidgets('a saved on and empty pair warns until it is fixed', (
    tester,
  ) async {
    await pumpView(tester, dns: const Dns(respectRules: true));
    final l = currentAppLocalizations;
    expect(find.text(l.dnsRespectRulesUnmetWarning), findsOneWidget);
    final warning = tester.getRect(find.text(l.dnsRespectRulesUnmetWarning));
    final first = tester.getRect(find.byType(ConfigToggleItem).first);
    expect(warning.bottom, lessThan(first.top), reason: 'atop the page');
    expect(
      tester.getRect(find.text(l.dnsFillProxyServerNameserver)).left,
      lessThan(tester.getRect(find.text(l.dnsTurnOffRespectRules)).left),
    );
    expect(find.text(l.dnsUseNameserverForProxyServer), findsNothing);
    expect(find.text(l.dnsUseNameserverForProxyServerDesc), findsNothing);
    expect(dns().respectRules, isTrue, reason: 'nothing changes by itself');

    await tapText(tester, l.dnsTurnOffRespectRules);

    expect(dns().respectRules, isFalse);
    expect(dns().proxyServerNameserver, isEmpty);
    expect(find.text(l.dnsRespectRulesUnmetWarning), findsNothing);
    expect(find.text(l.dnsRespectRulesNeedsProxyServer), findsNothing);
  });

  testWidgets('the warning goes once the list is filled in, leaving the '
      'switch on', (tester) async {
    await pumpView(tester, dns: const Dns(respectRules: true));
    final l = currentAppLocalizations;

    await tapText(tester, l.dnsFillProxyServerNameserver);
    Navigator.of(
      tester.element(find.byType(ListEditView)),
    ).pop(['https://doh.pub/dns-query']);
    await tester.pumpAndSettle();

    expect(dns().respectRules, isTrue);
    expect(dns().proxyServerNameserver, ['https://doh.pub/dns-query']);
    expect(find.text(l.dnsRespectRulesUnmetWarning), findsNothing);
  });

  testWidgets('a profile page leaves its switch alone', (tester) async {
    await pumpView(tester, profile: true);
    final l = currentAppLocalizations;

    await tapText(tester, l.respectRules);

    final overrides = container
        .read(profilesProvider)
        .getProfile(_profileId)!
        .overrides;
    expect(overrides.dns.respectRules, isTrue);
    expect(find.text(l.dnsRespectRulesNeedsProxyServer), findsNothing);
  });
}
