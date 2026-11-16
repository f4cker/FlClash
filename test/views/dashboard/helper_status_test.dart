import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:fl_clash/views/dashboard/widgets/live_status.dart';
import 'package:fl_clash/views/dashboard/widgets/mac_helper_status.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MacHelperBarStatus(maintenance: flow, version: '1.2.3 (4)'),
                    LiveStatusButton(separateCore: true, maintenance: flow),
                  ],
                ),
              ],
              body: const SizedBox.expand(),
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

  /// Opens the popover under the capsule, as a click does.
  Future<void> openPopover(WidgetTester tester, {bool settle = true}) async {
    await tester.tap(find.byType(MacHelperCapsule));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    expect(find.byType(MacHelperPopover), findsOneWidget);
  }

  /// The helper is ready: its bar button is the round green one.
  void expectReadyButton(WidgetTester tester) {
    final capsule = tester.widget<MacHelperCapsule>(
      find.byType(MacHelperCapsule),
    );
    expect(capsule.view.isReady, isTrue);
    final rect = tester.getRect(find.byType(MacHelperCapsule));
    expect(rect.width, rect.height);
    expect(
      find.bySemanticsLabel(currentAppLocalizations.macHelperOn),
      findsOneWidget,
    );
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
      expect(find.text(l.macHelperBarUpdate), findsOneWidget);
      expect(find.text(l.macHelperMigrationTitle), findsNothing);
      await openPopover(tester);
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
    expect(zh.macHelperVersionLine('1.2.3'), '版本 1.2.3');
    expect(zh.macHelperBarUpdate, '更新辅助程序');
    expect(zh.macHelperBarAllow, '允许辅助程序');
    expect(zh.macHelperBarStarting, '正在启动…');
    expect(zh.macHelperBarNotReady, '辅助程序未就绪');
    expect(zh.macHelperBarFailedCheck, '辅助程序未通过检查');
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.macHelperBarUpdate, 'Update helper');
    expect(en.macHelperBarAllow, 'Allow helper');
    expect(en.macHelperBarStarting, 'Starting…');
    expect(en.macHelperBarNotReady, 'Helper not ready');
    expect(en.macHelperBarFailedCheck, 'Helper failed check');
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
    await openPopover(tester);
    await tester.tap(find.text(l.macHelperMigrationAction));
    await tester.pump();
    expect(flow.busy, isTrue);
    expect(find.text(l.macHelperUpdating), findsOneWidget);
    expect(find.text(l.macHelperMigrationAction), findsNothing);
    expect(find.text(l.macHelperMigrationTitle), findsOneWidget);
    native.pending!.complete({'code': 'enabled'});
    await tester.pumpAndSettle();
    // Ready: the popover closes and the capsule is gone.
    expect(find.text(l.macHelperUpdating), findsNothing);
    expect(find.byType(MacHelperPopover), findsNothing);
    expectReadyButton(tester);
    expect(find.text(l.macHelperOn), findsNothing);
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
    await openPopover(tester);
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
    await openPopover(tester);
    await tester.tap(find.text(l.macHelperMigrationAction));
    await tester.pumpAndSettle();
    // The capsule turns red and the open popover shows the failure.
    expect(find.text(l.macHelperBarNotReady), findsOneWidget);
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
    expectReadyButton(tester);
    expect(find.byType(MacHelperPopover), findsNothing);
    expect(native.calls.where((call) => call == 'migrate'), hasLength(2));
  });

  testWidgets('approval lists readable steps and opens settings', (
    tester,
  ) async {
    native.state = 'notRegistered';
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperBarAllow), findsOneWidget);
    await openPopover(tester);
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
    expect(find.text(l.macHelperBarFailedCheck), findsOneWidget);
    await openPopover(tester);
    expect(find.text(l.macHelperSignatureTitle), findsOneWidget);
    expect(find.text(l.macHelperSignatureDetail), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MacHelperPopover),
        matching: find.byType(FilledButton),
      ),
      findsNothing,
    );
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
      // Only a waiting capsule: nothing to open, no buttons.
      expect(find.text(l.macHelperBarStarting), findsOneWidget);
      expect(find.byType(ActivityIndicator), findsOneWidget);
      await tester.tap(find.byType(MacHelperCapsule));
      await tester.pump();
      expect(find.byType(MacHelperPopover), findsNothing);
      expect(find.text(l.macHelperStartingTitle), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      await settleReady(tester);
      expectReadyButton(tester);
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
      expect(find.byType(MacHelperCapsule), findsOneWidget);
      await openPopover(tester);
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
    expect(find.text(l.macHelperBarAllow), findsOneWidget);
    await openPopover(tester);
    expect(find.text(l.macHelperDisabledTitle), findsOneWidget);
    expect(find.text(l.macHelperDisabledDetail), findsOneWidget);
    // The capsule and the card title both show the switch, no warning.
    for (final scope in [MacHelperCapsule, MacHelperPopover]) {
      final glyph = tester.widget<GlyphIcon>(
        find
            .descendant(
              of: find.byType(scope),
              matching: find.byType(GlyphIcon),
            )
            .first,
      );
      expect(glyph.glyph, AppGlyphs.helperDaemon);
    }
    expect(find.text(l.macHelperOpenSettings), findsOneWidget);
    expect(find.text(l.macHelperCheckAgain), findsOneWidget);
  });

  testWidgets('feature gate opens the same popover, not a dialog', (
    tester,
  ) async {
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
    await tester.pumpAndSettle();
    expect(find.byType(MacHelperDialog), findsNothing);
    expect(find.byType(MacHelperPopover), findsOneWidget);
    expect(find.text(l.macHelperRequiredDetail), findsOneWidget);
    expect(find.text(l.macHelperMigrationTitle), findsOneWidget);
    expect(find.text(l.macHelperMigrationAction), findsOneWidget);
    expect(closed, isFalse);
    // A second request while it is open joins the same popover.
    unawaited(showMacHelperFlow(maintenance: flow, requiredByFeature: true));
    await tester.pumpAndSettle();
    expect(find.byType(MacHelperPopover), findsOneWidget);
    // Escape closes it and the gate's future completes; nothing ran.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MacHelperPopover), findsNothing);
    expect(closed, isTrue);
    expect(native.calls, ['status']);
  });

  testWidgets('feature gate falls back to the dialog off the dashboard', (
    tester,
  ) async {
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    // Another page covers the dashboard: its capsule cannot be seen.
    unawaited(
      Navigator.of(tester.element(find.byType(MacHelperCapsule))).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      showMacHelperFlow(
        context: tester.element(find.byType(SizedBox).last),
        maintenance: flow,
        requiredByFeature: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MacHelperDialog), findsOneWidget);
    expect(find.text(l.macHelperRequiredTitle), findsOneWidget);
    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(MacHelperDialog), findsNothing);
    expect(native.calls, ['status']);
  });

  testWidgets('tapping outside closes the popover', (tester) async {
    native.state = 'notRegistered';
    await flow.check();
    await pumpStatus(tester);
    await openPopover(tester);
    await tester.tapAt(const Offset(20, 500));
    await tester.pumpAndSettle();
    expect(find.byType(MacHelperPopover), findsNothing);
    expect(find.byType(MacHelperCapsule), findsOneWidget);
  });

  testWidgets('popover is 320 wide, under the capsule, in the window', (
    tester,
  ) async {
    native.state = 'notRegistered';
    await flow.check();
    await pumpStatus(tester);
    await openPopover(tester);
    final capsule = tester.getRect(find.byType(MacHelperCapsule));
    final popover = tester.getRect(find.byType(MacHelperPopover));
    expect(popover.width, 320);
    expect(popover.top, greaterThan(capsule.bottom));
    expect(popover.right, lessThanOrEqualTo(tester.view.physicalSize.width));
    expect(popover.left, greaterThanOrEqualTo(0));
  });

  testWidgets('capsule matches the Core button height, 8 apart', (
    tester,
  ) async {
    // A running core shows the round check button.
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    native.state = 'notRegistered';
    await flow.check();
    await pumpStatus(tester);
    // Both show: the capsule left of the Core button, as tall, 8 apart,
    // centred on one line.
    final capsule = tester.getRect(find.byType(MacHelperCapsule));
    Rect coreButton() => tester.getRect(
      find.descendant(
        of: find.byType(LiveStatusButton),
        matching: find.byType(IconButton),
      ),
    );
    final core = coreButton();
    expect(capsule.height, macHelperBarHeight);
    expect(core.height, macHelperBarHeight);
    expect(core.left - capsule.right, 8);
    expect(barButtonGap, 8);
    expect(capsule.center.dy, core.center.dy);
    native.state = 'enabled';
    await flow.recheck();
    await tester.pumpAndSettle();
    expectReadyButton(tester);
    expect(coreButton(), core);
  });

  for (final (code, glyph) in [
    ('migrationRequired', AppGlyphs.helperDaemon),
    ('notRegistered', AppGlyphs.helperDaemon),
    ('requiresApproval', AppGlyphs.helperDaemon),
    ('migrationIncomplete', AppGlyphs.helperDaemon),
    ('signingRequired', AppGlyphs.shieldAlert),
  ]) {
    testWidgets('$code popover title repeats the capsule icon', (tester) async {
      native.state = code;
      await flow.check();
      await pumpStatus(tester);
      final capsuleGlyph = tester.widget<GlyphIcon>(
        find.descendant(
          of: find.byType(MacHelperCapsule),
          matching: find.byType(GlyphIcon),
        ),
      );
      expect(capsuleGlyph.glyph, glyph);
      await openPopover(tester);
      final titleGlyph = tester.widget<GlyphIcon>(
        find
            .descendant(
              of: find.byType(MacHelperPopover),
              matching: find.byType(GlyphIcon),
            )
            .first,
      );
      expect(titleGlyph.glyph, glyph);
      expect(titleGlyph.color, capsuleGlyph.color);
    });
  }

  testWidgets('capsule collapses to the green button in 0.2s when ready', (
    tester,
  ) async {
    native.state = 'notRegistered';
    await flow.check();
    await pumpStatus(tester);
    final wide = tester.getRect(find.byType(MacHelperCapsule));
    expect(wide.width, greaterThan(wide.height));
    native.state = 'enabled';
    await flow.recheck();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final halfway = tester.getRect(find.byType(MacHelperCapsule));
    expect(halfway.width, inExclusiveRange(wide.height, wide.width));
    expect(halfway.right, wide.right);
    await tester.pump(const Duration(milliseconds: 120));
    expectReadyButton(tester);
    // And widens again when the helper needs the user.
    native.state = 'signingRequired';
    await flow.recheck();
    await tester.pumpAndSettle();
    final again = tester.getRect(find.byType(MacHelperCapsule));
    expect(again.width, greaterThan(again.height));
    expect(
      find.text(currentAppLocalizations.macHelperBarFailedCheck),
      findsOneWidget,
    );
  });

  testWidgets('returning from System Settings checks again', (tester) async {
    native.state = 'notRegistered';
    await flow.check();
    await pumpStatus(tester);
    await openPopover(tester);
    await tester.tap(find.text(currentAppLocalizations.macHelperOpenSettings));
    await tester.pumpAndSettle();
    native.state = 'enabled';
    final before = native.calls.length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(native.calls.skip(before), contains('status'));
    expect(find.byType(MacHelperPopover), findsNothing);
    expectReadyButton(tester);
  });

  testWidgets('narrow window shows the icon only with tooltip and label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(viewSizeProvider.notifier).value = const Size(600, 700);
    native.state = 'notRegistered';
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(find.text(l.macHelperBarAllow), findsNothing);
    expect(
      find.bySemanticsLabel(l.macHelperBarHint(l.macHelperApprovalTitle)),
      findsOneWidget,
    );
    final capsule = tester.getRect(find.byType(MacHelperCapsule));
    expect(capsule.width, capsule.height);
    await openPopover(tester);
    expect(find.text(l.macHelperApprovalTitle), findsOneWidget);
  });

  testWidgets('screen readers hear the full title and each change', (
    tester,
  ) async {
    final announced = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
      SystemChannels.accessibility,
      (message) async {
        final data = (message as Map)['data'] as Map;
        if (data['message'] case final String text) announced.add(text);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
        SystemChannels.accessibility,
        null,
      ),
    );
    native.state = 'notRegistered';
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expect(
      find.bySemanticsLabel(l.macHelperBarHint(l.macHelperApprovalTitle)),
      findsOneWidget,
    );
    expect(announced, isEmpty);
    native.state = 'signingRequired';
    await flow.recheck();
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(l.macHelperBarHint(l.macHelperSignatureTitle)),
      findsOneWidget,
    );
    native.state = 'enabled';
    await flow.recheck();
    await tester.pumpAndSettle();
    expect(announced, [l.macHelperSignatureTitle, l.macHelperOn]);
  });

  testWidgets('ready shows a green round button that opens the version', (
    tester,
  ) async {
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    native.state = 'enabled';
    await flow.check();
    await pumpStatus(tester);
    final l = currentAppLocalizations;
    expectReadyButton(tester);
    expect(
      tester
          .widget<Tooltip>(
            find.descendant(
              of: find.byType(MacHelperCapsule),
              matching: find.byType(Tooltip),
            ),
          )
          .message,
      l.macHelperOn,
    );
    final glyph = tester.widget<GlyphIcon>(
      find.descendant(
        of: find.byType(MacHelperCapsule),
        matching: find.byType(GlyphIcon),
      ),
    );
    expect(glyph.glyph, AppGlyphs.helperDaemon);
    final context = tester.element(find.byType(MacHelperCapsule));
    // The Core check's own colors.
    expect(glyph.color, context.colorScheme.onSuccessContainer);
    final helperStyle = tester
        .widget<IconButton>(
          find.descendant(
            of: find.byType(MacHelperCapsule),
            matching: find.byType(IconButton),
          ),
        )
        .style!;
    final coreStyle = tester
        .widget<IconButton>(
          find.descendant(
            of: find.byType(LiveStatusButton),
            matching: find.byType(IconButton),
          ),
        )
        .style!;
    expect(
      helperStyle.backgroundColor!.resolve({}),
      coreStyle.backgroundColor!.resolve({}),
    );
    expect(
      helperStyle.backgroundColor!.resolve({}),
      context.colorScheme.successContainer,
    );
    // As big as the Core check, 8 to its left, on one line.
    final helper = tester.getRect(find.byType(MacHelperCapsule));
    final core = tester.getRect(
      find.descendant(
        of: find.byType(LiveStatusButton),
        matching: find.byType(IconButton),
      ),
    );
    expect(helper.size, core.size);
    expect(core.left - helper.right, 8);
    expect(helper.center.dy, core.center.dy);
    // The popover: the title and the version in grey, nothing to press.
    await openPopover(tester);
    expect(
      find.descendant(
        of: find.byType(MacHelperPopover),
        matching: find.text(l.macHelperOn),
      ),
      findsOneWidget,
    );
    expect(find.text(l.macHelperVersionLine('1.2.3 (4)')), findsOneWidget);
    for (final type in [FilledButton, TextButton]) {
      expect(
        find.descendant(
          of: find.byType(MacHelperPopover),
          matching: find.byType(type),
        ),
        findsNothing,
      );
    }
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
      expect(find.text(l.macHelperBarUpdate), findsOneWidget);
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
    expect(find.byType(MacHelperCapsule), findsNothing);
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
      await openPopover(tester);
      expect(find.text(l.macHelperApprovalTitle), findsOneWidget);
      expect(find.text(l.macHelperOpenSettings), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
