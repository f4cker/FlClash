import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/common/mitm_script.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/mitm/script_actions.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const line =
      'Fix = type=http-response,pattern=^https://api\\.a\\.com/v1,'
      'requires-body=1,timeout=30,script-path=https://x.com/fix.js,'
      'argument=k=v';

  group('a script line', () {
    test('reads its kind, pattern, path and limits', () {
      final info = parseMitmScriptInfo(line)!;
      expect(info.name, 'Fix');
      expect(info.kind, MitmScriptKind.response);
      expect(info.pattern, r'^https://api\.a\.com/v1');
      expect(info.path, 'https://x.com/fix.js');
      expect(info.requiresBody, isTrue);
      expect(info.timeout, 10);
      expect(info.host, 'api.a.com');
    });

    test('names its stored file and keeps only what the Core reads', () {
      final info = parseMitmScriptInfo('$line,engine=webview,debug=1')!;
      final stored = parseMitmScriptInfo(info.lineWith('abc.js'))!;
      expect(stored.path, 'abc.js');
      expect(stored.params.containsKey('engine'), isFalse);
      expect(stored.params['argument'], 'k=v');
      expect(stored.pattern, info.pattern);
    });

    test('cron and generic scripts are not run', () {
      expect(
        parseMitmScriptInfo('C = type=cron,cronexp=* * * * *,script-path=a.js'),
        isNull,
      );
      expect(mitmHttpScriptLines([line, 'C = type=generic,script-path=a']), [
        line,
      ]);
    });
  });

  group('a paste', () {
    test('a bare URL becomes a response script on its host', () {
      final paste = parseMitmScriptPaste('\n https://cdn.b.org/x/y.js \n');
      expect(paste.isBareUrl, isTrue);
      final info = paste.drafts.single.info;
      expect(info.name, 'y');
      expect(info.kind, MitmScriptKind.response);
      expect(info.pattern, r'^https?://cdn\.b\.org/');
      expect(info.requiresBody, isTrue);
      expect(paste.drafts.single.isRemote, isTrue);
    });

    test('lines are read one by one; bad ones are numbered', () {
      final paste = parseMitmScriptPaste(
        [
          '[Script]',
          '# note',
          line,
          'C = type=cron,cronexp=1,script-path=https://a/b.js',
          'garbage',
          'N = type=http-request,script-path=https://a/b.js',
          'P = type=http-request,pattern=^http://a,script-path=local.js',
        ].join('\n'),
      );
      expect(paste.drafts.single.info.name, 'Fix');
      expect(paste.errors, {
        4: MitmScriptPasteError.unsupportedType,
        5: MitmScriptPasteError.unreadable,
        6: MitmScriptPasteError.noPattern,
        7: MitmScriptPasteError.noPath,
      });
    });
  });

  group('a line diff', () {
    test('shows changes and folds long unchanged runs', () {
      final before = [for (var i = 0; i < 30; i++) 'l$i'].join('\n');
      final after = before.replaceFirst('l10', 'L10');
      final diff = mitmLineDiff(before, after);
      expect(mitmDiffCounts(diff), (added: 1, removed: 1));
      expect(diff.first.kind, MitmDiffKind.folded);
      expect(diff.first.count, 7);
      expect(diff.last.kind, MitmDiffKind.folded);
    });

    test('past the cell limit shows the middle replaced', () {
      final diff = mitmLineDiff('a\nb\nc', 'a\nc\nb', maxCells: 1);
      expect(mitmDiffCounts(diff), (added: 2, removed: 2));
    });

    test('equal texts have no change', () {
      expect(mitmDiffCounts(mitmLineDiff('a\nb', 'a\nb')), (
        added: 0,
        removed: 0,
      ));
    });
  });

  test('an update names the hosts and scripts it brings', () {
    MitmModuleContent parse(String text) => previewMitmModule(text);
    final before = parse('''
#!name=M
[Script]
A = type=http-request,pattern=^https://a\\.com,script-path=https://s/a.js
[MITM]
hostname = %APPEND% a.com
''');
    final after = parse('''
#!name=M
[URL Rewrite]
^https://a\\.com/ad - reject
[Script]
B = type=http-response,pattern=^https://b\\.com,script-path=https://s/b.js
[MITM]
hostname = %APPEND% a.com, b.com
''');
    final change = mitmModuleChange(before, after);
    expect(change.addedHosts, ['b.com']);
    expect(change.removedHosts, isEmpty);
    expect(change.addedScripts.single, startsWith('B · http-response'));
    expect(change.removedScripts.single, startsWith('A · http-request'));
    expect((change.rewritesBefore, change.rewritesAfter), (0, 1));
    expect(change.bringsAccess, isTrue);
    expect(mitmModuleScripts(after).single.path, 'https://s/b.js');
    expect(mitmModuleScripts(after).map((info) => info.name), ['B']);
  });

  test('uncovered hosts follow wildcards and exclusions', () {
    expect(
      mitmUncoveredHosts(
        ['A.com', 'x.b.com', 'b.com', 'y.c.com', 'd.com'],
        ['a.com', '*.b.com', '-y.c.com', '*.c.com'],
      ),
      ['b.com', 'y.c.com', 'd.com'],
    );
    expect(mitmUncoveredHosts(['a.com'], ['*']), isEmpty);
  });

  test('the setup puts the profile before the modules', () {
    const mitm = Mitm(enable: true, hostname: ['a.com']);
    final setup = composeMitmSetup(
      mitm,
      rewrites: const [
        MitmRewrite(
          id: 1,
          section: MitmList.urlRewrite,
          line: '^https://a.com/x - reject',
        ),
        MitmRewrite(
          id: 2,
          section: MitmList.urlRewrite,
          line: 'off',
          enabled: false,
        ),
      ],
      scripts: const [
        MitmScript(id: 3, line: 'S = x', file: 'f.js'),
        MitmScript(id: 4, line: 'T = x', file: 'g.js', enabled: false),
      ],
      modules: const MitmModuleRules(
        hostname: ['m.com'],
        rewrite: [
          {'id': 'm9.url-rewrite.0', 'section': 'url-rewrite', 'line': 'r'},
        ],
        script: [
          {'id': 'm9.0', 'line': 'M = y'},
        ],
      ),
    );
    expect(setup['hostname'], ['a.com', 'm.com']);
    expect((setup['rewrite']! as List).map((item) => (item as Map)['id']), [
      '1',
      'm9.url-rewrite.0',
    ]);
    expect(setup['script'], [
      {'id': 's3', 'line': 'S = x'},
      {'id': 'm9.0', 'line': 'M = y'},
    ]);
    final bare = composeMitmSetup(
      mitm,
      rewrites: const [],
      scripts: const [],
      modules: MitmModuleRules.empty,
    );
    expect(bare.containsKey('script'), isFalse);
    expect(bare.containsKey('rewrite'), isFalse);
  });
}
