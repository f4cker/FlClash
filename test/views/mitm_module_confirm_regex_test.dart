import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_script.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/mitm_module_confirm.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

const _badLine = r'^http(s:// - reject';
const _coreMessage =
    'invalid URL regex: error parsing regexp: missing closing )';

/// One good URL rule, one the Core rejects, one body rule.
const _module =
    '''
#!name=Re
[MITM]
hostname = %APPEND% a.example.com
[URL Rewrite]
^https://a\\.example\\.com/(?!keep) - reject
$_badLine
[Body Rewrite]
http-response ^https://a\\.example\\.com/b x y
''';

/// What the Core says of [_module]: index 1 of the URL rules is a bad
/// pattern, every other list clean.
Map<MitmList, Map<int, MitmRewriteIssue>> _coreAnswer({bool body = true}) => {
  MitmList.urlRewrite: {
    1: const MitmRewriteIssue(
      section: 'url-rewrite',
      kind: 'urlRegex',
      message: _coreMessage,
    ),
  },
  MitmList.headerRewrite: const {},
  if (body) MitmList.bodyRewrite: const {},
  MitmList.mapLocal: const {},
};

void main() {
  late Database testDatabase;

  setUpAll(
    () async => useAppPaths(Directory.systemTemp.createTempSync('regex')),
  );

  setUp(() {
    testDatabase = Database(NativeDatabase.memory());
    database = testDatabase;
  });

  tearDown(() => testDatabase.close());

  /// The sheet with [validator] for the Core's word, or the real one (with
  /// no Core running) when null; the rules it was asked about.
  Future<List<MitmRules>> pump(
    WidgetTester tester, {
    MitmRewriteValidator? validator,
    Size size = const Size(1024, 900),
    Locale locale = const Locale('en'),
    double textScale = 1,
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
    final asked = <MitmRules>[];
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(
          () => TestProfiles([
            const Profile(id: 1, label: 'P', autoUpdateDuration: Duration.zero),
          ]),
        ),
        if (validator != null)
          mitmRewriteValidatorProvider.overrideWithValue((rules) {
            asked.add(rules);
            return validator(rules);
          }),
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
    return asked;
  }

  (Future<bool?>, List<(bool, bool)>) open(WidgetTester tester) {
    final imports = <(bool, bool)>[];
    final result = showMitmModuleConfirmDialog(
      tester.element(find.byType(SizedBox).first),
      content: previewMitmModule(_module),
      name: 'Re',
      source: 'raw.example.io',
      onImport: (enable, rules) async => imports.add((enable, rules)),
    );
    return (result, imports);
  }

  Finder textContaining(String part) => find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText().contains(part),
  );

  testWidgets('the Core rejects a pattern: that rule says it will not work', (
    tester,
  ) async {
    final asked = await pump(tester, validator: (_) async => _coreAnswer());
    open(tester);
    await tester.pumpAndSettle();
    final l = currentAppLocalizations;

    // Asked once, with the module's lines as written.
    expect(asked, hasLength(1));
    final content = previewMitmModule(_module);
    expect(asked.single.urlRewrite, content.urlRewrite);
    expect(asked.single.bodyRewrite, content.bodyRewrite);
    expect(content.urlRewrite[1], _badLine);

    final hint = textContaining(l.mitmRuleRegexInvalid);
    expect(hint, findsOneWidget);
    expect(textContaining(l.mitmRuleUnverified), findsNothing);
    // The main line names the group and place, never the line or reason.
    final main = tester.widget<RichText>(hint).text.toPlainText();
    expect(main, contains('${l.mitmRewriteGroupReject} #2'));
    expect(main, isNot(contains('http(s')));
    expect(main, isNot(contains('regexp')));
    expect(textContaining(_coreMessage), findsNothing);

    // The details hold both, once opened.
    await tester.tap(find.text(l.viewOriginalError));
    await tester.pumpAndSettle();
    expect(find.text('$_badLine\n$_coreMessage'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the check fails: every rule says it could not be checked', (
    tester,
  ) async {
    await pump(tester, validator: (_) async => throw TimeoutException('gone'));
    open(tester);
    await tester.pumpAndSettle();
    final l = currentAppLocalizations;
    expect(textContaining(l.mitmRuleUnverified), findsNWidgets(3));
    expect(textContaining(l.mitmRuleRegexInvalid), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the check times out: unverified, never valid', (tester) async {
    final never = Completer<Map<MitmList, Map<int, MitmRewriteIssue>>>();
    await pump(tester, validator: (_) => never.future);
    open(tester);
    await tester.pump();
    final l = currentAppLocalizations;
    // While it is asked, every rule says so; none looks passed.
    expect(textContaining(l.mitmRuleChecking), findsNWidgets(3));
    expect(textContaining(l.mitmRuleUnverified), findsNothing);
    await tester.pump(
      mitmModuleRewriteCheckTimeout - const Duration(milliseconds: 1),
    );
    expect(textContaining(l.mitmRuleChecking), findsNWidgets(3));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(textContaining(l.mitmRuleChecking), findsNothing);
    expect(textContaining(l.mitmRuleUnverified), findsNWidgets(3));
    expect(textContaining(l.mitmRuleRegexInvalid), findsNothing);
    // An answer after the timeout changes nothing.
    never.complete(_coreAnswer());
    await tester.pumpAndSettle();
    expect(textContaining(l.mitmRuleUnverified), findsNWidgets(3));
    expect(textContaining(l.mitmRuleRegexInvalid), findsNothing);
  });

  testWidgets('pending, every rule shows checking; the answer replaces it', (
    tester,
  ) async {
    final answer = Completer<Map<MitmList, Map<int, MitmRewriteIssue>>>();
    await pump(tester, validator: (_) => answer.future);
    open(tester);
    await tester.pump();
    final l = currentAppLocalizations;
    expect(textContaining(l.mitmRuleChecking), findsNWidgets(3));
    expect(textContaining(l.mitmRuleRegexInvalid), findsNothing);
    expect(textContaining(l.mitmRuleUnverified), findsNothing);
    // No details while there is nothing to tell.
    expect(find.text(l.viewOriginalError), findsNothing);

    answer.complete(_coreAnswer());
    await tester.pumpAndSettle();
    expect(textContaining(l.mitmRuleChecking), findsNothing);
    expect(textContaining(l.mitmRuleRegexInvalid), findsOneWidget);
    expect(textContaining(l.mitmRuleUnverified), findsNothing);
  });

  testWidgets('pending, then every rule loads: the checking rows go', (
    tester,
  ) async {
    final answer = Completer<Map<MitmList, Map<int, MitmRewriteIssue>>>();
    await pump(tester, validator: (_) => answer.future);
    open(tester);
    await tester.pump();
    final l = currentAppLocalizations;
    expect(textContaining(l.mitmRuleChecking), findsNWidgets(3));
    answer.complete({
      ..._coreAnswer(),
      MitmList.urlRewrite: const <int, MitmRewriteIssue>{},
    });
    await tester.pumpAndSettle();
    expect(textContaining(l.mitmRuleChecking), findsNothing);
    expect(textContaining(l.mitmRuleRegexInvalid), findsNothing);
    expect(textContaining(l.mitmRuleUnverified), findsNothing);
  });

  testWidgets('no Core running: unverified', (tester) async {
    await pump(tester);
    open(tester);
    await tester.pumpAndSettle();
    expect(
      textContaining(currentAppLocalizations.mitmRuleUnverified),
      findsNWidgets(3),
    );
  });

  testWidgets('a list the Core leaves out stays unverified', (tester) async {
    await pump(tester, validator: (_) async => _coreAnswer(body: false));
    open(tester);
    await tester.pumpAndSettle();
    final l = currentAppLocalizations;
    expect(textContaining(l.mitmRuleRegexInvalid), findsOneWidget);
    final unverified = textContaining(l.mitmRuleUnverified);
    expect(unverified, findsOneWidget);
    expect(
      tester.widget<RichText>(unverified).text.toPlainText(),
      contains('${l.mitmRewriteGroupBody} #1'),
    );
  });

  testWidgets('every rule loads: no hint', (tester) async {
    await pump(
      tester,
      validator: (_) async => {
        for (final list in [
          MitmList.urlRewrite,
          MitmList.headerRewrite,
          MitmList.bodyRewrite,
          MitmList.mapLocal,
        ])
          list: const <int, MitmRewriteIssue>{},
      },
    );
    open(tester);
    await tester.pumpAndSettle();
    final l = currentAppLocalizations;
    expect(textContaining(l.mitmRuleRegexInvalid), findsNothing);
    expect(textContaining(l.mitmRuleUnverified), findsNothing);
    expect(find.text(l.viewOriginalError), findsNothing);
  });

  testWidgets('a rule issue that is not a pattern is not called one', (
    tester,
  ) async {
    await pump(
      tester,
      validator: (_) async => {
        ..._coreAnswer(),
        MitmList.urlRewrite: {
          1: const MitmRewriteIssue(kind: 'urlFieldCount', message: 'x'),
        },
      },
    );
    open(tester);
    await tester.pumpAndSettle();
    final l = currentAppLocalizations;
    expect(textContaining(l.mitmRuleRegexInvalid), findsNothing);
    expect(textContaining(l.mitmRuleUnverified), findsNothing);
  });

  for (final (name, validator) in <(String, MitmRewriteValidator)>[
    ('an invalid rule', (_) async => _coreAnswer()),
    ('a failed check', (_) async => throw StateError('gone')),
    ('a check still pending', (_) => Completer<Never>().future),
  ]) {
    for (final (label, enable) in [
      ('Import and Turn On', true),
      ('Import Only', false),
      ('Cancel', null),
    ]) {
      testWidgets('with $name, $label acts as before', (tester) async {
        await pump(tester, validator: validator);
        final (result, imports) = open(tester);
        await tester.pumpAndSettle();
        final l = currentAppLocalizations;
        final button = switch (enable) {
          true => l.mitmImportAndEnable,
          false => l.mitmImportOnly,
          null => l.cancel,
        };
        if (name == 'a check still pending') {
          expect(textContaining(l.mitmRuleChecking), findsNWidgets(3));
        }
        await tester.tap(find.text(button), warnIfMissed: true);
        await tester.pumpAndSettle();
        expect(await result, enable);
        // Routing rules stay on, as the sheet opens with them.
        expect(imports, enable == null ? isEmpty : [(enable, true)]);
        expect(tester.takeException(), isNull);
        // A check outliving the sheet ends quietly.
        await tester.pump(mitmModuleRewriteCheckTimeout);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a screen reader hears each hint as one node, with its rule', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, validator: (_) async => _coreAnswer(body: false));
    open(tester);
    await tester.pumpAndSettle();
    final l = currentAppLocalizations;
    expect(
      find.bySemanticsLabel(
        '${l.mitmRewriteGroupReject} #2, ${l.mitmRuleRegexInvalid}',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        '${l.mitmRewriteGroupBody} #1, ${l.mitmRuleUnverified}',
      ),
      findsOneWidget,
    );
    // The details are a button that says whether it is open.
    final details = find.bySemanticsLabel(l.viewOriginalError);
    expect(details, findsNWidgets(2));
    final node = tester.getSemantics(details.first);
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isExpanded.toBoolOrNull(), isFalse);
    semantics.dispose();
  });

  testWidgets('a screen reader hears the answer once: one live region '
      'around the hints, none on each', (tester) async {
    final semantics = tester.ensureSemantics();
    final answer = Completer<Map<MitmList, Map<int, MitmRewriteIssue>>>();
    await pump(tester, validator: (_) => answer.future);
    open(tester);
    await tester.pumpAndSettle();
    final l = currentAppLocalizations;

    /// Every live region on screen, and the one holding [node] if any.
    (List<SemanticsNode>, SemanticsNode?) liveRegions(SemanticsNode node) {
      var root = node;
      while (root.parent != null) {
        root = root.parent!;
      }
      final found = <SemanticsNode>[];
      void visit(SemanticsNode node) {
        if (node.flagsCollection.isLiveRegion) found.add(node);
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(root);
      SemanticsNode? holder = node.parent;
      while (holder != null && !holder.flagsCollection.isLiveRegion) {
        holder = holder.parent;
      }
      return (found, holder);
    }

    final checking = tester.getSemantics(
      find.bySemanticsLabel(
        '${l.mitmRewriteGroupReject} #2, ${l.mitmRuleChecking}',
      ),
    );
    expect(checking.flagsCollection.isLiveRegion, isFalse);
    var (regions, holder) = liveRegions(checking);
    expect(regions, hasLength(1));
    expect(holder, same(regions.single));

    answer.complete(_coreAnswer());
    await tester.pumpAndSettle();
    final invalid = tester.getSemantics(
      find.bySemanticsLabel(
        '${l.mitmRewriteGroupReject} #2, ${l.mitmRuleRegexInvalid}',
      ),
    );
    // Its own label as before, no live region of its own.
    expect(invalid.flagsCollection.isLiveRegion, isFalse);
    (regions, holder) = liveRegions(invalid);
    expect(regions, hasLength(1));
    expect(holder, same(regions.single));
    semantics.dispose();
  });

  // Narrow and doubled text: the hints wrap, nothing overflows, and the
  // actions are still reached, the same as with no hints at all.
  for (final locale in const [Locale('ru'), Locale('fr')]) {
    for (final (name, validator) in <(String, MitmRewriteValidator)>[
      (
        'no hint',
        (_) async => {
          for (final list in [
            MitmList.urlRewrite,
            MitmList.headerRewrite,
            MitmList.bodyRewrite,
            MitmList.mapLocal,
          ])
            list: const <int, MitmRewriteIssue>{},
        },
      ),
      (
        'an invalid and an unverified rule',
        (_) async => _coreAnswer(body: false),
      ),
      ('every rule checking', (_) => Completer<Never>().future),
    ]) {
      testWidgets('${locale.languageCode} 360x640 ×2 with $name: wraps, '
          'no new overflow, the actions act', (tester) async {
        await pump(
          tester,
          validator: validator,
          size: const Size(360, 640),
          locale: locale,
          textScale: 2,
        );
        final errors = <FlutterErrorDetails>[];
        final reported = FlutterError.onError;
        FlutterError.onError = errors.add;
        final (result, imports) = open(tester);
        await tester.pumpAndSettle();
        FlutterError.onError = reported;
        final l = currentAppLocalizations;
        // The rewrite section row that overflowed by 20 dp on d2e42ee0 now
        // wraps (fix/module-import-l10n), and the hints add no overflow.
        expect(errors.map((e) => e.exceptionAsString()).toList(), isEmpty);
        for (final error in errors) {
          final info = error.informationCollector?.call().join('\n') ?? '';
          expect(info, isNot(contains('_MitmRuleHint')));
          expect(info, isNot(contains('RawErrorDetails')));
        }
        for (final text in [
          l.mitmRuleRegexInvalid,
          l.mitmRuleUnverified,
          l.mitmRuleChecking,
        ]) {
          final found = textContaining(text);
          for (final element in found.evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            final rect = tester.getRect(
              find.byElementPredicate((e) => e == element),
            );
            // Whole and inside the sheet's width; the long ones wrap.
            expect(paragraph.didExceedMaxLines, isFalse);
            if (text != l.mitmRuleChecking) {
              expect(paragraph.size.height, greaterThan(40));
            }
            expect(rect.right, lessThanOrEqualTo(360));
          }
        }
        final primary = find.text(l.mitmImportAndEnable);
        await tester.ensureVisible(primary);
        await tester.pumpAndSettle();
        await tester.tap(primary, warnIfMissed: true);
        await tester.pumpAndSettle();
        expect(await result, isTrue);
        expect(imports, [(true, true)]);
        expect(tester.takeException(), isNull);
        await tester.pump(mitmModuleRewriteCheckTimeout);
      });
    }
  }
}
