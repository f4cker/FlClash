import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/app_paths.dart';
import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';

class _Core extends Mock implements CoreHandlerInterface {}

class _CheckAction extends CommonAction {
  late UpdateCheck answer;
  Completer<void>? checkHold;
  int checks = 0;

  @override
  Future<UpdateCheck> checkForAppUpdate() async {
    checks++;
    await checkHold?.future;
    ref.read(availableUpdateStateProvider.notifier).value =
        answer is UpdateAvailable ? answer as UpdateAvailable : null;
    return answer;
  }
}

class _Exit extends SystemAction {
  int exits = 0;
  @override
  Future<void> handleExit([bool needSave = true]) async {
    exits++;
  }
}

class _Restart extends CoreAction {
  int restarts = 0;
  @override
  Future<bool> restartCore() async {
    restarts++;
    return true;
  }
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.bytes);
  final List<int> bytes;
  final requested = <Uri>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested.add(options.uri);
    return ResponseBody.fromBytes(bytes, 200);
  }

  @override
  void close({bool force = false}) {}
}

UpdateAvailable candidate({
  int build = 2026111902,
  ReleaseChannel channel = ReleaseChannel.stable,
}) {
  final bytes = utf8.encode('test archive');
  final manifest = MacUpdateManifest(
    version: '1.0.0',
    channel: channel,
    releaseVersion: '1.0.0',
    releaseTag: 'v1.0.0',
    build: build,
    helperBuild: build,
    minimumSystemVersion: '12.0',
    notes: 'Published release notes',
    published: '2026-11-19T00:00:00Z',
    assets: [
      MacUpdateAsset(
        arch: 'arm64',
        name: 'Flash-1.0.0-macos-arm64.zip',
        url: Uri.parse(
          'https://example.invalid/v1.0.0/Flash-1.0.0-macos-arm64.zip',
        ),
        size: bytes.length,
        sha256: sha256.convert(bytes).toString(),
      ),
    ],
    envelope: Uint8List.fromList(utf8.encode('test-only-$build')),
  );
  return UpdateAvailable({'tag_name': manifest.tag}, manifest: manifest);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('macOS immediate update coordinator', () {
    late Directory home;
    late HttpClientAdapter previousAdapter;
    late _Adapter adapter;
    late _Core core;
    late _CheckAction action;
    late _Exit exit;
    late _Restart restart;
    late ProviderContainer container;
    late List<String> calls;
    late String prepareCode;
    late String installCode;
    Completer<void>? prepareHold;
    Completer<void>? installHold;
    const channel = MethodChannel('$packageName/mac_updater');

    setUp(() async {
      home = await Directory.systemTemp.createTemp('flash-update-fixture-');
      await useAppPaths(home);
      globalState.packageInfo = PackageInfo(
        appName: 'Flash',
        packageName: packageName,
        version: '0.9.15-mitm.12',
        buildNumber: '2026111901',
      );
      previousAdapter = request.releaseDio.httpClientAdapter;
      adapter = _Adapter(utf8.encode('test archive'));
      request.releaseDio.httpClientAdapter = adapter;
      calls = [];
      prepareCode = 'ok';
      installCode = 'ok';
      prepareHold = null;
      installHold = null;
      core = _Core();
      when(() => core.stop()).thenAnswer((_) async {
        calls.add('stop');
        return const CoreLifecycleResult(
          revision: 1,
          outcome: CoreLifecycleOutcome.applied,
        );
      });
      action = _CheckAction()..answer = candidate();
      exit = _Exit();
      restart = _Restart();
      container = ProviderContainer(
        overrides: [
          commonActionProvider.overrideWith(() => action),
          systemActionProvider.overrideWith(() => exit),
          coreActionProvider.overrideWith(() => restart),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        ],
      );
      globalState.container = container;
      container.listen(availableUpdateStateProvider, (_, _) {});
      container.listen(updateDownloadStateProvider, (_, _) {});
      container.listen(updateInstallBusyProvider, (_, _) {});
      container.read(commonActionProvider.notifier);
      container.read(availableUpdateStateProvider.notifier).value =
          action.answer as UpdateAvailable;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'identity') {
              return {'version': '0.9.15-mitm.12', 'build': 2026111901};
            }
            if (call.method == 'invalidate') return {'code': 'ok'};
            calls.add(call.method);
            if (call.method == 'prepare') {
              await prepareHold?.future;
              return {
                'code': prepareCode,
                if (prepareCode == 'ok') 'staged': '${home.path}/staged',
                if (prepareCode == 'ok') 'ticket': 'fixture-ticket',
              };
            }
            if (call.method == 'install') await installHold?.future;
            return {'code': call.method == 'install' ? installCode : 'ok'};
          });
    });
    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      request.releaseDio.httpClientAdapter = previousAdapter;
      container.dispose();
      await home.delete(recursive: true);
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(
            locale: Locale('zh'),
            child: HostScaffold(body: SizedBox.shrink()),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> settleUntil(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(done(), isTrue);
    }

    Future<void> closeFailure(WidgetTester tester) async {
      await settleUntil(
        tester,
        () => find.byType(TextButton).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
    }

    Future<void> stageForLater(WidgetTester tester) async {
      final offered = action.checkUpdateResultHandle(
        action.answer,
        isUser: true,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, '查看更新'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(currentAppLocalizations.macUpdateDownloadAndInstall),
      );
      await tester.pumpAndSettle();
      await offered;
      await settleUntil(
        tester,
        () => container.read(updateDownloadStateProvider) is UpdateReady,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(currentAppLocalizations.macUpdateLater));
      await tester.pumpAndSettle();
      expect(container.read(updateInstallBusyProvider), isFalse);
    }

    testWidgets('notice shows exact installed and signed target metadata', (
      tester,
    ) async {
      await pump(tester);
      final shown = action.checkUpdateResultHandle(action.answer, isUser: true);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('当前版本：0.9.15-mitm.12+2026111901'),
        findsOneWidget,
      );
      expect(find.textContaining('可更新版本：1.0.0+2026111902'), findsOneWidget);
      expect(find.text('查看更新'), findsOneWidget);
      expect(calls, isEmpty);
      await tester.tap(find.widgetWithText(TextButton, '取消'));
      await tester.pumpAndSettle();
      await shown;
    });

    testWidgets(
      'whole immediate action rechecks, verifies, installs then exits once',
      (tester) async {
        await pump(tester);
        final expected = action.answer as UpdateAvailable;
        action.checkHold = Completer<void>();
        final operation = action.updateFromTray(expected);
        await action.updateFromTray(expected);
        expect(action.checks, 1);
        expect(container.read(updateInstallBusyProvider), isTrue);
        action.checkHold!.complete();
        await settleUntil(tester, () => exit.exits == 1);
        await operation;
        expect(calls, ['prepare', 'stop', 'install', 'relaunch']);
        expect(
          adapter.requested.single.path,
          endsWith('/Flash-1.0.0-macos-arm64.zip'),
        );
        expect(container.read(updateInstallBusyProvider), isFalse);
        expect(container.read(updateDownloadStateProvider), isNull);
        await tester.pump(const Duration(seconds: 10));
      },
    );

    for (final failure in ['hash', 'prepare', 'install', 'stop']) {
      testWidgets(
        '$failure failure never exits and releases duplicate-tap guard',
        (tester) async {
          await pump(tester);
          if (failure == 'hash') {
            request.releaseDio.httpClientAdapter = _Adapter(
              utf8.encode('tampered'),
            );
          }
          if (failure == 'prepare') prepareCode = 'rejected';
          if (failure == 'install') installCode = 'rolledBack';
          if (failure == 'stop') {
            when(() => core.stop()).thenThrow(StateError('stop failed'));
          }
          final operation = action.updateFromTray(
            action.answer as UpdateAvailable,
          );
          await closeFailure(tester);
          await settleUntil(
            tester,
            () => !container.read(updateInstallBusyProvider),
          );
          await operation;
          expect(exit.exits, 0);
          expect(calls, isNot(contains('relaunch')));
          if (failure == 'hash' || failure == 'prepare') {
            expect(calls, isNot(contains('stop')));
            expect(calls, isNot(contains('install')));
          }
          expect(container.read(updateInstallBusyProvider), isFalse);
          await tester.pump(const Duration(seconds: 10));
        },
      );
    }

    for (final point in ['prepare', 'stop']) {
      testWidgets(
        'closing beta switch during held $point revokes continuation',
        (tester) async {
          await pump(tester);
          final beta = candidate(channel: ReleaseChannel.beta);
          action.answer = beta;
          container
              .read(appSettingProvider.notifier)
              .update((s) => s.copyWith(receiveBetaUpdates: true));
          container.read(availableUpdateStateProvider.notifier).value = beta;
          final hold = Completer<void>();
          if (point == 'prepare') {
            prepareHold = hold;
          } else {
            when(() => core.stop()).thenAnswer((_) async {
              calls.add('stop');
              await hold.future;
              return const CoreLifecycleResult(
                revision: 1,
                outcome: CoreLifecycleOutcome.applied,
              );
            });
          }
          final operation = action.updateFromTray(beta);
          await settleUntil(tester, () => calls.contains(point));
          container
              .read(appSettingProvider.notifier)
              .update((s) => s.copyWith(receiveBetaUpdates: false));
          expect(container.read(availableUpdateStateProvider), isNull);
          expect(container.read(updateDownloadStateProvider), isNull);
          hold.complete();
          await settleUntil(
            tester,
            () => !container.read(updateInstallBusyProvider),
          );
          await operation;
          await tester.pumpAndSettle();
          expect(calls, isNot(contains('install')));
          expect(calls, isNot(contains('relaunch')));
          expect(exit.exits, 0);
          if (point == 'stop') expect(restart.restarts, 1);
        },
      );
    }

    testWidgets('cancel during prepare does not stop or install', (
      tester,
    ) async {
      await pump(tester);
      prepareHold = Completer<void>();
      final operation = action.updateFromTray(action.answer as UpdateAvailable);
      await settleUntil(tester, () => calls.contains('prepare'));
      action.cancelUpdateDownload();
      prepareHold!.complete();
      await settleUntil(
        tester,
        () => !container.read(updateInstallBusyProvider),
      );
      await operation;
      expect(calls, isNot(contains('stop')));
      expect(calls, isNot(contains('install')));
      expect(exit.exits, 0);
      expect(container.read(updateDownloadStateProvider), isNull);
      await tester.pump(const Duration(seconds: 10));
    });

    for (final fromTray in [false, true]) {
      testWidgets(
        'discard during held Core stop cancels install (tray: $fromTray)',
        (tester) async {
          await pump(tester);
          final stop = Completer<CoreLifecycleResult>();
          when(() => core.stop()).thenAnswer((_) {
            calls.add('stop');
            return stop.future;
          });
          if (!fromTray) await stageForLater(tester);
          final operation = fromTray
              ? action.updateFromTray(action.answer as UpdateAvailable)
              : action.installUpdate();
          await settleUntil(tester, () => calls.contains('stop'));
          expect(container.read(updateInstallCommittedProvider), isFalse);
          await tester.runAsync(action.discardUpdate);
          expect(container.read(updateDownloadStateProvider), isNull);
          stop.complete(
            const CoreLifecycleResult(
              revision: 1,
              outcome: CoreLifecycleOutcome.applied,
            ),
          );
          await settleUntil(
            tester,
            () => !container.read(updateInstallBusyProvider),
          );
          await operation;
          expect(calls, isNot(contains('install')));
          expect(calls, isNot(contains('relaunch')));
          expect(exit.exits, 0);
          expect(restart.restarts, 1);
          await tester.pump(const Duration(seconds: 10));
        },
      );
    }

    testWidgets(
      'non-tray install publishes busy and rejects discard after commit',
      (tester) async {
        await pump(tester);
        await stageForLater(tester);
        installHold = Completer<void>();
        final ready =
            container.read(updateDownloadStateProvider) as UpdateReady;
        final operation = action.installUpdate();
        await settleUntil(tester, () => calls.contains('install'));
        expect(container.read(updateInstallBusyProvider), isTrue);
        expect(container.read(updateInstallCommittedProvider), isTrue);
        await action.discardUpdate();
        expect(container.read(updateDownloadStateProvider), same(ready));
        expect(File(ready.path).existsSync(), isTrue);
        await action.installUpdate();
        await action.updateFromTray(action.answer as UpdateAvailable);
        expect(calls.where((call) => call == 'install'), hasLength(1));
        expect(action.checks, 0);
        installHold!.complete();
        await settleUntil(tester, () => exit.exits == 1);
        await operation;
        expect(container.read(updateInstallBusyProvider), isFalse);
        expect(container.read(updateInstallCommittedProvider), isFalse);
        await tester.pump(const Duration(seconds: 10));
      },
    );

    testWidgets('fetch failure retains known target and never claims latest', (
      tester,
    ) async {
      await pump(tester);
      final real = ProviderContainer();
      addTearDown(real.dispose);
      real.listen(availableUpdateStateProvider, (_, _) {});
      final known = candidate();
      real.read(availableUpdateStateProvider.notifier).value = known;
      request.releaseDio.httpClientAdapter = _Adapter(
        utf8.encode('not a signed manifest'),
      );
      final result = await tester.runAsync(
        real.read(commonActionProvider.notifier).checkForAppUpdate,
      );
      expect(result, isA<UpdateCheckFailed>());
      expect(real.read(availableUpdateStateProvider), same(known));
      expect(real.read(lastUpdateCheckStateProvider), isA<UpdateCheckFailed>());
      expect(exit.exits, 0);
      expect(calls, isEmpty);
    });

    testWidgets('successful no-update recheck never starts download or exits', (
      tester,
    ) async {
      await pump(tester);
      final expected = action.answer as UpdateAvailable;
      action.answer = const UpdateUpToDate();
      await action.updateFromTray(expected);
      await tester.pumpAndSettle();
      expect(container.read(availableUpdateStateProvider), isNull);
      expect(calls, isEmpty);
      expect(exit.exits, 0);
      expect(container.read(updateInstallBusyProvider), isFalse);
      await tester.tap(find.byType(TextButton).first);
      await tester.pumpAndSettle();
    });

    testWidgets('stale row and changed signed candidate do not install', (
      tester,
    ) async {
      await pump(tester);
      await action.updateFromTray(candidate());
      expect(action.checks, 0);
      final expected = action.answer as UpdateAvailable;
      action.answer = candidate(build: 2026111903);
      await action.updateFromTray(expected);
      expect(action.checks, 1);
      expect(calls, isEmpty);
      expect(exit.exits, 0);
      expect(
        container.read(availableUpdateStateProvider)!.versionLabel,
        '1.0.0+2026111903',
      );
    });
  }, skip: !Platform.isMacOS);
}
