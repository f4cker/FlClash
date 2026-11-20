import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/tray_menu.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:rust_api/tray.dart';

import '../helpers/fake_tray_host.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

final _certificate = MitmCertificate(
  pem: '-----BEGIN CERTIFICATE-----\n',
  fingerprint: 'AB:CD',
  subject: 'FlClash CA 0000ABCD',
  notBefore: DateTime.utc(2026, 10, 20, 12),
  notAfter: DateTime.utc(2036, 10, 22, 12),
);

const _trusted = Mitm(trustedFingerprint: 'AB:CD');

TrayState _trayState({bool isStart = true, MitmIndicator? mitmIndicator}) =>
    TrayState(
      mode: Mode.rule,
      port: 7890,
      autoLaunch: false,
      systemProxy: false,
      tunEnable: false,
      isStart: isStart,
      groups: const [],
      selectedMap: const {},
      showTrayTitle: false,
      safeMode: false,
      mitmIndicator: mitmIndicator,
    );

void main() {
  late ProviderContainer container;
  late _MockCore core;
  late FakeTrayHost host;
  late AppTray tray;
  late int settingsOpened;

  setUpAll(() {
    registerFallbackValue(const MitmRules());
  });

  setUp(() {
    mitmFeature = true;
    settingsOpened = 0;
    mitmSettingsPort = () async => settingsOpened++;
  });

  tearDown(() {
    mitmFeature = false;
    mitmSettingsPort = null;
  });

  Mitm saved() => container.read(patchClashConfigProvider).mitm;

  Future<void> pump(
    WidgetTester tester, {
    Mitm mitm = const Mitm(),
    MitmCertificate? certificate,
  }) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    core = _MockCore();
    when(() => core.getMitmCertificate()).thenAnswer((_) async => certificate);
    when(
      () => core.generateMitmCertificate(),
    ).thenAnswer((_) async => _certificate);
    when(
      () => core.getMitmStatus(),
    ).thenAnswer((_) async => const MitmStatus());
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        currentProfileProvider.overrideWithValue(null),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        currentBrightnessProvider.overrideWithValue(Brightness.light),
        mitmTrustStoreProvider.overrideWithValue(null),
        mitmSignerProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.listen(patchClashConfigProvider, (_, _) {});
    container.listen(trayMitmPendingProvider, (_, _) {});
    container.read(patchClashConfigProvider.notifier).value = PatchClashConfig(
      mitm: mitm,
    );
    host = FakeTrayHost();
    Tray.instance.resetForTesting(host);
    tray = AppTray.forPlatform(isMacOS: true, isWindows: false);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: SizedBox.expand()),
      ),
    );
    await tester.runAsync(() => container.read(mitmCaProvider.future));
  }

  Future<void> update({bool isStart = true, MitmIndicator? indicator}) =>
      tray.update(
        trayState: _trayState(
          isStart: isStart,
          mitmIndicator:
              indicator ?? (saved().enable ? const MitmIndicator.on() : null),
        ),
        traffic: const Traffic(),
        read: container.read,
      );

  List<TrayItem> menu() => host.lastShown!.menu;

  TrayItem item(String label) => menu().firstWhere((i) => i.label == label);

  Future<void> select(WidgetTester tester, String label) async {
    host.emit(
      TraySignalKind.itemSelected,
      item(label).id,
      host.lastShown!.menuGeneration,
    );
    await tester.pump();
  }

  Finder confirm() =>
      find.widgetWithText(TextButton, currentAppLocalizations.confirm);
  Finder cancel() =>
      find.widgetWithText(TextButton, currentAppLocalizations.cancel);

  testWidgets('follows system proxy and TUN, in order', (tester) async {
    await pump(tester, mitm: _trusted);
    await update();
    final l = currentAppLocalizations;
    final labels = menu().map((i) => i.label).toList();
    final start = labels.indexOf(l.systemProxy);
    expect(labels.sublist(start, start + 6), [
      l.systemProxy,
      l.trayTunMode,
      l.trayMitm,
      l.trayMitmCapture,
      l.trayMitmCaptureNeedsMitm,
      l.mitmIndicatorOpenSettings,
    ]);
    expect(item(l.systemProxy).kind, TrayItemKind.checkbox);
    expect(item(l.trayMitm).kind, TrayItemKind.checkbox);
    expect(item(l.trayMitmCapture).kind, TrayItemKind.checkbox);
  });

  testWidgets('are absent without the MITM feature', (tester) async {
    await pump(tester);
    mitmFeature = false;
    await update();
    final labels = menu().map((i) => i.label);
    expect(labels, isNot(contains(currentAppLocalizations.trayMitm)));
    expect(labels, isNot(contains(currentAppLocalizations.trayMitmCapture)));
  });

  testWidgets('mirror the saved settings, both ways', (tester) async {
    await pump(tester, mitm: _trusted.copyWith(enable: true, capture: true));
    await update();
    final l = currentAppLocalizations;
    expect(item(l.trayMitm).checked, isTrue);
    expect(item(l.trayMitmCapture).checked, isTrue);
    expect(item(l.trayMitmCapture).enabled, isTrue);
    final labels = menu().map((i) => i.label).toList();
    expect(labels.first, l.show);
    expect(labels, isNot(contains(l.mitmIndicatorOn)));
    expect(labels.where((x) => x == l.mitmIndicatorOpenSettings), hasLength(1));
    expect(labels, isNot(contains(l.trayMitmCaptureNeedsMitm)));

    await update(
      indicator: const MitmIndicator.paused(MitmPauseReason.liveness),
    );
    final paused = menu().map((i) => i.label).toList();
    expect(paused.first, l.mitmIndicatorPausedBecause(l.mitmPauseLiveness));
    expect(paused, isNot(contains(l.mitmIndicatorOpenSettings)));

    // The settings page writes; the tray follows.
    container.read(systemActionProvider.notifier).setMitmCapture(false);
    await update();
    expect(item(l.trayMitmCapture).checked, isFalse);
    expect(item(l.trayMitm).checked, isTrue);
  });

  testWidgets('without a trusted certificate, opens the settings instead', (
    tester,
  ) async {
    await pump(tester, certificate: _certificate);
    await update();
    final l = currentAppLocalizations;
    expect(item(l.trayMitm).enabled, isTrue);
    expect(menu().map((i) => i.label), contains(l.mitmPauseNotTrusted));
    final reason = item(l.mitmPauseNotTrusted);
    expect(reason.enabled, isFalse);
    expect(reason.transientStatusKey, 'mitm-trust');

    await select(tester, l.trayMitm);
    await tester.pumpAndSettle();

    expect(settingsOpened, 1);
    expect(find.text(l.mitmEnableTip), findsNothing);
    expect(saved().enable, isFalse);
  });

  testWidgets('turns on through the settings switch\'s own question', (
    tester,
  ) async {
    await pump(tester, mitm: _trusted, certificate: _certificate);
    await update();
    final l = currentAppLocalizations;

    await select(tester, l.trayMitm);
    await tester.pumpAndSettle();
    // The settings come forward, with the switch's question over them.
    expect(settingsOpened, 1);
    expect(find.text(l.mitmEnableTip), findsOneWidget);
    expect(container.read(trayMitmPendingProvider), TrayMitmToggle.mitm);

    // In flight: both items ignore clicks.
    await update();
    expect(item(l.trayMitm).enabled, isFalse);
    expect(item(l.trayMitmCapture).enabled, isFalse);
    expect(item(l.trayMitm).checked, isFalse);
    await container.read(systemActionProvider.notifier).toggleMitmForTray();
    await tester.pumpAndSettle();
    expect(settingsOpened, 1);
    expect(find.text(l.mitmEnableTip), findsOneWidget);

    await tester.tap(confirm());
    await tester.pumpAndSettle();
    expect(saved().enable, isTrue);
    expect(container.read(trayMitmPendingProvider), isNull);
    verifyNever(() => core.generateMitmCertificate());
    await update();
    expect(item(l.trayMitm).checked, isTrue);
    expect(item(l.trayMitm).enabled, isTrue);
  });

  testWidgets('declined, it stays off and takes clicks again', (tester) async {
    await pump(tester, mitm: _trusted, certificate: _certificate);
    await update();
    final l = currentAppLocalizations;

    await select(tester, l.trayMitm);
    await tester.pumpAndSettle();
    await tester.tap(cancel());
    await tester.pumpAndSettle();

    expect(saved().enable, isFalse);
    expect(container.read(trayMitmPendingProvider), isNull);
    await update();
    expect(item(l.trayMitm).checked, isFalse);
    expect(item(l.trayMitm).enabled, isTrue);
  });

  testWidgets('a failure leaves the saved value, and the menu shows it', (
    tester,
  ) async {
    // Trusted earlier, but the certificate is gone: the switch makes one,
    // which fails here.
    await pump(tester, mitm: _trusted);
    when(() => core.generateMitmCertificate()).thenAnswer(
      (_) => Future.error(
        const CoreMethodException(code: 'core_error', message: 'disk full'),
      ),
    );
    await update();
    final l = currentAppLocalizations;

    await select(tester, l.trayMitm);
    await tester.pumpAndSettle();
    await tester.tap(confirm());
    await tester.pumpAndSettle();

    expect(saved().enable, isFalse);
    expect(container.read(trayMitmPendingProvider), isNull);
    await update();
    expect(item(l.trayMitm).checked, isFalse);
    expect(item(l.trayMitm).enabled, isTrue);
  });

  testWidgets('recording waits for decryption, as on the settings page', (
    tester,
  ) async {
    await pump(tester, mitm: _trusted.copyWith(capture: true));
    await update();
    final l = currentAppLocalizations;
    expect(item(l.trayMitmCapture).enabled, isFalse);
    expect(item(l.trayMitmCapture).checked, isTrue);
    final reason = item(l.trayMitmCaptureNeedsMitm);
    expect(reason.enabled, isFalse);
    expect(reason.transientStatusKey, 'mitm-capture');
    expect(item(l.mitmIndicatorOpenSettings).enabled, isTrue);
    // The settings page refuses the same write.
    expect(
      container.read(systemActionProvider.notifier).setMitmCapture(false),
      isFalse,
    );
    expect(saved().capture, isTrue);
    // Even called directly, the tray's action does not write either.
    await container
        .read(systemActionProvider.notifier)
        .toggleMitmCaptureForTray();
    expect(saved().capture, isTrue);
    expect(settingsOpened, 1);

    await select(tester, l.mitmIndicatorOpenSettings);
    await tester.pump();
    expect(settingsOpened, 2);
  });

  testWidgets('recording toggles while on; off keeps the choice', (
    tester,
  ) async {
    await pump(
      tester,
      mitm: _trusted.copyWith(enable: true),
      certificate: _certificate,
    );
    await update();
    final l = currentAppLocalizations;

    await select(tester, l.trayMitmCapture);
    await tester.pumpAndSettle();
    expect(saved().capture, isTrue);
    expect(container.read(trayMitmPendingProvider), isNull);

    // Turning decryption off asks nothing and keeps recording chosen.
    await update();
    await select(tester, l.trayMitm);
    await tester.pumpAndSettle();
    expect(find.text(l.mitmEnableTip), findsNothing);
    expect(saved().enable, isFalse);
    expect(saved().capture, isTrue);
    await update();
    expect(item(l.trayMitmCapture).checked, isTrue);
    expect(item(l.trayMitmCapture).enabled, isFalse);
  });

  testWidgets('sit with system proxy and TUN, only while running', (
    tester,
  ) async {
    await pump(tester, mitm: _trusted);
    await update(isStart: false);
    final labels = menu().map((i) => i.label);
    expect(labels, isNot(contains(currentAppLocalizations.trayMitm)));
  });
}
