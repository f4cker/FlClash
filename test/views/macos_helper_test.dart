import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
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
    bool requiredByFeature = false,
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
                showMacHelperFlow(
                  context: context,
                  maintenance: flow,
                  requiredByFeature: requiredByFeature,
                ),
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

  testWidgets('closing the dialog performs no migration', (tester) async {
    final native = InstallNative();
    final flow = makeMaintenance(native);
    await flow.check();
    await pumpHost(tester, flow);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperTitle), findsOneWidget);
    expect(find.text(l.macHelperMigrationTitle), findsOneWidget);
    expect(find.text(l.macHelperMigrationDetail), findsOneWidget);
    await tester.tap(find.text(l.close));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(MacHelperDialog), findsNothing);
    expect(native.calls, ['status']);
  });

  testWidgets('feature gate: cancel keeps the feature off, no effects', (
    tester,
  ) async {
    final native = InstallNative()..state = 'notRegistered';
    final flow = makeMaintenance(native);
    await flow.check();
    await pumpHost(tester, flow, requiredByFeature: true);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperRequiredTitle), findsOneWidget);
    expect(find.text(l.macHelperViewSetup), findsOneWidget);
    expect(find.text(l.macHelperApprovalTitle), findsNothing);
    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(MacHelperDialog), findsNothing);
    expect(native.calls, ['status']);
  });

  testWidgets('feature gate: view setup shows the same card', (tester) async {
    final native = InstallNative()..state = 'notRegistered';
    final flow = makeMaintenance(native);
    await flow.check();
    await pumpHost(tester, flow, requiredByFeature: true);
    final l = currentAppLocalizations;
    await tester.tap(find.text(l.macHelperViewSetup));
    await tester.pumpAndSettle();
    expect(find.text(l.macHelperApprovalTitle), findsOneWidget);
    expect(find.text(l.macHelperOpenSettings), findsOneWidget);
    await tester.tap(find.text(l.macHelperOpenSettings));
    await tester.pumpAndSettle();
    expect(native.calls, ['status', 'enable', 'openApprovalSettings']);
    // Returning to Flash re-checks and ends the short Settings poll.
    flow.resumed();
    await tester.pumpAndSettle();
    expect(native.calls.last, 'status');
    await tester.tap(find.text(l.close));
    await tester.pumpAndSettle();
    flow.dispose();
  });

  testWidgets(
    'closing progress and reopening joins the operation, no second prompt',
    (tester) async {
      final native = InstallNative()..pending = Completer();
      final flow = makeMaintenance(native);
      await flow.check();
      await pumpHost(tester, flow);
      final l = currentAppLocalizations;
      await tester.tap(find.text(l.macHelperMigrationAction));
      await tester.pump();
      expect(flow.busy, isTrue);
      expect(find.text(l.macHelperUpdating), findsOneWidget);
      await tester.tap(find.text(l.close));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(MacHelperDialog), findsNothing);
      expect(flow.busy, isTrue);
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(l.macHelperUpdating), findsOneWidget);
      expect(find.text(l.macHelperMigrationAction), findsNothing);
      expect(native.calls.where((call) => call == 'migrate'), hasLength(1));
      native.pending!.complete({'code': 'authorizationCancelled'});
      await tester.pumpAndSettle();
      expect(find.text(l.macHelperMigrationAction), findsOneWidget);
      expect(flow.busy, isFalse);
      await tester.tap(find.text(l.close));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('outside Applications explains move, offers no action', (
    tester,
  ) async {
    final native = InstallNative()..state = 'moveRequired';
    final flow = makeMaintenance(native);
    await flow.check();
    await pumpHost(tester, flow);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperMoveTitle), findsOneWidget);
    expect(find.text(l.macHelperMoveDetail), findsOneWidget);
    expect(find.text(l.macHelperMigrationAction), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    await tester.tap(find.text(l.close));
    await tester.pumpAndSettle();
    expect(native.calls, ['status']);
  });

  testWidgets('failure is localized, expandable, and fits dark large text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final native = InstallNative()
      ..migrateAnswer = {
        'code': 'migrationFailed',
        'step': 'stopOld',
        'detail': 'bootout failed: 5',
      };
    final flow = makeMaintenance(native);
    await flow.check();
    await flow.migrate(confirmed: true);
    await pumpHost(tester, flow, brightness: Brightness.dark);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperFailedTitle), findsOneWidget);
    expect(find.text(l.macHelperFailedStopOld), findsOneWidget);
    expect(find.textContaining('bootout failed'), findsNothing);
    await tester.ensureVisible(find.text(l.macHelperViewDetails));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.macHelperViewDetails));
    await tester.pumpAndSettle();
    expect(find.textContaining('bootout failed: 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(l.close));
    await tester.pumpAndSettle();
  });
}
