import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/app_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/navigation.dart';
import 'package:fl_clash/ui/icons/app_glyphs.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

const _size = Size(1200, 900);

void main() {
  setUp(() {
    mitmFeature = true;
    navigationPort = navigation;
    addTearDown(() {
      mitmFeature = false;
      navigationPort = null;
    });
  });

  ProviderContainer containerWith({
    Map<String, bool> collapsed = const {},
    bool decrypting = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        navigationItemsStateProvider.overrideWith(
          (_) => NavigationItemsState(
            value: navigation.getItems(
              openLogs: true,
              hasProxies: true,
              showRules: true,
            ),
          ),
        ),
        navigationBadgesProvider.overrideWithValue(const {}),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = _size;
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(sidebarCollapsedGroups: collapsed));
    container.listen(patchClashConfigProvider, (_, _) {});
    container
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) =>
              state.copyWith(mitm: state.mitm.copyWith(enable: decrypting)),
        );
    return container;
  }

  Future<void> pump(WidgetTester tester, ProviderContainer container) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          locale: Locale('en'),
          includeNavigatorKey: false,
          child: AppSidebarContainer(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A row in a closed section is clipped away, out of reach.
  bool shows(String label) =>
      find.text(label).hitTestable().evaluate().isNotEmpty;

  testWidgets('lists each page under its group, with More at the foot', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = containerWith(decrypting: true);
    await pump(tester, container);

    expect(navigation.getItems().last.glyph, same(AppGlyphs.moreCircle));
    final titles = ['Routing', 'Decryption & Rewrite', 'Debugging', 'Network'];
    final tops = [
      for (final title in titles) tester.getTopLeft(find.text(title)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(tester.getTopLeft(find.text('Rules')).dy, greaterThan(tops[0]));
    expect(tester.getTopLeft(find.text('Rules')).dy, lessThan(tops[1]));
    // More stays below the scrolling list, out of every group.
    expect(
      tester.getTopLeft(find.text('More')).dy,
      greaterThan(tester.getTopLeft(find.text('Network')).dy),
    );
    expect(shows('HTTPS decryption'), isTrue);
    expect(shows('Rewrite'), isTrue);
    // The network group starts closed.
    expect(shows('Tailscale'), isFalse);
    semantics.dispose();
  });

  testWidgets('decryption starts closed while it is off', (tester) async {
    final semantics = tester.ensureSemantics();
    final container = containerWith();
    await pump(tester, container);

    expect(shows('HTTPS decryption'), isFalse);
    expect(shows('Rules'), isTrue);
    expect(
      find.bySemanticsLabel('Decryption & Rewrite, group, collapsed'),
      findsOneWidget,
    );

    container
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(mitm: state.mitm.copyWith(enable: true)),
        );
    await tester.pumpAndSettle();
    expect(shows('HTTPS decryption'), isTrue);
    semantics.dispose();
  });

  testWidgets('a group the user closes stays closed and is remembered', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = containerWith(decrypting: true);
    await pump(tester, container);

    await tester.tap(find.text('Debugging'));
    await tester.pumpAndSettle();
    expect(shows('Requests'), isFalse);
    expect(container.read(appSettingProvider).sidebarCollapsedGroups, {
      'debug': true,
    });

    await tester.tap(find.text('Decryption & Rewrite'));
    await tester.pumpAndSettle();
    expect(shows('HTTPS decryption'), isFalse);

    // The user's choice outranks the switch from then on.
    container
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(mitm: state.mitm.copyWith(enable: false)),
        );
    container
        .read(patchClashConfigProvider.notifier)
        .update(
          (state) => state.copyWith(mitm: state.mitm.copyWith(enable: true)),
        );
    await tester.pumpAndSettle();
    expect(shows('HTTPS decryption'), isFalse);

    // A restart reads the saved setting back.
    final saved = container.read(appSettingProvider).sidebarCollapsedGroups;
    final restored = AppSettingProps.fromJson(
      jsonDecode(jsonEncode(AppSettingProps(sidebarCollapsedGroups: saved)))
          as Map<String, dynamic>,
    );
    final again = containerWith(
      collapsed: restored.sidebarCollapsedGroups,
      decrypting: true,
    );
    await pump(tester, again);
    expect(shows('Requests'), isFalse);
    expect(shows('HTTPS decryption'), isFalse);
    expect(shows('Rules'), isTrue);

    await tester.tap(find.text('Debugging'));
    await tester.pumpAndSettle();
    expect(shows('Requests'), isTrue);
    expect(
      again.read(appSettingProvider).sidebarCollapsedGroups['debug'],
      isFalse,
    );
    semantics.dispose();
  });

  testWidgets('a page opened inside a closed group opens it', (tester) async {
    final semantics = tester.ensureSemantics();
    final container = containerWith(collapsed: {'debug': true});
    await pump(tester, container);
    expect(shows('Requests'), isFalse);

    container.read(currentPageLabelProvider.notifier).toPage(PageLabel.dns);
    await tester.pumpAndSettle();

    expect(shows('Requests'), isTrue);
    expect(
      container.read(appSettingProvider).sidebarCollapsedGroups['debug'],
      isFalse,
    );
    semantics.dispose();
  });

  testWidgets('a screen reader names the heading and toggles it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final container = containerWith(collapsed: {'network': false});
    await pump(tester, container);
    expect(shows('Tailscale'), isTrue);

    tester.semantics.tap(find.semantics.byLabel('Network, group, expanded'));
    await tester.pumpAndSettle();

    expect(shows('Tailscale'), isFalse);
    expect(find.semantics.byLabel('Network, group, collapsed'), findsOne);
    semantics.dispose();
  });
}
