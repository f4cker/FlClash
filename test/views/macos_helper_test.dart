import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../core/desktop/macos_helper_install_test.dart'
    show InstallNative, makeMaintenance;
import '../helpers/test_app.dart';

void main() {
  Future<void> pumpHost(
    WidgetTester tester,
    MacHelperMaintenance flow, {
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.pumpWidget(
      TestApp(
        theme: ThemeData(brightness: brightness),
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: TextButton(
              onPressed: () => unawaited(
                showMacHelperFlow(context: context, maintenance: flow),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('decline performs no install and returns to usable GUI', (
    tester,
  ) async {
    final native = InstallNative();
    final flow = makeMaintenance(native);
    await flow.check();
    await pumpHost(tester, flow);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperInstallTitle), findsOneWidget);
    expect(find.text(l.macHelperInstallDetail), findsOneWidget);
    await tester.tap(find.text(l.macHelperNotNowInstall));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(MacHelperDialog), findsNothing);
    expect(native.calls, ['status']);
  });

  testWidgets(
    'closing progress and reopening joins operation without reinstall',
    (tester) async {
      final native = InstallNative()..pending = Completer();
      final flow = makeMaintenance(native);
      await flow.check();
      await pumpHost(tester, flow);
      final l = currentAppLocalizations;
      await tester.tap(find.text(l.macHelperInstall));
      await tester.pumpAndSettle();
      expect(flow.busy, isTrue);
      expect(find.text(l.macHelperInstalling), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(MacHelperDialog), findsNothing);
      expect(flow.busy, isTrue);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text(l.macHelperInstalling), findsOneWidget);
      expect(find.text(l.macHelperInstall), findsNothing);
      expect(
        native.calls.where((call) => call == 'installerInstructions'),
        hasLength(1),
      );
      native.pending!.complete({'code': 'authorizationCancelled'});
      await tester.pumpAndSettle();
      expect(find.text(l.macHelperInstallCancelled), findsOneWidget);
      expect(flow.busy, isFalse);
      await tester.tap(find.text(l.macHelperLater));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('unknown shows only recheck, no second privilege action', (
    tester,
  ) async {
    final native = InstallNative()..result = {'code': 'installationUnknown'};
    final flow = makeMaintenance(native);
    await flow.check();
    await flow.install(confirmed: true);
    await pumpHost(tester, flow);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperStopUnknown), findsOneWidget);
    expect(find.text(l.macHelperCheckAgain), findsOneWidget);
    expect(find.text(l.macHelperInstall), findsNothing);
    await tester.tap(find.text(l.macHelperCheckAgain));
    await tester.pumpAndSettle();
    expect(
      native.calls.where((call) => call == 'installerInstructions'),
      hasLength(1),
    );
    await tester.tap(find.text(l.macHelperLater));
    await tester.pumpAndSettle();
  });

  testWidgets('repairRequired offers only safe guidance and recheck', (
    tester,
  ) async {
    final native = InstallNative()..state = 'repairRequired';
    final flow = makeMaintenance(native);
    await flow.check();
    await pumpHost(tester, flow);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperCannotUse), findsOneWidget);
    expect(find.text(l.macHelperUnavailableDetail), findsOneWidget);
    expect(find.text(l.macHelperCheckAgain), findsOneWidget);
    expect(find.text(l.macHelperInstall), findsNothing);
    expect(find.text(l.macHelperUpdate), findsNothing);
    expect(find.text(l.macHelperTryAgain), findsNothing);
    expect(find.text(l.macHelperUpdateDetail), findsNothing);
    await tester.tap(find.text(l.macHelperCheckAgain));
    await tester.pumpAndSettle();
    expect(native.calls, ['status', 'status']);
    await tester.tap(find.text(l.macHelperLater));
    await tester.pumpAndSettle();
  });

  testWidgets('outside Applications explains move, never offers install', (
    tester,
  ) async {
    final native = InstallNative()..state = 'protectedInstallationRequired';
    final flow = makeMaintenance(native);
    await flow.check();
    await pumpHost(tester, flow);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperMoveDetail), findsOneWidget);
    expect(find.text(l.macHelperInstall), findsNothing);
    await tester.tap(find.text(l.macHelperLater));
    await tester.pumpAndSettle();
    expect(native.calls, ['status']);
  });

  testWidgets('failure is localized, expandable, and fits dark large text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final native = InstallNative()
      ..result = {'code': 'installerPayloadInvalid'};
    final flow = makeMaintenance(native);
    await flow.check();
    await flow.install(confirmed: true);
    await pumpHost(tester, flow, brightness: Brightness.dark);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperPayloadDetail), findsOneWidget);
    expect(find.text('installerPayloadInvalid'), findsNothing);
    await tester.tap(find.text(l.macHelperMoreDetails));
    await tester.pumpAndSettle();
    expect(find.text(l.macHelperLessDetails), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(l.macHelperLater));
    await tester.pumpAndSettle();
  });
}
