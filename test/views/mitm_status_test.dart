import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_indicator.dart';
import 'package:fl_clash/common/tray.dart'
    show mitmDotAmber, mitmDotRed, mitmTrayDot;
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
import 'package:rust_api/tray.dart' show TrayDot;

import '../helpers/core_connections.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

/// The bar's round button says its status only in its tooltip and label.
Finder statusTip(String text) => find.bySemanticsLabel(
  '$text. ${currentAppLocalizations.mitmIndicatorOpenSettings}',
);

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
      bool trusted = false,
      bool hostsListed = false,
    }) => mitmIndicatorOf(
      enabled: enabled,
      coreConnected: coreConnected,
      coreRefused: coreRefused,
      status: status,
      decrypting: decrypting,
      trusted: trusted,
      hostsListed: hostsListed,
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

    test('the Core\'s standing partialConnections caveat reads as on', () {
      // core/mitm.go mitmStatus reports it whenever it decrypts and nothing
      // is paused: a caveat, not a pause.
      const status = MitmStatus(enable: true, paused: 'partialConnections');
      expect(of(status: status), const MitmIndicator.on());
      expect(of(status: status, trusted: true), const MitmIndicator.on());
      expect(
        of(status: status, trusted: true, hostsListed: true),
        const MitmIndicator.on(),
      );
      final indicator = of(status: status)!;
      expect(indicator.reason, isNull);
      for (final locale in const [Locale('zh'), Locale('en')]) {
        final l = lookupAppLocalizations(locale);
        expect(mitmIndicatorText(l, indicator), l.mitmIndicatorOn);
        expect(mitmIndicatorLabel(l, indicator), l.mitmIndicatorOn);
        expect(
          mitmIndicatorText(l, indicator),
          isNot(l.mitmPartialConnections),
        );
      }
      expect(
        mitmIndicatorText(
          lookupAppLocalizations(const Locale('zh')),
          indicator,
        ),
        '解密已开启',
      );
      // The decryption page still maps it, to say it as information.
      expect(
        mitmCorePauseReason('partialConnections'),
        MitmPauseReason.partialConnections,
      );
    });

    test('every real reason still pauses, with its words', () {
      final zh = lookupAppLocalizations(const Locale('zh'));
      String paused(String reason) => zh.mitmIndicatorPausedBecause(reason);
      final cases = <(String, MitmIndicator?, MitmIndicator, String)>[
        (
          'core stopped',
          of(coreConnected: false),
          const MitmIndicator.paused(MitmPauseReason.coreStopped),
          paused(zh.mitmPauseCoreStopped),
        ),
        (
          'core refused',
          of(coreRefused: true),
          const MitmIndicator.paused(MitmPauseReason.coreIdentity),
          paused(zh.mitmPauseCoreIdentity),
        ),
        (
          'not trusted',
          of(status: const MitmStatus()),
          const MitmIndicator.paused(MitmPauseReason.notTrusted),
          '解密已暂停：根证书未生成或未受信任',
        ),
        (
          'not applied',
          of(status: const MitmStatus(), trusted: true, hostsListed: true),
          const MitmIndicator.paused(MitmPauseReason.notApplied),
          '解密未生效：设置还没应用到内核',
        ),
        for (final (core, reason, words) in [
          (
            'livenessUnavailable',
            MitmPauseReason.liveness,
            zh.mitmPauseLiveness,
          ),
          ('trustUnavailable', MitmPauseReason.liveness, zh.mitmPauseLiveness),
          (
            'indicatorPending',
            MitmPauseReason.indicatorPending,
            zh.mitmPauseIndicatorPending,
          ),
          (
            'coreIdentity',
            MitmPauseReason.coreIdentity,
            zh.mitmPauseCoreIdentity,
          ),
          (
            'appUnavailable',
            MitmPauseReason.appUnavailable,
            zh.mitmPauseAppUnavailable,
          ),
          ('signTimeout', MitmPauseReason.signTimeout, zh.mitmPauseSignTimeout),
          (
            'leafUnusable',
            MitmPauseReason.leafUnusable,
            zh.mitmPauseLeafUnusable,
          ),
          ('signFailed', MitmPauseReason.signRefused, zh.mitmPauseSignRefused),
          ('signBusy', MitmPauseReason.signRefused, zh.mitmPauseSignRefused),
          ('disabled', MitmPauseReason.signRefused, zh.mitmPauseSignRefused),
          (
            'somethingNew',
            MitmPauseReason.unavailable,
            zh.mitmPauseUnavailable,
          ),
        ])
          (
            core,
            of(status: MitmStatus(enable: true, paused: core)),
            MitmIndicator.paused(reason),
            paused(words),
          ),
      ];
      for (final (name, actual, expected, text) in cases) {
        expect(actual, expected, reason: name);
        expect(actual!.kind, MitmIndicatorKind.paused, reason: name);
        expect(mitmIndicatorText(zh, actual), text, reason: name);
        expect(
          mitmTrayDot(actual),
          const TrayDot(color: mitmDotAmber, breathing: false),
          reason: name,
        );
      }
    });

    test('names why it is paused', () {
      const cases = {
        'livenessUnavailable': MitmPauseReason.liveness,
        'trustUnavailable': MitmPauseReason.liveness,
        'indicatorPending': MitmPauseReason.indicatorPending,
        'coreIdentity': MitmPauseReason.coreIdentity,
        'appUnavailable': MitmPauseReason.appUnavailable,
        'signTimeout': MitmPauseReason.signTimeout,
        'leafUnusable': MitmPauseReason.leafUnusable,
        'signBusy': MitmPauseReason.signRefused,
        'somethingNew': MitmPauseReason.unavailable,
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

    test(
      'a Core that does not decrypt is "not trusted" only without trust',
      () {
        // Trust missing on this device: the old wording, listed hosts or not.
        for (final listed in [false, true]) {
          expect(
            of(status: const MitmStatus(), hostsListed: listed),
            const MitmIndicator.paused(MitmPauseReason.notTrusted),
          );
        }
        // Trusted and hosts listed: the settings did not reach the Core.
        expect(
          of(status: const MitmStatus(), trusted: true, hostsListed: true),
          const MitmIndicator.paused(MitmPauseReason.notApplied),
        );
        // Trusted with nothing listed: nothing to decrypt, nothing missing.
        expect(
          of(status: const MitmStatus(), trusted: true),
          const MitmIndicator.on(),
        );
        // The Core's own answer still wins once it decrypts.
        expect(of(trusted: true, hostsListed: true), const MitmIndicator.on());
        expect(
          of(status: null, trusted: true, hostsListed: true),
          const MitmIndicator.unconfirmed(),
        );
      },
    );

    test('"not applied" reads as its own sentence', () {
      const indicator = MitmIndicator.paused(MitmPauseReason.notApplied);
      expect(
        mitmIndicatorText(
          lookupAppLocalizations(const Locale('zh')),
          indicator,
        ),
        '解密未生效：设置还没应用到内核',
      );
      expect(
        mitmIndicatorText(
          lookupAppLocalizations(const Locale('en')),
          indicator,
        ),
        'Decryption not active: settings not applied to the core yet',
      );
    });

    test('reads in full with its reason', () {
      final l = lookupAppLocalizations(const Locale('zh'));
      final en = lookupAppLocalizations(const Locale('en'));
      const partial = MitmIndicator.paused(MitmPauseReason.partialConnections);
      expect(mitmIndicatorLabel(l, partial), '部分连接可能未解密');
      expect(mitmIndicatorText(l, partial), '部分连接可能未解密');
      expect(
        mitmIndicatorLabel(en, partial),
        'Some connections may not be decrypted',
      );
      expect(mitmIndicatorText(l, const MitmIndicator.on()), '解密已开启');
      expect(mitmIndicatorText(l, const MitmIndicator.decrypting()), '正在解密');
      expect(
        mitmIndicatorText(
          l,
          const MitmIndicator.paused(MitmPauseReason.notTrusted),
        ),
        '解密已暂停：根证书未生成或未受信任',
      );
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
        statusTip(l.mitmIndicatorPausedBecause(l.mitmPauseIndicatorPending)),
        findsOneWidget,
      );
      await settle(tester);
    });

    testWidgets('stays on, breathing, without reading the live connections', (
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

      // A decrypted connection is still open, and the Core reports its
      // standing caveat: the status is on, and nothing polls connections.
      await pump(
        tester,
        mitm: const Mitm(enable: true),
        status: const MitmStatus(enable: true, paused: 'partialConnections'),
        requests: [info('live', mitm: true), info('plain')],
        connections: [info('live'), info('plain')],
      );
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 2));
      }
      expect(statusTip(l.mitmIndicatorOn), findsOneWidget);
      expect(statusTip(l.mitmIndicatorDecrypting), findsNothing);
      expect(statusTip(l.mitmPartialConnections), findsNothing);
      final indicator = container.read(mitmIndicatorProvider);
      expect(indicator, const MitmIndicator.on());
      expect(
        mitmTrayDot(indicator),
        const TrayDot(color: mitmDotRed, breathing: true),
      );
      expect(container.exists(mitmDecryptingProvider), isFalse);
      verifyNever(() => core.getConnectionsWith<bool>(any()));
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

    testWidgets('beside a sidebar, opens its decryption page', (tester) async {
      await pump(tester, mitm: const Mitm(enable: true));

      await tester.tap(find.byType(MitmStatusCapsule));
      await tester.pump();

      expect(container.read(currentPageLabelProvider), PageLabel.mitm);
      expect(find.byType(MitmView), findsNothing);
      await settle(tester);
    });

    testWidgets('opens the MITM settings, whose own bar leaves it out', (
      tester,
    ) async {
      await pump(tester, mitm: const Mitm(enable: true));
      // A phone-wide window has no sidebar to list the page in.
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(400, 800));
      await tester.pump();
      expect(
        statusTip(currentAppLocalizations.mitmIndicatorOn),
        findsOneWidget,
      );
      await tester.tap(find.byType(MitmStatusCapsule));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(MitmView), findsOneWidget);
      // The page covers the one it came from, and its own bar adds none.
      expect(find.byType(MitmStatusCapsule), findsNothing);
      await settle(tester);
    });
  });
}
