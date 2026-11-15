import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/core/spill.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/providers/tailscale.dart';
import 'package:fl_clash/providers/tray_menu.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:riverpod/riverpod.dart';
import 'package:yaml/yaml.dart';

import '../helpers/app_paths.dart';
import '../helpers/preferences.dart';
import '../helpers/test_profiles.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

// checkAndUpdateAndCopy checks the file system before it refreshes, so its
// failure tests need appPath to resolve to a real, writable directory.
class _HeldSourceProfilesAction extends ProfilesAction {
  final ready = Completer<void>();
  final result = Completer<Profile?>();

  @override
  Future<Profile?> ensureSource(Profile profile) {
    ready.complete();
    return result.future;
  }
}

class _ListenerHandoffFailureSetupAction extends SetupAction {
  final List<bool> coreRunningCalls = [];

  @override
  Future<void> setCoreRunning(bool running) async {
    coreRunningCalls.add(running);
    if (running) {
      throw StateError('listener handoff failed');
    }
  }
}

class _MessageFailureSetupAction extends SetupAction {
  final List<bool> coreRunningCalls = [];

  @override
  Future<void> setCoreRunning(bool running) async {
    coreRunningCalls.add(running);
  }
}

class _UnflooredDebounceSetupAction extends SetupAction {
  @override
  Duration get minApplyDebounce => Duration.zero;
}

class _CappedDebounceSetupAction extends _UnflooredDebounceSetupAction {
  @override
  Duration get maxApplyDebounce => const Duration(milliseconds: 300);
}

class TestCommonAction extends CommonAction {
  int trafficUpdates = 0;

  @override
  Future<void> updateTraffic() async {
    trafficUpdates++;
  }
}

class TestSetupAction extends SetupAction {
  final List<bool> coreRunningCalls = [];
  final List<Completer<void>> pendingCoreCalls = [];
  int trafficResets = 0;
  int applyProfileCalls = 0;
  final List<bool> appliedForce = [];
  bool blockCoreCalls = false;
  Error? coreRunningError;
  final Set<bool> unansweredCoreCalls = {};
  int authorizeCalls = 0;
  AuthorizeCode authorizeResult = AuthorizeCode.none;
  DateTime? serviceStart;

  @override
  Future<DateTime?> serviceStartTime() async => serviceStart;

  @override
  Duration get minApplyDebounce => const Duration(milliseconds: 100);

  @override
  Future<AuthorizeCode> authorizeCore() async {
    authorizeCalls++;
    return authorizeResult;
  }

  @override
  Future<void> setCoreRunning(bool running) async {
    coreRunningCalls.add(running);
    if (blockCoreCalls) {
      final gate = Completer<void>();
      pendingCoreCalls.add(gate);
      await gate.future;
    }
    final error = coreRunningError;
    if (error != null) {
      throw error;
    }
    if (unansweredCoreCalls.contains(running)) {
      throw const CoreMethodException(code: 'no_response', message: '');
    }
  }

  @override
  void resetCoreTraffic() => trafficResets++;

  /// Null answers with the configured port, a healthy listener.
  int? listening;
  Exception? listeningError;
  int listeningQueries = 0;

  @override
  Future<int> listeningMixedPort() async {
    listeningQueries++;
    final error = listeningError;
    if (error != null) {
      throw error;
    }
    return listening ?? ref.read(patchClashConfigProvider).mixedPort;
  }

  /// What the Core reports holding; null fails the query.
  Map<String, Object?>? heldPorts;

  @override
  Future<Map<String, Object?>> listeningPorts() async =>
      heldPorts ?? (throw const CoreMethodException(code: 'x', message: ''));

  /// Stands in for [SystemProxyQueue.startCount].
  int proxyStarts = 0;

  /// Null answers from [proxyStarts]; false is a queue that cannot tell.
  bool? proxyUnchanged;
  final List<int> proxyMarksAsked = [];

  @override
  int systemProxyStartCount() => proxyStarts;

  @override
  Future<bool> systemProxyUnchangedSince(int mark) async {
    proxyMarksAsked.add(mark);
    return proxyUnchanged ?? proxyStarts == mark;
  }

  @override
  Future<bool> applyProfile({
    bool Function()? owns,
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    applyProfileCalls++;
    appliedForce.add(force);
    await preloadInvoke?.call();
    return true;
  }
}

class _TrayDeadlineSetupAction extends TestSetupAction {
  Duration deadline = const Duration(seconds: 15);
  Completer<AuthorizeCode>? authorization;
  Completer<int>? listener;

  @override
  Duration get trayModeDeadline => deadline;

  @override
  Future<AuthorizeCode> authorizeCore() async {
    final result = await super.authorizeCore();
    return authorization?.future ?? result;
  }

  @override
  Future<int> listeningMixedPort() =>
      listener?.future ?? super.listeningMixedPort();
}

class _ManagedHelperSetupAction extends TestSetupAction {
  MacHelperState helperState = MacHelperState.installerRequired;
  Completer<MacHelperState>? helperCheck;
  bool installSucceeds = false;
  int invitations = 0;

  @override
  bool get usesManagedMacHelper => true;

  @override
  Future<MacHelperState> checkMacHelper() async =>
      helperCheck?.future ?? helperState;

  @override
  Future<void> presentMacHelper() async {
    invitations++;
    if (installSucceeds) helperState = MacHelperState.enabled;
  }
}

class _HelperRetryCoreAction extends CoreAction {
  int starts = 0;

  @override
  Future<void> startCore() async {
    starts++;
    ref.read(coreStatusProvider.notifier).value = CoreStatus.connected;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(
      const SetupParams(
        selectedMap: {},
        options: CoreOptions(testUrl: ''),
      ),
    );
    registerFallbackValue(const SetupBase(path: '', overlay: ''));
    registerFallbackValue(
      const UpdateParams(
        tun: {'enable': false},
        mixedPort: 7890,
        allowLan: false,
        findProcessMode: FindProcessMode.off,
        mode: Mode.rule,
        logLevel: LogLevel.info,
        ipv6: false,
        tcpConcurrent: false,
        externalController: ExternalControllerStatus.close,
        unifiedDelay: false,
        options: CoreOptions(testUrl: ''),
      ),
    );
  });

  late TestSetupAction action;
  late ProviderContainer container;

  setUp(() async {
    // This suite exercises already-adopted paths. First-adoption cases live in
    // composition_adoption_test.dart and explicitly seed revision zero.
    await mockPreferences({'compositionRevision': 1});
    action = TestSetupAction();
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        setupActionProvider.overrideWith(() => action),
        commonActionProvider.overrideWith(TestCommonAction.new),
      ],
    );
    globalState.container = container;
    globalState.needInitStatus = true;
    container.read(setupActionProvider.notifier);
  });

  tearDown(() async {
    action.blockCoreCalls = false;
    action.coreRunningError = null;
    action.unansweredCoreCalls.clear();
    for (final gate in action.pendingCoreCalls) {
      if (!gate.isCompleted) {
        gate.complete();
      }
    }
    await container.read(setupActionProvider.notifier).setRunning(false);
    container.dispose();
    globalState.needInitStatus = true;
  });

  void markInitialized() {
    container.read(initProvider.notifier).value = true;
  }

  group('setRunning gating', () {
    test('ignores a start request before initialization completes', () async {
      await container.read(setupActionProvider.notifier).setRunning(true);

      expect(action.coreRunningCalls, isEmpty);
      expect(container.read(runTimeProvider), isNull);
    });

    test('an initialize request bypasses the init gate', () async {
      await container
          .read(setupActionProvider.notifier)
          .setRunning(true, initialize: true);

      expect(action.coreRunningCalls, [true]);
      expect(action.applyProfileCalls, 1);
      expect(globalState.needInitStatus, isFalse);
    });

    test('safe mode runs the profile but never touches the listener', () async {
      final scopedAction = TestSetupAction();
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          setupActionProvider.overrideWith(() => scopedAction),
          commonActionProvider.overrideWith(TestCommonAction.new),
          safeModeProvider.overrideWithValue(true),
        ],
      );
      addTearDown(scoped.dispose);
      globalState.container = scoped;
      scoped.read(setupActionProvider.notifier);

      await scoped
          .read(setupActionProvider.notifier)
          .setRunning(true, initialize: true);

      expect(scopedAction.coreRunningCalls, isEmpty);
      expect(scopedAction.applyProfileCalls, 1);
      expect(scoped.read(isStartProvider), isTrue);

      await scoped.read(setupActionProvider.notifier).setRunning(false);

      expect(scopedAction.coreRunningCalls, isEmpty);
      expect(scoped.read(isStartProvider), isFalse);
    });

    test('starts the core once initialization is done', () async {
      markInitialized();

      await container.read(setupActionProvider.notifier).setRunning(true);

      expect(action.coreRunningCalls, [true]);
      expect(container.read(runTimeProvider), isNotNull);
    });

    test('a stop request is never gated on initialization', () async {
      await container.read(setupActionProvider.notifier).setRunning(false);

      expect(action.coreRunningCalls, [false]);
    });
  });

  group('managed helper feature dependency', () {
    late _ManagedHelperSetupAction managed;
    late _HelperRetryCoreAction core;
    late ProviderContainer scoped;

    setUp(() {
      managed = _ManagedHelperSetupAction();
      core = _HelperRetryCoreAction();
      scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          setupActionProvider.overrideWith(() => managed),
          coreActionProvider.overrideWith(() => core),
          commonActionProvider.overrideWith(TestCommonAction.new),
        ],
      );
      globalState.container = scoped;
      scoped.read(initProvider.notifier).value = true;
      scoped.read(setupActionProvider.notifier);
    });

    tearDown(() => scoped.dispose());

    test('declining leaves GUI initialized and saved TUN unchanged', () async {
      final saved = scoped.read(patchClashConfigProvider).tun.enable;
      expect(await managed.setRunning(true), isFalse);
      expect(managed.invitations, 1);
      expect(scoped.read(initProvider), isTrue);
      expect(scoped.read(patchClashConfigProvider).tun.enable, saved);
      expect(managed.coreRunningCalls, isEmpty);
      expect(core.starts, 0);
    });

    test('automatic setup never repeats the invitation', () async {
      expect(await managed.setRunning(true, initialize: true), isFalse);
      expect(managed.invitations, 0);
      expect(managed.coreRunningCalls, isEmpty);
    });

    test(
      'installation does not start feature; explicit retry uses lifecycle owner',
      () async {
        managed.installSucceeds = true;
        expect(await managed.setRunning(true), isFalse);
        expect(core.starts, 0);
        expect(managed.coreRunningCalls, isEmpty);
        expect(await managed.setRunning(true), isTrue);
        expect(core.starts, 1);
        expect(managed.applyProfileCalls, 1);
        expect(managed.coreRunningCalls, [true]);
        expect(managed.invitations, 1);
      },
    );

    test(
      'stop supersedes pending helper readiness before any lifecycle start',
      () async {
        managed.helperCheck = Completer();
        final start = managed.setRunning(true);
        await managed.setRunning(false);
        managed.helperCheck!.complete(MacHelperState.enabled);
        expect(await start, isFalse);
        expect(core.starts, 0);
        expect(managed.coreRunningCalls, [false]);
      },
    );

    test(
      'TUN dependency requires a fresh user retry without mutating preferences',
      () async {
        managed.installSucceeds = true;
        final saved = scoped.read(patchClashConfigProvider);
        expect(await managed.prepareTunEnable(true), isFalse);
        expect(scoped.read(patchClashConfigProvider), saved);
        expect(await managed.prepareTunEnable(true), isTrue);
        expect(managed.invitations, 1);
        expect(core.starts, 0);
        expect(managed.coreRunningCalls, isEmpty);
      },
    );
  });

  group('mixed listener check', () {
    setUpAll(() => AppLocalizations.load(const Locale('en')));

    test('a start confirms the port the Core holds', () async {
      markInitialized();

      expect(
        await container.read(setupActionProvider.notifier).setRunning(true),
        isTrue,
      );

      expect(container.read(isStartProvider), isTrue);
      expect(
        container.read(listeningMixedPortProvider),
        system.isDesktop
            ? container.read(patchClashConfigProvider).mixedPort
            : isNull,
      );
    });

    test('a port the Core could not bind ends the run', () async {
      if (!system.isDesktop) return;
      markInitialized();
      action.listening = 0;

      final started = await container
          .read(setupActionProvider.notifier)
          .setRunning(true);

      expect(started, isFalse);
      expect(container.read(isStartProvider), isFalse);
      expect(action.coreRunningCalls, [true, false]);
      expect(container.read(listeningMixedPortProvider), isNull);
      expect(container.read(proxyStateProvider).isStart, isFalse);
    });

    group('the banner says what happened to the system proxy', () {
      late List<String> printed;

      setUp(() {
        printed = [];
        final original = debugPrint;
        debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
        addTearDown(() => debugPrint = original);
      });

      String bannerOf(int port, {required bool unchanged}) =>
          '[APP] banner: ${unchanged ? currentAppLocalizations.mixedPortUnavailableProxyUnchanged('$port') : currentAppLocalizations.mixedPortUnavailable('$port')}';

      test('a start that never set it says it was not changed', () async {
        if (!system.isDesktop) return;
        markInitialized();
        action.proxyStarts = 4;
        action.listening = 0;
        final port = container.read(patchClashConfigProvider).mixedPort;

        await container.read(setupActionProvider.notifier).setRunning(true);

        expect(action.proxyMarksAsked, [4]);
        expect(printed, contains(bannerOf(port, unchanged: true)));
        expect(printed, isNot(contains(bannerOf(port, unchanged: false))));
        expect(
          bannerOf(port, unchanged: true),
          endsWith('System proxy settings were not changed.'),
        );
      });

      test('a run that had set it does not claim it was unchanged', () async {
        if (!system.isDesktop) return;
        markInitialized();
        action.proxyStarts = 4;
        await container.read(setupActionProvider.notifier).setRunning(true);
        // The system proxy went on while the run was healthy.
        action.proxyStarts = 5;
        container
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith(mixedPort: 7999));
        action.listening = 0;

        await container.read(setupActionProvider.notifier).checkMixedListener();

        expect(action.proxyMarksAsked, [4]);
        expect(printed, contains(bannerOf(7999, unchanged: false)));
        expect(printed, isNot(contains(bannerOf(7999, unchanged: true))));
        expect(
          bannerOf(7999, unchanged: false),
          endsWith('The proxy service did not start.'),
        );
      });

      test('a queue that cannot tell gets the shorter message', () async {
        if (!system.isDesktop) return;
        markInitialized();
        action.proxyUnchanged = false;
        action.listening = 0;
        final port = container.read(patchClashConfigProvider).mixedPort;

        await container.read(setupActionProvider.notifier).setRunning(true);

        expect(printed, contains(bannerOf(port, unchanged: false)));
      });

      test('a new run takes a new mark', () async {
        if (!system.isDesktop) return;
        markInitialized();
        action.proxyStarts = 2;
        await container.read(setupActionProvider.notifier).setRunning(true);
        action.proxyStarts = 3;
        await container.read(setupActionProvider.notifier).setRunning(false);
        action.listening = 0;

        await container.read(setupActionProvider.notifier).setRunning(true);

        expect(action.proxyMarksAsked, [3]);
        expect(
          printed,
          contains(
            bannerOf(
              container.read(patchClashConfigProvider).mixedPort,
              unchanged: true,
            ),
          ),
        );
      });
    });

    test('an initializing start checks after the profile applied', () async {
      if (!system.isDesktop) return;
      action.listening = 0;

      final started = await container
          .read(setupActionProvider.notifier)
          .setRunning(true, initialize: true);

      expect(started, isFalse);
      expect(action.applyProfileCalls, 1);
      expect(container.read(isStartProvider), isFalse);
    });

    test(
      'an unanswered check keeps the run but not the system proxy',
      () async {
        if (!system.isDesktop) return;
        markInitialized();
        container.read(networkSettingProvider.notifier).value =
            const NetworkProps(systemProxy: true);
        action.listeningError = const CoreMethodException(
          code: 'no_response',
          message: '',
        );

        await container.read(setupActionProvider.notifier).setRunning(true);

        expect(container.read(isStartProvider), isTrue);
        expect(container.read(listeningMixedPortProvider), isNull);
        expect(container.read(proxyStateProvider).isStart, isFalse);
      },
    );

    test('a port change the Core could not bind ends the run', () async {
      if (!system.isDesktop) return;
      markInitialized();
      await container.read(setupActionProvider.notifier).setRunning(true);
      container
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(mixedPort: 7999));
      expect(container.read(proxyStateProvider).isStart, isFalse);
      action.listening = 0;

      expect(
        await container.read(setupActionProvider.notifier).checkMixedListener(),
        isFalse,
      );
      expect(container.read(isStartProvider), isFalse);
    });

    test('safe mode never asks', () async {
      final scopedAction = TestSetupAction();
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          setupActionProvider.overrideWith(() => scopedAction),
          commonActionProvider.overrideWith(TestCommonAction.new),
          safeModeProvider.overrideWithValue(true),
        ],
      );
      addTearDown(scoped.dispose);
      globalState.container = scoped;
      scoped.read(setupActionProvider.notifier);

      await scoped
          .read(setupActionProvider.notifier)
          .setRunning(true, initialize: true);

      expect(scopedAction.listeningQueries, 0);
      expect(scoped.read(isStartProvider), isTrue);
      globalState.container = container;
    });
  });

  group('inbound check', () {
    late List<String> printed;

    setUp(() async {
      await AppLocalizations.load(const Locale('zh', 'CN'));
      printed = [];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
      addTearDown(() => debugPrint = original);
    });

    Future<void> check({
      required Map<String, Object?> requested,
      Map<String, Object?>? held,
      bool systemProxy = false,
      int mixedPort = 7890,
    }) async {
      markInitialized();
      await container.read(setupActionProvider.notifier).setRunning(true);
      printed.clear();
      container
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(mixedPort: mixedPort));
      container
          .read(networkSettingProvider.notifier)
          .update((state) => state.copyWith(systemProxy: systemProxy));
      container.read(builtInboundsProvider.notifier).value = requested;
      action.heldPorts = held;
      await container.read(setupActionProvider.notifier).checkInbounds();
    }

    test('names an inbound that did not start by its listener', () async {
      if (!system.isDesktop) return;
      await check(
        requested: {'port': 7891, 'socks-port': 7892},
        held: {'port': 0, 'socks-port': 7892},
      );

      expect(printed, ['[APP] banner: HTTP 代理 未启动：端口 7891 未在监听。']);
    });

    test('a port of 0 is an inbound turned off, not a failure', () async {
      if (!system.isDesktop) return;
      await check(requested: {'port': 0, 'socks-port': 0}, held: {});

      expect(printed, isEmpty);
    });

    test('a system proxy with no port to point at is reported', () async {
      if (!system.isDesktop) return;
      await check(
        requested: {'mixed-port': 0},
        held: {},
        systemProxy: true,
        mixedPort: 0,
      );

      expect(printed, ['[APP] banner: 系统代理没有可用的目标端口，请检查端口配置。']);
    });

    test('an HTTP port left for the system proxy is no conflict', () async {
      if (!system.isDesktop) return;
      await check(
        requested: {'port': 7891},
        held: {'port': 7891},
        systemProxy: true,
        mixedPort: 0,
      );

      expect(printed, isEmpty);
    });

    test('no port is no conflict while the system proxy is off', () async {
      if (!system.isDesktop) return;
      await check(requested: {}, held: {}, mixedPort: 0);

      expect(printed, isEmpty);
    });

    test('the no-port warning stands when the Core cannot be asked', () async {
      if (!system.isDesktop) return;
      await check(requested: {}, systemProxy: true, mixedPort: 0);

      expect(printed, contains('[APP] banner: 系统代理没有可用的目标端口，请检查端口配置。'));
    });
  });

  group('run failures', () {
    test('a start the core rejects stops reporting a run time', () async {
      markInitialized();
      action.coreRunningError = StateError('start failed');

      await expectLater(
        container.read(setupActionProvider.notifier).setRunning(true),
        throwsStateError,
      );

      expect(container.read(runTimeProvider), isNull);
    });

    test(
      'a stop the core rejects keeps the run time it started with',
      () async {
        markInitialized();
        await container.read(setupActionProvider.notifier).setRunning(true);
        action.coreRunningError = StateError('stop failed');

        await expectLater(
          container.read(setupActionProvider.notifier).setRunning(false),
          throwsStateError,
        );

        expect(container.read(runTimeProvider), isNotNull);
      },
    );

    final unanswered = isA<CoreMethodException>().having(
      (error) => error.code,
      'code',
      'no_response',
    );

    test('a start the core leaves unanswered fails and is undone', () async {
      markInitialized();
      action.unansweredCoreCalls.add(true);

      await expectLater(
        container.read(setupActionProvider.notifier).setRunning(true),
        throwsA(unanswered),
      );

      expect(container.read(isStartProvider), isFalse);
      expect(container.read(runTimeProvider), isNull);
      expect(container.read(runningVpnOptionsProvider), isNull);
    });

    test('a stop the core leaves unanswered fails but stays stopped', () async {
      markInitialized();
      final setup = container.read(setupActionProvider.notifier);
      await setup.setRunning(true);
      action.unansweredCoreCalls.add(false);

      await expectLater(setup.setRunning(false), throwsA(unanswered));

      expect(container.read(isStartProvider), isFalse);
      expect(container.read(runTimeProvider), isNull);
      expect(container.read(runningVpnOptionsProvider), isNull);
      expect(action.trafficResets, 1);
    });

    test(
      'an initial start the core leaves unanswered is stopped again',
      () async {
        action.unansweredCoreCalls.add(true);

        final applied = await container
            .read(setupActionProvider.notifier)
            .setRunning(true, initialize: true);

        expect(applied, isFalse);
        expect(action.coreRunningCalls, [true, false]);
        expect(container.read(isStartProvider), isFalse);
        expect(container.read(runningVpnOptionsProvider), isNull);
      },
    );
  });

  group('stop cleanup', () {
    test('resets traffic counters', () async {
      markInitialized();
      await container.read(setupActionProvider.notifier).setRunning(true);
      container.read(totalTrafficProvider.notifier).value = const Traffic(
        up: 10,
        down: 20,
      );

      await container.read(setupActionProvider.notifier).setRunning(false);

      expect(action.trafficResets, 1);
      expect(container.read(trafficsProvider).list, isEmpty);
      expect(container.read(totalTrafficProvider), const Traffic());
      expect(container.read(runTimeProvider), isNull);
    });
  });

  group('run time ticker', () {
    late ProviderContainer scoped;

    // Built inside each test, on its fake clock: futures made there never
    // settle in the shared tearDown.
    SetupAction buildScoped() {
      scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          setupActionProvider.overrideWith(TestSetupAction.new),
          commonActionProvider.overrideWith(TestCommonAction.new),
          // Bypassing private addresses computes the routes in Isolate.run, which
          // the fake clock never lets finish.
          networkSettingProvider.overrideWithBuild(
            (_, _) => const NetworkProps(bypassPrivateRoute: false),
          ),
        ],
      );
      addTearDown(scoped.dispose);
      globalState.container = scoped;
      scoped
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(showTrayTitle: false));
      scoped.read(initProvider.notifier).value = true;
      return scoped.read(setupActionProvider.notifier);
    }

    int trafficUpdates() =>
        (scoped.read(commonActionProvider.notifier) as TestCommonAction)
            .trafficUpdates;

    void setVisible(bool visible) =>
        scoped.read(appVisibleProvider.notifier).value = visible;

    testWidgets('reads traffic only while the app is visible', (tester) async {
      final setup = buildScoped();
      await setup.setRunning(true);
      expect(trafficUpdates(), 1);

      await tester.pump(const Duration(seconds: 2));
      expect(trafficUpdates(), 3);

      setVisible(false);
      await tester.pump(const Duration(seconds: 5));
      expect(trafficUpdates(), 3);
      expect(scoped.read(isStartProvider), isTrue);

      setVisible(true);
      await tester.pump();
      expect(trafficUpdates(), 4);
      await tester.pump(const Duration(seconds: 1));
      expect(trafficUpdates(), 5);

      await setup.setRunning(false);
    });

    testWidgets('a start while hidden waits for the app to be shown', (
      tester,
    ) async {
      final setup = buildScoped();
      setVisible(false);
      await setup.setRunning(true);
      await tester.pump(const Duration(seconds: 3));

      expect(scoped.read(runTimeProvider), isNotNull);
      expect(trafficUpdates(), 0);

      setVisible(true);
      await tester.pump();
      expect(trafficUpdates(), 1);

      await setup.setRunning(false);
    });

    testWidgets('the macOS menu bar title keeps traffic coming while hidden', (
      tester,
    ) async {
      final setup = buildScoped();
      setVisible(false);
      await setup.setRunning(true);
      await tester.pump(const Duration(seconds: 2));
      expect(trafficUpdates(), 0);

      scoped
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(showTrayTitle: true));
      await tester.pump(const Duration(seconds: 2));

      expect(trafficUpdates(), system.isMacOS ? 3 : 0);

      await setup.setRunning(false);
    });
  });

  group('suspend', () {
    test('skips starting the core on an excluded SSID', () async {
      container.dispose();
      action = TestSetupAction();
      container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          setupActionProvider.overrideWith(() => action),
          commonActionProvider.overrideWith(TestCommonAction.new),
          excludeSSIDsProvider.overrideWithValue(const ['Office Wi-Fi']),
        ],
      );
      globalState.container = container;
      container.read(initProvider.notifier).value = true;
      container.read(currentSSIDProvider.notifier).value = 'Office Wi-Fi';

      await container.read(setupActionProvider.notifier).setRunning(true);

      expect(action.coreRunningCalls, isEmpty);
      expect(container.read(runningVpnOptionsProvider), isNull);
    });

    test('an excluded SSID parks a run and leaving it resumes', () async {
      container.dispose();
      action = TestSetupAction();
      container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          setupActionProvider.overrideWith(() => action),
          commonActionProvider.overrideWith(TestCommonAction.new),
          excludeSSIDsProvider.overrideWithValue(const ['Office Wi-Fi']),
        ],
      );
      globalState.container = container;
      container.read(initProvider.notifier).value = true;
      final setup = container.read(setupActionProvider.notifier);
      await setup.setRunning(true);
      action.coreRunningCalls.clear();

      container.read(currentSSIDProvider.notifier).value = 'Office Wi-Fi';
      setup.syncSuspend();
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(action.coreRunningCalls, [false]);
      expect(container.read(isStartProvider), isTrue);
      expect(container.read(runningVpnOptionsProvider), isNull);

      container.read(currentSSIDProvider.notifier).value = 'Home';
      setup.syncSuspend();
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(action.coreRunningCalls, [false, true]);
      expect(
        container.read(runningVpnOptionsProvider),
        await container.read(vpnOptionsProvider.future),
      );
    });

    test('an SSID change leaves a stopped run alone', () async {
      markInitialized();
      container.read(setupActionProvider.notifier).syncSuspend();
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(action.coreRunningCalls, isEmpty);
    });

    test('still stops the core on an excluded SSID', () async {
      container.dispose();
      action = TestSetupAction();
      container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          setupActionProvider.overrideWith(() => action),
          commonActionProvider.overrideWith(TestCommonAction.new),
          excludeSSIDsProvider.overrideWithValue(const ['Office Wi-Fi']),
        ],
      );
      globalState.container = container;
      container.read(currentSSIDProvider.notifier).value = 'Office Wi-Fi';

      await container.read(setupActionProvider.notifier).setRunning(false);

      expect(action.coreRunningCalls, [false]);
    });
  });

  group('running vpn options', () {
    test('a start keeps what the service starts with until a stop', () async {
      markInitialized();
      final setup = container.read(setupActionProvider.notifier);
      final started = await container.read(vpnOptionsProvider.future);

      await setup.setRunning(true);
      container
          .read(vpnSettingProvider.notifier)
          .update((state) => state.copyWith(ipv6: !state.ipv6));

      expect(container.read(runningVpnOptionsProvider), started);

      await setup.setRunning(false);

      expect(container.read(runningVpnOptionsProvider), isNull);
    });

    test('a start the core rejects keeps nothing', () async {
      markInitialized();
      action.coreRunningError = StateError('listener refused');

      await expectLater(
        container.read(setupActionProvider.notifier).setRunning(true),
        throwsStateError,
      );

      expect(container.read(runningVpnOptionsProvider), isNull);
    });

    test('a restart stops and starts with the current options', () async {
      markInitialized();
      final setup = container.read(setupActionProvider.notifier);
      await setup.setRunning(true);
      container
          .read(vpnSettingProvider.notifier)
          .update((state) => state.copyWith(ipv6: !state.ipv6));

      await setup.restartVpn();

      expect(action.coreRunningCalls, [true, false, true]);
      expect(container.read(isStartProvider), isTrue);
      expect(
        container.read(runningVpnOptionsProvider),
        await container.read(vpnOptionsProvider.future),
      );
    });

    test('a restart never starts a stopped run', () async {
      markInitialized();

      await container.read(setupActionProvider.notifier).restartVpn();

      expect(action.coreRunningCalls, isEmpty);
      expect(container.read(isStartProvider), isFalse);
    });
  });

  group('latest-intent arbitration', () {
    test('a superseded stop does not run the post-stop cleanup', () async {
      markInitialized();
      final notifier = container.read(setupActionProvider.notifier);
      action.blockCoreCalls = true;

      final stopping = notifier.setRunning(false);
      await Future<void>.delayed(Duration.zero);
      final starting = notifier.setRunning(true);
      await Future<void>.delayed(Duration.zero);

      action.blockCoreCalls = false;
      for (final gate in action.pendingCoreCalls) {
        if (!gate.isCompleted) {
          gate.complete();
        }
      }
      await Future.wait([stopping, starting]);

      expect(action.coreRunningCalls, [false, true]);
      expect(action.trafficResets, 0);
      expect(container.read(runTimeProvider), isNotNull);
    });

    test(
      'a superseded start the core leaves unanswered does not fail',
      () async {
        markInitialized();
        final notifier = container.read(setupActionProvider.notifier);
        action.blockCoreCalls = true;
        action.unansweredCoreCalls.add(true);

        final starting = notifier.setRunning(true);
        await Future<void>.delayed(Duration.zero);
        final stopping = notifier.setRunning(false);
        await Future<void>.delayed(Duration.zero);

        action.blockCoreCalls = false;
        for (final gate in action.pendingCoreCalls) {
          if (!gate.isCompleted) {
            gate.complete();
          }
        }

        expect(await Future.wait([starting, stopping]), [true, true]);
        expect(action.coreRunningCalls, [true, false]);
        expect(container.read(isStartProvider), isFalse);
      },
    );

    test('the newest request wins the local running state', () async {
      markInitialized();
      final notifier = container.read(setupActionProvider.notifier);

      await notifier.setRunning(true);
      expect(container.read(runTimeProvider), isNotNull);

      await notifier.setRunning(false);
      expect(container.read(runTimeProvider), isNull);

      await notifier.setRunning(true);
      expect(container.read(runTimeProvider), isNotNull);
      expect(action.coreRunningCalls, [true, false, true]);
    });
  });

  group('initStatus', () {
    test('is a no-op once the status has already been initialized', () async {
      globalState.needInitStatus = false;

      await container.read(setupActionProvider.notifier).initStatus();

      expect(action.coreRunningCalls, isEmpty);
      expect(action.applyProfileCalls, 0);
    });

    test('starts the core when autoRun is enabled', () async {
      container.read(appSettingProvider.notifier).value = const AppSettingProps(
        autoRun: true,
      );

      await container.read(setupActionProvider.notifier).initStatus();

      expect(action.coreRunningCalls, [true]);
      expect(globalState.needInitStatus, isFalse);
    });

    test('only applies the profile when autoRun is disabled', () async {
      container.read(appSettingProvider.notifier).value = const AppSettingProps(
        autoRun: false,
      );

      await container.read(setupActionProvider.notifier).initStatus();

      expect(action.coreRunningCalls, isEmpty);
      expect(action.applyProfileCalls, 1);
    });

    test('takes over a run the service already has without pushing the config '
        'it runs again, which would make url-test groups re-pick', () async {
      final lastConfigMd5 = globalState.lastConfigMd5;
      addTearDown(() => globalState.lastConfigMd5 = lastConfigMd5);
      await mockPreferences({appliedConfigMd5Key: 'running'});
      action.serviceStart = DateTime.now().subtract(const Duration(minutes: 1));

      await container.read(setupActionProvider.notifier).initStatus();

      expect(action.coreRunningCalls, [true]);
      expect(action.appliedForce, [false]);
      expect(globalState.lastConfigMd5, 'running');
      expect(container.read(isStartProvider), isTrue);
    });
  });

  group('requestAdmin', () {
    test('never asks for authorization while tun is disabled', () async {
      expect(await action.requestAdmin(false), isTrue);

      expect(action.authorizeCalls, 0);
      expect(
        container.read(authorizedTunEnableProvider),
        TunAuthorizationState.none,
      );
    });

    test('safe mode never asks, whatever the tun setting says', () async {
      final scopedAction = TestSetupAction();
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          setupActionProvider.overrideWith(() => scopedAction),
          safeModeProvider.overrideWithValue(true),
        ],
      );
      addTearDown(scoped.dispose);
      scoped.read(setupActionProvider.notifier);

      expect(await scopedAction.requestAdmin(true), isTrue);
      expect(scopedAction.authorizeCalls, 0);
      expect(
        scoped.read(authorizedTunEnableProvider),
        TunAuthorizationState.none,
      );
    });

    test('does not ask again once the state left none', () async {
      container.read(authorizedTunEnableProvider.notifier).value =
          TunAuthorizationState.authorized;

      expect(await action.requestAdmin(true), isTrue);
      expect(action.authorizeCalls, 0);
    });

    test(
      'a successful authorization hands off instead of continuing',
      () async {
        action.authorizeResult = AuthorizeCode.success;

        expect(await action.requestAdmin(true), isFalse);
        expect(action.authorizeCalls, 1);
        expect(
          container.read(authorizedTunEnableProvider),
          TunAuthorizationState.authorized,
        );
      },
    );

    test('a platform without an authorization step continues inline', () async {
      action.authorizeResult = AuthorizeCode.none;

      expect(await action.requestAdmin(true), isTrue);
      expect(
        container.read(authorizedTunEnableProvider),
        TunAuthorizationState.authorized,
      );
    });

    test(
      'a failed authorization preserves requested tun and asks again on retry',
      () async {
        await AppLocalizations.load(const Locale('en'));
        container
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith.tun(enable: true));
        action.authorizeResult = AuthorizeCode.error;

        expect(await action.requestAdmin(true), isTrue);
        expect(container.read(patchClashConfigProvider).tun.enable, isTrue);
        expect(
          container.read(authorizedTunEnableProvider),
          TunAuthorizationState.none,
        );

        action.authorizeResult = AuthorizeCode.success;

        expect(await action.requestAdmin(true), isFalse);
        expect(action.authorizeCalls, 2);
      },
    );
  });

  group('updateConfig', () {
    test(
      'ordinary invalid controller rejects before authorization or update',
      () async {
        await AppLocalizations.load(const Locale('en'));
        final core = _MockCoreHandlerInterface();
        final scopedAction = TestSetupAction();
        final scoped = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(TestProfiles.new),
            setupActionProvider.overrideWith(() => scopedAction),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            safeModeProvider.overrideWithValue(false),
          ],
        );
        addTearDown(scoped.dispose);
        scoped.read(setupActionProvider.notifier);
        scoped
            .read(patchClashConfigProvider.notifier)
            .update(
              (state) => state.copyWith(
                externalController: ExternalControllerStatus.open,
                secret: '',
                tun: state.tun.copyWith(enable: false),
              ),
            );
        await scopedAction.updateConfig();
        verifyNever(() => core.updateConfig(any()));
        expect(scopedAction.authorizeCalls, 0);
      },
    );

    test('safe mode pushes tun disabled even once authorized', () async {
      final core = _MockCoreHandlerInterface();
      when(() => core.updateConfig(any())).thenAnswer((_) async {});
      final scopedAction = TestSetupAction();
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          setupActionProvider.overrideWith(() => scopedAction),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          safeModeProvider.overrideWithValue(true),
        ],
      );
      addTearDown(scoped.dispose);
      scoped.read(setupActionProvider.notifier);
      scoped
          .read(patchClashConfigProvider.notifier)
          .update(
            (state) => state.copyWith(tun: state.tun.copyWith(enable: true)),
          );
      scoped.read(authorizedTunEnableProvider.notifier).value =
          TunAuthorizationState.authorized;

      await scopedAction.updateConfig();

      final params =
          verify(() => core.updateConfig(captureAny())).captured.single
              as UpdateParams;
      expect(params.tun?['enable'], isFalse);
      expect(scopedAction.authorizeCalls, 0);
    });

    test('safe mode closes the external controller', () async {
      final core = _MockCoreHandlerInterface();
      when(() => core.updateConfig(any())).thenAnswer((_) async {});
      final scopedAction = TestSetupAction();
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          setupActionProvider.overrideWith(() => scopedAction),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          safeModeProvider.overrideWithValue(true),
        ],
      );
      addTearDown(scoped.dispose);
      scoped.read(setupActionProvider.notifier);
      scoped
          .read(patchClashConfigProvider.notifier)
          .update(
            (state) => state.copyWith(
              externalController: ExternalControllerStatus.open,
            ),
          );

      await scopedAction.updateConfig();

      final params =
          verify(() => core.updateConfig(captureAny())).captured.single
              as UpdateParams;
      expect(params.externalController, ExternalControllerStatus.close);
      expect(
        scoped.read(patchClashConfigProvider).externalController,
        ExternalControllerStatus.open,
      );
    });

    Future<UpdateParams> updateWith(PatchClashConfig patchConfig) async {
      final core = _MockCoreHandlerInterface();
      when(() => core.updateConfig(any())).thenAnswer((_) async {});
      final scopedAction = TestSetupAction();
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          setupActionProvider.overrideWith(() => scopedAction),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        ],
      );
      addTearDown(scoped.dispose);
      scoped.read(setupActionProvider.notifier);
      scoped.read(patchClashConfigProvider.notifier).value = patchConfig;

      await scopedAction.updateConfig();

      return verify(() => core.updateConfig(captureAny())).captured.single
          as UpdateParams;
    }

    test('hands the Core the controller secret with the address', () async {
      final params = await updateWith(
        const PatchClashConfig(
          externalController: ExternalControllerStatus.open,
          secret: 'abc',
        ),
      );

      expect(params.externalController, ExternalControllerStatus.open);
      expect(params.secret, 'abc');
    });

    test('never opens the controller without a secret', () async {
      final params = await updateWith(
        const PatchClashConfig(
          externalController: ExternalControllerStatus.open,
        ),
      );

      expect(params.externalController, ExternalControllerStatus.close);
    });

    test('a page-owned find-process mode runs once the Core takes it, and a '
        'followed one keeps the applied mode', () async {
      final core = _MockCoreHandlerInterface();
      final pushed = Completer<void>();
      when(() => core.updateConfig(any())).thenAnswer((_) => pushed.future);
      final scopedAction = TestSetupAction();
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          setupActionProvider.overrideWith(() => scopedAction),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        ],
      );
      addTearDown(scoped.dispose);
      scoped.read(setupActionProvider.notifier);
      final running = scoped.read(runningFindProcessModeProvider.notifier);
      running.value = 'strict';
      scoped.read(patchClashConfigProvider.notifier).value =
          const PatchClashConfig(findProcessMode: FindProcessMode.always);

      final update = scopedAction.updateConfig();
      await pumpEventQueue();
      expect(running.value, 'strict');
      pushed.complete();
      await update;
      expect(running.value, 'always');

      scoped.read(patchClashConfigProvider.notifier).value =
          const PatchClashConfig(followKeys: {PageConfigKey.findProcessMode});
      await scopedAction.updateConfig();
      expect(running.value, 'always');
    });

    test('a failed live update leaves the running mode alone', () async {
      final core = _MockCoreHandlerInterface();
      when(
        () => core.updateConfig(any()),
      ).thenThrow(const CoreMethodException(code: 'failed', message: ''));
      final scopedAction = TestSetupAction();
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          setupActionProvider.overrideWith(() => scopedAction),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        ],
      );
      addTearDown(scoped.dispose);
      scoped.read(setupActionProvider.notifier);

      await scopedAction.updateConfig();

      expect(scoped.read(runningFindProcessModeProvider), isNull);
    });
  });

  group('recoverMissingProfile', () {
    ProviderContainer buildScoped(List<Profile> profiles, int? profileId) {
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles(profiles)),
          currentProfileIdProvider.overrideWithBuild((_, _) => profileId),
          setupActionProvider.overrideWith(TestSetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);
      return scoped;
    }

    test('a dangling profile id falls back to the first profile', () {
      final profile = Profile.normal(label: 'p').copyWith(id: 1);
      final scoped = buildScoped([profile], 404);

      final recovered = scoped
          .read(setupActionProvider.notifier)
          .recoverMissingProfile();

      expect(recovered?.id, profile.id);
      expect(scoped.read(currentProfileIdProvider), profile.id);
    });

    test('no profiles keeps the stored id untouched', () {
      final scoped = buildScoped(const [], 404);

      expect(
        scoped.read(setupActionProvider.notifier).recoverMissingProfile(),
        isNull,
      );
      expect(scoped.read(currentProfileIdProvider), 404);
    });

    test('an unset id is the first-run state, not a dangling one', () {
      final profile = Profile.normal(label: 'p').copyWith(id: 1);
      final scoped = buildScoped([profile], null);

      expect(
        scoped.read(setupActionProvider.notifier).recoverMissingProfile(),
        isNull,
      );
      expect(scoped.read(currentProfileIdProvider), isNull);
    });
  });

  group('tray mode transaction', () {
    late ProviderContainer scoped;
    late _TrayDeadlineSetupAction owner;
    late _MockCoreHandlerInterface core;
    late Completer<void> reply;

    void bindOwner() {
      core = _MockCoreHandlerInterface();
      reply = Completer<void>();
      when(() => core.updateConfig(any())).thenAnswer((_) => reply.future);
      owner = _TrayDeadlineSetupAction();
      scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          setupActionProvider.overrideWith(() => owner),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          isStartProvider.overrideWithValue(true),
        ],
      );
      scoped.read(setupActionProvider.notifier);
      addTearDown(scoped.dispose);
    }

    setUp(() async {
      await AppLocalizations.load(const Locale('en'));
      bindOwner();
    });

    void resetOwner() {
      scoped.dispose();
      bindOwner();
    }

    test(
      'keeps configured mode pending and commits only after acknowledgement',
      () async {
        final operation = owner.changeModeForTray(Mode.global);
        await pumpEventQueue();
        expect(scoped.read(patchClashConfigProvider).mode, Mode.rule);
        expect(scoped.read(trayModeMenuStateProvider).pendingMode, Mode.global);
        final params =
            verify(() => core.updateConfig(captureAny())).captured.single
                as UpdateParams;
        expect(params.mode, Mode.global);
        await owner.changeModeForTray(Mode.direct);
        verifyNever(() => core.updateConfig(any()));
        reply.complete();
        await operation;
        expect(scoped.read(patchClashConfigProvider).mode, Mode.global);
        expect(scoped.read(trayModeMenuStateProvider).pendingMode, isNull);
        expect(scoped.read(trayModeMenuStateProvider).error, isNull);
      },
    );

    for (final fails in [false, true]) {
      testWidgets(
        'deadline releases UI but serializes retry behind late ${fails ? 'error' : 'success'}',
        (tester) async {
          resetOwner();
          var finished = false;
          final operation = owner.changeModeForTray(Mode.global);
          unawaited(operation.then((_) => finished = true));
          await tester.pump();
          await tester.pump(const Duration(seconds: 14));
          expect(finished, isFalse);
          expect(
            scoped.read(trayModeMenuStateProvider).pendingMode,
            Mode.global,
          );
          await tester.pump(const Duration(seconds: 1));
          await operation;
          expect(finished, isTrue);
          expect(scoped.read(patchClashConfigProvider).mode, Mode.rule);
          expect(scoped.read(trayModeMenuStateProvider).pendingMode, isNull);
          expect(
            scoped.read(trayModeMenuStateProvider).error,
            currentAppLocalizations.traySwitchUnconfirmed,
          );
          final retryReply = Completer<void>();
          when(
            () => core.updateConfig(any()),
          ).thenAnswer((_) => retryReply.future);
          final retry = owner.changeModeForTray(Mode.global);
          await tester.pump();
          expect(
            scoped.read(trayModeMenuStateProvider).pendingMode,
            Mode.global,
          );
          expect(scoped.read(trayModeMenuStateProvider).error, isNull);
          verify(() => core.updateConfig(any())).called(1);
          scoped.read(runningFindProcessModeProvider.notifier).value = 'always';
          if (fails) {
            reply.completeError(StateError('late RPC error'));
          } else {
            reply.complete();
          }
          await tester.pump();
          verify(() => core.updateConfig(any())).called(1);
          expect(scoped.read(runningFindProcessModeProvider), 'always');
          expect(owner.listeningQueries, 0);
          expect(scoped.read(patchClashConfigProvider).mode, Mode.rule);
          expect(
            scoped.read(trayModeMenuStateProvider).pendingMode,
            Mode.global,
          );
          expect(scoped.read(trayModeMenuStateProvider).error, isNull);
          retryReply.complete();
          await tester.pump();
          await retry;
          expect(scoped.read(patchClashConfigProvider).mode, Mode.global);
          expect(scoped.read(trayModeMenuStateProvider).pendingMode, isNull);
          scoped.dispose();
          await tester.pump();
        },
      );
    }

    for (final adoptionPending in [false, true]) {
      testWidgets(
        'expired queued ${adoptionPending ? 'adoption' : 'patch'} never sends or authorizes',
        (tester) async {
          resetOwner();
          final blocker = owner.updateConfig();
          await tester.pump();
          verify(() => core.updateConfig(any())).called(1);
          if (adoptionPending) {
            await tester.runAsync(
              () => mockPreferences({'compositionRevision': 0}),
            );
          }
          scoped
              .read(patchClashConfigProvider.notifier)
              .update(
                (state) =>
                    state.copyWith(tun: state.tun.copyWith(enable: true)),
              );
          owner.deadline = const Duration(seconds: 2);
          final operation = owner.changeModeForTray(Mode.direct);
          await tester.pump();
          await tester.pump(owner.deadline);
          await operation;
          expect(scoped.read(trayModeMenuStateProvider).pendingMode, isNull);
          expect(
            scoped.read(trayModeMenuStateProvider).error,
            currentAppLocalizations.traySwitchUnconfirmed,
          );
          reply.complete();
          await tester.pump();
          await blocker;
          verifyNever(() => core.updateConfig(any()));
          verifyNever(() => core.setupConfig(any()));
          expect(owner.authorizeCalls, 0);
          expect(scoped.read(patchClashConfigProvider).mode, Mode.rule);
          scoped.dispose();
          await tester.pump();
        },
      );
    }

    for (final authorization in AuthorizeCode.values) {
      testWidgets('late authorization $authorization cannot send or restart', (
        tester,
      ) async {
        resetOwner();
        owner.authorization = Completer<AuthorizeCode>();
        scoped
            .read(patchClashConfigProvider.notifier)
            .update(
              (state) => state.copyWith(tun: state.tun.copyWith(enable: true)),
            );
        final operation = owner.changeModeForTray(Mode.direct);
        await tester.pump();
        expect(owner.authorizeCalls, 1);
        await tester.pump(owner.deadline);
        await operation;
        expect(scoped.read(trayModeMenuStateProvider).pendingMode, isNull);
        expect(
          scoped.read(trayModeMenuStateProvider).error,
          currentAppLocalizations.traySwitchUnconfirmed,
        );
        expect(
          scoped.read(authorizedTunEnableProvider),
          TunAuthorizationState.none,
        );
        owner.authorization!.complete(authorization);
        await tester.pump();
        verifyNever(() => core.updateConfig(any()));
        expect(
          scoped.read(authorizedTunEnableProvider),
          TunAuthorizationState.none,
        );
        expect(owner.coreRunningCalls, isEmpty);
        expect(scoped.read(patchClashConfigProvider).mode, Mode.rule);
        owner.authorization = Completer<AuthorizeCode>();
        final retry = owner.changeModeForTray(Mode.direct);
        await tester.pump();
        expect(owner.authorizeCalls, 2);
        expect(scoped.read(trayModeMenuStateProvider).pendingMode, Mode.direct);
        owner.authorization!.complete(AuthorizeCode.none);
        await tester.pump();
        reply.complete();
        await tester.pump();
        await retry;
        expect(scoped.read(patchClashConfigProvider).mode, Mode.direct);
        expect(scoped.read(trayModeMenuStateProvider).error, isNull);
        scoped.dispose();
        await tester.pump();
      });
    }

    for (final fails in [false, true]) {
      testWidgets(
        'post-ack deadline ignores late listener ${fails ? 'error' : 'mismatch'}',
        (tester) async {
          resetOwner();
          owner.listener = Completer<int>();
          final operation = owner.changeModeForTray(Mode.direct);
          await tester.pump();
          reply.complete();
          await tester.pump();
          await tester.pump(owner.deadline);
          await operation;
          expect(
            scoped.read(trayModeMenuStateProvider).error,
            currentAppLocalizations.traySwitchUnconfirmed,
          );
          expect(scoped.read(trayModeMenuStateProvider).pendingMode, isNull);
          scoped.read(runningFindProcessModeProvider.notifier).value = 'always';
          if (fails) {
            owner.listener!.completeError(StateError('late listener error'));
          } else {
            owner.listener!.complete(0);
          }
          await tester.pump();
          expect(scoped.read(runningFindProcessModeProvider), 'always');
          expect(scoped.read(listeningMixedPortProvider), isNull);
          expect(scoped.read(patchClashConfigProvider).mode, Mode.rule);
          expect(owner.coreRunningCalls, isEmpty);
          scoped.dispose();
          await tester.pump();
        },
      );
    }

    testWidgets(
      'older deadline and finally cannot clear newer pending intent',
      (tester) async {
        resetOwner();
        final first = owner.changeModeForTray(Mode.direct);
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        owner.changeMode(Mode.global);
        final second = owner.changeModeForTray(Mode.direct);
        await tester.pump();
        await tester.pump(const Duration(seconds: 10));
        await first;
        expect(scoped.read(trayModeMenuStateProvider).pendingMode, Mode.direct);
        expect(scoped.read(trayModeMenuStateProvider).error, isNull);
        await tester.pump(const Duration(seconds: 5));
        await second;
        expect(scoped.read(trayModeMenuStateProvider).pendingMode, isNull);
        expect(scoped.read(patchClashConfigProvider).mode, Mode.global);
        reply.complete();
        await tester.pump();
        verify(() => core.updateConfig(any())).called(2);
        scoped.dispose();
        await tester.pump();
      },
    );

    test('rejection keeps old mode and exposes the reason', () async {
      final operation = owner.changeModeForTray(Mode.direct);
      await pumpEventQueue();
      reply.completeError(
        const CoreMethodException(
          code: 'config_rejected',
          message: 'fixture rejected',
          details: {'outcome': 'kept'},
        ),
      );
      await operation;
      expect(scoped.read(patchClashConfigProvider).mode, Mode.rule);
      expect(scoped.read(trayModeMenuStateProvider).pendingMode, isNull);
      expect(
        scoped.read(trayModeMenuStateProvider).error,
        contains('fixture rejected'),
      );
      expect(
        scoped.read(trayModeMenuStateProvider).error,
        contains(currentAppLocalizations.trayCouldNotSwitch),
      );
    });

    test('missing acknowledgement is unconfirmed, not selected', () async {
      final operation = owner.changeModeForTray(Mode.direct);
      await pumpEventQueue();
      reply.completeError(
        const CoreMethodException(
          code: 'no_response',
          message: 'fixture timeout',
        ),
      );
      await operation;
      expect(scoped.read(patchClashConfigProvider).mode, Mode.rule);
      expect(
        scoped.read(trayModeMenuStateProvider).error,
        contains(currentAppLocalizations.traySwitchUnconfirmed),
      );
      expect(scoped.read(trayModeMenuStateProvider).pendingMode, isNull);
    });

    for (final fails in [false, true]) {
      test(
        'newer ordinary intent wins over late ${fails ? 'failure' : 'success'}',
        () async {
          final operation = owner.changeModeForTray(Mode.direct);
          await pumpEventQueue();
          when(() => core.updateConfig(any())).thenAnswer((_) async {});
          owner.changeMode(Mode.global);
          if (fails) {
            reply.completeError(
              const CoreMethodException(
                code: 'config_rejected',
                message: 'late',
                details: {'outcome': 'kept'},
              ),
            );
          } else {
            reply.complete();
          }
          await operation;
          await pumpEventQueue();
          expect(scoped.read(patchClashConfigProvider).mode, Mode.global);
          expect(scoped.read(trayModeMenuStateProvider).pendingMode, isNull);
          expect(scoped.read(trayModeMenuStateProvider).error, isNull);
        },
      );
    }

    for (final fails in [false, true]) {
      test(
        'same-value ordinary intent cancels late ${fails ? 'failure' : 'success'} and reapplies it',
        () async {
          final operation = owner.changeModeForTray(Mode.direct);
          await pumpEventQueue();
          owner.changeMode(Mode.rule);
          when(() => core.updateConfig(any())).thenAnswer((_) async {});
          if (fails) {
            reply.completeError(
              const CoreMethodException(
                code: 'config_rejected',
                message: 'late',
                details: {'outcome': 'kept'},
              ),
            );
          } else {
            reply.complete();
          }
          await operation;
          expect(scoped.read(patchClashConfigProvider).mode, Mode.rule);
          expect(scoped.read(trayModeMenuStateProvider).pendingMode, isNull);
          expect(scoped.read(trayModeMenuStateProvider).error, isNull);
          await pumpEventQueue();
          final params = verify(
            () => core.updateConfig(captureAny()),
          ).captured.cast<UpdateParams>();
          expect(params.map((value) => value.mode), [Mode.direct, Mode.rule]);
        },
      );
    }

    test('unrelated concurrent config edit is preserved on success', () async {
      final operation = owner.changeModeForTray(Mode.direct);
      await pumpEventQueue();
      scoped
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(mixedPort: 8899));
      reply.complete();
      await operation;
      expect(scoped.read(patchClashConfigProvider).mode, Mode.direct);
      expect(scoped.read(patchClashConfigProvider).mixedPort, 8899);
    });

    test('stopped mode is saved without a Core request', () async {
      final stopped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          isStartProvider.overrideWithValue(false),
        ],
      );
      addTearDown(stopped.dispose);
      await stopped
          .read(setupActionProvider.notifier)
          .changeModeForTray(Mode.direct);
      expect(stopped.read(patchClashConfigProvider).mode, Mode.direct);
      verifyNever(() => core.updateConfig(any()));
    });

    test(
      'scope change abandons an in-flight response without a stale selection',
      () async {
        final operation = owner.changeModeForTray(Mode.direct);
        await pumpEventQueue();
        scoped.read(coreStatusProvider.notifier).value = CoreStatus.connected;
        expect(scoped.read(trayModeMenuStateProvider).pendingMode, isNull);
        reply.complete();
        await operation;
        expect(scoped.read(patchClashConfigProvider).mode, Mode.rule);
        expect(scoped.read(trayModeMenuStateProvider).error, isNull);
      },
    );

    test('controller validation still rejects before a tray request', () async {
      scoped
          .read(patchClashConfigProvider.notifier)
          .update(
            (state) => state.copyWith(
              externalController: ExternalControllerStatus.open,
              secret: '',
            ),
          );
      await owner.changeModeForTray(Mode.direct);
      verifyNever(() => core.updateConfig(any()));
      expect(owner.authorizeCalls, 0);
      expect(scoped.read(patchClashConfigProvider).mode, Mode.rule);
      expect(scoped.read(trayModeMenuStateProvider).pendingMode, isNull);
      expect(scoped.read(trayModeMenuStateProvider).error, isNotEmpty);
    });

    test('current mode is a no-op', () async {
      await owner.changeModeForTray(Mode.rule);
      verifyNever(() => core.updateConfig(any()));
      expect(scoped.read(trayModeMenuStateProvider).pendingMode, isNull);
    });
  });

  group('changeMode', () {
    test('records the requested mode', () {
      container.read(setupActionProvider.notifier).changeMode(Mode.direct);

      expect(container.read(patchClashConfigProvider).mode, Mode.direct);
    });

    test('leaving global alone keeps the selected group', () {
      final profile = Profile.normal(
        label: 'p',
      ).copyWith(id: 1, currentGroupName: 'Manual');
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          setupActionProvider.overrideWith(TestSetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);

      scoped.read(setupActionProvider.notifier).changeMode(Mode.rule);

      expect(scoped.read(currentProfileProvider)?.currentGroupName, 'Manual');
    });

    test('global mode also selects the global group', () {
      final profile = Profile.normal(
        label: 'p',
      ).copyWith(id: 1, currentGroupName: 'Manual');
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          setupActionProvider.overrideWith(TestSetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);

      scoped.read(setupActionProvider.notifier).changeMode(Mode.global);

      expect(scoped.read(patchClashConfigProvider).mode, Mode.global);
      expect(
        scoped.read(currentProfileProvider)?.currentGroupName,
        GroupName.GLOBAL.name,
      );
    });
  });

  group('applyProfileDebounce', () {
    test('collapses a burst into a single apply', () async {
      final notifier = container.read(setupActionProvider.notifier);

      notifier.applyProfileDebounce(force: true);
      notifier.applyProfileDebounce(force: true);
      notifier.applyProfileDebounce(force: true);
      expect(action.applyProfileCalls, 0);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(action.applyProfileCalls, 1);
    });

    test('a forced apply stays forced when a plain one follows', () async {
      final notifier = container.read(setupActionProvider.notifier);

      notifier.applyProfileDebounce(force: true);
      notifier.applyProfileDebounce();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      notifier.applyProfileDebounce();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(action.appliedForce, [true, false]);
    });

    test('a stop cancels a pending apply', () async {
      markInitialized();
      final notifier = container.read(setupActionProvider.notifier);

      notifier.applyProfileDebounce(force: true);
      await notifier.setRunning(false);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(action.applyProfileCalls, 0);

      notifier.applyProfileDebounce();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(action.appliedForce, [false]);
    });
  });

  group('applyIfGlobalRulesUsed', () {
    for (final (name, profile, applies) in [
      ('a standard extension', Profile.normal(label: 'p'), true),
      (
        'a script extension',
        Profile.normal(label: 'p').copyWith(extendType: ExtendType.script),
        false,
      ),
      ('a custom profile', Profile.custom(label: 'p'), false),
    ]) {
      test('${applies ? 'applies' : 'leaves alone'} $name', () async {
        final setupAction = TestSetupAction();
        final scoped = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(() => TestProfiles([profile])),
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
            setupActionProvider.overrideWith(() => setupAction),
          ],
        );
        addTearDown(scoped.dispose);

        scoped.read(setupActionProvider.notifier).applyIfGlobalRulesUsed();
        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(setupAction.applyProfileCalls, applies ? 1 : 0);
      });
    }
  });

  group('_setupConfig via the real SetupAction', () {
    late Directory tempDir;
    late String? originalLastConfigMd5;

    setUpAll(() async {
      tempDir = Directory.systemTemp.createTempSync('setup_action_test');
      await useAppPaths(tempDir);
      await AppLocalizations.load(const Locale('en'));
      originalLastConfigMd5 = globalState.lastConfigMd5;
      globalState.packageInfo = PackageInfo(
        appName: 'FlClash',
        packageName: 'com.follow.clash',
        version: '0.0.0',
        buildNumber: '0',
      );
    });

    tearDownAll(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    tearDown(() {
      globalState.lastConfigMd5 = originalLastConfigMd5;
    });

    // profileId: null routes getProfile/setupState around the database and
    // Core.getConfig, isolating the behavior under test.
    const nullProfileSetupState = SetupState(
      profileId: null,
      profileLastUpdateDate: null,
      profileType: ProfileType.file,
      extendType: ExtendType.standard,
      rules: [],
      proxyGroups: [],
      addedRules: [],
      script: null,
      overrides: ProfileOverrides(),
    );

    for (final change in ['delete', 'switch', 'type', 'commit']) {
      test('stale setup source $change never builds or applies', () async {
        final profile = Profile.normal(
          label: 'synthetic',
          url: 'https://example.invalid/source',
        );
        final other = Profile.custom(label: 'other');
        final core = _MockCoreHandlerInterface();
        final profiles = _HeldSourceProfilesAction();
        final scoped = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(() => TestProfiles([profile, other])),
            profilesActionProvider.overrideWith(() => profiles),
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
            initProvider.overrideWithBuild((_, _) => true),
            setupStateProvider.overrideWith((_, _) => nullProfileSetupState),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          ],
        );
        addTearDown(scoped.dispose);
        globalState.container = scoped;
        final applying = scoped
            .read(setupActionProvider.notifier)
            .applyProfile(force: true);
        await profiles.ready.future;
        switch (change) {
          case 'delete':
            await scoped.read(profilesProvider.notifier).del(profile.id);
          case 'switch':
            scoped.read(currentProfileIdProvider.notifier).value = other.id;
          case 'type':
            scoped
                .read(profilesProvider.notifier)
                .put(profile.copyWith(type: ProfileType.file));
          case 'commit':
            break;
        }
        profiles.result.complete(change == 'commit' ? profile : null);
        expect(await applying, isFalse);
        verifyNever(() => core.getProfileBase(any()));
        verifyNever(() => core.setupConfig(any()));
      });
    }

    test(
      'a refresh failure still runs core.setupConfig and preloadInvoke',
      () async {
        final profile = Profile.normal(label: 'p', url: 'http://127.0.0.1:9/');
        final core = _MockCoreHandlerInterface();
        when(() => core.setupConfig(any())).thenAnswer((_) async {});
        var preloadRan = false;
        final scoped = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(() => TestProfiles([profile])),
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
            setupStateProvider.overrideWith((_, _) => nullProfileSetupState),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            setupActionProvider.overrideWith(SetupAction.new),
          ],
        );
        addTearDown(scoped.dispose);

        await scoped
            .read(setupActionProvider.notifier)
            .applyProfile(
              force: true,
              preloadInvoke: () async {
                preloadRan = true;
              },
            );

        expect(preloadRan, isTrue);
        verify(() => core.setupConfig(any())).called(1);
      },
    );

    test(
      'provider directories it cannot create leave the config applied',
      () async {
        final profile = Profile.normal(label: 'p', url: 'http://127.0.0.1:9/');
        final providersRoot = File(await appPath.getProvidersRootPath());
        final earlierRoot = Directory(providersRoot.path);
        if (await earlierRoot.exists()) {
          await earlierRoot.delete(recursive: true);
        }
        await providersRoot.parent.create(recursive: true);
        await providersRoot.writeAsString('');
        addTearDown(() => providersRoot.delete());
        final core = _MockCoreHandlerInterface();
        when(() => core.setupConfig(any())).thenAnswer((_) async {});
        final scoped = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(() => TestProfiles([profile])),
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
            setupStateProvider.overrideWith((_, _) => nullProfileSetupState),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            setupActionProvider.overrideWith(SetupAction.new),
          ],
        );
        addTearDown(scoped.dispose);

        final succeeded = await scoped
            .read(setupActionProvider.notifier)
            .applyProfile(force: true);

        expect(succeeded, isTrue);
        verify(() => core.setupConfig(any())).called(1);
      },
    );

    test(
      'a failed build preserves confirmed file and metadata without setup',
      () async {
        final profile = Profile.normal(label: 'p');
        final core = _MockCoreHandlerInterface();
        when(
          () => core.getProfileBase(any()),
        ).thenThrow(Exception('broken yaml'));
        String? pushedConfig;
        when(() => core.setupConfig(any())).thenAnswer((_) async {
          pushedConfig = await File(
            await appPath.configFilePath,
          ).readAsString();
        });
        final configFile = File(await appPath.configFilePath);
        await configFile.parent.create(recursive: true);
        await configFile.writeAsString('confirmed synthetic config');
        globalState.lastConfigMd5 = 'confirmed-md5';
        final confirmedCounts = configCountsOf({
          'rules': ['MATCH,DIRECT'],
        });
        globalState.lastConfigCounts = confirmedCounts;
        final scoped = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(() => TestProfiles([profile])),
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
            setupStateProvider.overrideWith(
              (_, profileId) =>
                  nullProfileSetupState.copyWith(profileId: profileId),
            ),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            setupActionProvider.overrideWith(SetupAction.new),
          ],
        );
        addTearDown(scoped.dispose);

        final succeeded = await scoped
            .read(setupActionProvider.notifier)
            .applyProfile(force: true);

        expect(succeeded, isFalse);
        expect(pushedConfig, isNull);
        verifyNever(() => core.setupConfig(any()));
        expect(await configFile.readAsString(), 'confirmed synthetic config');
        expect(globalState.lastConfigMd5, 'confirmed-md5');
        expect(globalState.lastConfigCounts, confirmedCounts);
        expect(scoped.read(currentProfileIdProvider), profile.id);
      },
    );

    test(
      'a config write failure reports setup as failed without calling core',
      () async {
        final configPath = await appPath.configFilePath;
        final configFile = File(configPath);
        if (await configFile.exists()) {
          await configFile.delete();
        }
        final configAsDirectory = Directory(configPath);
        await configAsDirectory.create(recursive: true);

        final core = _MockCoreHandlerInterface();
        when(() => core.setupConfig(any())).thenAnswer((_) async {});
        final scoped = ProviderContainer(
          overrides: [
            currentProfileProvider.overrideWithValue(null),
            setupStateProvider.overrideWith((_, _) => nullProfileSetupState),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            setupActionProvider.overrideWith(SetupAction.new),
          ],
        );
        addTearDown(scoped.dispose);

        try {
          final succeeded = await scoped
              .read(setupActionProvider.notifier)
              .applyProfile(force: true);

          expect(succeeded, isFalse);
          verifyNever(() => core.setupConfig(any()));
        } finally {
          await configAsDirectory.delete(recursive: true);
        }
      },
    );

    test(
      'safe mode writes a closed external controller into the profile',
      () async {
        final profile = Profile.normal(label: 'p');
        final core = _MockCoreHandlerInterface();
        when(
          () => core.getProfileBase(any()),
        ).thenAnswer((_) async => const ProfileBase(config: {}, digest: 'd'));
        String? pushedConfig;
        when(() => core.setupConfig(any())).thenAnswer((invocation) async {
          final params = invocation.positionalArguments.single as SetupParams;
          pushedConfig = params.base?.overlay;
        });
        final scoped = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(() => TestProfiles([profile])),
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
            setupStateProvider.overrideWith(
              (_, profileId) =>
                  nullProfileSetupState.copyWith(profileId: profileId),
            ),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            setupActionProvider.overrideWith(SetupAction.new),
            safeModeProvider.overrideWithValue(true),
          ],
        );
        addTearDown(scoped.dispose);
        scoped
            .read(patchClashConfigProvider.notifier)
            .update(
              (state) => state.copyWith(
                externalController: ExternalControllerStatus.open,
              ),
            );

        final succeeded = await scoped
            .read(setupActionProvider.notifier)
            .applyProfile(force: true);

        expect(succeeded, isTrue);
        expect(pushedConfig, contains('external-controller: ""'));
        expect(pushedConfig, isNot(contains('9090')));
      },
    );

    group('running find-process mode', () {
      Future<(bool, String?)> apply({
        required Map<String, dynamic> file,
        required PatchClashConfig patchConfig,
        CoreMethodException? pushError,
      }) async {
        final profile = Profile.normal(label: 'p');
        final core = _MockCoreHandlerInterface();
        when(
          () => core.getProfileBase(any()),
        ).thenAnswer((_) async => ProfileBase(config: file, digest: 'd'));
        late final ProviderContainer scoped;
        String? duringPush = 'unread';
        when(() => core.setupConfig(any())).thenAnswer((_) async {
          duringPush = scoped.read(runningFindProcessModeProvider);
          if (pushError != null) {
            throw pushError;
          }
        });
        scoped = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(() => TestProfiles([profile])),
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
            setupStateProvider.overrideWith(
              (_, profileId) =>
                  nullProfileSetupState.copyWith(profileId: profileId),
            ),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            setupActionProvider.overrideWith(SetupAction.new),
          ],
        );
        addTearDown(scoped.dispose);
        scoped.read(patchClashConfigProvider.notifier).value = patchConfig;

        final succeeded = await scoped
            .read(setupActionProvider.notifier)
            .applyProfile(force: true);

        expect(duringPush, isNull);
        return (succeeded, scoped.read(runningFindProcessModeProvider));
      }

      const followed = PatchClashConfig(
        followKeys: {PageConfigKey.findProcessMode},
      );

      test('the page mode wins over the profile file', () async {
        final result = await apply(
          file: {'find-process-mode': 'always'},
          patchConfig: const PatchClashConfig(),
        );

        expect(result, (true, 'off'));
      });

      test('a followed mode is the profile file one', () async {
        final result = await apply(
          file: {'find-process-mode': 'always'},
          patchConfig: followed,
        );

        expect(result, (true, 'always'));
      });

      test('a followed mode the file leaves out is mihomo default', () async {
        final result = await apply(file: {}, patchConfig: followed);

        expect(result, (true, 'strict'));
      });

      test('a value mihomo would not run stays unknown', () async {
        final result = await apply(
          file: {'find-process-mode': 'sometimes'},
          patchConfig: followed,
        );

        expect(result, (true, null));
      });

      test('a push the Core fails sets nothing', () async {
        final result = await apply(
          file: {'find-process-mode': 'always'},
          patchConfig: followed,
          pushError: const CoreMethodException(code: 'failed', message: ''),
        );

        expect(result, (false, null));
      });
    });

    test('leaving an editor rebuilds the profile only once its inputs '
        'differ from the applied config', () async {
      final profile = Profile.normal(label: 'p');
      final core = _MockCoreHandlerInterface();
      when(
        () => core.getProfileBase(any()),
      ).thenAnswer((_) async => const ProfileBase(config: {}, digest: 'd'));
      when(() => core.setupConfig(any())).thenAnswer((_) async {});
      var setupState = nullProfileSetupState.copyWith(profileId: profile.id);
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          setupStateProvider.overrideWith((_, _) => setupState),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(SetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);
      final setupAction = scoped.read(setupActionProvider.notifier);
      Future<void> leaveEditor() async {
        setupAction.autoApplyProfile();
        SchedulerBinding.instance
          ..handleBeginFrame(null)
          ..handleDrawFrame();
        await pumpEventQueue();
      }

      await setupAction.applyProfile(force: true);
      verify(() => core.getProfileBase(any())).called(1);

      await leaveEditor();
      verifyNever(() => core.getProfileBase(any()));

      setupState = setupState.copyWith(matchTarget: 'DIRECT');
      scoped.invalidate(setupStateProvider);
      await leaveEditor();
      verify(() => core.getProfileBase(any())).called(1);
      // Queued behind the rebuild: one that outlasts the pump would compare
      // against the md5 tearDown resets and push into a disposed container.
      await setupAction.applyProfile();
    });

    test('a debounced apply waits as long as the last push to the Core took, '
        'whatever an apply that sent nothing took since', () async {
      final profile = Profile.normal(label: 'p');
      final core = _MockCoreHandlerInterface();
      when(
        () => core.getProfileBase(any()),
      ).thenAnswer((_) async => const ProfileBase(config: {}, digest: 'd'));
      when(() => core.setupConfig(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          setupStateProvider.overrideWith(
            (_, _) => nullProfileSetupState.copyWith(profileId: profile.id),
          ),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(_UnflooredDebounceSetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);
      final setupAction = scoped.read(setupActionProvider.notifier);

      await setupAction.applyProfile(force: true);
      await setupAction.applyProfile();
      verify(() => core.setupConfig(any())).called(1);
      clearInteractions(core);

      setupAction.applyProfileDebounce(silence: true, force: true);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      verifyNever(() => core.getProfileBase(any()));
      await Future<void>.delayed(const Duration(seconds: 1));
      verify(() => core.getProfileBase(any())).called(1);
      // Queued behind the forced push, so the container outlives it.
      await setupAction.applyProfile();
    });

    test('a slow push holds a debounced apply back no longer than the '
        'ceiling', () async {
      final profile = Profile.normal(label: 'p');
      final core = _MockCoreHandlerInterface();
      when(
        () => core.getProfileBase(any()),
      ).thenAnswer((_) async => const ProfileBase(config: {}, digest: 'd'));
      when(() => core.setupConfig(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          setupStateProvider.overrideWith(
            (_, _) => nullProfileSetupState.copyWith(profileId: profile.id),
          ),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(_CappedDebounceSetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);
      final setupAction = scoped.read(setupActionProvider.notifier);

      await setupAction.applyProfile(force: true);
      clearInteractions(core);

      setupAction.applyProfileDebounce(silence: true, force: true);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      verify(() => core.getProfileBase(any())).called(1);
      await setupAction.applyProfile();
    });

    test('a config the Core already runs is not pushed again, while the start '
        'riding on it still opens the listeners', () async {
      final profile = Profile.normal(label: 'p');
      final core = _MockCoreHandlerInterface();
      when(
        () => core.getProfileBase(any()),
      ).thenAnswer((_) async => const ProfileBase(config: {}, digest: 'd'));
      when(() => core.setupConfig(any())).thenAnswer((_) async {});
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          setupStateProvider.overrideWith(
            (_, _) => nullProfileSetupState.copyWith(profileId: profile.id),
          ),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(SetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);
      final setupAction = scoped.read(setupActionProvider.notifier);
      await setupAction.applyProfile(force: true);
      final counts = globalState.lastConfigCounts;
      expect(counts, isNotNull);
      globalState.lastConfigCounts = null;

      var listenersOpened = false;
      final applied = await setupAction.applyProfile(
        preloadInvoke: () async {
          listenersOpened = true;
        },
      );

      expect(applied, isTrue);
      expect(listenersOpened, isTrue);
      expect(globalState.lastConfigCounts, counts);
      verify(() => core.setupConfig(any())).called(1);
    });

    test('a known kept rejection retains groups and reverting to confirmed '
        'inputs needs no extra push', () async {
      final profile = Profile.normal(label: 'p');
      final core = _MockCoreHandlerInterface();
      Map<String, dynamic> global(List<String> all) => {
        'name': 'GLOBAL',
        'type': 'Selector',
        'hidden': true,
        'all': all,
      };
      final profileProxies = ProxiesData(
        all: const ['Proxy', 'GLOBAL'],
        proxies: {
          'Proxy': <String, dynamic>{
            'name': 'Proxy',
            'type': 'Selector',
            'hidden': false,
            'all': ['HK-01'],
          },
          'HK-01': <String, dynamic>{'name': 'HK-01', 'type': 'ss'},
          'GLOBAL': global(['Proxy']),
        },
      );
      var rejecting = false;
      var coreProxies = profileProxies;
      when(
        () => core.getProfileBase(any()),
      ).thenAnswer((_) async => const ProfileBase(config: {}, digest: 'd'));
      when(() => core.getExternalProviders()).thenAnswer((_) async => []);
      when(() => core.getProxies()).thenAnswer((_) async => coreProxies);
      when(() => core.setupConfig(any())).thenAnswer((_) async {
        if (rejecting) {
          throw const CoreMethodException(
            code: 'config_rejected',
            message: 'invalid hosts',
            details: {'outcome': 'kept'},
          );
        }
        coreProxies = profileProxies;
      });
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          setupStateProvider.overrideWith(
            (_, profileId) =>
                nullProfileSetupState.copyWith(profileId: profileId),
          ),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(SetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);
      final setupAction = scoped.read(setupActionProvider.notifier);
      List<String> shownGroups() => [
        for (final group in scoped.read(currentGroupsStateProvider).value)
          group.name,
      ];
      void setHosts(Map<String, String> hosts) {
        scoped
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith(hosts: hosts));
      }

      final originalHosts = scoped.read(patchClashConfigProvider).hosts;
      expect(await setupAction.applyProfile(force: true), isTrue);
      expect(shownGroups(), ['Proxy']);

      rejecting = true;
      setHosts({'example.com': 'not-an-address'});
      expect(await setupAction.applyProfile(), isFalse);
      expect(shownGroups(), ['Proxy']);

      rejecting = false;
      setHosts(originalHosts);
      expect(await setupAction.applyProfile(), isTrue);
      verify(() => core.setupConfig(any())).called(2);
      expect(shownGroups(), ['Proxy']);
    });

    test('a mounted profile hands its mounts over and tells a kept run '
        'from a blocked one', () async {
      final profile = Profile.normal(label: 'p');
      final core = _MockCoreHandlerInterface();
      final mounts = MountSetup(
        target: profile.id,
        revision: 'r1',
        sources: const [MountSource(id: 2, label: 'Air', path: '/p/2.yaml')],
      );
      when(
        () => core.getProfileBase(any()),
      ).thenAnswer((_) async => const ProfileBase(config: {}, digest: 'd'));
      when(() => core.getExternalProviders()).thenAnswer((_) async => []);
      var groupReads = 0;
      when(() => core.getProxies()).thenAnswer((_) async {
        groupReads++;
        return const ProxiesData(all: [], proxies: {});
      });
      final pushed = <SetupParams>[];
      String? outcome;
      when(() => core.setupConfig(any())).thenAnswer((invocation) async {
        pushed.add(invocation.positionalArguments.single as SetupParams);
        if (outcome case final outcome?) {
          throw CoreMethodException(
            code: 'mount_rejected',
            message: 'bad',
            details: {'outcome': outcome},
          );
        }
      });
      var revision = 'r1';
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          setupStateProvider.overrideWith(
            (_, profileId) => nullProfileSetupState.copyWith(
              profileId: profileId,
              mounts: mounts.copyWith(revision: revision),
            ),
          ),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(SetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);
      addTearDown(() => globalState.lastConfigCounts = null);
      final setupAction = scoped.read(setupActionProvider.notifier);

      expect(await setupAction.applyProfile(force: true), isTrue);
      expect(pushed.single.mounts, mounts);
      await setupAction.applyProfile();
      expect(pushed, hasLength(1));

      revision = 'r2';
      scoped.invalidate(setupStateProvider);
      await setupAction.applyProfile();
      expect(pushed.last.mounts?.revision, 'r2');

      outcome = 'kept';
      revision = 'r3';
      scoped.invalidate(setupStateProvider);
      globalState.lastConfigCounts = (groups: 1, proxies: 1, rules: 1);
      var reads = groupReads;
      expect(await setupAction.applyProfile(), isFalse);
      expect(globalState.lastConfigCounts, (groups: 1, proxies: 1, rules: 1));
      expect(groupReads, reads);

      outcome = 'blocked';
      reads = groupReads;
      expect(await setupAction.applyProfile(), isFalse);
      expect(globalState.lastConfigCounts, (groups: 0, proxies: 0, rules: 0));
      expect(groupReads, greaterThan(reads));
    });

    test('an apply keeps the profile on the names the Core followed its '
        'mounted selections to', () async {
      final profile = Profile.normal(
        label: 'p',
      ).copyWith(selectedMap: {'Proxy': 'HK', 'Media': 'JP', 'Other': 'X'});
      final core = _MockCoreHandlerInterface();
      when(
        () => core.getProfileBase(any()),
      ).thenAnswer((_) async => const ProfileBase(config: {}, digest: 'd'));
      when(() => core.getExternalProviders()).thenAnswer((_) async => []);
      when(
        () => core.getProxies(),
      ).thenAnswer((_) async => const ProxiesData(all: [], proxies: {}));
      when(() => core.setupConfig(any())).thenAnswer((_) async {});
      when(() => core.getMountState()).thenAnswer(
        (_) async => MountRuntimeState(
          report: MountReport(target: profile.id),
          moved: const {'Proxy': 'HK (B)'},
          lost: const ['Media'],
        ),
      );
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          setupStateProvider.overrideWith(
            (_, profileId) => nullProfileSetupState.copyWith(
              profileId: profileId,
              mounts: MountSetup(target: profile.id, revision: 'r'),
            ),
          ),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(SetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);
      addTearDown(() => globalState.lastConfigCounts = null);
      final setupAction = scoped.read(setupActionProvider.notifier);

      expect(await setupAction.applyProfile(force: true), isTrue);

      expect(
        scoped.read(profilesProvider).getProfile(profile.id)!.selectedMap,
        {'Proxy': 'HK (B)', 'Other': 'X'},
      );
      expect(setupAction.lostMountSelections, ['Media']);
    });

    test('a profile file leaves its bulk sections in the Core and records '
        'what the Core was handed', () async {
      final profile = Profile.normal(label: 'p');
      final core = _MockCoreHandlerInterface();
      var digest = 'first';
      when(() => core.getProfileBase(any())).thenAnswer(
        (_) async => ProfileBase(
          config: const {'mixed-port': 1},
          digest: digest,
          matchRules: const ['MATCH,DIRECT', 'MATCH,Proxy'],
          proxies: 3,
          proxyGroups: 2,
          rules: 5,
        ),
      );
      final pushed = <SetupParams>[];
      when(() => core.setupConfig(any())).thenAnswer((invocation) async {
        pushed.add(invocation.positionalArguments.single as SetupParams);
      });
      final configFile = File(await appPath.configFilePath);
      await configFile.writeAsString('previous');
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
          setupStateProvider.overrideWith(
            (_, profileId) => nullProfileSetupState.copyWith(
              profileId: profileId,
              addedRules: [Rule.parse('DOMAIN,added.test,MATCH')],
            ),
          ),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(SetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);
      final setupAction = scoped.read(setupActionProvider.notifier);
      addTearDown(() => globalState.lastConfigCounts = null);

      expect(await setupAction.applyProfile(force: true), isTrue);

      final base = pushed.single.base!;
      expect(base.path, await appPath.getProfilePath(profile.id.toString()));
      final overlay = loadYaml(base.overlay) as YamlMap;
      expect(overlay['rules'], ['DOMAIN,added.test,Proxy']);
      expect(overlay['mixed-port'], isNot(1));
      expect(await configFile.readAsString(), 'previous');
      expect(globalState.lastConfigCounts, (groups: 2, proxies: 3, rules: 6));

      await setupAction.applyProfile();
      expect(pushed, hasLength(1));

      digest = 'second';
      await setupAction.applyProfile();
      expect(pushed, hasLength(2));

      when(() => core.setupConfig(any())).thenAnswer(
        (_) async => throw const CoreMethodException(
          code: 'config_rejected',
          message: 'rejected',
        ),
      );
      digest = 'third';
      expect(await setupAction.applyProfile(), isFalse);
      expect(globalState.lastConfigCounts, (groups: 0, proxies: 0, rules: 0));
    });

    test('the preview shows the config the Core merges', () async {
      final profile = Profile.normal(label: 'p');
      final core = _MockCoreHandlerInterface();
      when(
        () => core.getProfileBase(any()),
      ).thenAnswer((_) async => const ProfileBase(config: {}, digest: 'd'));
      final built = File(
        join(await appPath.homeDirPath, coreSpillDirectoryName, 'p.yaml'),
      );
      when(
        () => core.buildProfile(
          base: any(named: 'base'),
          config: any(named: 'config'),
          mounts: any(named: 'mounts'),
        ),
      ).thenAnswer((_) async {
        await built.create(recursive: true);
        await built.writeAsString('proxies: []\n');
        return built.path;
      });
      when(() => core.getTailscaleExit(profile.id)).thenAnswer(
        (_) async => TailscaleExitReport(
          profileId: profile.id,
          state: TailscaleRuntimeState.none,
        ),
      );
      when(() => core.getTailscaleRuntimeRules(profile.id)).thenAnswer(
        (_) async => TailscaleRuntimeRules(
          profileId: profile.id,
          state: TailscaleRuntimeState.none,
        ),
      );
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          setupStateProvider.overrideWith(
            (_, profileId) =>
                nullProfileSetupState.copyWith(profileId: profileId),
          ),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(SetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);

      final yaml = await scoped
          .read(setupActionProvider.notifier)
          .getProfileWithId(profile.id);

      verifyNever(() => core.readConfig(any()));
      expect(yaml, 'proxies: []\n\n# ${currentAppLocalizations.tsViewerNone}');
      expect(built.existsSync(), isFalse);
    });

    test('the preview holds the mounts the Core runs', () async {
      final profile = Profile.normal(label: 'p');
      const mounts = MountSetup(
        target: 1,
        revision: 'r',
        sources: [MountSource(id: 2, label: 'A', path: '/profiles/2.yaml')],
      );
      final core = _MockCoreHandlerInterface();
      when(
        () => core.getProfileBase(any()),
      ).thenAnswer((_) async => const ProfileBase(config: {}, digest: 'd'));
      final built = File(
        join(await appPath.homeDirPath, coreSpillDirectoryName, 'm.yaml'),
      );
      when(
        () => core.buildProfile(
          base: any(named: 'base'),
          config: any(named: 'config'),
          mounts: any(named: 'mounts'),
        ),
      ).thenAnswer((_) async {
        await built.create(recursive: true);
        await built.writeAsString('proxy-providers: {}\n');
        return built.path;
      });
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          setupStateProvider.overrideWith(
            (_, profileId) => nullProfileSetupState.copyWith(
              profileId: profileId,
              mounts: mounts,
            ),
          ),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(SetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);

      await scoped
          .read(setupActionProvider.notifier)
          .getProfileWithId(profile.id);

      verify(
        () => core.buildProfile(
          base: any(named: 'base', that: isNotNull),
          config: null,
          mounts: mounts,
        ),
      ).called(1);
    });

    test('a preview whose mount check fails still shows the profile', () async {
      final profile = Profile.normal(label: 'p');
      const mounts = MountSetup(
        target: 1,
        revision: 'r',
        sources: [MountSource(id: 2, label: 'A', path: '/profiles/2.yaml')],
      );
      final core = _MockCoreHandlerInterface();
      when(
        () => core.getProfileBase(any()),
      ).thenAnswer((_) async => const ProfileBase(config: {}, digest: 'd'));
      final built = File(
        join(await appPath.homeDirPath, coreSpillDirectoryName, 'f.yaml'),
      );
      when(
        () => core.buildProfile(
          base: any(named: 'base'),
          config: any(named: 'config'),
          mounts: any(named: 'mounts', that: isNotNull),
        ),
      ).thenThrow(Exception('mount check failed'));
      when(
        () => core.buildProfile(
          base: any(named: 'base'),
          config: any(named: 'config'),
        ),
      ).thenAnswer((_) async {
        await built.create(recursive: true);
        await built.writeAsString('proxies: [base]\n');
        return built.path;
      });
      when(() => core.getTailscaleExit(profile.id)).thenAnswer(
        (_) async => TailscaleExitReport(
          profileId: profile.id,
          state: TailscaleRuntimeState.none,
        ),
      );
      when(() => core.getTailscaleRuntimeRules(profile.id)).thenAnswer(
        (_) async => TailscaleRuntimeRules(
          profileId: profile.id,
          state: TailscaleRuntimeState.none,
        ),
      );
      final scoped = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(() => TestProfiles([profile])),
          setupStateProvider.overrideWith(
            (_, profileId) => nullProfileSetupState.copyWith(
              profileId: profileId,
              mounts: mounts,
            ),
          ),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(SetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);

      final yaml = await scoped
          .read(setupActionProvider.notifier)
          .getProfileWithId(profile.id);

      expect(
        yaml,
        'proxies: [base]\n\n# ${currentAppLocalizations.tsViewerNone}',
      );
    });

    for (final (revision, found) in [('r', true), ('r0', false)]) {
      test('a search of the preview ${found ? 'finds' : 'does not find'} a '
          'mounted node when the Core runs ${found ? 'this' : 'another'} '
          'revision', () async {
        final profile = Profile.normal(label: 'p');
        const mounts = MountSetup(
          target: 1,
          revision: 'r',
          sources: [MountSource(id: 2, label: 'C', path: '/profiles/2.yaml')],
        );
        final core = _MockCoreHandlerInterface();
        when(
          () => core.getProfileBase(any()),
        ).thenAnswer((_) async => const ProfileBase(config: {}, digest: 'd'));
        final built = File(
          join(await appPath.homeDirPath, coreSpillDirectoryName, 'n.yaml'),
        );
        when(
          () => core.buildProfile(
            base: any(named: 'base'),
            config: any(named: 'config'),
            mounts: any(named: 'mounts'),
          ),
        ).thenAnswer((_) async {
          await built.create(recursive: true);
          await built.writeAsString(
            'proxy-providers:\n  flash-mount-2:\n    type: file\n',
          );
          return built.path;
        });
        when(() => core.getMountState()).thenAnswer(
          (_) async => MountRuntimeState(
            report: MountReport(
              target: 1,
              revision: revision,
              sources: const [
                MountSourceReport(
                  id: 2,
                  provider: 'flash-mount-2',
                  status: MountSourceStatus.nodes,
                  nodes: [MountNode(name: 'HK (C)', original: 'HK')],
                ),
              ],
            ),
            sources: const [
              MountRuntimeSource(
                id: 2,
                provider: 'flash-mount-2',
                present: true,
                count: 1,
                matches: true,
              ),
            ],
          ),
        );
        final scoped = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(() => TestProfiles([profile])),
            setupStateProvider.overrideWith(
              (_, profileId) => nullProfileSetupState.copyWith(
                profileId: profileId,
                mounts: mounts,
              ),
            ),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            setupActionProvider.overrideWith(SetupAction.new),
          ],
        );
        addTearDown(scoped.dispose);

        final yaml = await scoped
            .read(setupActionProvider.notifier)
            .getProfileWithId(profile.id);

        final l10n = currentAppLocalizations;
        expect(yaml.contains('HK (C)'), found);
        expect(
          yaml,
          startsWith(
            found
                ? 'proxy-providers:\n  # ${l10n.mountViewerSource('C', 1)}\n'
                      '  #   - HK (C)\n  flash-mount-2:\n'
                : 'proxy-providers:\n  # ${l10n.mountViewerPending('C')}\n'
                      '  flash-mount-2:\n',
          ),
        );
      });
    }

    for (final failed in [false, true]) {
      test('the preview notes the Tailscale rules the Core runs'
          '${failed ? ', or that it could not read them' : ''}', () async {
        final profile = Profile.normal(label: 'p');
        final setup = TailscaleSetup(
          profileId: profile.id,
          configSource: TailscaleSettingSource.profile,
          managed: const [TailscaleManagedSetup(id: 'a1', attached: true)],
        );
        final core = _MockCoreHandlerInterface();
        when(
          () => core.getProfileBase(any()),
        ).thenAnswer((_) async => const ProfileBase(config: {}, digest: 'd'));
        final built = File(
          join(await appPath.homeDirPath, coreSpillDirectoryName, 't.yaml'),
        );
        when(
          () => core.buildProfile(
            base: any(named: 'base'),
            config: any(named: 'config'),
            mounts: any(named: 'mounts'),
          ),
        ).thenAnswer((_) async {
          await built.create(recursive: true);
          await built.writeAsString('rules:\n  - MATCH,DIRECT\n');
          return built.path;
        });
        when(() => core.getTailscaleRuntimeRules(profile.id)).thenAnswer((
          _,
        ) async {
          if (failed) {
            throw StateError('unread');
          }
          return TailscaleRuntimeRules(
            profileId: profile.id,
            state: TailscaleRuntimeState.confirmed,
            revision: tailscaleRuntimeRevisionOf(setup),
            accounts: const [
              TailscaleRuntimeAccount(
                id: 'a1',
                node: 'TS',
                rules: ['DOMAIN-SUFFIX,ts.net,REJECT'],
              ),
            ],
          );
        });
        when(() => core.getTailscaleExit(profile.id)).thenAnswer(
          (_) async => TailscaleExitReport(
            profileId: profile.id,
            state: TailscaleRuntimeState.confirmed,
          ),
        );
        final scoped = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(() => TestProfiles([profile])),
            setupStateProvider.overrideWith(
              (_, profileId) =>
                  nullProfileSetupState.copyWith(profileId: profileId),
            ),
            tailscaleSetupProvider.overrideWithValue(setup),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            setupActionProvider.overrideWith(SetupAction.new),
          ],
        );
        addTearDown(scoped.dispose);

        final yaml = await scoped
            .read(setupActionProvider.notifier)
            .getProfileWithId(profile.id);

        final l10n = currentAppLocalizations;
        expect(
          yaml,
          failed
              ? 'rules:\n  # ${l10n.tsViewerReadFailed}\n  - MATCH,DIRECT\n'
              : 'rules:\n  # ${l10n.tsViewerRules(1, 'TS')}\n'
                    '  #   - DOMAIN-SUFFIX,ts.net,REJECT\n  - MATCH,DIRECT\n',
        );
      });
    }

    test(
      'the extend page reads only the outbounds of a profile file',
      () async {
        final profile = Profile.normal(label: 'p');
        final core = _MockCoreHandlerInterface();
        when(() => core.getProfileOutbounds(any())).thenAnswer(
          (_) async => {
            'proxies': [
              {'name': 'a', 'type': 'ss'},
            ],
            'proxy-groups': [
              {'name': 'g', 'type': 'select'},
            ],
          },
        );
        final scoped = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(() => TestProfiles([profile])),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          ],
        );
        addTearDown(scoped.dispose);

        final config = await scoped.read(
          clashConfigProvider(profile.id).future,
        );

        verifyNever(() => core.readConfig(any()));
        expect(
          {
            for (final proxy in config.proxies) proxy.name: proxy.type,
            for (final group in config.proxyGroups) group.name: group.type,
          },
          {'a': 'ss', 'g': GroupType.Selector},
        );
      },
    );

    test(
      'a start applies the profile again only once its inputs changed',
      () async {
        final profile = Profile.normal(label: 'p');
        final core = _MockCoreHandlerInterface();
        when(
          () => core.getProfileBase(any()),
        ).thenAnswer((_) async => const ProfileBase(config: {}, digest: 'd'));
        when(() => core.setupConfig(any())).thenAnswer((_) async {});
        when(() => core.startListener()).thenAnswer((_) async {});
        when(() => core.stopListener()).thenAnswer((_) async {});
        when(() => core.resetTraffic()).thenAnswer((_) async {});
        final scoped = ProviderContainer(
          overrides: [
            profilesProvider.overrideWith(() => TestProfiles([profile])),
            currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
            setupStateProvider.overrideWith(
              (_, profileId) =>
                  nullProfileSetupState.copyWith(profileId: profileId),
            ),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            commonActionProvider.overrideWith(TestCommonAction.new),
            setupActionProvider.overrideWith(_UnflooredDebounceSetupAction.new),
          ],
        );
        addTearDown(scoped.dispose);
        scoped.read(initProvider.notifier).value = true;
        final setupAction = scoped.read(setupActionProvider.notifier);
        await setupAction.applyProfile(force: true);
        verify(() => core.setupConfig(any())).called(1);

        await setupAction.setRunning(true);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        verifyNever(() => core.setupConfig(any()));

        await setupAction.setRunning(false);
        scoped.read(patchClashConfigProvider.notifier).value = scoped
            .read(patchClashConfigProvider)
            .copyWith(testUrl: 'https://example.com/204');
        await setupAction.setRunning(true);
        await Future<void>.delayed(const Duration(milliseconds: 800));
        verify(() => core.setupConfig(any())).called(1);
        await setupAction.setRunning(false);
      },
    );

    test('a custom profile declares only the proxies and providers it names, '
        'without a profile file', () async {
      final profile = Profile.custom(label: 'p');
      final core = _MockCoreHandlerInterface();
      const appProxy = CustomProxy(
        id: 11,
        definition: {'name': 'mine', 'type': 'socks5', 'server': '::1'},
      );
      const unusedProxy = CustomProxy(
        id: 15,
        definition: {'name': 'spare', 'type': 'socks5', 'server': '::1'},
      );
      const appRule = ClashProvider(
        id: 12,
        label: 'appRules',
        url: 'https://example.com/r.yaml',
        behavior: RuleProviderBehavior.domain,
        format: RuleProviderFormat.yaml,
      );
      final compiled = File(await appRule.compiledPath)
        ..createSync(recursive: true);
      addTearDown(compiled.deleteSync);
      const unusedRule = ClashProvider(
        id: 13,
        label: 'unused',
        url: 'https://example.com/u.yaml',
      );
      const localRule = ClashProvider(
        id: 14,
        label: 'localRules',
        behavior: RuleProviderBehavior.classical,
        format: RuleProviderFormat.yaml,
      );
      const nestedRule = ClashProvider(
        id: 16,
        label: 'nestedRules',
        behavior: RuleProviderBehavior.classical,
        format: RuleProviderFormat.yaml,
      );
      final setupState = nullProfileSetupState.copyWith(
        profileId: profile.id,
        profileType: ProfileType.custom,
        proxyGroups: [
          const ProxyGroup(
            id: 1,
            name: 'g',
            type: GroupType.Selector,
            proxies: ['mine'],
            use: ['sub'],
          ),
        ],
        rules: [
          Rule.parse('RULE-SET,appRules,DIRECT', id: 2),
          Rule.parse('RULE-SET,localRules,DIRECT', id: 3),
          Rule.parse(
            'AND,((RULE-SET,nestedRules),(NETWORK,UDP)),REJECT',
            id: 4,
          ),
        ],
        clashProviders: const [appRule, unusedRule, localRule, nestedRule],
        profileProviders: const {'sub': 42},
        appProxies: const [appProxy, unusedProxy],
      );
      final scoped = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(SetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);

      final res = await scoped
          .read(setupActionProvider.notifier)
          .getProfile(
            setupState: setupState,
            patchConfig: const PatchClashConfig(),
          );
      final config = loadYaml(res.yaml) as YamlMap;
      final proxyProviders = config['proxy-providers'] as YamlMap;

      verifyNever(() => core.readConfig(any()));
      expect(proxyProviders.keys, {'sub'});
      expect((config['proxies'] as YamlList).single['name'], 'mine');
      expect(proxyProviders['sub']['type'], 'file');
      expect(proxyProviders['sub']['path'], await appPath.getProfilePath('42'));
      expect((config['proxy-groups'] as YamlList).single['name'], 'g');
      expect(config['rules'], [
        'RULE-SET,appRules,DIRECT',
        'RULE-SET,localRules,DIRECT',
        'AND,((RULE-SET,nestedRules),(NETWORK,UDP)),REJECT',
      ]);
      expect(config['rule-providers'].containsKey('nestedRules'), isTrue);
      final remote = config['rule-providers']['appRules'] as YamlMap;
      expect(remote['type'], 'file');
      expect(remote.containsKey('url'), isFalse);
      expect(remote['behavior'], 'domain');
      expect(remote['format'], 'mrs');
      expect(remote['path'], compiled.path);
      expect(config['rule-providers'].containsKey('unused'), isFalse);
      final local = config['rule-providers']['localRules'] as YamlMap;
      expect(local['type'], 'file');
      expect(local.containsKey('url'), isFalse);
      expect(
        local['path'],
        await appPath.getProviderCachePath(localRule.fileName),
      );
    });

    test('a provider a custom profile names carries its options', () async {
      final profile = Profile.custom(label: 'p');
      final core = _MockCoreHandlerInterface();
      final setupState = nullProfileSetupState.copyWith(
        profileId: profile.id,
        profileType: ProfileType.custom,
        proxyGroups: [
          const ProxyGroup(
            id: 1,
            name: 'g',
            type: GroupType.Selector,
            use: ['sub', 'plain'],
          ),
        ],
        profileProviders: const {'sub': 42, 'plain': 43},
        overrides: const ProfileOverrides(
          proxyProviders: {
            'sub': ProxyProviderOptions(
              healthCheck: ProviderHealthCheck(interval: 600),
              filter: 'HK',
              excludeFilter: 'expire',
            ),
          },
        ),
      );
      final scoped = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(SetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);

      final res = await scoped
          .read(setupActionProvider.notifier)
          .getProfile(
            setupState: setupState,
            patchConfig: const PatchClashConfig(),
          );
      final providers = (loadYaml(res.yaml) as YamlMap)['proxy-providers'];

      expect(providers['sub']['filter'], 'HK');
      expect(providers['sub']['exclude-filter'], 'expire');
      expect(providers['sub']['health-check'], {
        'enable': true,
        'url': defaultTestUrl,
        'interval': 600,
      });
      expect(providers['sub']['type'], 'file');
      expect((providers['plain'] as YamlMap).keys, {'type', 'path'});
    });

    test('a custom profile group taking in every proxy or provider declares '
        'none the profile does not name', () async {
      final profile = Profile.custom(label: 'p');
      final core = _MockCoreHandlerInterface();
      final setupState = nullProfileSetupState.copyWith(
        profileId: profile.id,
        profileType: ProfileType.custom,
        proxyGroups: [
          const ProxyGroup(
            id: 1,
            name: 'g',
            type: GroupType.Selector,
            filter: 'HK',
            includeAllProxies: true,
            includeAllProviders: true,
          ),
          const ProxyGroup(
            id: 2,
            name: 'h',
            type: GroupType.Selector,
            proxies: ['mine'],
            use: ['sub'],
          ),
        ],
        profileProviders: const {'sub': 42, 'plain': 43},
        appProxies: const [
          CustomProxy(id: 11, definition: {'name': 'mine', 'type': 'direct'}),
          CustomProxy(id: 15, definition: {'name': 'spare', 'type': 'direct'}),
        ],
      );
      final scoped = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(SetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);

      final res = await scoped
          .read(setupActionProvider.notifier)
          .getProfile(
            setupState: setupState,
            patchConfig: const PatchClashConfig(),
          );
      final config = loadYaml(res.yaml) as YamlMap;

      expect((config['proxy-providers'] as YamlMap).keys, {'sub'});
      expect([for (final proxy in config['proxies']) proxy['name']], ['mine']);
      final group = (config['proxy-groups'] as YamlList).first as YamlMap;
      expect(group['include-all-proxies'], isTrue);
      expect(group['include-all-providers'], isTrue);
    });

    test('only a subscription profile runs its script extension', () async {
      final engine = scriptEvaluator;
      addTearDown(() => scriptEvaluator = engine);
      final evaluated = <String>[];
      scriptEvaluator =
          ({required String script, required String config}) async {
            evaluated.add(script);
            return config;
          };
      final script = await Script(
        id: 77,
        label: 'script',
        lastUpdateTime: DateTime(2026),
      ).save('const main = (config) => config;');
      final core = _MockCoreHandlerInterface();
      when(() => core.readConfig(any())).thenAnswer((_) async => {});
      final scoped = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          setupActionProvider.overrideWith(SetupAction.new),
        ],
      );
      addTearDown(scoped.dispose);
      Future<void> build(ProfileType type) => scoped
          .read(setupActionProvider.notifier)
          .getProfile(
            setupState: nullProfileSetupState.copyWith(
              profileId: 5,
              profileType: type,
              extendType: ExtendType.script,
              script: script,
            ),
            patchConfig: const PatchClashConfig(),
          );

      await build(ProfileType.custom);
      expect(evaluated, isEmpty);
      verifyNever(() => core.readConfig(any()));

      await build(ProfileType.file);
      expect(evaluated, hasLength(1));
      verify(() => core.readConfig(any())).called(1);
    });

    test(
      'a rejected setupConfig without a handoff reports failure, not success',
      () async {
        final core = _MockCoreHandlerInterface();
        when(() => core.setupConfig(any())).thenThrow(StateError('rejected'));
        final scoped = ProviderContainer(
          overrides: [
            currentProfileProvider.overrideWithValue(null),
            setupStateProvider.overrideWith((_, _) => nullProfileSetupState),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            setupActionProvider.overrideWith(SetupAction.new),
          ],
        );
        addTearDown(scoped.dispose);

        final succeeded = await scoped
            .read(setupActionProvider.notifier)
            .applyProfile(force: true);

        expect(succeeded, isFalse);
        verify(() => core.setupConfig(any())).called(1);
      },
    );

    test(
      'a listener handoff failure during initialize rolls back running',
      () async {
        final core = _MockCoreHandlerInterface();
        when(() => core.setupConfig(any())).thenAnswer((_) async {});
        final scoped = ProviderContainer(
          overrides: [
            currentProfileProvider.overrideWithValue(null),
            setupStateProvider.overrideWith((_, _) => nullProfileSetupState),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            setupActionProvider.overrideWith(
              _ListenerHandoffFailureSetupAction.new,
            ),
          ],
        );
        addTearDown(scoped.dispose);
        final handoffAction =
            scoped.read(setupActionProvider.notifier)
                as _ListenerHandoffFailureSetupAction;

        await handoffAction.setRunning(true, initialize: true);

        expect(handoffAction.coreRunningCalls, [true, false]);
        expect(scoped.read(runTimeProvider), isNull);
        verify(() => core.setupConfig(any())).called(1);
      },
    );

    test(
      'a non-empty setupConfig message during initialize rolls back running',
      () async {
        final core = _MockCoreHandlerInterface();
        when(() => core.setupConfig(any())).thenAnswer(
          (_) async => throw const CoreMethodException(
            code: 'config_rejected',
            message: 'config rejected',
          ),
        );
        final scoped = ProviderContainer(
          overrides: [
            currentProfileProvider.overrideWithValue(null),
            setupStateProvider.overrideWith((_, _) => nullProfileSetupState),
            coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
            setupActionProvider.overrideWith(_MessageFailureSetupAction.new),
          ],
        );
        addTearDown(scoped.dispose);
        final messageAction =
            scoped.read(setupActionProvider.notifier)
                as _MessageFailureSetupAction;

        await messageAction.setRunning(true, initialize: true);

        expect(messageAction.coreRunningCalls, [true, false]);
        expect(scoped.read(runTimeProvider), isNull);
        verify(() => core.setupConfig(any())).called(1);
      },
    );
  });
}
