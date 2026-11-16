import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/launch.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalLauncher = AutoLaunch.entry;
  late ProviderContainer container;
  late ValueNotifier<bool> settingsVisible;
  late Completer<Object?> nativeResult;
  final calls = <MethodCall>[];
  final savedValues = <bool>[];

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1000, 3000);
    settingsVisible = ValueNotifier(true);
    calls.clear();
    savedValues.clear();
    AutoLaunch.entry = const MacOSLoginItemEntry();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MacOSLoginItemEntry.channel, (call) {
          calls.add(call);
          expect(call.method, 'launchAtStartupSetEnabled');
          return nativeResult.future;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MacOSLoginItemEntry.channel, null);
    AutoLaunch.entry = originalLauncher;
    settingsVisible.dispose();
    container.dispose();
  });

  Future<void> startToggle(WidgetTester tester, {required bool enabled}) async {
    nativeResult = Completer<Object?>();
    container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(autoLaunch: !enabled));
    // The app's ThemeManager also observes settings outside the Settings route.
    final subscription = container.listen(
      appSettingProvider.select((state) => state.autoLaunch),
      (_, next) => savedValues.add(next),
    );
    addTearDown(subscription.close);
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          themeMode: ThemeMode.light,
          child: ValueListenableBuilder<bool>(
            valueListenable: settingsVisible,
            builder: (context, visible, child) => visible
                ? const GeneralView()
                : const SizedBox(key: ValueKey('settings-closed')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BannerHost), findsOneWidget);
    await tester.tap(find.text(currentAppLocalizations.autoLaunch));
    await tester.pump();
    expect(calls, hasLength(1));
    expect(calls.single.arguments, {'setEnabledValue': enabled});
    expect(container.read(appSettingProvider).autoLaunch, !enabled);
    expect(savedValues, isEmpty);
    settingsVisible.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(GeneralView), findsNothing);
    expect(find.byKey(const ValueKey('settings-closed')), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  }

  for (final enabled in [true, false]) {
    testWidgets(
      '${enabled ? 'enable' : 'disable'} commits native success after the row is disposed',
      (tester) async {
        await startToggle(tester, enabled: enabled);
        nativeResult.complete();
        await tester.pumpAndSettle();

        expect(container.read(appSettingProvider).autoLaunch, enabled);
        expect(savedValues, [enabled]);
        expect(calls, hasLength(1));
        expect(
          find.byType(Text),
          findsNothing,
          reason: 'No false error banner',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
      skip: !Platform.isMacOS || safeModeBuild,
    );
  }

  testWidgets(
    'native failure after disposal preserves preference and shows an error banner',
    (tester) async {
      await startToggle(tester, enabled: true);
      nativeResult.completeError(
        PlatformException(code: 'login_item_requires_approval'),
      );
      await tester.pumpAndSettle();

      expect(container.read(appSettingProvider).autoLaunch, isFalse);
      expect(savedValues, isEmpty);
      expect(calls, hasLength(1));
      expect(
        find.text(currentAppLocalizations.loginItemRequiresApproval),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !Platform.isMacOS || safeModeBuild,
  );
}
