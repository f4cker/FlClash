import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_script.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/mitm_module_confirm.dart';
import 'package:fl_clash/views/config/mitm_modules.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

const _locales = [
  Locale('es'),
  Locale('fr'),
  Locale('ja'),
  Locale('ko'),
  Locale('ru'),
];

/// Authorization copy that waits for a native review, so it stays English.
final _reserved = <String, String Function(AppLocalizations)>{
  'mitmScriptConfirmBody': (l) => l.mitmScriptConfirmBody,
  'mitmModuleConfirmTitle': (l) => l.mitmModuleConfirmTitle,
  'mitmModuleHostsHint': (l) => l.mitmModuleHostsHint,
  'mitmModuleNoHosts': (l) => l.mitmModuleNoHosts,
  'mitmScriptConfirmTitle': (l) => l.mitmScriptConfirmTitle,
};

/// Every section of the sheet: hosts past the first ones, an excluded one,
/// a script, and a rule whose policy the profile lacks.
final _module =
    '''
#!name=Long
#!desc=A module with every section
[MITM]
hostname = %APPEND% ${[for (var i = 0; i < 14; i++) 'h$i.example.com', '-skip.example.com'].join(', ')}
[Script]
Clean = type=http-response,pattern=^https://h1\\.example\\.com/,requires-body=1,script-path=https://cdn.example.com/clean.js
[Rule]
DOMAIN,h1.example.com,Missing Policy
''';

void main() {
  test('the authorization copy stays English in every translated locale', () {
    final en = lookupAppLocalizations(const Locale('en'));
    for (final locale in _locales) {
      final l = lookupAppLocalizations(locale);
      for (final MapEntry(key: key, value: text) in _reserved.entries) {
        expect(text(l), text(en), reason: '${locale.languageCode} $key');
      }
    }
  });

  late Database testDatabase;

  setUpAll(
    () async => useAppPaths(Directory.systemTemp.createTempSync('import-l10n')),
  );

  setUp(() {
    testDatabase = Database(NativeDatabase.memory());
    database = testDatabase;
  });

  tearDown(() => testDatabase.close());

  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    required Locale locale,
    Widget child = const SizedBox(),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await database.profilesDao.putAll([
      const Profile(id: 1, autoUpdateDuration: Duration.zero).toCompanion(),
    ]);
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(
          () => TestProfiles([
            const Profile(id: 1, label: 'P', autoUpdateDuration: Duration.zero),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.listen(patchClashConfigProvider, (_, _) {});
    container.listen(currentProfileIdProvider, (_, _) {});
    container.read(currentProfileIdProvider.notifier).value = 1;
    container.read(patchClashConfigProvider.notifier).value =
        const PatchClashConfig(mitm: Mitm(enable: true));
    container.read(viewSizeProvider.notifier).update((_) => size);
    loadAppLocalizations(locale);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(locale: locale, child: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  void open(WidgetTester tester) => showMitmModuleConfirmDialog(
    tester.element(find.byType(SizedBox).first),
    content: previewMitmModule(_module),
    name: 'Long',
    source: 'raw.example.io',
    onImport: (_, _) async {},
  );

  /// The tests' Ahem font is far wider than any real one; Arial, close to
  /// the macOS system font, shows the real one-row footer.
  const arial = '/System/Library/Fonts/Supplemental/Arial.ttf';
  final noArial = File(arial).existsSync() ? null : 'needs $arial (macOS)';
  Future<void> realFont(WidgetTester tester) async {
    await tester.runAsync(() async {
      final bytes = ByteData.sublistView(File(arial).readAsBytesSync());
      await (FontLoader('Roboto')..addFont(Future.value(bytes))).load();
    });
  }

  for (final locale in _locales) {
    final tag = locale.languageCode;

    testWidgets('$tag 360x640: the confirm sheet lays out without overflow', (
      tester,
    ) async {
      await pump(tester, size: const Size(360, 640), locale: locale);
      open(tester);
      await tester.pumpAndSettle();
      final l = currentAppLocalizations;

      expect(find.text(l.mitmImportAndEnable), findsOneWidget);
      expect(find.text(l.mitmImportOnly), findsOneWidget);
      expect(find.text(l.mitmExcludedCount(1)), findsOneWidget);
      expect(find.text(l.mitmMoreHosts(3)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$tag 1024x768: the confirm sheet footer fits without overflow',
      skip: noArial != null,
      (tester) async {
        await realFont(tester);
        await pump(tester, size: const Size(1024, 768), locale: locale);
        open(tester);
        await tester.pumpAndSettle();
        final l = currentAppLocalizations;

        for (final label in [l.mitmImportAndEnable, l.mitmImportOnly]) {
          final text = find.text(label);
          expect(text, findsOneWidget, reason: label);
          final button = find.ancestor(
            of: text,
            matching: find.byWidgetPredicate(
              (w) => w is FilledButton || w is TextButton,
            ),
          );
          final inside = tester.getRect(button.first);
          final rect = tester.getRect(text);
          expect(rect.left, greaterThanOrEqualTo(inside.left), reason: label);
          expect(rect.right, lessThanOrEqualTo(inside.right), reason: label);
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$tag 360x640: the empty module page lays out without '
        'overflow', (tester) async {
      await pump(
        tester,
        size: const Size(360, 640),
        locale: locale,
        child: const MitmModulesView(),
      );
      final l = currentAppLocalizations;

      expect(find.text(l.mitmImportModule), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
}
