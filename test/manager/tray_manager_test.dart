import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/tray_menu.dart';
import 'package:fl_clash/common/compute.dart';
import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/manager/locale_manager.dart';
import 'package:fl_clash/manager/tray_manager.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:rust_api/tray.dart';

import '../helpers/fake_desktop_window.dart';
import '../helpers/fake_tray_host.dart';
import '../helpers/test_profiles.dart';
import '../helpers/test_app.dart';

class _RecordingSystemAction extends SystemAction {
  static int updateTrayCount = 0;
  static final List<String> updateTrayLocales = <String>[];

  @override
  Future<void> updateTray() async {
    updateTrayCount++;
    updateTrayLocales.add(Intl.getCurrentLocale());
  }
}

class _FailingSystemAction extends SystemAction {
  @override
  Future<void> updateTray() async {
    throw StateError('tray boom');
  }
}

class _SlowFirstFailureSystemAction extends SystemAction {
  static int updateTrayCount = 0;
  static Completer<void> firstUpdate = Completer<void>();

  @override
  Future<void> updateTray() async {
    if (updateTrayCount++ == 0) {
      await firstUpdate.future;
      throw StateError('tray boom');
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeDesktopWindow fakeWindow;
  late FakeTrayHost trayHost;

  setUpAll(() async {
    loadAppLocalizations(const Locale('en'));
  });

  setUp(() {
    _RecordingSystemAction.updateTrayCount = 0;
    _RecordingSystemAction.updateTrayLocales.clear();
    trayHost = FakeTrayHost();
    Tray.instance.resetForTesting(trayHost);
    fakeWindow = FakeDesktopWindow().install();
  });

  tearDown(() {
    container.dispose();
  });

  void emitTrayEvent(TraySignalKind kind) {
    trayHost.emit(kind);
  }

  Future<void> pumpTrayManager(
    WidgetTester tester, {
    SystemAction Function()? systemAction,
    bool isMacOS = true,
  }) async {
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        currentProfileProvider.overrideWithValue(null),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        systemBrightnessProvider.overrideWithBuild((_, _) => Brightness.light),
        systemActionProvider.overrideWith(
          systemAction ?? _RecordingSystemAction.new,
        ),
      ],
    );
    globalState.container = container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: HostApp(
          home: TrayManager(isMacOS: isMacOS, child: const SizedBox.shrink()),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpLocalizedTrayManager(
    WidgetTester tester,
    Locale locale,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: HostApp(
          locale: locale,
          home: const LocaleManager(
            child: TrayManager(isMacOS: true, child: SizedBox.shrink()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final isMacOS in [true, false]) {
    testWidgets('Core lifecycle changes refresh tray (macOS: $isMacOS)', (
      tester,
    ) async {
      await pumpTrayManager(tester, isMacOS: isMacOS);
      expect(container.read(isStartProvider), isFalse);
      for (final change in <void Function()>[
        () =>
            container.read(trayCoreTogglePendingProvider.notifier).value = true,
        () => container.read(trayCoreTogglePendingProvider.notifier).value =
            false,
        () => container.read(coreStatusProvider.notifier).value =
            CoreStatus.disconnected,
      ]) {
        _RecordingSystemAction.updateTrayCount = 0;
        change();
        await tester.pumpAndSettle();
        expect(_RecordingSystemAction.updateTrayCount, greaterThan(0));
      }
    });
  }

  testWidgets('global install busy refreshes the macOS tray', (tester) async {
    await pumpTrayManager(tester);
    _RecordingSystemAction.updateTrayCount = 0;
    container.read(updateInstallBusyProvider.notifier).value = true;
    await tester.pumpAndSettle();
    expect(_RecordingSystemAction.updateTrayCount, greaterThan(0));
  });

  testWidgets('hidden setting and source label changes refresh the menu', (
    tester,
  ) async {
    await pumpTrayManager(tester);
    container
        .read(proxiesStyleSettingProvider.notifier)
        .update((state) => state.copyWith(showHiddenGroups: true));
    await tester.pumpAndSettle();
    expect(_RecordingSystemAction.updateTrayCount, greaterThan(0));
    _RecordingSystemAction.updateTrayCount = 0;
    container
        .read(profilesProvider.notifier)
        .put(
          const Profile(
            id: 7,
            label: 'Renamed source',
            type: ProfileType.url,
            autoUpdateDuration: Duration.zero,
          ),
        );
    await tester.pumpAndSettle();
    expect(_RecordingSystemAction.updateTrayCount, greaterThan(0));
  });

  testWidgets('confirmed availability and clearing refresh the status icon', (
    tester,
  ) async {
    await pumpTrayManager(tester);
    final available = container.read(availableUpdateStateProvider.notifier);
    for (final value in [
      const UpdateAvailable({'tag_name': 'v1.0.0+2026111902'}),
      null,
    ]) {
      _RecordingSystemAction.updateTrayCount = 0;
      available.value = value;
      await tester.pumpAndSettle();
      expect(_RecordingSystemAction.updateTrayCount, 1);
    }
  });

  testWidgets('renders its child untouched', (tester) async {
    await pumpTrayManager(tester);

    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('activating the icon brings the window back', (tester) async {
    await pumpTrayManager(tester);
    fakeWindow.calls.clear();

    emitTrayEvent(TraySignalKind.iconActivated);
    await tester.pumpAndSettle();
    // A macOS host arms the Dock settle timer on show; drain it so the binding
    // ends the test with no pending timer.
    await tester.pump(const Duration(seconds: 1));

    expect(fakeWindow.methods, containsAll(<String>['show', 'focus']));
  });

  testWidgets('a menu request is forwarded to the tray', (tester) async {
    await pumpTrayManager(tester);

    emitTrayEvent(TraySignalKind.menuRequested);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a tray state change pushes the tray forward', (tester) async {
    await pumpTrayManager(tester);
    _RecordingSystemAction.updateTrayCount = 0;

    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mixedPort: state.mixedPort + 1));
    await tester.pumpAndSettle();

    expect(_RecordingSystemAction.updateTrayCount, 1);
  });

  testWidgets('an unchanged tray state does not touch the tray', (
    tester,
  ) async {
    await pumpTrayManager(tester);
    _RecordingSystemAction.updateTrayCount = 0;

    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mixedPort: state.mixedPort));
    await tester.pumpAndSettle();

    expect(_RecordingSystemAction.updateTrayCount, 0);
  });

  testWidgets('a failed tray update is reported instead of thrown', (
    tester,
  ) async {
    await pumpTrayManager(tester, systemAction: _FailingSystemAction.new);

    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mixedPort: state.mixedPort + 1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a change made during a failing update still reaches the tray', (
    tester,
  ) async {
    _SlowFirstFailureSystemAction.updateTrayCount = 0;
    _SlowFirstFailureSystemAction.firstUpdate = Completer<void>();
    await pumpTrayManager(
      tester,
      systemAction: _SlowFirstFailureSystemAction.new,
    );

    for (var i = 0; i < 2; i++) {
      container
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(mixedPort: state.mixedPort + 1));
      await tester.pump();
    }
    expect(_SlowFirstFailureSystemAction.updateTrayCount, 1);

    _SlowFirstFailureSystemAction.firstUpdate.complete();
    await tester.pumpAndSettle();

    expect(_SlowFirstFailureSystemAction.updateTrayCount, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a language switch pushes the tray in the new language', (
    tester,
  ) async {
    addTearDown(() => loadAppLocalizations(const Locale('en')));
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        currentProfileProvider.overrideWithValue(null),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        systemBrightnessProvider.overrideWithBuild((_, _) => Brightness.light),
        systemActionProvider.overrideWith(_RecordingSystemAction.new),
      ],
    );
    globalState.container = container;
    await pumpLocalizedTrayManager(tester, const Locale('en'));
    _RecordingSystemAction.updateTrayCount = 0;
    _RecordingSystemAction.updateTrayLocales.clear();

    await pumpLocalizedTrayManager(tester, const Locale('zh', 'CN'));

    expect(_RecordingSystemAction.updateTrayCount, 1);
    expect(_RecordingSystemAction.updateTrayLocales, <String>['zh']);
  });

  testWidgets('the locale a language switch starts from does not push twice', (
    tester,
  ) async {
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        currentProfileProvider.overrideWithValue(null),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        systemBrightnessProvider.overrideWithBuild((_, _) => Brightness.light),
        systemActionProvider.overrideWith(_RecordingSystemAction.new),
      ],
    );
    globalState.container = container;
    await pumpLocalizedTrayManager(tester, const Locale('en'));
    _RecordingSystemAction.updateTrayCount = 0;

    await pumpLocalizedTrayManager(tester, const Locale('en'));

    expect(_RecordingSystemAction.updateTrayCount, 0);
  });

  testWidgets('mounting subscribes without an initial recursive tray read', (
    tester,
  ) async {
    await pumpTrayManager(tester);
    expect(_RecordingSystemAction.updateTrayCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('raw confirmation changes update a selection-stripped menu', (
    tester,
  ) async {
    await pumpTrayManager(tester);
    const group = Group(
      name: 'Proxy',
      type: GroupType.Selector,
      now: 'A',
      all: [
        Proxy(name: 'A', type: 'Direct'),
        Proxy(name: 'B', type: 'Direct'),
      ],
    );
    container.read(groupsProvider.notifier).value = [group];
    await tester.pumpAndSettle();
    _RecordingSystemAction.updateTrayCount = 0;
    container.read(groupsProvider.notifier).value = [group.copyWith(now: 'B')];
    await tester.pumpAndSettle();
    expect(_RecordingSystemAction.updateTrayCount, 1);
  });

  testWidgets(
    'pending, confirmation, read failure and group test state update the menu',
    (tester) async {
      await pumpTrayManager(tester);
      final states = container.read(trayGroupMenuStatesProvider.notifier);
      final readFailure = container.read(trayGroupsReadFailedProvider.notifier);
      final testing = container.read(delayTestingGroupsProvider.notifier);
      for (final change in <void Function()>[
        () => states.set(
          'Proxy',
          const TrayGroupMenuState(confirmedName: 'A', pendingName: 'B'),
        ),
        () => states.set('Proxy', const TrayGroupMenuState(confirmedName: 'B')),
        () => readFailure.set(true),
        () => testing.start('Proxy'),
      ]) {
        _RecordingSystemAction.updateTrayCount = 0;
        change();
        await tester.pumpAndSettle();
        expect(_RecordingSystemAction.updateTrayCount, 1);
      }
    },
  );

  testWidgets('pending target phases update even with no measured delays', (
    tester,
  ) async {
    await pumpTrayManager(tester);
    final key = delayTestKey('https://test.invalid', 'Leaf');
    final pending = container.read(pendingDelayTestsProvider.notifier);
    for (final change in <void Function()>[
      () => pending.apply(acquired: [key]),
      () => pending.apply(started: [key]),
      () => pending.apply(finished: [key]),
    ]) {
      _RecordingSystemAction.updateTrayCount = 0;
      change();
      await tester.pumpAndSettle();
      expect(_RecordingSystemAction.updateTrayCount, 1);
    }
  });

  testWidgets(
    'theme scheme, brightness, core and profile changes reach the menu',
    (tester) async {
      await pumpTrayManager(tester);
      for (final change in <void Function()>[
        () => container
            .read(themeSettingProvider.notifier)
            .update((state) => state.copyWith(primaryColor: 0xFF0080FF)),
        () => container.read(systemBrightnessProvider.notifier).value =
            Brightness.dark,
        () => container
            .read(themeSettingProvider.notifier)
            .update((state) => state.copyWith(primaryColor: null)),
        () => container
            .read(dynamicColorProvider.notifier)
            .seed(accentColor: const Color(0xFF00FF80)),
        () => container.read(coreStatusProvider.notifier).value =
            CoreStatus.disconnected,
        () => container.read(currentProfileIdProvider.notifier).value = 42,
      ]) {
        _RecordingSystemAction.updateTrayCount = 0;
        change();
        await tester.pumpAndSettle();
        expect(_RecordingSystemAction.updateTrayCount, greaterThanOrEqualTo(1));
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('unrelated app state does not refresh the tray', (tester) async {
    await pumpTrayManager(tester);
    _RecordingSystemAction.updateTrayCount = 0;
    container.read(queryProvider(QueryTag.proxies).notifier).value = 'search';
    await tester.pumpAndSettle();
    expect(_RecordingSystemAction.updateTrayCount, 0);
  });

  testWidgets('non-macOS avoids all rich-menu subscriptions', (tester) async {
    await pumpTrayManager(tester, isMacOS: false);
    _RecordingSystemAction.updateTrayCount = 0;
    container
        .read(trayGroupMenuStatesProvider.notifier)
        .set('Proxy', const TrayGroupMenuState(pendingName: 'A'));
    container
        .read(pendingDelayTestsProvider.notifier)
        .apply(acquired: ['test-key']);
    container
        .read(themeSettingProvider.notifier)
        .update((state) => state.copyWith(primaryColor: 0xFF123456));
    await tester.pumpAndSettle();
    expect(_RecordingSystemAction.updateTrayCount, 0);
  });

  testWidgets('rich-menu subscriptions stop after disposal', (tester) async {
    await pumpTrayManager(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    _RecordingSystemAction.updateTrayCount = 0;
    container
        .read(trayGroupMenuStatesProvider.notifier)
        .set('Proxy', const TrayGroupMenuState(pendingName: 'A'));
    container
        .read(pendingDelayTestsProvider.notifier)
        .apply(acquired: ['test-key']);
    container
        .read(themeSettingProvider.notifier)
        .update((state) => state.copyWith(primaryColor: 0xFF123456));
    await tester.pumpAndSettle();
    expect(_RecordingSystemAction.updateTrayCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tray events stop being handled after disposal', (tester) async {
    await pumpTrayManager(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    fakeWindow.calls.clear();

    emitTrayEvent(TraySignalKind.iconActivated);
    await tester.pumpAndSettle();

    expect(fakeWindow.methods, isEmpty);
  });
}
