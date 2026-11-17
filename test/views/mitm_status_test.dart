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

import '../helpers/core_connections.dart';
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
      bool decrypting = false,
    }) => mitmIndicatorOf(
      enabled: enabled,
      coreConnected: coreConnected,
      coreRefused: coreRefused,
      status: status,
      decrypting: decrypting,
    );

    test('says nothing while decryption is off', () {
      expect(of(enabled: false), isNull);
    });

    test('is on when the Core says so, decrypting only with a connection', () {
      expect(of(), const MitmIndicator.on());
      expect(of(decrypting: true), const MitmIndicator.decrypting());
      expect(of(status: null), const MitmIndicator.unconfirmed());
      expect(
        of(status: null, decrypting: true),
        const MitmIndicator.unconfirmed(),
      );
      expect(
        of(
          status: const MitmStatus(enable: true, paused: 'indicatorPending'),
          decrypting: true,
        ),
        const MitmIndicator.paused(MitmPauseReason.indicatorPending),
      );
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
      expect(mitmIndicatorText(l, const MitmIndicator.on()), '解密已开启');
      expect(mitmIndicatorText(l, const MitmIndicator.decrypting()), '正在解密');
      expect(
        mitmIndicatorText(
          l,
          const MitmIndicator.paused(MitmPauseReason.notTrusted),
        ),
        '解密已暂停：根证书未生成或未受信任',
      );
      final en = lookupAppLocalizations(const Locale('en'));
      expect(mitmIndicatorText(en, const MitmIndicator.on()), 'Decryption on');
      expect(
        mitmIndicatorText(
          en,
          const MitmIndicator.paused(MitmPauseReason.coreStopped),
        ),
        'Decryption paused: core is not running',
      );
      expect(
        mitmIndicatorLabel(en, const MitmIndicator.unconfirmed()),
        'Checking decryption status',
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
      List<TrackerInfo> requests = const [],
      List<TrackerInfo> connections = const [],
    }) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      core = _MockCore();
      when(() => core.getMitmStatus()).thenAnswer((_) async => status);
      when(() => core.getMitmCertificate()).thenAnswer((_) async => null);
      whenConnections<bool>(core, () async => connections);
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
      for (final request in requests) {
        container.read(requestsProvider.notifier).addRequest(request);
      }
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

    testWidgets('says decrypting only while a decrypted connection is open', (
      tester,
    ) async {
      TrackerInfo info(String id, {bool mitm = false}) => TrackerInfo(
        id: id,
        start: DateTime(2026),
        metadata: Metadata(network: 'tcp', host: '$id.test', mitm: mitm),
        chains: const [],
        rule: '',
        rulePayload: '',
      );
      final l = currentAppLocalizations;

      // Decrypted earlier, but that connection has closed.
      await pump(
        tester,
        mitm: const Mitm(enable: true),
        requests: [info('old', mitm: true), info('plain')],
        connections: [info('plain')],
      );
      await tester.pump();
      expect(find.text(l.mitmIndicatorOn), findsOneWidget);
      expect(find.text(l.mitmIndicatorDecrypting), findsNothing);
      await settle(tester);

      await pump(
        tester,
        mitm: const Mitm(enable: true),
        requests: [info('live', mitm: true), info('plain')],
        connections: [info('live'), info('plain')],
      );
      await tester.pump();
      expect(find.text(l.mitmIndicatorDecrypting), findsOneWidget);
      await settle(tester);
    });

    testWidgets('does not read the connections while paused', (tester) async {
      await pump(
        tester,
        mitm: const Mitm(enable: true),
        status: const MitmStatus(enable: true, paused: 'indicatorPending'),
        requests: [
          TrackerInfo(
            id: 'live',
            start: DateTime(2026),
            metadata: const Metadata(mitm: true),
            chains: const [],
            rule: '',
            rulePayload: '',
          ),
        ],
      );
      verifyNever(() => core.getConnectionsWith<bool>(any()));
      await settle(tester);
    });

    testWidgets('opens the MITM settings, whose own bar leaves it out', (
      tester,
    ) async {
      await pump(tester, mitm: const Mitm(enable: true));
      expect(
        find.text(currentAppLocalizations.mitmIndicatorOn),
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
