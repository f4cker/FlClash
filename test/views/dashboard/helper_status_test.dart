// The macOS helper inside the live status deck: one card while it is not
// ready, its actions through the shared dispatch, and the feature gate that
// opens the deck on it.
import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/core/desktop/model.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:fl_clash/views/dashboard/widgets/live_status.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/desktop/macos_helper_install_test.dart'
    show InstallNative, makeMaintenance;
import '../../helpers/test_app.dart';

class _SessionNative extends InstallNative {
  final receive = Completer<Map<Object?, Object?>>();

  @override
  Future<Map<Object?, Object?>> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) => switch (method) {
    'start' => Future.value({'code': 'ok', 'protocol': 1, 'pid': 42}),
    'receive' => receive.future,
    'stop' => Future.value({'code': 'ok', 'exitConfirmed': true}),
    _ => super.invoke(method, arguments),
  };
}

HelperLiveStatus _helperCard(MacHelperCardKind kind) =>
    HelperLiveStatus(MacHelperCardView(kind: kind, title: kind.name));

void main() {
  late ProviderContainer container;
  late InstallNative native;
  late MacHelperMaintenance flow;

  setUp(() {
    container = ProviderContainer();
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1200, 800);
    container.listen(patchClashConfigProvider, (_, _) {});
    container.listen(networkSettingProvider, (_, _) {});
    globalState.packageInfo = PackageInfo(
      appName: 'Flash',
      packageName: 'com.layoute.flash',
      version: '1.0.0-beta.2',
      buildNumber: '2026111904',
    );
    native = InstallNative();
    flow = makeMaintenance(native);
  });

  tearDown(() {
    flow.dispose();
    container.dispose();
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> pumpStatus(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double scale = 1,
    Size size = const Size(1200, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          locale: locale,
          child: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              title: 'Dashboard',
              actions: [
                LiveStatusButton(separateCore: true, maintenance: flow),
              ],
              body: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Finder entry() => find.byType(LiveStatusButton);

  Future<void> openDeck(WidgetTester tester) async {
    await tester.tap(
      find.descendant(of: entry(), matching: find.byType(Tooltip)).first,
    );
    await settle(tester);
  }

  Finder front(String text) => find.text(text).hitTestable();

  Finder label(String text) => find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == text,
  );

  Future<void> settleReady(WidgetTester tester) async {
    native.state = 'enabled';
    await flow.recheck();
    await settle(tester);
  }

  group('ordering and count', () {
    test('initial order: helper, core fault, update, resources, MITM', () {
      final statuses = composeLiveStatuses(
        core: CoreStatus.disconnected,
        separateCore: true,
        download: const UpdateReady('v1', ''),
        resources: const [(name: 'GEOIP', isProfile: false)],
        awaitingConsent: const ['Ads'],
        helper: _helperCard(MacHelperCardKind.notReady),
      );
      expect(
        [for (final status in statuses) status.runtimeType],
        [
          HelperLiveStatus,
          CoreLiveStatus,
          UpdateStatus,
          ResourcesStatus,
          MitmConsentStatus,
        ],
      );
      expect(statuses.where(countsInLiveStatus), hasLength(5));
    });

    test('an update downloading follows the helper and the core fault', () {
      final statuses = composeLiveStatuses(
        core: CoreStatus.connecting,
        separateCore: true,
        download: const UpdateDownloading('v1', received: 41, total: 100),
        helper: _helperCard(MacHelperCardKind.approval),
      );
      expect(
        [for (final status in statuses) status.runtimeType],
        [HelperLiveStatus, CoreLiveStatus, UpdateStatus],
      );
    });

    test('a running core comes last and is not counted', () {
      final statuses = composeLiveStatuses(
        core: CoreStatus.connected,
        separateCore: true,
        awaitingConsent: const ['Ads'],
      );
      expect(statuses.last, isA<CoreLiveStatus>());
      expect(statuses.where(countsInLiveStatus), hasLength(1));
    });

    test('a core stopped only for the helper is not a card of its own', () {
      final statuses = composeLiveStatuses(
        core: CoreStatus.disconnected,
        separateCore: true,
        helper: _helperCard(MacHelperCardKind.approval),
        coreWaitsForHelper: true,
      );
      expect(statuses, hasLength(1));
      expect(statuses.single, isA<HelperLiveStatus>());
    });

    test('update, resources and MITM cards are never hidden', () {
      final statuses = composeLiveStatuses(
        core: CoreStatus.disconnected,
        separateCore: true,
        download: const UpdateDownloading('v1', received: 1, total: 2),
        resources: const [
          (name: 'a', isProfile: true),
          (name: 'b', isProfile: false),
        ],
        awaitingConsent: const ['Ads', 'Scripts'],
        helper: _helperCard(MacHelperCardKind.starting),
        coreWaitsForHelper: true,
        coreUnknown: true,
      );
      expect(
        [for (final status in statuses) status.runtimeType],
        [HelperLiveStatus, UpdateStatus, ResourcesStatus, MitmConsentStatus],
      );
      // Many resources are one card; its rows count inside it.
      expect(statuses.whereType<ResourcesStatus>().single.items, hasLength(2));
    });

    test('ready, unchecked and a routine re-check add no card', () async {
      final l = lookupAppLocalizations(const Locale('en'));
      // Not checked yet.
      expect(macHelperLiveState(l, flow, stoppedForHelper: false).card, isNull);
      native.state = 'enabled';
      await flow.check();
      expect(macHelperLiveState(l, flow, stoppedForHelper: false).card, isNull);
      // A routine re-check of a ready helper does not flicker into a card.
      native.pendingStatus = Completer();
      final checking = flow.check();
      expect(flow.routineCheck, isTrue);
      final state = macHelperLiveState(l, flow, stoppedForHelper: false);
      expect(state.card, isNull);
      expect(state.coreWaitsForHelper, isFalse);
      native.pendingStatus!.complete({'code': 'enabled'});
      await checking;
    });

    test(
      'any other state is one card; the core gives way only on the marker',
      () async {
        final l = lookupAppLocalizations(const Locale('en'));
        native.state = 'notRegistered';
        await flow.check();
        // No helper-linked marker (no reason, or a reason of its own): the
        // core keeps its card.
        final unmarked = macHelperLiveState(l, flow, stoppedForHelper: false);
        expect(unmarked.card, isNotNull);
        expect(unmarked.coreWaitsForHelper, isFalse);
        final marked = macHelperLiveState(l, flow, stoppedForHelper: true);
        expect(marked.card, isNotNull);
        expect(marked.coreWaitsForHelper, isTrue);
      },
    );

    test(
      'the marker alone does not hide the core once the helper is ready',
      () async {
        final l = lookupAppLocalizations(const Locale('en'));
        native.state = 'enabled';
        await flow.check();
        final state = macHelperLiveState(l, flow, stoppedForHelper: true);
        expect(state.card, isNull);
        expect(state.coreWaitsForHelper, isFalse);
      },
    );
  });

  group('actions follow the card model', () {
    final l = lookupAppLocalizations(const Locale('en'));

    // Native code → (primary, secondary) on the card.
    const expected = <String, (MacHelperCardAction?, MacHelperCardAction?)>{
      // Nothing to switch on yet: no steps, details only if any.
      'notRegistered': (
        MacHelperCardAction.register,
        MacHelperCardAction.viewDetails,
      ),
      'requiresApproval': (
        MacHelperCardAction.openSettings,
        MacHelperCardAction.viewSteps,
      ),
      'migrationRequired': (MacHelperCardAction.migrate, null),
      'migrationIncomplete': (
        MacHelperCardAction.retry,
        MacHelperCardAction.viewDetails,
      ),
      'helperNotReady': (
        MacHelperCardAction.recover,
        MacHelperCardAction.viewDetails,
      ),
      'staleCoreUnconfirmed': (
        MacHelperCardAction.recover,
        MacHelperCardAction.viewDetails,
      ),
      // Unknown never reads as ready: a neutral re-check.
      'garbage': (MacHelperCardAction.recheck, MacHelperCardAction.viewDetails),
      'signingRequired': (null, MacHelperCardAction.viewDetails),
      'notFound': (null, MacHelperCardAction.viewDetails),
      'incompatible': (null, MacHelperCardAction.viewDetails),
      'moveRequired': (null, null),
      'unsupported': (null, null),
      'launcherCheckFailed': (null, MacHelperCardAction.viewDetails),
      'launcherDowngrade': (null, MacHelperCardAction.viewDetails),
      'launcherFailed': (null, MacHelperCardAction.viewDetails),
    };
    for (final MapEntry(key: code, value: (primary, secondary))
        in expected.entries) {
      test(code, () async {
        native.state = code;
        await flow.check();
        final view = macHelperCardView(l, flow);
        expect(view.primary, primary, reason: '${view.kind}');
        expect(view.secondary, secondary, reason: '${view.kind}');
      });
    }

    test('disabled by user says so and opens System Settings', () async {
      native.statusAnswer = {
        'code': 'requiresApproval',
        'previouslyEnabled': true,
      };
      await flow.check();
      final view = macHelperCardView(l, flow);
      expect(view.kind, MacHelperCardKind.disabledByUser);
      // Its own title, never the approval one.
      expect(view.title, l.macHelperDisabledTitle);
      expect(view.title, isNot(l.macHelperApprovalTitle));
      expect(view.detail, l.macHelperDisabledByUserDetail);
      expect(view.primary, MacHelperCardAction.openSettings);
      expect(view.secondary, MacHelperCardAction.viewSteps);
    });

    test('awaiting approval never says the permission is off', () async {
      native.state = 'requiresApproval';
      await flow.check();
      final zh = lookupAppLocalizations(const Locale('zh'));
      final view = macHelperCardView(zh, flow);
      expect(view.detail, isNot(contains('已关闭')));
      // No recovery happened: the steps only ask to turn the switch on.
      expect(view.steps.join(), isNot(contains('关掉再打开')));
      expect(view.steps.last, zh.macHelperApprovalStep3);
    });

    test('every card kind has a tone, and none of them is ready', () {
      for (final kind in MacHelperCardKind.values) {
        final (_, tone) = macHelperBarKindOf(kind);
        expect(
          tone == MacHelperBarTone.ready,
          kind == MacHelperCardKind.ready,
          reason: '$kind',
        );
      }
    });

    test('an unchecked helper reads as checking, with nothing to run', () {
      final view = macHelperCardView(l, flow);
      expect(view.progress, l.macHelperChecking);
      expect(view.primary, isNull);
    });

    test('register and open settings register, then open Settings', () async {
      native.state = 'notRegistered';
      await flow.check();
      runMacHelperAction(flow, MacHelperCardAction.register);
      await pumpEventQueue();
      expect(native.calls, ['status', 'enable', 'openApprovalSettings']);
    });

    test('retry resumes the update, never the generic recovery', () async {
      var recoveries = 0;
      flow.dispose();
      flow = MacHelperMaintenance(
        MacHelperClient(native: native, safeMode: () => false),
        stop: () async => const CoreLifecycleResult(
          revision: 1,
          outcome: CoreLifecycleOutcome.applied,
        ),
        recover: () async {
          recoveries++;
          return MacHelperState.enabled;
        },
        startPoll: const Duration(hours: 1),
        startTimeout: const Duration(hours: 1),
      );
      native.state = 'migrationIncomplete';
      await flow.check();
      runMacHelperAction(flow, MacHelperCardAction.retry);
      await pumpEventQueue();
      expect(native.calls, ['status', 'migrate']);
      expect(recoveries, 0);
      // "Recover" and "Repair" (service not found) run the recovery.
      native.state = 'helperNotReady';
      await flow.check();
      var before = recoveries;
      runMacHelperAction(flow, MacHelperCardAction.recover);
      await pumpEventQueue();
      expect(recoveries, before + 1);
      native.state = 'serviceNotFound';
      await flow.check();
      before = recoveries;
      runMacHelperAction(flow, MacHelperCardAction.repairRegistration);
      await pumpEventQueue();
      expect(recoveries, before + 1);
    });

    test('nothing runs twice while an operation is in flight', () async {
      native.pending = Completer();
      await flow.check();
      runMacHelperAction(flow, MacHelperCardAction.migrate);
      runMacHelperAction(flow, MacHelperCardAction.migrate);
      runMacHelperAction(flow, MacHelperCardAction.recheck);
      await pumpEventQueue();
      expect(native.calls, ['status', 'migrate']);
      native.pending!.complete({'code': 'enabled'});
      await pumpEventQueue();
    });

    test('the view actions ask the helper nothing', () async {
      native.state = 'signingRequired';
      await flow.check();
      runMacHelperAction(flow, MacHelperCardAction.viewDetails);
      runMacHelperAction(flow, MacHelperCardAction.viewSteps);
      await pumpEventQueue();
      expect(native.calls, ['status']);
    });
  });

  testWidgets('needs registration alone: one card, count 1, steps in place', (
    tester,
  ) async {
    native.state = 'notRegistered';
    await flow.check();
    // The helper kept the core from starting (as at launch).
    container.read(coreStoppedForHelperProvider.notifier).value = true;
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(label('${l.macHelperRegisterTitle}, 1 item'), findsOneWidget);
    // The core stopped by the helper (marker set) is not a second card.
    expect(container.read(coreStatusProvider), CoreStatus.disconnected);
    await openDeck(tester);
    expect(front(l.macHelperRegisterTitle), findsOneWidget);
    expect(front(l.macHelperRegisterDetail), findsOneWidget);
    expect(front(l.coreStopped), findsNothing);
    expect(front(l.macHelperRegisterAction), findsOneWidget);
    // Nothing to switch on before registering: no steps.
    expect(front(l.macHelperViewSteps), findsNothing);
    await tester.tap(front(l.macHelperRegisterAction));
    await settle(tester);
    expect(native.calls, ['status', 'enable', 'openApprovalSettings']);
    // Back from System Settings: the status is read again.
    native.state = 'requiresApproval';
    flow.resumed();
    await settle(tester);
    expect(native.calls.last, 'status');
    expect(front(l.macHelperApprovalTitle), findsOneWidget);
    // View steps: the switch to turn on, in the deck's details, with back.
    await tester.tap(front(l.macHelperViewSteps));
    await settle(tester);
    expect(front(l.back), findsNothing); // a tooltip, not text
    for (final (index, step) in [
      l.macHelperApprovalStep1,
      l.macHelperApprovalStep2,
      l.macHelperApprovalStep3,
    ].indexed) {
      expect(front('${index + 1}. $step'), findsOneWidget);
    }
    // Never the "turn it off and on again" step.
    expect(find.textContaining('off and on'), findsNothing);
    expect(find.textContaining('turn it back on'), findsNothing);
    expect(front(l.macHelperViewSteps), findsNothing);
    // The primary action stays under the details.
    expect(front(l.macHelperOpenSettings), findsOneWidget);
    await tester.tap(find.byTooltip(l.back));
    await settle(tester);
    expect(front(l.macHelperViewSteps), findsOneWidget);
    expect(front(l.macHelperApprovalTitle), findsOneWidget);
    // Approved: the card goes, and with nothing left the deck closes.
    await settleReady(tester);
    await settle(tester);
    expect(find.text(l.macHelperApprovalTitle), findsNothing);
    expect(front(l.coreStopped), findsOneWidget);
  });

  testWidgets('helper not ready and a core stopped with no reason: two cards', (
    tester,
  ) async {
    native.state = 'notRegistered';
    await flow.check();
    // Stopped, but nothing says the helper caused it.
    expect(container.read(coreStatusProvider), CoreStatus.disconnected);
    expect(container.read(coreStopReasonProvider), isNull);
    expect(container.read(coreStoppedForHelperProvider), isFalse);
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(label('${l.macHelperRegisterTitle}, 2 items'), findsOneWidget);
    await openDeck(tester);
    expect(front(l.macHelperRegisterTitle), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(front(l.coreStopped), findsOneWidget);
  });

  testWidgets(
    'helper not ready and a helper-linked stop: the helper card only',
    (tester) async {
      native.state = 'notRegistered';
      await flow.check();
      container.read(coreStoppedForHelperProvider.notifier).value = true;
      await pumpStatus(tester);
      final l = currentAppLocalizations;
      expect(label('${l.macHelperRegisterTitle}, 1 item'), findsOneWidget);
      await openDeck(tester);
      expect(front(l.macHelperRegisterTitle), findsOneWidget);
      expect(find.text(l.coreStopped), findsNothing);
      // A start clears the marker; a later stop with no reason shows again.
      container.read(coreStatusProvider.notifier).value = CoreStatus.connecting;
      container.read(coreStatusProvider.notifier).value =
          CoreStatus.disconnected;
      expect(container.read(coreStoppedForHelperProvider), isFalse);
    },
  );

  testWidgets('a failed helper check is a visible card, never silence', (
    tester,
  ) async {
    native.pendingStatus = Completer()
      ..completeError(Exception('channel closed'));
    final state = await flow.check();
    expect(state, MacHelperState.unavailable);
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(label('${l.macHelperUnavailableTitle}, 2 items'), findsOneWidget);
    await openDeck(tester);
    expect(front(l.macHelperUnavailableTitle), findsOneWidget);
    expect(front(l.macHelperStatusUnreadable), findsOneWidget);
    expect(front(l.macHelperCheckAgain), findsOneWidget);
  });

  testWidgets('the helper and an independent core fault: two cards', (
    tester,
  ) async {
    native.state = 'notRegistered';
    await flow.check();
    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    container.read(coreStopReasonProvider.notifier).value = 'Core crashed';
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(label('${l.macHelperRegisterTitle}, 2 items'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await openDeck(tester);
    expect(front(l.macHelperRegisterTitle), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(front('Core crashed'), findsOneWidget);
  });

  testWidgets('helper, resources, download 41% and MITM: the % wins', (
    tester,
  ) async {
    native.state = 'migrationIncomplete';
    await flow.check();
    // The helper kept the core from starting (as at launch).
    container.read(coreStoppedForHelperProvider.notifier).value = true;
    container.read(updateDownloadStateProvider.notifier).value =
        const UpdateDownloading('v1.0.0', received: 41, total: 100);
    container
        .read(updatingKeysProvider.notifier)
        .start(GeoResource.GEOIP.updatingKey);
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(
      label('${l.macHelperFailedTitle}, 3 items, Update download 41%'),
      findsOneWidget,
    );
    expect(find.text('41%'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('a state change updates the same card in place', (tester) async {
    native.state = 'notRegistered';
    await flow.check();
    container.read(updateDownloadStateProvider.notifier).value =
        const UpdateReady('v9', '');
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    await openDeck(tester);
    expect(front(l.macHelperRegisterTitle), findsOneWidget);
    native.state = 'signingRequired';
    await flow.recheck();
    await settle(tester);
    // Still the front card, now the security check failure.
    expect(front(l.macHelperSignatureTitle), findsOneWidget);
    expect(find.text(l.macHelperRegisterTitle), findsNothing);
  });

  testWidgets('the open deck keeps its card while others change', (
    tester,
  ) async {
    native.state = 'notRegistered';
    await flow.check();
    // The helper kept the core from starting (as at launch).
    container.read(coreStoppedForHelperProvider.notifier).value = true;
    container.read(updateDownloadStateProvider.notifier).value =
        const UpdateDownloading('v9', received: 10, total: 100);
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    await openDeck(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    expect(front(l.downloadingUpdate), findsOneWidget);
    container.read(updateDownloadStateProvider.notifier).value =
        const UpdateDownloading('v9', received: 60, total: 100);
    native.state = 'requiresApproval';
    await flow.recheck();
    await settle(tester);
    expect(front(l.downloadingUpdate), findsOneWidget);
  });

  testWidgets('signature failure: details only, never a bypass', (
    tester,
  ) async {
    native.state = 'signingRequired';
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    await openDeck(tester);
    expect(front(l.macHelperSignatureTitle), findsOneWidget);
    expect(find.byType(FilledButton).hitTestable(), findsNothing);
    await tester.tap(front(l.macHelperViewDetails));
    await settle(tester);
    expect(find.textContaining('signingRequired'), findsOneWidget);
    expect(find.text(l.copy), findsOneWidget);
    expect(native.calls, ['status']);
  });

  testWidgets('migration: busy text replaces the button, no second request', (
    tester,
  ) async {
    native.pending = Completer();
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    final saved = container.read(patchClashConfigProvider);
    await openDeck(tester);
    await tester.tap(front(l.macHelperMigrationAction));
    await tester.pump();
    expect(flow.busy, isTrue);
    expect(front(l.macHelperUpdating), findsOneWidget);
    expect(find.text(l.macHelperMigrationAction), findsNothing);
    // Closing the deck does not cancel the operation.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(flow.busy, isTrue);
    native.pending!.complete({'code': 'enabled'});
    await settle(tester);
    expect(flow.state, MacHelperState.enabled);
    expect(native.calls.where((call) => call == 'migrate'), hasLength(1));
    // Ready never starts the Core nor shows a success dialog.
    expect(container.read(isStartProvider), isFalse);
    expect(container.read(patchClashConfigProvider), saved);
    expect(find.byType(MacHelperDialog), findsNothing);
  });

  testWidgets('feature gate opens the deck on the helper card', (tester) async {
    container.read(updateDownloadStateProvider.notifier).value =
        const UpdateReady('v9', '');
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    var closed = false;
    unawaited(
      showMacHelperFlow(
        maintenance: flow,
        requiredByFeature: true,
      ).whenComplete(() => closed = true),
    );
    await settle(tester);
    expect(find.byType(MacHelperDialog), findsNothing);
    expect(front(l.macHelperMigrationTitle), findsOneWidget);
    expect(find.text(l.macHelperRequiredTitle), findsOneWidget);
    // A second request while it is open joins the same deck.
    unawaited(showMacHelperFlow(maintenance: flow, requiredByFeature: true));
    await settle(tester);
    expect(front(l.macHelperMigrationTitle), findsOneWidget);
    expect(closed, isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(closed, isTrue);
    expect(native.calls, ['status']);
  });

  testWidgets('feature gate falls back to the dialog off the dashboard', (
    tester,
  ) async {
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    unawaited(
      Navigator.of(tester.element(entry())).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const SizedBox.expand(),
        ),
      ),
    );
    await settle(tester);
    unawaited(
      showMacHelperFlow(
        context: tester.element(find.byType(SizedBox).last),
        maintenance: flow,
        requiredByFeature: true,
      ),
    );
    await settle(tester);
    expect(find.byType(MacHelperDialog), findsOneWidget);
    expect(find.text(l.macHelperRequiredTitle), findsOneWidget);
    await tester.tap(find.text(l.cancel));
    await settle(tester);
    expect(find.byType(MacHelperDialog), findsNothing);
    expect(native.calls, ['status']);
  });

  testWidgets('a retained Core session is never called stopped', (
    tester,
  ) async {
    final sessionNative = _SessionNative()..state = 'enabled';
    flow.dispose();
    flow = makeMaintenance(sessionNative);
    const session = '0123456789abcdef0123456789abcdef';
    await flow.client.start(session);
    sessionNative.state = 'migrationRequired';
    await flow.check();
    expect(flow.client.hasCoreSession, isTrue);
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(label('${l.macHelperMigrationTitle}, 1 item'), findsOneWidget);
    expect(await flow.client.stop(session), isTrue);
    sessionNative.receive.complete({'code': 'unavailable'});
    await settle(tester);
  });

  testWidgets('safe mode keeps the core status without a helper card', (
    tester,
  ) async {
    await flow.check();
    container.dispose();
    container = ProviderContainer(
      overrides: [safeModeProvider.overrideWithValue(true)],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1200, 800);
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(label('${l.coreStopped}, 1 item'), findsOneWidget);
    expect(native.calls, ['status']);
  });

  for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
    testWidgets('narrow window and large text reach every action in $locale', (
      tester,
    ) async {
      native.state = 'migrationIncomplete';
      native.migrateAnswer = {
        'code': 'migrationFailed',
        'step': 'removeOld',
        'detail': 'launchctl bootout: 5',
      };
      await flow.check();
      await flow.migrate(confirmed: true);
      await pumpStatus(
        tester,
        locale: locale,
        scale: 2,
        size: const Size(480, 640),
      );
      final l = currentAppLocalizations;
      await openDeck(tester);
      expect(tester.takeException(), isNull);
      expect(front(l.macHelperTryAgain), findsOneWidget);
      await tester.tap(front(l.macHelperViewDetails));
      await settle(tester);
      expect(find.textContaining('launchctl bootout: 5'), findsOneWidget);
      expect(front(l.macHelperTryAgain), findsOneWidget);
      expect(tester.takeException(), isNull);
      native.migrateAnswer = {'code': 'enabled'};
      await tester.tap(front(l.macHelperTryAgain));
      await settle(tester);
      expect(native.calls.where((call) => call == 'migrate'), hasLength(2));
    });
  }

  test('zh copy matches the reviewed wording', () {
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(zh.macHelperRegisterDetail, '辅助程序尚未登记。点按“登记”继续。');
    expect(zh.macHelperRegisterAction, '登记');
    expect(
      zh.macHelperDisabledByUserDetail,
      'Flash 的后台运行权限已关闭。请在系统设置中允许 Flash 在后台运行。',
    );
    expect(zh.macHelperDisabledTitle, '辅助程序已关闭');
    expect(
      lookupAppLocalizations(const Locale('en')).macHelperDisabledTitle,
      'The helper is turned off',
    );
    expect(zh.macHelperOpenSettings, '打开系统设置');
    expect(zh.macHelperAwaitingApprovalDetail, '请在系统设置中允许 Flash 在后台运行。');
    expect(zh.macHelperApprovalTitle, '等待后台运行授权');
    // Turning the switch off and on again is not a generic step.
    expect(zh.macHelperApprovalStep3, isNot(contains('关掉再打开')));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.macHelperApprovalTitle, 'Waiting for background permission');
    expect(en.liveStatusItems(1), '1 item');
    expect(en.liveStatusItems(3), '3 items');
    expect(en.updatingResourcesCount(1), '1 item updating');
    expect(en.updatingResourcesCount(2), '2 items updating');
    expect(en.liveStatusUpdateDownload('41%'), 'Update download 41%');
    expect(en.updateCurrentVersion('v1'), 'Current version v1');
    expect(en.updateNewVersion('v2'), 'New version v2');
    expect(en.updatingResources, 'Updating');
    expect(
      lookupAppLocalizations(const Locale('fr')).macHelperOpenSettings,
      'Ouvrir Réglages Système',
    );
    expect(zh.macHelperUnavailableTitle, '辅助程序暂不可用');
    expect(zh.macHelperNotReadyTitle, '辅助程序暂未就绪');
    expect(zh.macHelperRequiredTitle, '请先启用辅助程序');
    expect(zh.macHelperFailedTitle, '辅助程序更新未完成');
    expect(zh.liveStatusItems(3), '3 项');
    expect(zh.liveStatusUpdateDownload('41%'), '更新下载 41%');
    expect(zh.updateCurrentVersion('1.0'), '当前版本 1.0');
    expect(zh.updateNewVersion('1.1'), '新版本 1.1');
    for (final text in [
      zh.macHelperApprovalStep3,
      zh.macHelperNotReadyTitle,
      zh.macHelperRegistrationFailedDetail,
      zh.macHelperStaleCoreDetail,
      zh.macHelperStatusUnreadable,
    ]) {
      expect(text, isNot(contains('重启')));
      expect(text, isNot(contains('重新安装')));
    }
  });
}
