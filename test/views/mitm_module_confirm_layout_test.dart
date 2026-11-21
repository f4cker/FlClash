import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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
    TextDirection? textDirection,
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
        child: TestApp(
          locale: locale,
          textDirection: textDirection,
          child: const SizedBox(),
        ),
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

  /// The dialog's panel, and the frame's content inside its padding.
  (Rect, Rect) dialogRects(WidgetTester tester) => (
    tester.getRect(
      find
          .ancestor(
            of: find.byType(PinnedFooter),
            matching: find.byType(Surface),
          )
          .first,
    ),
    tester.getRect(find.byType(PinnedFooter)),
  );

  /// The padding the button around [label] keeps beside it.
  EdgeInsets labelPadding(WidgetTester tester, String label) =>
      tester
              .widget<Padding>(
                find
                    .ancestor(
                      of: find.text(label),
                      matching: find.byWidgetPredicate(
                        (widget) => widget is Padding && widget.child is Align,
                      ),
                    )
                    .first,
              )
              .padding
          as EdgeInsets;

  /// The window's margin each side of [panel], and [content]'s inside it.
  void expectInsets(
    WidgetTester tester, {
    required double outer,
    required double inner,
    double start = 0,
    double end = 0,
  }) {
    final (panel, content) = dialogRects(tester);
    final window = tester.view.physicalSize.width - end;
    expect(panel.left - start, closeTo(outer, 0.5), reason: 'left margin');
    expect(window - panel.right, closeTo(outer, 0.5), reason: 'right margin');
    expect(content.left - panel.left, closeTo(inner, 0.5));
    expect(panel.right - content.right, closeTo(inner, 0.5));
  }

  /// Opens the dialog in a narrow window between [start] and [end] insets:
  /// 16pt margins, 12pt label padding, actions as wide as the content, Tab
  /// in row order and Esc cancelling.
  Future<void> expectNarrow(
    WidgetTester tester, {
    double start = 0,
    double end = 0,
  }) async {
    final (result, imports) = open(tester);
    await tester.pumpAndSettle();
    final l = currentAppLocalizations;
    expect(tester.takeException(), isNull);

    expectInsets(tester, outer: 16, inner: 16, start: start, end: end);
    final (_, content) = dialogRects(tester);
    for (final label in stackedLabels(l)) {
      final padding = labelPadding(tester, label);
      expect(padding.left, 12, reason: label);
      expect(padding.right, 12, reason: label);
      final button = tester.getRect(buttonOf(label));
      expect(button.left, closeTo(content.left, 0.5), reason: label);
      expect(button.right, closeTo(content.right, 0.5), reason: label);
    }

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
    Object? closed = 'open';
    unawaited(result.then((value) => closed = value));
    await tester.pumpAndSettle();
    expect(closed, isNull);
    expect(imports, isEmpty);
    expect(tester.takeException(), isNull);
  }

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

      for (final size in const [narrow, Size(320, 640)]) {
        testWidgets('$tag ${size.width.toInt()}x640 ×${scale.toInt()}: 16pt '
            'margins, labels 12pt in, full-width actions, keyboard', (
          tester,
        ) async {
          await pump(tester, size: size, locale: locale, textScale: scale);
          await expectNarrow(tester);
        });
      }

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

  for (final locale in locales) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('${locale.languageCode} 1024x768 ×${scale.toInt()}: the '
          'alert keeps its width, margins and label padding', (tester) async {
        await pump(
          tester,
          size: const Size(1024, 768),
          locale: locale,
          textScale: scale,
        );
        final (result, _) = open(tester);
        await tester.pumpAndSettle();
        final l = currentAppLocalizations;
        expect(tester.takeException(), isNull);

        expectInsets(tester, outer: (1024 - 560) / 2, inner: 16);
        expect(find.byType(OverflowBox), findsNothing);
        // prism_ui's own label padding: no theme over the actions.
        final ambient = ButtonTheme.of(
          tester.element(find.byType(PinnedFooter)),
        );
        for (final label in stackedLabels(l)) {
          expect(
            ButtonTheme.of(tester.element(find.text(label))),
            same(ambient),
            reason: label,
          );
        }

        await tapButton(tester, l.cancel, capturePrints());
        expect(await result, isNull);
      });
    }
  }

  testWidgets('uneven side insets: 16pt from each safe edge, centred in '
      'the safe area', (tester) async {
    tester.view.padding = const FakeViewPadding(left: 24, right: 8);
    addTearDown(tester.view.resetPadding);
    await pump(
      tester,
      size: narrow,
      locale: const Locale('ru'),
      textScale: 2.0,
    );
    await expectNarrow(tester, start: 24, end: 8);
  });

  testWidgets('RTL 360x640: the stack, its margins and Tab order are as in '
      'LTR', (tester) async {
    await pump(
      tester,
      size: narrow,
      locale: const Locale('en'),
      textScale: 1.0,
      textDirection: TextDirection.rtl,
    );
    final (result, _) = open(tester);
    await tester.pumpAndSettle();
    final tops = [
      for (final label in stackedLabels(currentAppLocalizations))
        tester.getRect(buttonOf(label)).top,
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]));
    }
    await tapButton(tester, currentAppLocalizations.cancel, capturePrints());
    expect(await result, isNull);
    await expectNarrow(tester);
  });

  testWidgets(
    'RTL 1024x768: the row mirrors, Tab keeps the row order, Enter acts',
    skip: noArial != null,
    (tester) async {
      await realFont(tester);
      await pump(
        tester,
        size: const Size(1024, 768),
        locale: const Locale('en'),
        textScale: 1.0,
        textDirection: TextDirection.rtl,
      );
      final (result, imports) = open(tester);
      await tester.pumpAndSettle();
      final l = currentAppLocalizations;
      final labels = stackedLabels(l);
      final centers = [
        for (final label in labels) tester.getCenter(buttonOf(label)),
      ];
      for (var i = 1; i < centers.length; i++) {
        expect(centers[i].dy, closeTo(centers[0].dy, 0.5));
        expect(centers[i].dx, lessThan(centers[i - 1].dx), reason: labels[i]);
      }
      FocusNode nodeOf(String label) =>
          Focus.of(tester.element(find.text(label)), createDependency: false);
      nodeOf(labels.first).requestFocus();
      await tester.pumpAndSettle();
      for (final label in labels.skip(1)) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, nodeOf(label));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      Object? closed = 'open';
      unawaited(result.then((value) => closed = value));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(imports, [true]);
    },
  );

  testWidgets('a barrier tap leaves the dialog open', (tester) async {
    await pump(
      tester,
      size: narrow,
      locale: const Locale('en'),
      textScale: 1.0,
    );
    final (result, imports) = open(tester);
    await tester.pumpAndSettle();
    final (panel, _) = dialogRects(tester);
    for (final spot in [
      Offset(panel.left / 2, panel.center.dy),
      Offset(narrow.width - panel.left / 2, panel.center.dy),
      Offset(narrow.width / 2, 4),
    ]) {
      await tester.tapAt(spot);
      await tester.pumpAndSettle();
      expect(find.byType(PinnedFooter), findsOneWidget, reason: '$spot');
    }
    Object? closed = 'open';
    unawaited(result.then((value) => closed = value));
    await tester.pump();
    expect(closed, 'open');
    expect(imports, isEmpty);
    await tapButton(tester, currentAppLocalizations.cancel, capturePrints());
    expect(closed, isNull);
  });

  testWidgets('a plain prism_ui alert keeps the margin the frame assumes', (
    tester,
  ) async {
    const window = Size(800, 600);
    await pump(
      tester,
      size: window,
      locale: const Locale('en'),
      textScale: 1.0,
    );
    // Wider than the window: only prism_ui's margin decides where it ends.
    unawaited(
      dialogs.showCommonDialog<void>(
        context: tester.element(find.byType(SizedBox).first),
        child: const AlertDialog(title: 'T', width: 2000, child: Text('Body')),
      ),
    );
    await tester.pumpAndSettle();
    final panel = tester.getRect(
      find
          .ancestor(of: find.text('Body'), matching: find.byType(Surface))
          .first,
    );
    expect(panel.width, greaterThan(280));
    expect(panel.left, closeTo(ruleEditAlertMargin, 0.5));
    expect(window.width - panel.right, closeTo(ruleEditAlertMargin, 0.5));
    Navigator.of(tester.element(find.text('Body'))).pop();
    await tester.pumpAndSettle();
  });

  /// A frame with every kind of action: delete, a leading one, cancel, save.
  (Future<bool?>, List<String>) openFrame(
    WidgetTester tester, {
    FocusNode? body,
    bool dismissible = false,
    double? narrowMargin,
  }) {
    final calls = <String>[];
    final result = dialogs.showCommonDialog<bool>(
      context: tester.element(find.byType(SizedBox).first),
      dismissible: dismissible,
      child: RuleEditFrame(
        narrowMargin: narrowMargin,
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

  testWidgets('a dismissible narrow frame: a tap outside the panel closes it, '
      'one inside does not', (tester) async {
    await pump(
      tester,
      size: narrow,
      locale: const Locale('en'),
      textScale: 1.0,
    );
    for (final outside in [
      const Offset(8, 320),
      Offset(narrow.width - 8, 320),
      Offset(narrow.width / 2, 4),
    ]) {
      final (result, calls) = openFrame(
        tester,
        dismissible: true,
        narrowMargin: 16,
      );
      await tester.pumpAndSettle();
      expect(find.byType(OverflowBox), findsOneWidget);
      expectInsets(tester, outer: 16, inner: 16);

      await tester.tapAt(tester.getCenter(find.text('Body')));
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsOneWidget, reason: 'inside');

      Object? closed = 'open';
      unawaited(result.then((value) => closed = value));
      await tester.tapAt(outside);
      await tester.pumpAndSettle();
      expect(find.text('Body'), findsNothing, reason: '$outside');
      expect(closed, isNull, reason: '$outside');
      expect(calls, isEmpty);
    }
  });

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

  testWidgets('other frames keep the alert margin, no OverflowBox', (
    tester,
  ) async {
    await pump(
      tester,
      size: narrow,
      locale: const Locale('en'),
      textScale: 2.0,
    );
    final (result, _) = openFrame(tester);
    await tester.pumpAndSettle();
    expectInsets(tester, outer: ruleEditAlertMargin, inner: 16);
    expect(find.byType(OverflowBox), findsNothing);
    Navigator.of(tester.element(find.text('Body'))).pop();
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

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

  /// The clipping ancestors of [target] that cut any of it off.
  List<String> clipsCutting(WidgetTester tester, Finder target) {
    Rect global(RenderBox box) => MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    final box = tester.renderObject<RenderBox>(target);
    final rect = global(box);
    final cuts = <String>[];
    for (var node = box.parent; node != null; node = node.parent) {
      final clip = switch (node) {
        RenderClipRect(:final clipBehavior) ||
        RenderClipRRect(:final clipBehavior) ||
        RenderClipPath(:final clipBehavior) ||
        RenderPhysicalShape(:final clipBehavior) ||
        RenderPhysicalModel(:final clipBehavior) ||
        RenderStack(:final clipBehavior) ||
        RenderFlex(:final clipBehavior) => clipBehavior,
        RenderAbstractViewport() => Clip.hardEdge,
        _ => Clip.none,
      };
      if (clip == Clip.none || node is! RenderBox) continue;
      final kept = global(node).intersect(rect);
      if (kept.width < rect.width - 0.5 || kept.height < rect.height - 0.5) {
        cuts.add('${node.runtimeType}');
      }
    }
    return cuts;
  }

  for (final tag in const ['en', 'ru']) {
    for (final scale in const [1.0, 2.0]) {
      final name = '$tag 320x640 ×${scale.toInt()}, real font';

      testWidgets(
        '$name: once settled, the panel and every action are whole on '
        'screen, nothing clips them',
        skip: noArial != null,
        (tester) async {
          await realFont(tester);
          const size = Size(320, 640);
          await pump(tester, size: size, locale: Locale(tag), textScale: scale);
          final (result, _) = open(tester);
          await tester.pumpAndSettle();
          final l = currentAppLocalizations;
          final screen = Offset.zero & size;

          final (panel, _) = dialogRects(tester);
          expect(screen.intersect(panel), panel);
          expect(find.byType(OverflowBox), findsOneWidget);
          for (final label in stackedLabels(l)) {
            final button = tester.getRect(buttonOf(label));
            expect(screen.intersect(button), button, reason: label);
            expect(clipsCutting(tester, buttonOf(label)), isEmpty);
            expect(clipsCutting(tester, find.text(label)), isEmpty);
          }
          expect(tester.takeException(), isNull);

          await tester.tapAt(tester.getCenter(buttonOf(l.cancel)));
          await tester.pumpAndSettle();
          expect(await result, isNull);
        },
      );

      for (final (action, enable) in const [
        ('Import Only', false),
        ('Cancel', null),
        ('Import and Turn On', true),
      ]) {
        testWidgets(
          '$name: $action takes a tap at its centre unscrolled, and Enter',
          skip: noArial != null,
          (tester) async {
            await realFont(tester);
            await pump(
              tester,
              size: const Size(320, 640),
              locale: Locale(tag),
              textScale: scale,
            );
            final l = currentAppLocalizations;
            final label = switch (enable) {
              true => l.mitmImportAndEnable,
              false => l.mitmImportOnly,
              null => l.cancel,
            };
            for (final byKey in [false, true]) {
              final (result, imports) = open(tester);
              await tester.pumpAndSettle();
              Object? closed = 'open';
              unawaited(result.then((value) => closed = value));
              if (byKey) {
                final labels = stackedLabels(l);
                Focus.of(
                  tester.element(find.text(labels.first)),
                  createDependency: false,
                ).requestFocus();
                await tester.pumpAndSettle();
                for (final _ in labels.take(labels.indexOf(label))) {
                  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
                  await tester.pumpAndSettle();
                }
                await tester.sendKeyEvent(LogicalKeyboardKey.enter);
              } else {
                await tester.tapAt(tester.getCenter(buttonOf(label)));
              }
              await tester.pumpAndSettle();
              expect(closed, enable, reason: 'byKey: $byKey');
              expect(imports, enable == null ? isEmpty : [enable]);
            }
            final (result, _) = open(tester);
            await tester.pumpAndSettle();
            Focus.of(
              tester.element(find.text(label)),
              createDependency: false,
            ).requestFocus();
            await tester.pumpAndSettle();
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            Object? closed = 'open';
            unawaited(result.then((value) => closed = value));
            await tester.pumpAndSettle();
            expect(closed, isNull);
          },
        );
      }
    }
  }

  /// The product of every fade above the panel: what share of it is drawn.
  double panelOpacity(WidgetTester tester) {
    var opacity = 1.0;
    tester.element(find.byType(PinnedFooter)).visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is LiquidGlassFade) {
        opacity *= widget.opacity.value.clamp(0.0, 1.0);
      } else if (widget is FadeTransition) {
        opacity *= widget.opacity.value;
      } else if (widget is Opacity) {
        opacity *= widget.opacity;
      }
      return true;
    });
    return opacity;
  }

  Rect scaledAbout(Rect rect, Offset centre, double scale) => Rect.fromLTRB(
    centre.dx + (rect.left - centre.dx) * scale,
    centre.dy + (rect.top - centre.dy) * scale,
    centre.dx + (rect.right - centre.dx) * scale,
    centre.dy + (rect.bottom - centre.dy) * scale,
  );

  /// The alert's entry: 404 ms on one spring that both fades it in and
  /// shrinks it from 1.2 times its size.
  const entry = Duration(milliseconds: 404);

  for (final tag in const ['en', 'ru']) {
    for (final scale in const [1.0, 2.0]) {
      final name = '$tag 320x640 ×${scale.toInt()}, real font, entry';

      testWidgets(
        '$name: past the window only while at most 0.6 opaque, and whole '
        'on screen from 22% on',
        skip: noArial != null,
        (tester) async {
          await realFont(tester);
          const size = Size(320, 640);
          final screen = Offset.zero & size;
          await pump(tester, size: size, locale: Locale(tag), textScale: scale);
          final (result, _) = open(tester);
          Object? closed = 'open';
          unawaited(result.then((value) => closed = value));
          final l = currentAppLocalizations;
          final frames = <(int, double, Rect, List<Rect>)>[];
          for (var ms = 0; ms <= entry.inMilliseconds; ms++) {
            await tester.pump(
              ms == 0 ? Duration.zero : const Duration(milliseconds: 1),
            );
            frames.add((
              ms,
              panelOpacity(tester),
              dialogRects(tester).$1,
              [
                for (final label in stackedLabels(l))
                  tester.getRect(buttonOf(label)),
              ],
            ));
          }
          await tester.pumpAndSettle();
          final (settled, _) = dialogRects(tester);
          final centre = size.center(Offset.zero);
          expect(
            settled,
            rectMoreOrLessEquals(
              const Rect.fromLTRB(16, 24, 304, 616),
              epsilon: 0.5,
            ),
          );

          bool whole(Rect rect) => screen.intersect(rect) == rect;
          var lastPastPanel = -1, lastPastButton = -1;
          var opacityPast = 0.0, widestPast = 0.0;
          for (final (ms, opacity, panel, buttons) in frames) {
            final grown = scaledAbout(settled, centre, 1.2 - 0.2 * opacity);
            expect(
              panel,
              rectMoreOrLessEquals(grown, epsilon: 0.5),
              reason: '$ms ms',
            );
            if (!whole(panel)) {
              lastPastPanel = ms;
              opacityPast = math.max(opacityPast, opacity);
              widestPast = math.max(widestPast, -panel.left);
            }
            if (!buttons.every(whole)) lastPastButton = ms;
          }
          final (_, first, firstPanel, _) = frames.first;
          expect(first, 0);
          expect(
            firstPanel,
            rectMoreOrLessEquals(
              const Rect.fromLTRB(-12.8, -35.2, 332.8, 675.2),
              epsilon: 0.5,
            ),
          );
          expect(widestPast, closeTo(12.8, 0.1));
          expect(lastPastPanel, 87);
          expect(opacityPast, closeTo(0.591, 0.005));
          expect(lastPastButton, 36);

          const quarters = {
            0: (0.0, Rect.fromLTRB(-12.8, -35.2, 332.8, 675.2)),
            101: (0.671, Rect.fromLTRB(6.5, 4.5, 313.5, 635.5)),
            202: (0.945, Rect.fromLTRB(14.4, 20.7, 305.6, 619.3)),
            303: (0.993, Rect.fromLTRB(15.8, 23.6, 304.2, 616.4)),
            404: (1.0, Rect.fromLTRB(16, 24, 304, 616)),
          };
          for (final MapEntry(key: ms, value: (opacity, rect))
              in quarters.entries) {
            final (_, drawn, panel, buttons) = frames[ms];
            expect(drawn, closeTo(opacity, 0.001), reason: '$ms ms');
            expect(
              panel,
              rectMoreOrLessEquals(rect, epsilon: 0.1),
              reason: '$ms ms',
            );
            expect(whole(panel), ms > 0, reason: '$ms ms');
            expect(buttons.every(whole), ms > 0, reason: '$ms ms');
          }

          await tester.tapAt(tester.getCenter(buttonOf(l.cancel)));
          await tester.pumpAndSettle();
          expect(closed, isNull);
        },
      );
    }

    testWidgets(
      '$tag 320x640, entry: each action taken half way in acts',
      skip: noArial != null,
      (tester) async {
        await realFont(tester);
        await pump(
          tester,
          size: const Size(320, 640),
          locale: Locale(tag),
          textScale: 1,
        );
        final l = currentAppLocalizations;
        for (final (label, enable) in [
          (l.mitmImportOnly, false),
          (l.cancel, null),
          (l.mitmImportAndEnable, true),
        ]) {
          final (result, imports) = open(tester);
          Object? closed = 'open';
          unawaited(result.then((value) => closed = value));
          await tester.pump();
          await tester.pump(entry ~/ 2);
          expect(panelOpacity(tester), inExclusiveRange(0.9, 0.99));
          await tester.tapAt(tester.getCenter(buttonOf(label)));
          await tester.pumpAndSettle();
          expect(closed, enable, reason: label);
          expect(imports, enable == null ? isEmpty : [enable], reason: label);
        }
      },
    );

    testWidgets(
      '$tag 320x640, real font, nothing focused first: Esc does nothing '
      'until Tab reaches an action, as on d2e42ee0',
      skip: noArial != null,
      (tester) async {
        await realFont(tester);
        await pump(
          tester,
          size: const Size(320, 640),
          locale: Locale(tag),
          textScale: 1,
        );
        final l = currentAppLocalizations;
        String focused() {
          final node = FocusManager.instance.primaryFocus;
          if (node is FocusScopeNode &&
              (node.debugLabel ?? '').contains('_ModalScopeState')) {
            return 'route';
          }
          for (final label in [...stackedLabels(l), l.mitmMoreHosts(9)]) {
            for (final element
                in find.text(label, findRichText: true).evaluate()) {
              if (Focus.of(element, createDependency: false) == node) {
                return label;
              }
            }
          }
          return 'other';
        }

        for (final mid in [false, true]) {
          final (result, imports) = open(tester);
          Object? closed = 'open';
          unawaited(result.then((value) => closed = value));
          if (mid) {
            await tester.pump();
            await tester.pump(entry ~/ 2);
          } else {
            await tester.pumpAndSettle();
          }
          final why = mid ? 'half way in' : 'settled';
          expect(focused(), 'route', reason: why);
          expect(
            await tester.sendKeyEvent(LogicalKeyboardKey.escape),
            isFalse,
            reason: why,
          );
          await tester.pumpAndSettle();
          expect(closed, 'open', reason: why);
          for (final label in [...stackedLabels(l), l.mitmMoreHosts(9)]) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pumpAndSettle();
            expect(focused(), label, reason: why);
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(closed, isNull, reason: why);
          expect(imports, isEmpty);
        }

        final (result, _) = open(tester);
        Object? closed = 'open';
        unawaited(result.then((value) => closed = value));
        await tester.pump();
        await tester.pump(entry ~/ 2);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final firstTab = focused();
        expect(firstTab, tag == 'ru' ? l.mitmMoreHosts(9) : 'route');
        expect(stackedLabels(l), isNot(contains(firstTab)));
        expect(closed, 'open');
        await tester.tapAt(tester.getCenter(buttonOf(l.cancel)));
        await tester.pumpAndSettle();
        expect(closed, isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }
}
