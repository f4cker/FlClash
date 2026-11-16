import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:fl_clash/views/dashboard/widgets/live_status.dart';
import 'package:fl_clash/views/dashboard/widgets/mac_helper_status.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    native = InstallNative();
    flow = makeMaintenance(native);
  });

  tearDown(() {
    flow.dispose();
    container.dispose();
  });

  Future<void> pumpStatus(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    double scale = 1,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          locale: locale,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              title: 'Dashboard',
              actions: [
                LiveStatusButton(separateCore: true, maintenance: flow),
              ],
              body: MacHelperStatus(
                maintenance: flow,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  /// Clears the start-up wait timers before the test ends.
  Future<void> settleReady(WidgetTester tester) async {
    native.state = 'enabled';
    await flow.recheck();
    await tester.pumpAndSettle();
  }

  for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
    testWidgets('migration card explains the update in $locale', (
      tester,
    ) async {
      await flow.check();
      await pumpStatus(tester, locale: locale);
      final l = currentAppLocalizations;
      expect(find.text(l.macHelperMigrationTitle), findsOneWidget);
      expect(find.text(l.macHelperMigrationDetail), findsOneWidget);
      expect(find.text(l.macHelperMigrationAction), findsOneWidget);
      expect(find.byType(MacHelperDialog), findsNothing);
      expect(native.calls, ['status']);
      expect(tester.takeException(), isNull);
    });
  }

  test('zh copy matches the reviewed wording', () {
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(zh.macHelperTitle, '辅助程序');
    expect(zh.macHelperOn, '辅助程序已就绪');
    expect(zh.macHelperSignatureTitle, '辅助程序未通过安全检查');
    expect(zh.macHelperRequiredTitle, '请先启用辅助程序');
    expect(zh.macHelperViewSetup, '查看设置');
    expect(zh.macHelperFailedTitle, '辅助程序更新未完成');
    expect(zh.macHelperStartSlowTitle, '辅助程序启动时间较长');
  });

  testWidgets('migration shows progress, then ready, and never starts Core', (
    tester,
  ) async {
    native.pending = Completer();
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    final saved = container.read(patchClashConfigProvider);
    final network = container.read(networkSettingProvider);
    await tester.tap(find.text(l.macHelperMigrationAction));
    await tester.pump();
    expect(flow.busy, isTrue);
    expect(find.text(l.macHelperUpdating), findsOneWidget);
    expect(find.text(l.macHelperMigrationAction), findsNothing);
    expect(find.text(l.macHelperMigrationTitle), findsOneWidget);
    native.pending!.complete({'code': 'enabled'});
    await tester.pumpAndSettle();
    expect(find.text(l.macHelperUpdating), findsNothing);
    expect(find.text(l.macHelperOn), findsOneWidget);
    expect(find.bySemanticsLabel(l.coreStopped), findsOneWidget);
    expect(container.read(coreStatusProvider), CoreStatus.disconnected);
    expect(container.read(isStartProvider), isFalse);
    expect(container.read(patchClashConfigProvider), saved);
    expect(container.read(networkSettingProvider), network);
    expect(native.calls, ['status', 'migrate']);
  });

  testWidgets('cancelled administrator prompt keeps the migration card', (
    tester,
  ) async {
    native.migrateAnswer = {'code': 'authorizationCancelled'};
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    await tester.tap(find.text(l.macHelperMigrationAction));
    await tester.pumpAndSettle();
    expect(find.text(l.macHelperMigrationTitle), findsOneWidget);
    expect(find.text(l.macHelperMigrationAction), findsOneWidget);
    expect(native.calls.where((call) => call == 'migrate'), hasLength(1));
  });

  testWidgets('failed step is named; details are copyable; retry resumes', (
    tester,
  ) async {
    native.migrateAnswer = {
      'code': 'migrationFailed',
      'step': 'removeOld',
      'detail': 'launchctl bootout: 5',
    };
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    await tester.tap(find.text(l.macHelperMigrationAction));
    await tester.pumpAndSettle();
    expect(find.text(l.macHelperFailedTitle), findsOneWidget);
    expect(find.text(l.macHelperFailedRemoveOld), findsOneWidget);
    expect(find.text(l.macHelperTryAgain), findsOneWidget);
    expect(find.textContaining('launchctl bootout: 5'), findsNothing);
    await tester.tap(find.text(l.macHelperViewDetails));
    await tester.pumpAndSettle();
    expect(find.textContaining('launchctl bootout: 5'), findsOneWidget);
    expect(find.text(l.copy), findsOneWidget);
    native.migrateAnswer = {'code': 'enabled'};
    await tester.tap(find.text(l.macHelperTryAgain));
    await tester.pumpAndSettle();
    expect(find.text(l.macHelperOn), findsOneWidget);
    expect(native.calls.where((call) => call == 'migrate'), hasLength(2));
  });

  testWidgets('approval lists readable steps and opens settings', (
    tester,
  ) async {
    native.state = 'notRegistered';
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperApprovalTitle), findsOneWidget);
    for (final (index, step) in [
      l.macHelperApprovalStep1,
      l.macHelperApprovalStep2,
      l.macHelperApprovalStep3,
    ].indexed) {
      expect(find.text('${index + 1}. $step'), findsOneWidget);
      expect(
        find.bySemanticsLabel(l.macHelperStepLabel('${index + 1}', step)),
        findsOneWidget,
      );
    }
    await tester.tap(find.text(l.macHelperOpenSettings));
    await tester.pumpAndSettle();
    expect(native.calls, ['status', 'enable', 'openApprovalSettings']);
    expect(find.text(l.macHelperApprovalTitle), findsOneWidget);
    await tester.tap(find.text(l.macHelperCheckAgain));
    await tester.pumpAndSettle();
    expect(native.calls.last, 'status');
  });

  testWidgets('signature failure offers details only, never a bypass', (
    tester,
  ) async {
    native.state = 'signingRequired';
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperSignatureTitle), findsOneWidget);
    expect(find.text(l.macHelperSignatureDetail), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text(l.macHelperViewDetails), findsOneWidget);
    await tester.tap(find.text(l.macHelperViewDetails));
    await tester.pumpAndSettle();
    expect(find.textContaining('signingRequired'), findsOneWidget);
    expect(native.calls, ['status']);
  });

  testWidgets(
    'approved daemon that does not answer shows starting, no buttons',
    (tester) async {
      native.state = 'unavailable';
      await flow.check();
      await pumpStatus(tester, settle: false);
      final l = currentAppLocalizations;
      expect(find.text(l.macHelperStartingTitle), findsOneWidget);
      expect(find.byType(ActivityIndicator), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      await settleReady(tester);
      expect(find.text(l.macHelperOn), findsOneWidget);
    },
  );

  const titles = {
    'migrationRequired': 'macHelperMigrationTitle',
    'requiresApproval': 'macHelperApprovalTitle',
    'notRegistered': 'macHelperApprovalTitle',
    'signingRequired': 'macHelperSignatureTitle',
    'migrationIncomplete': 'macHelperFailedTitle',
    'notFound': 'macHelperReinstallTitle',
    'incompatible': 'macHelperReinstallTitle',
    'moveRequired': 'macHelperMoveTitle',
    'unsupported': 'macHelperReinstallTitle',
    'garbage': 'macHelperStartSlowTitle',
  };
  for (final MapEntry(key: code, value: key) in titles.entries) {
    testWidgets('$code has a visible reason without side effects', (
      tester,
    ) async {
      native.state = code;
      await flow.check();
      await pumpStatus(tester);
      final l = currentAppLocalizations;
      final title = switch (key) {
        'macHelperMigrationTitle' => l.macHelperMigrationTitle,
        'macHelperApprovalTitle' => l.macHelperApprovalTitle,
        'macHelperSignatureTitle' => l.macHelperSignatureTitle,
        'macHelperFailedTitle' => l.macHelperFailedTitle,
        'macHelperReinstallTitle' => l.macHelperReinstallTitle,
        'macHelperMoveTitle' => l.macHelperMoveTitle,
        _ => l.macHelperStartSlowTitle,
      };
      expect(find.text(title), findsOneWidget);
      expect(find.byType(MacHelperDialog), findsNothing);
      expect(native.calls, ['status']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('disabled by user asks to turn the switch back on', (
    tester,
  ) async {
    native.statusAnswer = {
      'code': 'requiresApproval',
      'previouslyEnabled': true,
    };
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperDisabledTitle), findsOneWidget);
    expect(find.text(l.macHelperDisabledDetail), findsOneWidget);
    expect(find.text(l.macHelperOpenSettings), findsOneWidget);
    expect(find.text(l.macHelperCheckAgain), findsOneWidget);
  });

  testWidgets('feature gate explains first; cancel leaves the feature off', (
    tester,
  ) async {
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    unawaited(
      showMacHelperFlow(
        context: tester.element(find.byType(MacHelperStatus)),
        maintenance: flow,
        requiredByFeature: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l.macHelperRequiredTitle), findsOneWidget);
    expect(find.text(l.macHelperRequiredDetail), findsOneWidget);
    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(MacHelperDialog), findsNothing);
    expect(native.calls, ['status']);
    unawaited(
      showMacHelperFlow(
        context: tester.element(find.byType(MacHelperStatus)),
        maintenance: flow,
        requiredByFeature: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.macHelperViewSetup));
    await tester.pumpAndSettle();
    expect(find.text(l.macHelperRequiredTitle), findsNothing);
    expect(find.text(l.macHelperMigrationTitle), findsNWidgets(2));
    await tester.tap(find.text(l.close));
    await tester.pumpAndSettle();
    expect(native.calls, ['status']);
  });

  testWidgets('ready collapses to one line and shows Core status', (
    tester,
  ) async {
    native.state = 'enabled';
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperOn), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.bySemanticsLabel(l.coreStopped), findsOneWidget);
  });

  testWidgets(
    'disconnected UI with retained session never claims Core is stopped',
    (tester) async {
      final sessionNative = _SessionNative()..state = 'enabled';
      flow.dispose();
      flow = makeMaintenance(sessionNative);
      const session = '0123456789abcdef0123456789abcdef';
      await flow.client.start(session);
      sessionNative.state = 'migrationRequired';
      await flow.check();
      expect(flow.client.hasCoreSession, isTrue);
      expect(container.read(coreStatusProvider), CoreStatus.disconnected);
      await pumpStatus(tester);
      final l = currentAppLocalizations;
      // The Core keeps running; the card only offers the update, which
      // stops the Core first.
      expect(find.text(l.macHelperMigrationTitle), findsOneWidget);
      expect(find.bySemanticsLabel(l.coreStopped), findsNothing);
      expect(await flow.client.stop(session), isTrue);
      sessionNative.receive.complete({'code': 'unavailable'});
      await tester.pumpAndSettle();
    },
  );

  testWidgets('safe mode keeps existing core status without helper card', (
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
    expect(find.bySemanticsLabel(l.coreStopped), findsOneWidget);
    expect(find.text(l.macHelperMigrationAction), findsNothing);
    expect(native.calls, ['status']);
  });

  for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
    testWidgets('large text keeps the card readable in $locale', (
      tester,
    ) async {
      native.state = 'notRegistered';
      await flow.check();
      await pumpStatus(tester, scale: 2, locale: locale);
      final l = currentAppLocalizations;
      expect(find.text(l.macHelperApprovalTitle), findsOneWidget);
      expect(find.text(l.macHelperOpenSettings), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
