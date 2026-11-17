import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_indicator.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/mitm.dart';
import 'package:fl_clash/views/config/mitm_status.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

void main() {
  setUpAll(() {
    registerFallbackValue(const MitmRules());
  });

  group('mitmIndicatorOf', () {
    MitmIndicator? of({
      bool enabled = true,
      bool coreConnected = true,
      bool coreRefused = false,
      MitmStatus? status = const MitmStatus(enable: true),
    }) => mitmIndicatorOf(
      enabled: enabled,
      coreConnected: coreConnected,
      coreRefused: coreRefused,
      status: status,
    );

    test('says nothing while decryption is off', () {
      expect(of(enabled: false), isNull);
    });

    test('decrypts only when the Core says so', () {
      expect(of(), const MitmIndicator.decrypting());
      expect(of(status: null), const MitmIndicator.unconfirmed());
    });

    test('names why it is paused', () {
      const cases = {
        'livenessUnavailable': MitmPauseReason.liveness,
        'trustUnavailable': MitmPauseReason.liveness,
        'indicatorPending': MitmPauseReason.indicatorPending,
        'coreIdentity': MitmPauseReason.coreIdentity,
        'appUnavailable': MitmPauseReason.unavailable,
        'signTimeout': MitmPauseReason.unavailable,
        'leafRejected': MitmPauseReason.unavailable,
      };
      for (final MapEntry(key: paused, value: reason) in cases.entries) {
        expect(
          of(status: MitmStatus(enable: true, paused: paused)),
          MitmIndicator.paused(reason),
          reason: paused,
        );
      }
      expect(
        of(coreConnected: false),
        const MitmIndicator.paused(MitmPauseReason.coreStopped),
      );
      expect(
        of(coreRefused: true),
        const MitmIndicator.paused(MitmPauseReason.coreIdentity),
      );
      expect(
        of(status: const MitmStatus()),
        const MitmIndicator.paused(MitmPauseReason.notTrusted),
      );
    });

    test('reads in full with its reason', () {
      final l = lookupAppLocalizations(const Locale('zh'));
      expect(mitmIndicatorText(l, const MitmIndicator.decrypting()), '正在解密');
      expect(
        mitmIndicatorText(
          l,
          const MitmIndicator.paused(MitmPauseReason.notTrusted),
        ),
        '解密已暂停：根证书未生成或未信任',
      );
      expect(
        mitmIndicatorLabel(l, const MitmIndicator.unconfirmed()),
        '正在确认解密状态',
      );
    });
  });

  group('the bar status', () {
    late ProviderContainer container;
    late _MockCore core;

    setUp(() {
      mitmFeature = true;
    });

    tearDown(() {
      mitmFeature = false;
    });

    Future<void> pump(
      WidgetTester tester, {
      required Mitm mitm,
      MitmStatus status = const MitmStatus(enable: true),
      Widget? page,
    }) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      core = _MockCore();
      when(() => core.getMitmStatus()).thenAnswer((_) async => status);
      when(() => core.getMitmCertificate()).thenAnswer((_) async => null);
      when(
        () => core.validateMitm(any()),
      ).thenAnswer((_) async => {for (final list in MitmList.values) list: {}});
      container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
          mitmTrustStoreProvider.overrideWithValue(null),
          mitmSignerProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.listen(patchClashConfigProvider, (_, _) {});
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(1000, 800));
      container.read(patchClashConfigProvider.notifier).value =
          PatchClashConfig(mitm: mitm);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            child: ScaffoldBarStatus(
              status: const MitmBarStatus(),
              child:
                  page ??
                  const Scaffold(
                    title: 'Page',
                    body: Scaffold(title: 'Inner', body: SizedBox.expand()),
                  ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> settle(WidgetTester tester) async {
      // The status polls every two seconds; leave its timer behind.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
    }

    testWidgets('shows nothing and asks nothing while decryption is off', (
      tester,
    ) async {
      await pump(tester, mitm: const Mitm());
      expect(find.byType(MitmStatusCapsule), findsNothing);
      verifyNever(() => core.getMitmStatus());
      await settle(tester);
    });

    testWidgets('is in the page bar once, not in a bar inside the page', (
      tester,
    ) async {
      await pump(
        tester,
        mitm: const Mitm(enable: true),
        status: const MitmStatus(enable: true, paused: 'indicatorPending'),
      );
      expect(find.byType(MitmStatusCapsule), findsOneWidget);
      final l = currentAppLocalizations;
      expect(
        find.text(l.mitmIndicatorPausedBecause(l.mitmPauseIndicatorPending)),
        findsOneWidget,
      );
      await settle(tester);
    });

    testWidgets('opens the MITM settings, whose own bar leaves it out', (
      tester,
    ) async {
      await pump(tester, mitm: const Mitm(enable: true));
      expect(
        find.text(currentAppLocalizations.mitmIndicatorDecrypting),
        findsOneWidget,
      );
      await tester.tap(find.byType(MitmStatusCapsule));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(MitmView), findsOneWidget);
      expect(find.byType(MitmStatusCapsule), findsOneWidget);
      await settle(tester);
    });
  });
}
