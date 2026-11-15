import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:fl_clash/views/dashboard/widgets/core_status_button.dart';
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
              actions: [CoreStatusButton(maintenance: flow)],
              body: MacHelperStatus(
                maintenance: flow,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
    testWidgets('update reason survives open and decline in $locale', (
      tester,
    ) async {
      native.state = 'updateRequired';
      await flow.check();
      await pumpStatus(tester, locale: locale);
      final l = currentAppLocalizations;
      expect(find.text(l.macHelperStartupUpdate), findsOneWidget);
      expect(find.text(l.macHelperUpdateAction), findsOneWidget);
      expect(find.byType(ActivityIndicator), findsNothing);
      expect(find.byType(MacHelperDialog), findsNothing);
      expect(native.calls, ['status']);
      await tester.tap(find.text(l.macHelperUpdateAction));
      await tester.pumpAndSettle();
      expect(find.text(l.macHelperUpdateTitle), findsOneWidget);
      expect(native.calls, ['status']);
      await tester.tap(find.text(l.macHelperNotNowUpdate));
      await tester.pumpAndSettle();
      expect(find.text(l.macHelperStartupUpdate), findsOneWidget);
      expect(find.text(l.macHelperUpdateAction), findsOneWidget);
      expect(native.calls, ['status']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('install requires dialog consent and ready never starts Core', (
    tester,
  ) async {
    native.pending = Completer();
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    final saved = container.read(patchClashConfigProvider);
    final network = container.read(networkSettingProvider);
    expect(find.text(l.macHelperStartupInstall), findsOneWidget);
    await tester.tap(find.text(l.macHelperInstallAction));
    await tester.pumpAndSettle();
    expect(native.calls, ['status']);
    await tester.tap(find.text(l.macHelperInstall));
    await tester.pumpAndSettle();
    expect(flow.busy, isTrue);
    expect(find.text(l.macHelperInstalling), findsNWidgets(2));
    expect(find.text(l.macHelperInstallAction), findsNothing);
    await tester.tap(find.text(l.close));
    await tester.pumpAndSettle();
    expect(find.text(l.macHelperInstalling), findsOneWidget);
    expect(find.byType(ActivityIndicator), findsNothing);
    native.state = 'enabled';
    native.pending!.complete({'code': 'enabled'});
    await tester.pumpAndSettle();
    expect(find.text(l.macHelperInstalling), findsNothing);
    expect(find.text(l.disconnected), findsOneWidget);
    expect(container.read(coreStatusProvider), CoreStatus.disconnected);
    expect(container.read(isStartProvider), isFalse);
    expect(container.read(patchClashConfigProvider), saved);
    expect(container.read(networkSettingProvider), network);
    expect(native.calls, [
      'status',
      'status',
      'installerInstructions',
      'status',
    ]);
  });

  testWidgets(
    'cancelled update stays visible and retry still requires consent',
    (tester) async {
      native.state = 'updateRequired';
      await flow.check();
      await pumpStatus(tester);
      final l = currentAppLocalizations;
      await tester.tap(find.text(l.macHelperUpdateAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.macHelperUpdate));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.macHelperLater));
      await tester.pumpAndSettle();
      expect(find.text(l.macHelperUpdateCancelled), findsOneWidget);
      expect(find.text(l.macHelperTryAgain), findsOneWidget);
      await tester.tap(find.text(l.macHelperTryAgain));
      await tester.pumpAndSettle();
      expect(find.byType(MacHelperDialog), findsOneWidget);
      expect(
        native.calls.where((call) => call == 'installerInstructions'),
        hasLength(1),
      );
      await tester.tap(find.text(l.macHelperLater));
      await tester.pumpAndSettle();
    },
  );

  for (final state in MacHelperState.values.where(
    (value) => value != MacHelperState.enabled,
  )) {
    testWidgets('$state has a visible reason and safe action', (tester) async {
      native.state = state.name;
      await flow.check();
      await pumpStatus(tester);
      final l = currentAppLocalizations;
      final reason = switch (state) {
        MacHelperState.off ||
        MacHelperState.installerRequired => l.macHelperStartupInstall,
        MacHelperState.updateRequired ||
        MacHelperState.incompatible => l.macHelperStartupUpdate,
        MacHelperState.repairRequired => l.macHelperStartupUnavailable,
        MacHelperState.signingRequired => l.macHelperVerificationFailed,
        MacHelperState.unknown ||
        MacHelperState.unavailable => l.macHelperStatusUnknown,
        MacHelperState.exitUnconfirmed => l.macHelperCoreUnconfirmed,
        _ => macHelperLabel(l, state),
      };
      expect(find.text(reason), findsOneWidget);
      expect(find.byType(ActivityIndicator), findsNothing);
      expect(find.byType(MacHelperDialog), findsNothing);
      expect(native.calls, ['status']);
      final action = macHelperAction(state);
      if (action == MacHelperAction.recheck) {
        await tester.tap(find.text(l.macHelperCheckAgain));
        await tester.pumpAndSettle();
        expect(native.calls, ['status', 'status']);
        expect(find.byType(MacHelperDialog), findsNothing);
      } else if (action == MacHelperAction.settings) {
        await tester.tap(find.text(l.macHelperOpenSettings));
        await tester.pumpAndSettle();
        expect(native.calls, ['status', 'openApprovalSettings']);
      } else {
        expect(find.byType(TextButton), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pending native transaction stays unknown and only rechecks', (
    tester,
  ) async {
    native.state = 'installInProgress';
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperStatusUnknown), findsOneWidget);
    expect(find.text(l.macHelperCheckAgain), findsOneWidget);
    expect(find.text(l.macHelperInstalling), findsNothing);
    await tester.tap(find.text(l.macHelperCheckAgain));
    await tester.pumpAndSettle();
    expect(native.calls, ['status', 'status']);
  });

  testWidgets('connected Core is never described as not started', (
    tester,
  ) async {
    native.state = 'updateRequired';
    await flow.check();
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperStartupUpdate), findsNothing);
    expect(find.text(l.macHelperRepair), findsOneWidget);
  });

  testWidgets(
    'disconnected UI with retained session never claims Core is stopped',
    (tester) async {
      final sessionNative = _SessionNative()..state = 'enabled';
      flow.dispose();
      flow = makeMaintenance(sessionNative);
      const session = '0123456789abcdef0123456789abcdef';
      await flow.client.start(session);
      sessionNative.state = 'updateRequired';
      await flow.check();
      expect(flow.client.hasCoreSession, isTrue);
      expect(container.read(coreStatusProvider), CoreStatus.disconnected);
      await pumpStatus(tester);
      final l = currentAppLocalizations;
      expect(find.text(l.macHelperStartupUpdate), findsNothing);
      expect(
        find.text('${l.macHelperRepair}\n${l.macHelperCoreUnconfirmed}'),
        findsOneWidget,
      );
      expect(await flow.client.stop(session), isTrue);
      sessionNative.receive.complete({'code': 'unavailable'});
      await tester.pumpAndSettle();
    },
  );

  testWidgets('safe mode keeps existing core status without helper actions', (
    tester,
  ) async {
    native.state = 'updateRequired';
    await flow.check();
    container.dispose();
    container = ProviderContainer(
      overrides: [safeModeProvider.overrideWithValue(true)],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1200, 800);
    await pumpStatus(tester);
    expect(find.text(currentAppLocalizations.disconnected), findsOneWidget);
    expect(
      find.text(currentAppLocalizations.macHelperUpdateAction),
      findsNothing,
    );
    expect(native.calls, ['status']);
  });

  testWidgets(
    'large text keeps helper reason and action in dashboard status area',
    (tester) async {
      native.state = 'updateRequired';
      await flow.check();
      await pumpStatus(tester, scale: 2);
      expect(
        find.text(currentAppLocalizations.macHelperStartupUpdate),
        findsOneWidget,
      );
      expect(
        find.text(currentAppLocalizations.macHelperUpdateAction),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
