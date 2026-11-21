import 'package:fl_clash/common/mitm_rewrite.dart';
import 'package:fl_clash/core/method.dart' show CoreMethodException;
import 'package:fl_clash/features/mitm/rewrite_dialogs.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/rules/rule_edit_dialogs.dart' show RuleEditFrame;
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

final zh = lookupAppLocalizations(const Locale('zh', 'CN'));
final en = lookupAppLocalizations(const Locale('en'));
final ru = lookupAppLocalizations(const Locale('ru'));

MitmRewriteIssue _issue(String kind, [List<String> args = const []]) =>
    MitmRewriteIssue(
      section: 'script',
      kind: kind,
      args: args,
      message: 'core text for $kind',
    );

void main() {
  group('script issue codes', () {
    // As core/mitm_script.go sends them: Go-quoted where it quotes.
    final cases = <String, (List<String>, String, String)>{
      'scriptLine': (
        [],
        '脚本行格式不正确，或缺少请求/响应类型。',
        'The script line has an invalid format or is missing a request/response type.',
      ),
      'scriptType': (
        ['"cron"'],
        '不支持的脚本类型：cron。',
        'Unsupported script type: cron.',
      ),
      'scriptPattern': ([], '缺少匹配模式。', 'Missing match pattern.'),
      'scriptPath': ([], '缺少脚本路径。', 'Missing script path.'),
      'scriptMaxSize': (
        ['"10k"'],
        '字节数必须为数字：10k。',
        'The byte count must be a number: 10k.',
      ),
      'scriptTimeout': (
        ['"0"'],
        '秒数必须为数字：0。',
        'The number of seconds must be a number: 0.',
      ),
      'scriptArgument': (
        [],
        '参数不是有效的 JSON。',
        'The argument is not valid JSON.',
      ),
      // Without the script's own name: no file named (see below).
      'scriptUnreadable': (
        ['ab12.js'],
        '无法读取脚本文件。',
        'Cannot read the script file.',
      ),
      'scriptTooLarge': (
        ['ab12.js'],
        '脚本文件超过 8 MiB。',
        'The script file exceeds 8 MiB.',
      ),
      'scriptSyntax': (
        ['SyntaxError: Unexpected token (line 1)'],
        '脚本无法编译。',
        'The script could not be compiled.',
      ),
    };
    for (final MapEntry(key: kind, value: (args, zhText, enText))
        in cases.entries) {
      test('$kind reads in zh and en, its value filled', () {
        final issue = _issue(kind, args);
        expect(mitmRewriteIssueText(zh, issue), zhText);
        expect(mitmRewriteIssueText(en, issue), enText);
        expect(mitmRewriteIssueText(ru, issue), isNot(enText));
        final shown = mitmIssueError(zh, issue);
        expect(shown.text, zhText);
        expect(shown.raw, issue.message);
      });
    }

    test('a compile error stays out of the words, only in the details', () {
      const raw = 'script does not compile: SyntaxError: Unexpected token';
      const issue = MitmRewriteIssue(
        kind: 'scriptSyntax',
        args: ['SyntaxError: Unexpected token'],
        message: raw,
      );
      for (final l in [zh, en, ru]) {
        final shown = mitmIssueError(l, issue);
        expect(shown.text, isNot(contains('SyntaxError')));
        expect(shown.raw, raw);
      }
    });

    test('shared codes keep their rewrite words', () {
      expect(
        mitmRewriteIssueText(zh, _issue('unterminatedQuote', ['script'])),
        zh.mitmRewriteErrorUnterminatedQuote('script'),
      );
      expect(
        mitmRewriteIssueText(zh, _issue('dataFileName', ['"../a.js"'])),
        zh.mitmRewriteErrorDataFileName('"../a.js"'),
      );
      expect(
        mitmRewriteIssueText(zh, _issue('urlRegex')),
        zh.mitmRewriteErrorUrlRegex,
      );
      expect(
        mitmRewriteIssueText(zh, _issue('dataURL')),
        zh.mitmRewriteErrorDataUrl,
      );
    });

    test('an unknown or missing code reads generic, the raw text kept', () {
      for (final kind in ['scriptFuture', '']) {
        final shown = mitmIssueError(en, _issue(kind));
        expect(shown.text, en.mitmRewriteErrorGeneric);
        expect(shown.raw, 'core text for $kind');
      }
      expect(
        mitmIssueError(
          en,
          const MitmRewriteIssue(kind: 'x', message: '  '),
        ).raw,
        isNull,
      );
    });
  });

  group('mitmUnquotedArg', () {
    test('drops the quotes Go put around a plain value', () {
      expect(mitmUnquotedArg('"cron"'), 'cron');
      expect(mitmUnquotedArg(r'"a\"b"'), 'a"b');
      expect(mitmUnquotedArg(r'"\u00e9t\u00e9"'), 'été');
    });

    test('keeps them where the value would vanish or JSON cannot read it', () {
      expect(mitmUnquotedArg('""'), '""');
      expect(mitmUnquotedArg('" 1"'), '" 1"');
      expect(mitmUnquotedArg(r'"\x00"'), r'"\x00"');
      expect(mitmUnquotedArg('ab12.js'), 'ab12.js');
      expect(mitmUnquotedArg('"'), '"');
    });
  });

  group('a script row keeps its issue', () {
    test('and words it in the current language, the raw text behind', () {
      const issue = MitmRewriteIssue(
        section: 'script',
        kind: 'scriptType',
        args: ['"cron"'],
        message: '"cron" scripts are not supported',
      );
      final stored = mitmStoredIssue(issue);
      expect(mitmIssueOfStored(stored), issue);
      expect(mitmStoredError(zh, stored), (
        text: '不支持的脚本类型：cron。',
        raw: '"cron" scripts are not supported',
      ));
      expect(
        mitmStoredError(en, stored).text,
        'Unsupported script type: cron.',
      );
    });

    test('a stored script file reads by the name the user knows', () {
      const stored = '3f9a0c51e2b7d4a6.js';
      for (final (kind, message) in [
        ('scriptUnreadable', 'script file $stored cannot be read'),
        ('scriptTooLarge', 'script file $stored is over 8 MiB'),
      ]) {
        final issue = MitmRewriteIssue(
          section: 'script',
          kind: kind,
          args: const [stored],
          message: message,
        );
        for (final l in [zh, en, ru]) {
          final shown = mitmIssueError(l, issue, scriptName: '签到.js');
          expect(shown.text, contains('签到.js'));
          expect(shown.text, isNot(contains(stored)));
          // The stored name only behind 查看原始错误, as the Core said it.
          expect(shown.raw, message);
          final row = mitmStoredError(
            l,
            mitmStoredIssue(issue),
            scriptName: '签到.js',
          );
          expect(row, shown);
        }
        expect(
          mitmIssueError(zh, issue, scriptName: '签到.js').text,
          kind == 'scriptUnreadable' ? '无法读取文件：签到.js。' : '文件超过 8 MiB：签到.js。',
        );
        // No name to give, or a blank one: no file named, never a guess
        // from the stored name, which stays only in the details.
        for (final l in [zh, en, ru]) {
          final generic = kind == 'scriptUnreadable'
              ? l.mitmScriptErrorUnreadableNoName
              : l.mitmScriptErrorTooLargeNoName;
          for (final name in [null, '', '  ']) {
            final shown = mitmIssueError(l, issue, scriptName: name);
            expect(shown, (text: generic, raw: message));
            expect(
              mitmStoredError(l, mitmStoredIssue(issue), scriptName: name),
              shown,
            );
          }
        }
        expect(
          mitmIssueError(zh, issue).text,
          kind == 'scriptUnreadable' ? '无法读取脚本文件。' : '脚本文件超过 8 MiB。',
        );
        expect(
          mitmIssueError(en, issue).text,
          kind == 'scriptUnreadable'
              ? 'Cannot read the script file.'
              : 'The script file exceeds 8 MiB.',
        );
      }
    });

    test('other codes ignore the script name', () {
      const issue = MitmRewriteIssue(
        section: 'script',
        kind: 'scriptMaxSize',
        args: ['"10k"'],
        message: 'max-size must be a number of bytes, got "10k"',
      );
      expect(
        mitmIssueError(zh, issue, scriptName: '签到.js'),
        mitmIssueError(zh, issue),
      );
    });

    test('text it wrote itself, or an old row, shows as it is', () {
      expect(mitmIssueOfStored('Download failed'), isNull);
      expect(mitmIssueOfStored(null), isNull);
      expect(mitmStoredError(en, 'Download failed'), (
        text: 'Download failed',
        raw: null,
      ));
    });

    test('a kept issue it cannot read is generic, never the mark', () {
      const broken = '\u0001mitm-issue:{not json';
      expect(mitmIssueOfStored(broken), isNull);
      expect(mitmStoredError(zh, broken), (
        text: zh.mitmRewriteErrorGeneric,
        raw: null,
      ));
    });
  });

  group('a failed save or check', () {
    test('without the app\'s words is generic, the raw text behind', () {
      const error = CoreMethodException(
        code: 'internal',
        message: 'mitm: rule 3 failed: /Users/x/a.js',
      );
      expect(mitmRewriteFailure(zh, error), (
        text: zh.mitmRewriteFailureGeneric,
        raw: 'mitm: rule 3 failed: /Users/x/a.js',
      ));
      final applied = mitmRewriteNotAppliedError(zh, error);
      expect(
        applied.text,
        zh.mitmRewriteNotApplied(zh.mitmRewriteFailureGeneric),
      );
      expect(applied.raw, error.message);
    });

    test('with the app\'s words has no raw text', () {
      const error = CoreMethodException(
        code: 'rule_set_empty',
        message: 'empty',
      );
      expect(mitmRewriteFailure(zh, error), (
        text: zh.ruleSetEmptyTip,
        raw: null,
      ));
    });
  });

  group('RawErrorDetails', () {
    Future<void> pump(WidgetTester tester, Widget child, {Locale? locale}) =>
        tester.pumpWidget(
          TestApp(
            locale: locale ?? const Locale('zh', 'CN'),
            child: Center(child: child),
          ),
        );

    testWidgets('is collapsed until tapped, then shows the raw text as it is', (
      tester,
    ) async {
      const raw =
          'script does not compile: SyntaxError: (anonymous): Line 1:10';
      await pump(tester, const RawErrorDetails(raw: raw));
      await tester.pumpAndSettle();
      expect(find.text('查看原始错误'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      expect(find.textContaining('SyntaxError'), findsNothing);

      await tester.tap(find.text('查看原始错误'));
      await tester.pumpAndSettle();
      final shown = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(shown.data, raw);

      await tester.tap(find.text('查看原始错误'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('says its state to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        const RawErrorDetails(raw: 'x'),
        locale: const Locale('en'),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('View original error')),
        matchesSemantics(
          label: 'View original error',
          isButton: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.text('View original error'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('View original error')),
        matchesSemantics(
          label: 'View original error',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('shows nothing without raw text', (tester) async {
      await pump(tester, const RawErrorDetails(raw: null));
      expect(find.text('查看原始错误'), findsNothing);
      await pump(tester, const RawErrorDetails(raw: '  '));
      expect(find.text('查看原始错误'), findsNothing);
    });

    testWidgets('a new error starts collapsed', (tester) async {
      await pump(tester, const RawErrorDetails(raw: 'one'));
      await tester.tap(find.text('查看原始错误'));
      await tester.pumpAndSettle();
      expect(find.text('one'), findsOneWidget);
      await pump(tester, const RawErrorDetails(raw: 'two'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('sits in a dialog\'s error bar only with raw text', (
      tester,
    ) async {
      Widget frame(String? raw) => RuleEditFrame(
        title: 't',
        subtitle: 's',
        width: 420,
        primaryLabel: 'OK',
        onPrimary: null,
        error: '未能生效：出现错误，规则保持不变。',
        errorRaw: raw,
        children: const [SizedBox(height: 10)],
      );
      await pump(tester, frame(null));
      await tester.pumpAndSettle();
      expect(find.text('未能生效：出现错误，规则保持不变。'), findsOneWidget);
      expect(find.text('查看原始错误'), findsNothing);

      await pump(tester, frame('mitm: boom'));
      await tester.pumpAndSettle();
      expect(find.text('查看原始错误'), findsOneWidget);
      expect(find.text('mitm: boom'), findsNothing);
      await tester.tap(find.text('查看原始错误'));
      await tester.pumpAndSettle();
      expect(find.text('mitm: boom'), findsOneWidget);
    });
  });
}
