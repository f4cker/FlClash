import 'dart:async';
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
import 'package:fl_clash/views/rules/rule_edit_dialogs.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

const _lastHost = 'zz-last.example.com';

/// Long enough to need more than one line beside the script's name.
const _scriptHost = 'scripts.very-long-cdn-name.example-provider.com';

/// More hosts than the sheet shows at first, and more sections under them,
/// so the body runs well past a short window.
final _module =
    '''
#!name=Long
#!desc=A module with more than fits
[MITM]
hostname = %APPEND% ${[for (var i = 0; i < 20; i++) 'h$i.example.com', _lastHost].join(', ')}
[Script]
Clean = type=http-response,pattern=^https://h1\\.example\\.com/,requires-body=1,script-path=https://$_scriptHost/clean.js
[Rule]
DOMAIN,h1.example.com,REJECT
DOMAIN,h2.example.com,REJECT
''';

/// A module with rewrite rules: the last group's count line carries Show
/// More beside it.
const _rewriteModule = r'''
#!name=Rewrites
[MITM]
hostname = %APPEND% a.example.com
[URL Rewrite]
^https://a\.example\.com/x - reject
[Body Rewrite]
http-response ^https://a\.example\.com/b x y
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
  (Future<bool?>, List<bool>) open(WidgetTester tester, {String? module}) {
    final imports = <bool>[];
    final result = showMitmModuleConfirmDialog(
      tester.element(find.byType(SizedBox).first),
      content: previewMitmModule(module ?? _module),
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
    Rect? last;
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
      // A drag that starts on a button spends the slop before it scrolls.
      final slop = rect == last ? by.sign * kDragSlopDefault : 0.0;
      last = rect;
      // Slow enough not to fling past it.
      await tester.timedDragFrom(
        area.center,
        Offset(0, by.clamp(-step, step) + slop),
        const Duration(seconds: 1),
      );
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
  const locales = [
    Locale('en'),
    Locale('zh'),
    Locale('ja'),
    Locale('ko'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
  ];

  /// The stacked actions top to bottom, as the one row has them left to
  /// right.
  List<String> stackedLabels(AppLocalizations l) => [
    l.mitmImportOnly,
    l.cancel,
    l.mitmImportAndEnable,
  ];

  /// The button around [label].
  Finder buttonOf(String label) => find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is FilledButton || widget is TextButton,
        ),
      )
      .first;

  /// The scroll view the body scrolls in, apart from the actions.
  Finder bodyScroll() => find
      .ancestor(
        of: find.textContaining(' · raw.example.io'),
        matching: find.byType(Scrollable),
      )
      .first;

  for (final locale in locales) {
    final tag = locale.languageCode;
    for (final scale in const [1.0, 2.0]) {
      final name = '$tag 360x640 ×${scale.toInt()}';

      testWidgets('$name: the actions stack in row order, pinned under the '
          'body', (tester) async {
        final printed = capturePrints();
        await pump(tester, size: narrow, locale: locale, textScale: scale);
        final (result, _) = open(tester);
        await tester.pumpAndSettle();
        final l = currentAppLocalizations;
        expect(tester.takeException(), isNull);

        final labels = stackedLabels(l);
        final buttons = [for (final label in labels) buttonOf(label)];
        // Top to bottom in row order, 8 apart, one width, at least 44 tall,
        // each label whole.
        for (var i = 1; i < buttons.length; i++) {
          final above = tester.getRect(buttons[i - 1]);
          final below = tester.getRect(buttons[i]);
          expect(below.top - above.bottom, closeTo(8, 0.5), reason: labels[i]);
          expect(below.width, closeTo(above.width, 0.5), reason: labels[i]);
          expect(below.left, closeTo(above.left, 0.5), reason: labels[i]);
        }
        for (final (index, button) in buttons.indexed) {
          final rect = tester.getRect(button);
          expect(rect.height, greaterThanOrEqualTo(44), reason: labels[index]);
          final text = tester.getRect(find.text(labels[index]));
          expect(text.left, greaterThanOrEqualTo(rect.left));
          expect(text.right, lessThanOrEqualTo(rect.right));
          expect(text.bottom, lessThanOrEqualTo(rect.bottom + 0.5));
          expect(
            tester.widget<Text>(find.text(labels[index])).overflow,
            isNot(TextOverflow.ellipsis),
          );
        }

        // The body is long and scrolls on its own; the actions stay where
        // they are under it, and the first is in view throughout.
        final scroll = tester.state<ScrollableState>(bodyScroll());
        expect(scroll.position.maxScrollExtent, greaterThan(0));
        final pinned = tester.getRect(buttons.first);
        final more = find.text(l.mitmMoreHosts(9));
        await dragIntoView(tester, more);
        await tester.tap(more, warnIfMissed: true);
        await tester.pumpAndSettle();
        await dragIntoView(tester, find.text(_lastHost));
        expect(scroll.position.pixels, greaterThan(0));
        expect(tester.getRect(buttons.first), pinned);
        expect(inView(tester, buttons.first), isTrue);
        expect(
          tester.getRect(find.text(_lastHost)).bottom,
          lessThanOrEqualTo(tester.getRect(bodyScroll()).bottom + 0.5),
        );
        expect(
          tester.getRect(bodyScroll()).bottom,
          lessThanOrEqualTo(pinned.top),
        );
        expect(
          tester.getRect(bodyScroll()).bottom,
          lessThanOrEqualTo(tester.view.physicalSize.height),
        );

        // Every action can be brought into the window whole and hit there.
        for (final button in buttons) {
          await dragIntoView(tester, button);
          final rect = tester.getRect(button);
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(narrow.height));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(narrow.width));
          final box = tester.renderObject(button);
          expect(
            tester
                .hitTestOnBinding(rect.center)
                .path
                .any((entry) => entry.target == box),
            isTrue,
            reason: 'not hit',
          );
        }
        expect(tester.takeException(), isNull);

        await tapButton(tester, l.cancel, printed);
        expect(await result, isNull);
      });

      testWidgets('$name: rewrite counts wrap beside Show More', (
        tester,
      ) async {
        final printed = capturePrints();
        await pump(tester, size: narrow, locale: locale, textScale: scale);
        final (result, imports) = open(tester, module: _rewriteModule);
        await tester.pumpAndSettle();
        final l = currentAppLocalizations;
        expect(tester.takeException(), isNull);

        final more = find.text(l.showMore, findRichText: true);
        expect(more, findsOneWidget);
        final body = tester.getRect(bodyScroll());
        await dragIntoView(tester, more);
        final link = tester.getRect(more);
        expect(link.left, greaterThanOrEqualTo(body.left - 0.5));
        expect(link.right, lessThanOrEqualTo(body.right + 0.5));
        await tester.tap(more, warnIfMissed: true);
        await tester.pumpAndSettle();
        expect(more, findsNothing);
        expect(
          find.text(r'^https://a\.example\.com/x - reject'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expect(
          printed.where((line) => line.contains('would not hit test')),
          isEmpty,
        );

        await tapButton(tester, l.mitmImportAndEnable, printed);
        expect(await result, isTrue);
        expect(imports, [true]);
      });

      testWidgets('$name: Tab follows the stacked order, Esc cancels', (
        tester,
      ) async {
        await pump(tester, size: narrow, locale: locale, textScale: scale);
        final (result, imports) = open(tester);
        await tester.pumpAndSettle();
        final l = currentAppLocalizations;
        FocusNode nodeOf(String label) =>
            Focus.of(tester.element(find.text(label)), createDependency: false);

        final labels = stackedLabels(l);
        nodeOf(labels.first).requestFocus();
        await tester.pumpAndSettle();
        for (final label in labels.skip(1)) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(FocusManager.instance.primaryFocus, nodeOf(label));
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text(l.mitmModuleConfirmTitle), findsNothing);
        Object? closed = false;
        unawaited(result.then((value) => closed = value));
        await tester.pumpAndSettle();
        expect(closed, isNull);
        expect(imports, isEmpty);
        expect(tester.takeException(), isNull);
      });

      for (final (action, enable) in [
        ('Import and Turn On', true),
        ('Import Only', false),
        ('Cancel', null),
      ]) {
        testWidgets('$name: $action is hit and acts', (tester) async {
          final printed = capturePrints();
          await pump(tester, size: narrow, locale: locale, textScale: scale);
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

        testWidgets('$name: Enter on a focused $action acts as a tap', (
          tester,
        ) async {
          await pump(tester, size: narrow, locale: locale, textScale: scale);
          final (result, imports) = open(tester);
          await tester.pumpAndSettle();
          final l = currentAppLocalizations;
          final label = switch (enable) {
            true => l.mitmImportAndEnable,
            false => l.mitmImportOnly,
            null => l.cancel,
          };
          Focus.of(
            tester.element(find.text(label)),
            createDependency: false,
          ).requestFocus();
          await tester.pumpAndSettle();
          expect(imports, isEmpty, reason: 'focus alone submits nothing');

          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          Object? closed = 'open';
          unawaited(result.then((value) => closed = value));
          await tester.pumpAndSettle();

          expect(closed, enable);
          expect(imports, enable == null ? isEmpty : [enable]);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('$tag 360x640 ×2: the script source wraps, in full on hover', (
      tester,
    ) async {
      await pump(tester, size: narrow, locale: locale, textScale: 2.0);
      open(tester);
      await tester.pumpAndSettle();
      final label = find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data ?? '').endsWith(' · $_scriptHost'),
      );
      await dragIntoView(tester, label);
      final text = tester.widget<Text>(label);
      expect(text.maxLines, 2);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: label, matching: find.byType(RichText)),
      );
      // More than one line beside the name, never more than two.
      final lines = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: text.data!.length),
          )
          .map((box) => box.top.round())
          .toSet();
      expect(lines.length, inInclusiveRange(1, 2));
      expect(
        tester
            .widget<Tooltip>(
              find.ancestor(of: label, matching: find.byType(Tooltip)),
            )
            .message,
        text.data,
      );
      expect(tester.takeException(), isNull);
    });
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

  for (final locale in locales) {
    testWidgets(
      '${locale.languageCode} 1024x768: the actions keep the row order, '
      'in one row where it fits, and each acts',
      skip: noArial != null,
      (tester) async {
        final printed = capturePrints();
        await realFont(tester);
        await pump(
          tester,
          size: const Size(1024, 768),
          locale: locale,
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
          final centers = [
            for (final text in stackedLabels(l))
              tester.getCenter(find.text(text)),
          ];
          final oneRow = {for (final c in centers) c.dy.round()}.length == 1;
          // English has always fit one row at this size.
          if (locale.languageCode == 'en') expect(oneRow, isTrue);
          for (var i = 1; i < centers.length; i++) {
            expect(
              oneRow ? centers[i].dx : centers[i].dy,
              greaterThan(oneRow ? centers[i - 1].dx : centers[i - 1].dy),
            );
          }
          for (final text in stackedLabels(l)) {
            final rect = tester.getRect(buttonOf(text));
            expect(
              (Offset.zero & tester.view.physicalSize).intersect(rect),
              rect,
              reason: text,
            );
          }

          await tapButton(tester, label, printed);

          expect(await result, enable);
          expect(imports, enable == null ? isEmpty : [enable]);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  /// A frame with every kind of action: delete, a leading one, cancel, save.
  (Future<bool?>, List<String>) openFrame(
    WidgetTester tester, {
    FocusNode? body,
  }) {
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
        children: [Focus(focusNode: body, child: const Text('Body'))],
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

  testWidgets(
    'a layout change leaves the focus where the user has since moved it',
    skip: noArial != null,
    (tester) async {
      await realFont(tester);
      await pump(
        tester,
        size: const Size(1024, 768),
        locale: const Locale('en'),
        textScale: 1.0,
      );
      final body = FocusNode(debugLabel: 'body');
      addTearDown(body.dispose);
      final l = currentAppLocalizations;
      openFrame(tester, body: body);
      await tester.pumpAndSettle();
      final cancel = Focus.of(
        tester.element(find.text(l.cancel)),
        createDependency: false,
      );
      cancel.requestFocus();
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, cancel);

      // The layout flips (one frame), then the user moves on before the
      // focus would follow (the next).
      tester.view.physicalSize = const Size(300, 768);
      await tester.pump();
      body.requestFocus();
      await tester.pumpAndSettle();

      expect(
        tester.getCenter(find.text('Save')).dy,
        lessThan(tester.getCenter(find.text(l.cancel)).dy),
      );
      expect(FocusManager.instance.primaryFocus, body);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('other frames keep the default stack: save first, cancel last, '
      'the footer pinned without a scroll view of its own', (tester) async {
    await pump(
      tester,
      size: const Size(300, 400),
      locale: const Locale('en'),
      textScale: 2.0,
    );
    final l = currentAppLocalizations;
    final (result, _) = openFrame(tester);
    await tester.pumpAndSettle();

    final labels = ['Save', 'Lead', l.delete, l.cancel];
    final tops = [
      for (final label in labels) tester.getRect(find.text(label)).top,
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: labels[i]);
    }
    int scrollsAround(Finder target) => find
        .ancestor(of: target, matching: find.byType(Scrollable))
        .evaluate()
        .length;
    expect(
      scrollsAround(find.text('Save')),
      scrollsAround(find.byType(PinnedFooter)),
    );
    expect(tester.takeException(), isNull);

    Navigator.of(tester.element(find.text('Body'))).pop();
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}
