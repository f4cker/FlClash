import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/icons/app_glyphs.dart';
import 'package:fl_clash/views/config/mitm_modules.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_app.dart';

const _module = r'''
#!name=Ads
#!desc=Removes ads
#!arguments=Toggle:true
[MITM]
hostname = %APPEND% *.example.com
[URL Rewrite]
^https://example\.com/a _ reject
bad line
[General]
skip-proxy = example.com
[Script]
Ads = type=http-response,pattern=^https://example\.com/b,script-path=https://example.com/ads.js
cron "0 8 * * *" script-path=https://example.com/daily.js, tag=Daily
''';

const _resources = {
  'https://example.com/ads.js': 'ads.js',
  'https://example.com/daily.js': 'daily.js',
};

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

class _ArgumentAction extends MitmModulesAction {
  @override
  Future<MitmModule?> setArguments(
    MitmModule module,
    Map<String, String> arguments,
  ) async {
    final saved = module.copyWith(arguments: arguments);
    putModule(saved);
    return saved;
  }
}

class _ScriptedSetupAction extends SetupAction {
  _ScriptedSetupAction(this.results);

  final List<bool> results;
  int calls = 0;

  @override
  Future<bool> applyProfile({
    bool Function()? owns,
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async => results[calls++];
}

final _remote = MitmModule(
  id: 1,
  name: 'Ads',
  description: 'Removes ads',
  url: 'https://example.com/ads.sgmodule',
  lastUpdateTime: DateTime(2026, 10, 24),
  order: 0,
);

final _local = MitmModule(
  id: 2,
  name: 'Mine',
  enabled: false,
  scripts: 1,
  resources: const {'own.js': 'h1.js'},
  lastUpdateTime: DateTime(2026, 10, 24),
  order: 1,
);

void main() {
  late Database testDatabase;
  late ProviderContainer container;

  setUp(() {
    testDatabase = Database(NativeDatabase.memory());
    database = testDatabase;
  });

  tearDown(() => testDatabase.close());

  Future<List<MitmModule>> stored() => database.mitmModulesDao.query().get();

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    CoreHandlerInterface? core,
    bool fakeArguments = false,
  }) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await database.mitmModulesDao.putAll([
      _remote.toCompanion(),
      _local.toCompanion(),
    ]);
    final content = parseMitmModule(_module, resources: _resources);
    container = ProviderContainer(
      overrides: [
        mitmModuleDetailsProvider(_local.id).overrideWith((ref) async => null),
        mitmModuleContentProvider(_local.id).overrideWith(
          (ref) async => parseMitmModule(
            '[Script]\nOwn = type=http-response,pattern=.*,script-path=own.js',
          ),
        ),
        if (fakeArguments)
          mitmModulesActionProvider.overrideWith(_ArgumentAction.new),
        if (core != null)
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        mitmModuleDetailsProvider(_remote.id).overrideWith(
          (ref) async => (
            content: content,
            views: const <MitmList, Map<String, MitmLineView>>{},
            issues: {
              MitmList.urlRewrite: {'bad line': 'unknown type'},
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
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

  testWidgets('empty modules use the navigation puzzle glyph', (tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: MitmModulesView()),
      ),
    );
    await tester.pumpAndSettle();

    final illustration = tester.widget<EmptyIllustration>(
      find.byType(EmptyIllustration),
    );
    expect(illustration.type, NullStatusIllustration.modules);
    expect(illustration.type.glyph, same(AppGlyphs.puzzle));
  });

  testWidgets('the list shows each module and turns one off', (tester) async {
    await pump(tester, const MitmModulesView());

    expect(find.text('Ads'), findsOneWidget);
    expect(
      find.textContaining('Remote · updated', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Mine'), findsOneWidget);
    expect(
      find.text(
        currentAppLocalizations.mitmModuleLocalSource,
        findRichText: true,
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    final modules = await stored();
    expect(modules.first.enabled, isFalse);
    expect(modules.last.enabled, isFalse);
  });

  testWidgets('a module with scripts asks before it turns on', (tester) async {
    await pump(tester, const MitmModulesView());

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    expect(
      find.text(currentAppLocalizations.mitmScriptRiskTitle),
      findsOneWidget,
    );
    await tester.tap(find.text(currentAppLocalizations.cancel));
    await tester.pumpAndSettle();
    expect((await stored()).last.enabled, isFalse);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(currentAppLocalizations.turnOn));
    await tester.pumpAndSettle();
    expect((await stored()).last.enabled, isTrue);
  });

  testWidgets('the details show what the module adds and leaves out', (
    tester,
  ) async {
    await pump(tester, MitmModuleView(id: _remote.id));

    expect(find.text('Removes ads'), findsOneWidget);
    expect(find.text('Toggle'), findsOneWidget);
    expect(find.text(MitmList.hostname.label), findsOneWidget);
    expect(
      find.text(currentAppLocalizations.invalidOfCount(1, 2)),
      findsOneWidget,
    );

    await tester.tap(find.text(currentAppLocalizations.mitmIgnoredLines));
    await tester.pumpAndSettle();

    expect(find.text('bypassDomain'), findsOneWidget);
    expect(
      find.text(currentAppLocalizations.mitmSkipSetting),
      findsNWidgets(2),
    );
  });

  testWidgets('unsupported cron scripts cannot be run from the menu', (
    tester,
  ) async {
    final core = _MockCoreHandlerInterface();
    await pump(tester, MitmModuleView(id: _remote.id), core: core);
    container.listen(patchClashConfigProvider, (_, _) {});
    container.read(patchClashConfigProvider.notifier).value =
        const PatchClashConfig(mitm: Mitm(enable: true));
    await tester.tap(find.text(MitmList.script.label));
    await tester.pumpAndSettle();
    await tester.longPress(find.textContaining('Daily = '));
    await tester.pumpAndSettle();
    expect(find.text(currentAppLocalizations.mitmRunScript), findsNothing);
    verifyNever(() => core.runMitmScript('Daily'));
  });

  testWidgets('an argument is saved on the module', (tester) async {
    await pump(tester, MitmModuleView(id: _remote.id), fakeArguments: true);
    await tester.tap(find.text('Toggle'));
    await tester.pumpAndSettle();
    expect((await stored()).first.arguments, {'Toggle': 'false'});
  });

  testWidgets('only a local module is edited and takes attachments', (
    tester,
  ) async {
    await pump(tester, MitmModuleView(id: _local.id));

    expect(find.text(currentAppLocalizations.edit), findsOneWidget);
    expect(find.text(currentAppLocalizations.mitmAttachments), findsOneWidget);
    expect(find.text('own.js'), findsOneWidget);
    expect(find.text(currentAppLocalizations.update), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(child: MitmModuleView(id: _remote.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(currentAppLocalizations.edit), findsNothing);
    expect(find.text(currentAppLocalizations.mitmAttachments), findsNothing);
    expect(find.text(currentAppLocalizations.update), findsOneWidget);
  });

  testWidgets('removing an attachment asks first', (tester) async {
    await pump(tester, MitmModuleView(id: _local.id));

    await tester.longPress(find.text('own.js'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(currentAppLocalizations.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(currentAppLocalizations.cancel));
    await tester.pumpAndSettle();
    expect((await stored()).last.resources, _local.resources);

    await tester.longPress(find.text('own.js'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(currentAppLocalizations.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text(currentAppLocalizations.delete).last);
    await tester.pumpAndSettle();
    expect((await stored()).last.resources, isEmpty);
  });

  testWidgets('an install link resolves to the module it names', (
    tester,
  ) async {
    await pump(tester, const MitmModulesView());
    final l10n = currentAppLocalizations;

    await tester.tap(find.text(l10n.mitmImportModule));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.importUrl));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText),
      'surge:///install-module?url=${Uri.encodeComponent(_remote.url!)}',
    );
    await tester.tap(find.text(l10n.submit));
    await tester.pumpAndSettle();

    expect(find.text(l10n.existsTip(l10n.mitmModule)), findsOneWidget);
    expect(await stored(), hasLength(2));
  });

  testWidgets('a module can be written from the add menu', (tester) async {
    await pump(tester, const MitmModulesView());

    await tester.tap(find.text(currentAppLocalizations.mitmImportModule));
    await tester.pumpAndSettle();

    expect(find.text(currentAppLocalizations.mitmNewModule), findsOneWidget);
  });

  for (final (restored, banner) in [
    (true, 'mitmRoutingRulesNotApplied'),
    (false, 'mitmRoutingRulesRevertFailed'),
  ]) {
    testWidgets('routing rules that fail to apply are turned back; restored '
        '$restored', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await database.mitmModulesDao.putAll([_remote.toCompanion()]);
      final setup = _ScriptedSetupAction([false, restored]);
      container = ProviderContainer(
        overrides: [
          setupActionProvider.overrideWith(() => setup),
          mitmModuleDetailsProvider(_remote.id).overrideWith(
            (ref) async => (
              content: parseMitmModule(
                '$_module[Rule]\nDOMAIN,ads.example.com,REJECT\n',
                resources: _resources,
              ),
              issues: const <MitmList, Map<String, String>>{},
              views: const <MitmList, Map<String, MitmLineView>>{},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.listen(patchClashConfigProvider, (_, _) {});
      container.read(patchClashConfigProvider.notifier).value =
          const PatchClashConfig(mitm: Mitm(enable: true));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: HostApp(
            navigatorKey: globalState.navigatorKey,
            builder: (context, child) => BannerHost(
              stacked: false,
              topInset: 0,
              child: wrapAppScopes(context, child!),
            ),
            home: MitmModuleView(id: _remote.id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = currentAppLocalizations;

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      expect(setup.calls, 2);
      expect((await stored()).single.rulesEnabled, isTrue);
      expect(
        find.text(
          restored
              ? l.mitmRoutingRulesNotApplied
              : l.mitmRoutingRulesRevertFailed,
        ),
        findsOneWidget,
        reason: banner,
      );
    });
  }
}
