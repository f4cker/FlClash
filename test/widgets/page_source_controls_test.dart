import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/host_scaffold.dart';
import '../helpers/preferences.dart';
import '../helpers/test_app.dart';

const _file = <String, Object?>{
  'log-level': 'silent',
  'find-process-mode': 'strict',
  'tun': {'enable': false, 'stack': 'gVisor'},
};

Future<ProviderContainer> _pump(
  WidgetTester tester,
  PatchClashConfig config,
  Widget child,
) async {
  await mockPreferences();
  final container = ProviderContainer();
  addTearDown(container.dispose);
  globalState.container = container;
  container.read(patchClashConfigProvider.notifier).value = config;
  container.read(profileSettingsProvider.notifier).value = _file;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TestApp(
        locale: const Locale('zh', 'CN'),
        child: HostScaffold(body: Column(children: [child])),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

bool _switchValue(WidgetTester tester) =>
    tester.widget<Switch>(find.byType(Switch)).value;

void main() {
  group('shownClashConfig', () {
    test('shows the file value, or the default, for a followed field', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(patchClashConfigProvider.notifier)
          .value = const PatchClashConfig(
        tun: Tun(enable: true, stack: TunStack.mixed),
        allowLan: true,
        logLevel: LogLevel.error,
        followKeys: {
          PageConfigKey.tunEnable,
          PageConfigKey.tunStack,
          PageConfigKey.allowLan,
        },
      );
      container.read(profileSettingsProvider.notifier).value = _file;

      final shown = container.read(shownClashConfigProvider);
      expect(shown.tun.enable, isFalse);
      expect(shown.tun.stack, TunStack.gvisor);
      expect(shown.allowLan, isFalse, reason: 'missing, so the default');
      expect(shown.logLevel, LogLevel.error, reason: 'not followed');
    });

    test('shows the page as stored in legacy mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(patchClashConfigProvider.notifier)
          .value = const PatchClashConfig(
        tun: Tun(enable: true),
        pagePriority: false,
        followKeys: {PageConfigKey.tunEnable},
      );
      container.read(profileSettingsProvider.notifier).value = _file;

      expect(container.read(shownClashConfigProvider).tun.enable, isTrue);
    });
  });

  testWidgets('a followed switch shows the file value', (tester) async {
    await _pump(
      tester,
      const PatchClashConfig(
        tun: Tun(enable: true),
        followKeys: {PageConfigKey.tunEnable},
      ),
      const TUNItem(),
    );

    expect(_switchValue(tester), isFalse);
  });

  testWidgets('moving a followed switch takes it back to the page', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      const PatchClashConfig(
        tun: Tun(enable: true),
        followKeys: {PageConfigKey.tunEnable},
      ),
      const TUNItem(),
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final config = container.read(patchClashConfigProvider);
    expect(config.followKeys, isEmpty);
    expect(config.tun.enable, isTrue);
    expect(_switchValue(tester), isTrue);
  });

  testWidgets('moving a followed switch to a new value keeps that value', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      const PatchClashConfig(
        tun: Tun(enable: false),
        followKeys: {PageConfigKey.tunEnable},
      ),
      const TUNItem(),
    );
    container.read(profileSettingsProvider.notifier).value = const {
      'tun': {'enable': true},
    };
    await tester.pumpAndSettle();
    expect(_switchValue(tester), isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final config = container.read(patchClashConfigProvider);
    expect(config.followKeys, isEmpty);
    expect(config.tun.enable, isFalse);
  });

  testWidgets('a followed list shows the file value in field terms', (
    tester,
  ) async {
    await _pump(
      tester,
      const PatchClashConfig(
        logLevel: LogLevel.error,
        followKeys: {PageConfigKey.logLevel},
      ),
      const LogLevelItem(),
    );

    expect(find.text('静默'), findsWidgets);
    expect(find.text('silent'), findsNothing);
    expect(find.text('error'), findsNothing);
  });

  testWidgets('picking from a followed list takes it back to the page', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      const PatchClashConfig(
        logLevel: LogLevel.error,
        followKeys: {PageConfigKey.logLevel},
      ),
      const LogLevelItem(),
    );

    await tester.tap(find.text('静默').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('调试').last);
    await tester.pumpAndSettle();

    final config = container.read(patchClashConfigProvider);
    expect(config.followKeys, isEmpty);
    expect(config.logLevel, LogLevel.debug);
  });
}
