import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_script.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/mitm_module_confirm.dart';
import 'package:fl_clash/views/rules/rule_edit_dialogs.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

const _lastHost = 'zz-last.example.com';

/// More hosts than the sheet shows at first, and more sections under them,
/// so the body runs well past a short window.
final _module =
    '''
#!name=Long
#!desc=A module with more than fits
[MITM]
hostname = %APPEND% ${[for (var i = 0; i < 20; i++) 'h$i.example.com', _lastHost].join(', ')}
[Script]
Clean = type=http-response,pattern=^https://h1\\.example\\.com/,requires-body=1,script-path=https://x.com/clean.js
[Rule]
DOMAIN,h1.example.com,REJECT
DOMAIN,h2.example.com,REJECT
''';

void main() {
  late Database testDatabase;

  setUpAll(
    () async => useAppPaths(Directory.systemTemp.createTempSync('confirm')),
  );

  setUp(() {
    testDatabase = Database(NativeDatabase.memory());
    database = testDatabase;
  });

  tearDown(() => testDatabase.close());

  /// Every debugPrint, so a tap that would not hit its target (tap's
  /// warnIfMissed) fails the test.
  List<String> capturePrints() {
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      printed.add(message ?? '');
      original(message, wrapWidth: wrapWidth);
    };
    addTearDown(() => debugPrint = original);
    return printed;
  }

  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    required Locale locale,
    required double textScale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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
        child: TestApp(locale: locale, child: const SizedBox()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the sheet; what it was closed with, and each import asked for.
  (Future<bool?>, List<bool>) open(WidgetTester tester) {
    final imports = <bool>[];
    final result = showMitmModuleConfirmDialog(
      tester.element(find.byType(SizedBox).first),
      content: previewMitmModule(_module),
      name: 'Long',
      source: 'raw.example.io',
      onImport: (enable, _) async => imports.add(enable),
    );
    return (result, imports);
  }

  /// Whether [target] lies inside every scroll view around it (its end, for
  /// one taller than the view).
  bool inView(WidgetTester tester, Finder target) {
    final rect = tester.getRect(target);
    var visible = Offset.zero & tester.view.physicalSize;
    for (final element
        in find
            .ancestor(of: target, matching: find.byType(Scrollable))
            .evaluate()) {
      visible = visible.intersect(
        tester.getRect(find.byElementPredicate((e) => e == element)),
      );
    }
    if (rect.bottom > visible.bottom + 0.5 || rect.bottom <= visible.top) {
      return false;
    }
    // One taller than the view counts once its end is in it.
    return rect.top >= visible.top - 0.5 || rect.height > visible.height;
  }

  /// Drags the innermost scroll view that still hides [target] until it is
  /// in view.
  Future<void> dragIntoView(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 80 && !inView(tester, target); i++) {
      final rect = tester.getRect(target);
      final scrollables = [
        for (final element
            in find
                .ancestor(of: target, matching: find.byType(Scrollable))
                .evaluate())
          tester.getRect(find.byElementPredicate((e) => e == element)),
      ];
      // Innermost first: the first that still cuts [target] off.
      final hiding = scrollables.firstWhere(
        (box) => rect.top < box.top || rect.bottom > box.bottom,
        orElse: () => scrollables.last,
      );
      // Dragged from where it shows through every scroll view around it.
      var area = hiding.intersect(Offset.zero & tester.view.physicalSize);
      for (final box in scrollables) {
        area = area.intersect(box);
      }
      // Just far enough, at most most of the view per drag.
      final by = rect.bottom > hiding.bottom
          ? hiding.bottom - rect.bottom - 4
          : hiding.top - rect.top + 4;
      final step = hiding.height * 0.8;
      await tester.dragFrom(area.center, Offset(0, by.clamp(-step, step)));
      await tester.pumpAndSettle();
    }
    expect(inView(tester, target), isTrue, reason: 'not scrolled into view');
  }

  /// Taps [label]'s button, checking the tap reaches it.
  Future<void> tapButton(
    WidgetTester tester,
    String label,
    List<String> printed,
  ) async {
    final button = find.text(label);
    expect(button, findsOneWidget, reason: label);
    await dragIntoView(tester, button);
    await tester.tap(button, warnIfMissed: true);
    await tester.pumpAndSettle();
    expect(
      printed.where((line) => line.contains('would not hit test')),
      isEmpty,
      reason: label,
    );
  }

  const narrow = Size(360, 640);
  for (final locale in const [Locale('ru'), Locale('ja')]) {
    final tag = locale.languageCode;

    testWidgets('$tag 360x640 ×2: the body scrolls to its last host', (
      tester,
    ) async {
      final printed = capturePrints();
      await pump(tester, size: narrow, locale: locale, textScale: 2.0);
      final (result, _) = open(tester);
      await tester.pumpAndSettle();
      final l = currentAppLocalizations;

      // Under the first hosts the rest wait behind Show More.
      final more = find.text(l.mitmMoreHosts(9));
      await dragIntoView(tester, more);
      await tester.tap(more, warnIfMissed: true);
      await tester.pumpAndSettle();
      final last = find.text(_lastHost);
      expect(last, findsOneWidget);
      await dragIntoView(tester, last);

      // The actions stay in view below it, stacked full width.
      final primary = find.text(l.mitmImportAndEnable);
      final only = find.text(l.mitmImportOnly);
      final cancel = find.text(l.cancel);
      for (final button in [primary, only, cancel]) {
        expect(inView(tester, button), isTrue);
      }
      expect(tester.getCenter(primary).dy, lessThan(tester.getCenter(only).dy));
      expect(tester.getCenter(only).dy, lessThan(tester.getCenter(cancel).dy));
      expect(
        tester.getRect(last).bottom,
        lessThanOrEqualTo(tester.getRect(primary).top),
      );
      expect(tester.takeException(), isNull);

      await tapButton(tester, l.cancel, printed);
      expect(await result, isNull);
      expect(
        printed.where((line) => line.contains('would not hit test')),
        isEmpty,
      );
    });

    for (final (name, enable) in [
      ('Import and Turn On', true),
      ('Import Only', false),
      ('Cancel', null),
    ]) {
      testWidgets('$tag 360x640 ×2: $name is hit and acts', (tester) async {
        final printed = capturePrints();
        await pump(tester, size: narrow, locale: locale, textScale: 2.0);
        final (result, imports) = open(tester);
        await tester.pumpAndSettle();
        final l = currentAppLocalizations;
        final label = switch (enable) {
          true => l.mitmImportAndEnable,
          false => l.mitmImportOnly,
          null => l.cancel,
        };

        await tapButton(tester, label, printed);

        expect(await result, enable);
        expect(imports, enable == null ? isEmpty : [enable]);
        expect(find.text(l.mitmModuleConfirmTitle), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  /// The tests' Ahem font is far wider than any real one, so one row never
  /// fits it; Arial, close to the macOS system font, stands in.
  const arial = '/System/Library/Fonts/Supplemental/Arial.ttf';
  final noArial = File(arial).existsSync() ? null : 'needs $arial (macOS)';
  Future<void> realFont(WidgetTester tester) async {
    await tester.runAsync(() async {
      final bytes = ByteData.sublistView(File(arial).readAsBytesSync());
      await (FontLoader('Roboto')..addFont(Future.value(bytes))).load();
    });
  }

  testWidgets(
    'en 1024x768: the actions sit in one row and each acts',
    skip: noArial != null,
    (tester) async {
      final printed = capturePrints();
      await realFont(tester);
      await pump(
        tester,
        size: const Size(1024, 768),
        locale: const Locale('en'),
        textScale: 1.0,
      );
      final l = currentAppLocalizations;
      for (final (label, enable) in [
        (l.mitmImportAndEnable, true),
        (l.mitmImportOnly, false),
        (l.cancel, null),
      ]) {
        final (result, imports) = open(tester);
        await tester.pumpAndSettle();
        final rows = {
          for (final text in [
            l.mitmImportAndEnable,
            l.mitmImportOnly,
            l.cancel,
          ])
            tester.getCenter(find.text(text)).dy.round(),
        };
        expect(rows, hasLength(1), reason: 'buttons not in one row');
        expect(
          tester.getCenter(find.text(l.mitmImportOnly)).dx,
          lessThan(tester.getCenter(find.text(l.cancel)).dx),
        );
        expect(
          tester.getCenter(find.text(l.cancel)).dx,
          lessThan(tester.getCenter(find.text(l.mitmImportAndEnable)).dx),
        );

        await tapButton(tester, label, printed);

        expect(await result, enable);
        expect(imports, enable == null ? isEmpty : [enable]);
        expect(tester.takeException(), isNull);
      }
    },
  );

  /// A frame with every kind of action: delete, a leading one, cancel, save.
  (Future<bool?>, List<String>) openFrame(WidgetTester tester) {
    final calls = <String>[];
    final result = dialogs.showCommonDialog<bool>(
      context: tester.element(find.byType(SizedBox).first),
      dismissible: false,
      child: RuleEditFrame(
        title: 'Edit',
        subtitle: 'A rule',
        width: 560,
        primaryLabel: 'Save',
        onPrimary: () => calls.add('save'),
        onDelete: () => calls.add('delete'),
        leading: TextButton(
          onPressed: () => calls.add('lead'),
          child: const Text('Lead'),
        ),
        children: const [Text('Body')],
      ),
    );
    return (result, calls);
  }

  testWidgets(
    'en 1024x768: delete, leading, cancel, save keep their order '
    'and each tap reaches only the shown copy',
    skip: noArial != null,
    (tester) async {
      final printed = capturePrints();
      await realFont(tester);
      await pump(
        tester,
        size: const Size(1024, 768),
        locale: const Locale('en'),
        textScale: 1.0,
      );
      final l = currentAppLocalizations;
      final (result, calls) = openFrame(tester);
      await tester.pumpAndSettle();

      final labels = [l.delete, 'Lead', l.cancel, 'Save'];
      for (final label in labels) {
        // Built in both layouts, only one copy on stage.
        expect(find.text(label, skipOffstage: false), findsNWidgets(2));
        expect(find.text(label), findsOneWidget);
      }
      final centers = [
        for (final label in labels) tester.getCenter(find.text(label)),
      ];
      expect({for (final c in centers) c.dy.round()}, hasLength(1));
      for (var i = 1; i < centers.length; i++) {
        expect(
          centers[i].dx,
          greaterThan(centers[i - 1].dx),
          reason: labels[i],
        );
      }

      for (final (label, call) in [
        (l.delete, 'delete'),
        ('Lead', 'lead'),
        ('Save', 'save'),
      ]) {
        calls.clear();
        await tapButton(tester, label, printed);
        expect(calls, [call], reason: label);
      }
      await tapButton(tester, l.cancel, printed);
      expect(await result, isNull);
      expect(find.text('Body'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a focused action keeps the focus as the footer changes layout',
    skip: noArial != null,
    (tester) async {
      await realFont(tester);
      await pump(
        tester,
        size: const Size(1024, 768),
        locale: const Locale('en'),
        textScale: 1.0,
      );
      final l = currentAppLocalizations;
      openFrame(tester);
      await tester.pumpAndSettle();
      FocusNode nodeOf(String label) =>
          Focus.of(tester.element(find.text(label)), createDependency: false);
      bool stacked() =>
          tester.getCenter(find.text('Save')).dy <
          tester.getCenter(find.text(l.cancel)).dy;

      for (final label in [l.cancel, 'Lead', 'Save', l.delete]) {
        tester.view.physicalSize = const Size(1024, 768);
        await tester.pumpAndSettle();
        expect(stacked(), isFalse);
        nodeOf(label).requestFocus();
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, nodeOf(label));

        // Narrower than one row: the stacked copy takes the focus.
        tester.view.physicalSize = const Size(300, 768);
        await tester.pumpAndSettle();
        expect(stacked(), isTrue, reason: label);
        expect(
          FocusManager.instance.primaryFocus,
          nodeOf(label),
          reason: label,
        );

        // And back.
        tester.view.physicalSize = const Size(1024, 768);
        await tester.pumpAndSettle();
        expect(stacked(), isFalse);
        expect(
          FocusManager.instance.primaryFocus,
          nodeOf(label),
          reason: label,
        );
      }
      // Still reachable by keyboard from there.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
