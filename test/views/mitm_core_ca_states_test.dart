// Checks each state of the macOS certificate UI and, when asked, renders it
// to PNG for review, light and dark, at a narrow window:
//   MITM_CORE_CA_SCREENSHOTS=<dir> flutter test \
//     test/views/mitm_core_ca_states_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/common/restore_mount_plan.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/mitm_core_ca.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/mitm_core_ca.dart';
import 'package:fl_clash/views/restore_mount.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart' show Switch, ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../helpers/test_app.dart';

final _outDir = Platform.environment['MITM_CORE_CA_SCREENSHOTS'];
final _shoot = _outDir != null && _outDir!.isNotEmpty;
// Any other family falls back to Ahem, which draws every glyph as a bar.
const _loadedFamilies = {null, 'Roboto', 'JetBrainsMono'};
const _unicodeFont = '/System/Library/Fonts/Supplemental/Arial Unicode.ttf';

class _FixedLease extends MitmCoreCaLease {
  _FixedLease(this.trust);

  final MitmCoreCaTrust trust;

  @override
  MitmCoreCaTrust build() => trust;
}

class _FixedMigration extends MitmCaMigration {
  _FixedMigration(this.running);

  final bool running;

  @override
  bool build() => running;
}

final _legacy = MitmCertificate(
  pem: '-----BEGIN CERTIFICATE-----\n',
  fingerprint: 'AB:CD:EF:01:23:45:67:89:AB:CD:EF:01:23:45:67:89',
  subject: 'FlClash CA 0000ABCD',
  notBefore: DateTime.utc(2026, 10, 20, 12),
  notAfter: DateTime.utc(2036, 10, 22, 12),
);

final _fresh = _legacy.copyWith(
  fingerprint: '12:34:56:78:9A:BC:DE:F0:12:34:56:78:9A:BC:DE:F0',
  subject: 'Flash CA 9ABCDEF0',
);

final _earlier = _legacy.copyWith(
  fingerprint: '0F:1E:2D:3C:4B:5A:69:78:87:96:A5:B4:C3:D2:E1:F0',
  subject: 'Flash CA 87654321',
);

final _p12 = MitmCaP12('Q0FQMTI=');

typedef _State = ({
  MitmCertificate shown,
  Mitm mitm,
  MitmCoreCaTrust trust,
  bool running,
  List<MitmCertificate> old,
});

final _states = <String, _State>{
  'legacy': (
    shown: _legacy,
    mitm: const Mitm(enable: true),
    trust: MitmCoreCaTrust.off,
    running: false,
    old: const [],
  ),
  'pending': (
    shown: _legacy,
    mitm: Mitm(enable: true, pendingCaP12: _p12, pendingCaCertificate: _fresh),
    trust: MitmCoreCaTrust.off,
    running: false,
    old: const [],
  ),
  'verifying': (
    shown: _legacy,
    mitm: Mitm(enable: true, pendingCaP12: _p12, pendingCaCertificate: _fresh),
    trust: MitmCoreCaTrust.off,
    running: true,
    old: const [],
  ),
  'available': (
    shown: _legacy,
    mitm: const Mitm(),
    trust: MitmCoreCaTrust.off,
    running: false,
    old: const [],
  ),
  'switched': (
    shown: _fresh,
    mitm: Mitm(enable: true, caP12: _p12, caCertificate: _fresh),
    trust: MitmCoreCaTrust(MitmCoreCaStatus.leased, leased: _fresh.fingerprint),
    running: false,
    old: [_legacy, _earlier],
  ),
  'untrusted': (
    shown: _fresh,
    mitm: Mitm(enable: true, caP12: _p12, caCertificate: _fresh),
    trust: const MitmCoreCaTrust(MitmCoreCaStatus.untrusted),
    running: false,
    old: const [],
  ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final boundary = GlobalKey();

  setUpAll(() async {
    if (!_shoot) return;
    WidgetsApp.debugAllowBannerOverride = false;
    final loader = FontLoader('Roboto');
    loader.addFont(
      Future.value(ByteData.sublistView(File(_unicodeFont).readAsBytesSync())),
    );
    await loader.load();
    final mono = FontLoader('JetBrainsMono')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/JetBrainsMono-Regular.ttf').readAsBytesSync(),
          ),
        ),
      );
    await mono.load();
    Directory(_outDir!).createSync(recursive: true);
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required Locale locale,
    required Brightness brightness,
    required Widget child,
    Size size = const Size(390, 640),
    double textScale = 1,
    List<Override> overrides = const [],
    Mitm mitm = const Mitm(),
  }) async {
    final container = ProviderContainer(
      overrides: [safeModeProvider.overrideWithValue(false), ...overrides],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mitm: mitm));
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => TestApp(
              locale: locale,
              theme: watchAppTheme(ref, Brightness.light),
              darkTheme: watchAppTheme(ref, Brightness.dark),
              themeMode: brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return container;
  }

  Future<void> save(WidgetTester tester, String name) async {
    if (!_shoot) return;
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final families = <String?>{};
    void visit(RenderObject node) {
      if (node is RenderParagraph) {
        node.text.visitChildren((span) {
          families.add(span.style?.fontFamily);
          return true;
        });
      }
      node.visitChildren(visit);
    }

    visit(render);
    expect(families.difference(_loadedFamilies), isEmpty, reason: name);
    await tester.runAsync(() async {
      final image = await render.toImage(
        pixelRatio: tester.view.devicePixelRatio,
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File('$_outDir/$name.png').writeAsBytes(data!.buffer.asUint8List());
    });
  }

  for (final locale in const [Locale('zh'), Locale('en')]) {
    final l = lookupAppLocalizations(locale);
    final tag = locale.languageCode;
    for (final brightness in Brightness.values) {
      final mode = brightness.name;

      for (final MapEntry(key: name, value: state) in _states.entries) {
        testWidgets('section-$name-$tag-$mode', (tester) async {
          await pump(
            tester,
            locale: locale,
            brightness: brightness,
            mitm: state.mitm,
            overrides: [
              mitmCoreCaProvider.overrideWith(() => _FixedLease(state.trust)),
              mitmCaMigrationProvider.overrideWith(
                () => _FixedMigration(state.running),
              ),
              mitmOldCaProvider.overrideWith((ref) async => state.old),
            ],
            child: SingleChildScrollView(
              child: MitmCoreCaSection(
                certificate: state.shown,
                trustLabel: name == 'untrusted'
                    ? l.mitmTrustUntrusted
                    : l.mitmTrustReady,
                onDetails: () {},
                onExport: () {},
                onDelete: () {},
                onInstall: () {},
                onRetrust: () {},
              ),
            ),
          );
          final inUse = switch (name) {
            'available' => l.mitmCaAvailable(state.shown.subject),
            _ when state.mitm.coreCa == null => l.mitmCaInUseLegacy(
              state.shown.subject,
            ),
            _ => l.mitmCaConfigured(state.shown.subject),
          };
          expect(find.text(inUse), findsOneWidget);
          switch (name) {
            case 'legacy':
              expect(find.text(l.mitmUpdateCertificate), findsOneWidget);
              expect(find.text(l.mitmUpdateCertificateDesc), findsOneWidget);
              expect(find.text(l.mitmImportCertificate), findsOneWidget);
            case 'pending':
              expect(find.text(l.mitmPendingVerification), findsOneWidget);
              expect(find.text(l.mitmInstallAndSwitch), findsOneWidget);
            case 'verifying':
              expect(find.text(l.mitmVerifying), findsOneWidget);
              expect(find.text(l.mitmPendingVerification), findsNothing);
            case 'switched':
              expect(find.text(l.mitmOldCaSection(2)), findsOneWidget);
              expect(find.text(_legacy.subject), findsOneWidget);
              expect(find.text(_earlier.subject), findsOneWidget);
              expect(find.text(l.mitmRemoveOldCa), findsNWidgets(2));
              expect(find.text(l.mitmDeleteCurrentCa), findsOneWidget);
              expect(
                find.text('${l.mitmTrustReady}\n${l.mitmRunActive}'),
                findsOneWidget,
              );
            case 'untrusted':
              expect(find.text(l.mitmCoreCaUntrustedTitle), findsOneWidget);
              expect(find.text(l.mitmCoreCaUntrusted), findsOneWidget);
              expect(find.text(l.mitmRetrust), findsOneWidget);
              expect(find.text(l.mitmRunStopped), findsOneWidget);
              expect(find.textContaining(l.mitmTrustUntrusted), findsNothing);
            case 'available':
              expect(
                find.text('${l.mitmTrustReady}\n${l.mitmRunOff}'),
                findsOneWidget,
              );
          }
          await save(tester, 'section-$name-$tag-$mode');
        });
      }

      testWidgets('import-error-$tag-$mode', (tester) async {
        await pump(
          tester,
          locale: locale,
          brightness: brightness,
          child: Center(
            child: MitmImportDialog(
              pick: () async => (name: 'Flash CA.p12', bytes: [1, 2, 3]),
              submit: (_, _) async => 'badPassphrase',
            ),
          ),
        );
        await tester.tap(find.text(l.mitmChooseP12));
        await tester.pump();
        await tester.enterText(find.byType(EditableText), 'wrong');
        await tester.pump();
        await tester.tap(find.text(l.mitmContinue));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.text('Flash CA.p12'), findsOneWidget);
        expect(find.text(l.mitmImportBadPassphrase), findsOneWidget);
        await save(tester, 'import-error-$tag-$mode');
      });

      testWidgets('backup-include-$tag-$mode', (tester) async {
        await pump(
          tester,
          locale: locale,
          brightness: brightness,
          child: const Center(child: MitmBackupDialog(include: true)),
        );
        expect(find.text(l.includeMitmCa), findsOneWidget);
        expect(find.text(l.includeMitmCaTip), findsOneWidget);
        await save(tester, 'backup-include-$tag-$mode');
      });

      testWidgets('restore-ca-$tag-$mode', (tester) async {
        await pump(
          tester,
          locale: locale,
          brightness: brightness,
          child: const Center(child: MitmRestoredCaDialog()),
        );
        expect(find.text(l.mitmRestoredCaTip), findsOneWidget);
        expect(find.text(l.mitmInstallAndTrust), findsOneWidget);
        expect(find.text(l.mitmCaNotNow), findsOneWidget);
        await save(tester, 'restore-ca-$tag-$mode');
      });
    }
  }

  testWidgets('while verifying, install and discard are dimmed, skipped by '
      'focus and announced as disabled', (tester) async {
    final l = lookupAppLocalizations(const Locale('en'));
    final state = _states['verifying']!;
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      mitm: state.mitm,
      overrides: [
        mitmCoreCaProvider.overrideWith(() => _FixedLease(state.trust)),
        mitmCaMigrationProvider.overrideWith(() => _FixedMigration(true)),
        mitmOldCaProvider.overrideWith((ref) async => const []),
      ],
      child: SingleChildScrollView(
        child: MitmCoreCaSection(
          certificate: state.shown,
          trustLabel: l.mitmTrustReady,
          onDetails: () {},
          onExport: () {},
        ),
      ),
    );
    for (final label in [l.mitmInstallAndSwitch, l.mitmDiscardPending]) {
      final row = find.widgetWithText(MitmActionRow, label);
      expect(
        tester.getSemantics(row),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.color?.a, lessThan(0.5));
    }
    for (var i = 0; i < 12; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(focused?.findAncestorWidgetOfExactType<MitmActionRow>(), isNull);
    }
    semantics.dispose();
  });

  testWidgets('a delete names its target, focuses Cancel, and Enter keeps '
      'the certificate', (tester) async {
    final l = lookupAppLocalizations(const Locale('en'));
    late BuildContext host;
    await pump(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      child: Builder(
        builder: (context) {
          host = context;
          return const SizedBox.expand();
        },
      ),
    );
    final result = Navigator.of(host).push<bool>(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, _, _) => Center(
          child: MitmDeleteCaDialog(
            title: l.mitmDeleteCurrentCaTitle,
            text: l.mitmDeleteCurrentCaTip,
            confirmText: l.mitmDeleteCurrentCaConfirm,
            certificate: _fresh,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_fresh.subject), findsOneWidget);
    expect(find.text(_fresh.fingerprint), findsOneWidget);
    expect(find.text(l.mitmCaScopeThisMac), findsOneWidget);
    final focused = FocusManager.instance.primaryFocus!.context!;
    expect(
      find.descendant(
        of: find.byElementPredicate((e) => e == focused),
        matching: find.text(l.cancel),
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  testWidgets('the backup warning shows only with the toggle on', (
    tester,
  ) async {
    final l = lookupAppLocalizations(const Locale('en'));
    await pump(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      child: const Center(child: MitmBackupDialog()),
    );
    expect(find.text(l.includeMitmCaTip), findsNothing);
    expect(find.text(l.backup), findsWidgets);
    expect(find.text(l.mitmBackupWithKey), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text(l.includeMitmCaTip), findsOneWidget);
    expect(find.text(l.mitmBackupWithKey), findsOneWidget);
    expect(find.text(l.mitmBackupRiskRevoke), findsNothing);
    await tester.tap(find.text(l.mitmBackupRiskDetails));
    await tester.pump();
    expect(find.text(l.mitmBackupRiskImpact), findsOneWidget);
    expect(find.text(l.mitmBackupRiskRevoke), findsOneWidget);
  });

  test('the old certificate header counts in en and not in zh', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(en.mitmOldCaSection(1), 'Old Certificate Still on This Mac');
    expect(en.mitmOldCaSection(2), 'Old Certificates Still on This Mac');
    expect(zh.mitmOldCaSection(1), '仍保留在这台 Mac 的旧证书');
    expect(zh.mitmOldCaSection(2), '仍保留在这台 Mac 的旧证书');
  });

  testWidgets('one old certificate is headed in the singular', (tester) async {
    final l = lookupAppLocalizations(const Locale('en'));
    final state = _states['switched']!;
    await pump(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      mitm: state.mitm,
      overrides: [
        mitmCoreCaProvider.overrideWith(() => _FixedLease(state.trust)),
        mitmCaMigrationProvider.overrideWith(() => _FixedMigration(false)),
        mitmOldCaProvider.overrideWith((ref) async => [_legacy]),
      ],
      child: SingleChildScrollView(
        child: MitmCoreCaSection(
          certificate: state.shown,
          trustLabel: l.mitmTrustReady,
          onExport: () {},
          onDelete: () {},
        ),
      ),
    );
    expect(find.text(l.mitmOldCaSection(1)), findsOneWidget);
    expect(find.text(l.mitmOldCaSection(2)), findsNothing);
  });

  testWidgets('the p12 password keeps its label while typed in', (
    tester,
  ) async {
    final l = lookupAppLocalizations(const Locale('en'));
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      child: Center(
        child: MitmImportDialog(
          pick: () async => (name: 'Flash CA.p12', bytes: [1, 2, 3]),
          submit: (_, _) async => null,
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), 'secret');
    await tester.pump();
    expect(find.text(l.mitmImportPassword), findsOneWidget);
    expect(find.bySemanticsLabel(l.mitmImportPassword), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a restore with no CA here and a damaged one says so', (
    tester,
  ) async {
    final l = lookupAppLocalizations(const Locale('en'));
    await pump(
      tester,
      locale: const Locale('en'),
      brightness: Brightness.light,
      size: const Size(390, 1000),
      child: Column(
        children: [
          RestoreMitmCaNote(
            RestoreMitmCa(RestoreMitmCaChange.replaced, backup: _fresh),
          ),
          const RestoreMitmCaNote(RestoreMitmCa(RestoreMitmCaChange.damaged)),
          RestoreMitmCaNote(
            RestoreMitmCa(RestoreMitmCaChange.damaged, local: _legacy),
          ),
        ],
      ),
    );
    expect(find.text(l.mitmRestoreCaLocalNone), findsOneWidget);
    expect(find.text(l.mitmRestoreCaPending), findsOneWidget);
    expect(find.text(l.mitmRestoreCaLocalKept), findsNothing);
    expect(find.text(l.mitmRestoreCaDamagedNone), findsOneWidget);
    expect(find.text(l.mitmRestoreCaDamaged), findsOneWidget);
  });

  const reviewSizes = [
    (tag: 'zh-390', locale: Locale('zh'), width: 390.0, scale: 1.0),
    (tag: 'en-360-2x', locale: Locale('en'), width: 360.0, scale: 2.0),
    (tag: 'ru-360', locale: Locale('ru'), width: 360.0, scale: 1.0),
  ];
  for (final size in reviewSizes) {
    final l = lookupAppLocalizations(size.locale);
    Future<void> shoot(
      WidgetTester tester,
      String name,
      Widget child, {
      _State? state,
    }) async {
      await pump(
        tester,
        locale: size.locale,
        brightness: Brightness.light,
        size: Size(size.width, 800),
        textScale: size.scale,
        mitm: state?.mitm ?? const Mitm(),
        overrides: [
          if (state != null) ...[
            mitmCoreCaProvider.overrideWith(() => _FixedLease(state.trust)),
            mitmCaMigrationProvider.overrideWith(
              () => _FixedMigration(state.running),
            ),
            mitmOldCaProvider.overrideWith((ref) async => state.old),
          ],
        ],
        child: child,
      );
      expect(tester.takeException(), isNull);
      await save(tester, 'review-$name-${size.tag}');
    }

    testWidgets('review-untrusted-${size.tag}', (tester) async {
      final state = _states['untrusted']!;
      await shoot(
        tester,
        'untrusted',
        SingleChildScrollView(
          child: MitmCoreCaSection(
            certificate: state.shown,
            trustLabel: l.mitmTrustUntrusted,
            onRetrust: () {},
            onExport: () {},
            onDelete: () {},
          ),
        ),
        state: state,
      );
      expect(find.text(l.mitmRetrust), findsOneWidget);
    });

    testWidgets('review-switched-${size.tag}', (tester) async {
      final state = _states['switched']!;
      await shoot(
        tester,
        'switched',
        SingleChildScrollView(
          child: MitmCoreCaSection(
            certificate: state.shown,
            trustLabel: l.mitmTrustReady,
            onExport: () {},
            onDelete: () {},
          ),
        ),
        state: state,
      );
      expect(find.text(l.mitmRemoveOldCa), findsNWidgets(2));
    });

    testWidgets('review-delete-confirm-${size.tag}', (tester) async {
      await shoot(
        tester,
        'delete-confirm',
        Center(
          child: MitmDeleteCaDialog(
            title: l.mitmDeleteCurrentCaTitle,
            text: l.mitmDeleteCurrentCaTip,
            confirmText: l.mitmDeleteCurrentCaConfirm,
            certificate: _fresh,
          ),
        ),
      );
      expect(find.text(l.mitmDeleteCurrentCaConfirm), findsOneWidget);
    });

    testWidgets('review-restore-conflict-${size.tag}', (tester) async {
      await shoot(
        tester,
        'restore-conflict',
        RestoreMountConfirmSheet(
          plan: RestoreMountPlan.empty,
          mitmCa: RestoreMitmCa(
            RestoreMitmCaChange.replaced,
            local: _legacy,
            backup: _fresh,
          ),
        ),
      );
      expect(find.text(_legacy.fingerprint), findsOneWidget);
      expect(find.text(_fresh.fingerprint), findsOneWidget);
      expect(find.text(l.mitmRestoreCaLocalKept), findsOneWidget);
    });

    testWidgets('review-restore-first-${size.tag}', (tester) async {
      await shoot(
        tester,
        'restore-first',
        RestoreMountConfirmSheet(
          plan: RestoreMountPlan.empty,
          mitmCa: RestoreMitmCa(RestoreMitmCaChange.replaced, backup: _fresh),
        ),
      );
      expect(find.text(l.mitmRestoreCaLocalNone), findsOneWidget);
    });

    testWidgets('review-backup-include-${size.tag}', (tester) async {
      await shoot(
        tester,
        'backup-include',
        const Center(child: MitmBackupDialog(include: true)),
      );
      await tester.tap(find.text(l.mitmBackupRiskDetails));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await save(tester, 'review-backup-include-open-${size.tag}');
    });
  }
}
