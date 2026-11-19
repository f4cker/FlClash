import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_script.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/features/connection/mitm_script_hits.dart';
import 'package:fl_clash/features/mitm/script.dart';
import 'package:fl_clash/features/mitm/script_dialogs.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/mitm_module_confirm.dart';
import 'package:fl_clash/views/config/mitm_modules.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_clash/views/logs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

MitmScript _script(
  int id,
  String line, {
  bool enabled = true,
  String? url,
  String? pending,
  String? error,
  MitmUpdateFailure? failure,
}) => MitmScript(
  id: id,
  profileId: 1,
  line: line,
  enabled: enabled,
  url: url,
  source: url ?? 'own.js',
  file: 's$id.js',
  pendingFile: pending,
  checkedAt: DateTime(2026, 11, 18),
  error: error,
  failure: failure,
);

final _scripts = [
  _script(
    1,
    r'Sign = type=http-request,pattern=^https://api\.a\.com/,script-path=s1.js',
    url: 'https://x.com/sign.js',
  ),
  _script(
    2,
    r'Feed = type=http-response,pattern=^https://api\.a\.com/feed,'
    'requires-body=1,script-path=s2.js',
    url: 'https://x.com/feed.js',
    pending: 's2.next.js',
  ),
  _script(
    3,
    r'Hidden = type=http-response,pattern=^https://c\.org/,script-path=s3.js',
  ),
  _script(
    4,
    r'Broken = type=http-response,pattern=^https://api\.a\.com/x,'
    'script-path=s4.js',
    url: 'https://x.com/broken.js',
    error: 'HTTP 404',
    failure: MitmUpdateFailure.load,
  ),
  _script(
    5,
    r'Stale = type=http-response,pattern=^https://api\.a\.com/y,'
    'script-path=s5.js',
    url: 'https://x.com/stale.js',
    error: 'HTTP 503',
    failure: MitmUpdateFailure.check,
  ),
];

const _module = r'''
#!name=Ads
#!desc=Removes ads
[MITM]
hostname = %APPEND% api.a.com, ads.b.com, -skip.b.com
[URL Rewrite]
^https://ads\.b\.com - reject
[Script]
Clean = type=http-response,pattern=^https://ads\.b\.com/,requires-body=1,script-path=https://x.com/clean.js
[Rule]
DOMAIN,ads.b.com,REJECT
[General]
skip-proxy = a.com
''';

void main() {
  late Database testDatabase;
  late ProviderContainer container;

  setUpAll(
    () async => useAppPaths(Directory.systemTemp.createTempSync('scripts')),
  );

  setUp(() {
    testDatabase = Database(NativeDatabase.memory());
    database = testDatabase;
  });

  tearDown(() => testDatabase.close());

  Future<List<MitmScript>> stored() =>
      database.mitmScriptsDao.queryProfile(1).get();

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    List<MitmScript>? scripts,
    bool decrypting = true,
  }) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await database.profilesDao.putAll([
      const Profile(id: 1, autoUpdateDuration: Duration.zero).toCompanion(),
    ]);
    await database.batch(
      (b) => database.mitmScriptsDao.setProfileWithBatch(
        1,
        b,
        scripts ?? _scripts,
      ),
    );
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(
          () => TestProfiles([
            const Profile(
              id: 1,
              label: 'Daily',
              autoUpdateDuration: Duration.zero,
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.listen(patchClashConfigProvider, (_, _) {});
    container.listen(currentProfileIdProvider, (_, _) {});
    container.read(currentProfileIdProvider.notifier).value = 1;
    container.read(patchClashConfigProvider.notifier).value = PatchClashConfig(
      mitm: Mitm(enable: decrypting, hostname: const ['api.a.com']),
    );
    container
        .read(viewSizeProvider.notifier)
        .update((_) => const Size(1000, 2000));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(child: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'three logs-module-script cycles share the existing logs heading anchor',
    (tester) async {
      final page = ValueNotifier(0);
      addTearDown(page.dispose);
      final pages = ValueListenableBuilder<int>(
        valueListenable: page,
        builder: (_, index, _) => switch (index) {
          0 => const LogsView(),
          1 => const MitmModulesView(),
          _ => const MitmScriptView(),
        },
      );
      await pump(tester, pages, scripts: const []);
      tester.view.physicalSize = const Size(1220, 900);
      container.read(viewSizeProvider.notifier).value = const Size(1220, 900);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(locale: const Locale('zh', 'CN'), child: pages),
        ),
      );
      await tester.pumpAndSettle();

      (Offset, double) heading() {
        final empty = tester.widget<NullStatus>(find.byType(NullStatus));
        final label = find.text(empty.label!);
        final paragraph = tester.renderObject<RenderParagraph>(label);
        return (
          tester.getCenter(find.byType(EmptyIllustration)),
          tester.getTopLeft(label).dy +
              paragraph.getDryBaseline(
                paragraph.constraints,
                TextBaseline.alphabetic,
              )!,
        );
      }

      final baseline = heading();
      Rect? baselineAction;
      for (var cycle = 0; cycle < 3; cycle++) {
        for (final index in [1, 2, 0]) {
          page.value = index;
          await tester.pump();
          await tester.pump();
          if (index == 0) {
            await tester.pumpAndSettle();
          }
          for (final elapsed in [
            Duration.zero,
            const Duration(milliseconds: 16),
            const Duration(milliseconds: 80),
            const Duration(milliseconds: 160),
            const Duration(milliseconds: 400),
            const Duration(milliseconds: 900),
          ]) {
            await tester.pump(elapsed);
            final current = heading();
            expect(current.$1.dx, closeTo(baseline.$1.dx, 1));
            expect(current.$1.dy, closeTo(baseline.$1.dy, 1));
            expect(current.$2, closeTo(baseline.$2, 1));
            if (index != 0) {
              final empty = tester.widget<NullStatus>(find.byType(NullStatus));
              expect(empty.animate, isFalse);
              expect(empty.anchorToHeading, isTrue);
              final action = tester.getRect(find.byWidget(empty.action!));
              baselineAction ??= action;
              expect(action, baselineAction);
              expect(action.height, 40);
            }
          }
        }
      }
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      page.value = 0;
      await tester.pumpAndSettle();
      final scaledBaseline = heading();
      for (final index in [1, 2]) {
        page.value = index;
        await tester.pumpAndSettle();
        final scaled = heading();
        expect(scaled.$1.dy, closeTo(scaledBaseline.$1.dy, 1));
        expect(scaled.$2, closeTo(scaledBaseline.$2, 1));
      }
      final empty = tester.widget<NullStatus>(find.byType(NullStatus));
      final description = tester.getRect(find.text(empty.description!));
      expect(description.height, greaterThanOrEqualTo(80));
      final action = tester.getRect(find.byWidget(empty.action!));
      expect(action.top - description.bottom, closeTo(24, 0.01));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('the entry counts scripts, updates and errors', (tester) async {
    await pump(tester, const MitmScriptEntryItem());
    final l = currentAppLocalizations;

    expect(find.text(l.mitmScripts), findsOneWidget);
    expect(
      find.text(
        '${l.mitmScriptCount(5)} · ${l.mitmUpdateCount(1)} · '
        '${l.mitmScriptInvalidCount(1)}',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('the page groups scripts and marks each state', (tester) async {
    await pump(tester, const MitmScriptView());
    final l = currentAppLocalizations;

    expect(find.text(l.mitmScriptGroupRequest), findsOneWidget);
    expect(find.text(l.mitmScriptGroupResponse), findsOneWidget);
    expect(find.text(l.mitmViewUpdate), findsOneWidget);
    expect(
      find.textContaining(
        l.mitmScriptLoadFailed('HTTP 404'),
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(l.mitmUpdateCheckFailedKept, findRichText: true),
      findsOneWidget,
    );
    expect(find.text(l.retry), findsNWidgets(2));
    expect(
      find.text(l.mitmScriptHostNotDecrypted, findRichText: true),
      findsOneWidget,
    );
    expect(find.text(l.mitmAddToDecryption), findsOneWidget);
    expect(find.text(l.mitmScriptNeedsBody), findsOneWidget);
  });

  testWidgets('a switch saves the script turned off', (tester) async {
    await pump(tester, const MitmScriptView());

    await tester.tap(find.byType(Switch).first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect((await stored()).first.enabled, isFalse);
  });

  testWidgets('with decryption off the page says scripts do not run', (
    tester,
  ) async {
    await pump(tester, const MitmScriptView(), decrypting: false);
    expect(
      find.text(currentAppLocalizations.mitmScriptsOff, findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('with no scripts the page offers to add one', (tester) async {
    await pump(tester, const MitmScriptView(), scripts: const []);
    final l = currentAppLocalizations;

    expect(find.text(l.mitmScriptsEmptyTitle), findsOneWidget);
    expect(find.text(l.mitmAddScript), findsOneWidget);
    expect(find.byKey(MitmScriptView.addKey), findsNothing);
  });

  testWidgets('a paste is checked line by line, then confirmed with what '
      'scripts can do', (tester) async {
    await pump(tester, const MitmScriptView(), scripts: const []);
    final l = currentAppLocalizations;

    await tester.tap(find.text(l.mitmAddScript));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText),
      'New = type=http-response,pattern=^https://d\\.net/,'
      'script-path=https://x.com/new.js\n'
      'C = type=cron,cronexp=1,script-path=https://x.com/c.js',
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.textContaining(
        l.mitmScriptPasteLineError(2, l.mitmScriptUnsupportedType),
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(l.mitmContinue));
    await tester.pumpAndSettle();

    expect(find.text(l.mitmScriptConfirmTitle), findsOneWidget);
    expect(find.text(l.mitmCapabilityRead), findsOneWidget);
    expect(find.text(l.mitmCapabilitySend), findsOneWidget);
    expect(find.text(l.mitmCapabilityStore), findsOneWidget);
    expect(find.text(l.mitmCapabilityNotify), findsOneWidget);
    expect(find.text(l.mitmHostNotDecrypted('d.net')), findsOneWidget);
    expect(find.text(l.mitmAlsoDecryptHost('d.net')), findsOneWidget);
    expect(find.text(l.mitmAddAndEnable), findsOneWidget);
  });

  testWidgets('an update shows its diff and is used only when chosen', (
    tester,
  ) async {
    await pump(tester, const SizedBox(), scripts: const []);
    final context = tester.element(find.byType(SizedBox));
    var adopted = 0;
    final result = showMitmUpdateDialog(
      context,
      name: 'Feed',
      subtitle: 'Found today',
      before: 'a\nb\nc',
      after: 'a\nB\nc\nd',
      onAdopt: () async => adopted++,
    );
    await tester.pumpAndSettle();
    final l = currentAppLocalizations;

    expect(find.text(l.mitmUpdateTitle('Feed')), findsOneWidget);
    expect(find.text('Found today'), findsOneWidget);
    expect(
      find.text(
        '${l.mitmDiffAdded(2)}  ${l.mitmDiffRemoved(1)}',
        findRichText: true,
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(l.mitmAdoptUpdate));
    await tester.pumpAndSettle();

    expect(adopted, 1);
    expect(await result, isTrue);
  });

  testWidgets('a module is shown before it is saved; Import Only keeps it '
      'off', (tester) async {
    await pump(tester, const SizedBox(), scripts: const []);
    final context = tester.element(find.byType(SizedBox));
    bool? enabled;
    bool? rules;
    final result = showMitmModuleConfirmDialog(
      context,
      content: previewMitmModule(_module),
      name: 'Ads',
      source: 'x.com',
      onImport: (enable, withRules) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        enabled = enable;
        rules = withRules;
      },
    );
    await tester.pumpAndSettle();
    final l = currentAppLocalizations;

    expect(find.text(l.mitmModuleConfirmTitle), findsOneWidget);
    expect(find.text('ads.b.com'), findsOneWidget);
    expect(
      find.textContaining(l.mitmAlreadyListed, findRichText: true),
      findsOneWidget,
    );
    expect(find.text(l.mitmExcludedCount(1)), findsOneWidget);
    expect(find.text(l.mitmCapabilityRead), findsOneWidget);
    expect(find.text(l.mitmModuleRulesDesc), findsOneWidget);
    expect(
      find.text('DOMAIN,ads.b.com,REJECT', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.mitmImportOnly));
    await tester.pumpAndSettle();

    expect(enabled, isFalse);
    expect(rules, isFalse);
    expect(await result, isNotNull);
  });

  testWidgets('hostnames the Core would skip are named before import', (
    tester,
  ) async {
    await pump(tester, const SizedBox(), scripts: const []);
    final context = tester.element(find.byType(SizedBox));
    unawaited(
      showMitmModuleConfirmDialog(
        context,
        content: previewMitmModule('''
#!name=Ports
[MITM]
hostname = %APPEND% a.com:443, b.com:8443, api*.c.com, d.com
'''),
        name: 'Ports',
        source: 'x.com',
        onImport: (_, _) async {},
      ),
    );
    await tester.pumpAndSettle();
    final l = currentAppLocalizations;

    expect(
      find.text(l.mitmModuleHostsIgnored('b.com:8443, api*.c.com')),
      findsOneWidget,
    );
  });

  testWidgets('a module with plain hostnames shows no ignored notice', (
    tester,
  ) async {
    await pump(tester, const SizedBox(), scripts: const []);
    final context = tester.element(find.byType(SizedBox));
    unawaited(
      showMitmModuleConfirmDialog(
        context,
        content: previewMitmModule(_module),
        name: 'Ads',
        source: 'x.com',
        onImport: (_, _) async {},
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(currentAppLocalizations.mitmHostFormatHint),
      findsNothing,
    );
    expect(find.textContaining('api.a.com'), findsWidgets);
  });

  testWidgets('the request detail lists each script run and why one did not '
      'finish', (tester) async {
    final exchange = MitmExchange(
      id: 1,
      start: DateTime(2026, 11, 18),
      method: 'GET',
      url: 'https://api.a.com/feed',
      actions: const [
        MitmAction(
          kind: mitmScriptKind,
          phase: 'request',
          detail: 'Sign',
          rule: 's1',
          tookNs: 12000000,
          logs: [MitmScriptLog(level: 'log', text: 'signed')],
          requests: [
            MitmScriptRequest(
              method: 'GET',
              url: 'https://x.com/t',
              status: 200,
            ),
          ],
        ),
        MitmAction(
          kind: mitmScriptKind,
          phase: 'response',
          detail: 'Feed',
          rule: 's2',
          skipped: 'scriptTimeout',
        ),
      ],
    );
    await pump(
      tester,
      SingleChildScrollView(child: MitmScriptHitsSection(exchange: exchange)),
    );
    final l = currentAppLocalizations;

    expect(find.text(l.mitmScriptsPassed(1)), findsOneWidget);
    expect(find.text(l.mitmScriptTimedOut), findsOneWidget);
    expect(find.textContaining('signed', findRichText: true), findsOneWidget);
    expect(
      find.textContaining(l.mitmScriptRequestsSent(1), findRichText: true),
      findsOneWidget,
    );
    expect(find.text(l.mitmViewInScripts), findsNWidgets(2));
  });
}
