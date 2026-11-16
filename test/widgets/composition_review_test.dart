import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

class _DialogProbe extends SetupAction {
  Future<bool> open() => super.reviewComposition(
    '''
tun: {enable: true, stack: mixed}
hosts: {}
dns: {use-hosts: false, generated-zero: 0}
secret: synthetic-secret-never-display
proxies: [{name: hidden-bulk-proxy}]
''',
    pagePaths: {'tun.enable', 'tun.stack', 'hosts', 'secret'},
    basePaths: {'dns.use-hosts'},
  );
}

void main() {
  for (final locale in [const Locale('en'), const Locale('zh', 'CN')]) {
    testWidgets(
      'first adoption review has honest sources and Cancel/Apply only ($locale)',
      (tester) async {
        final probe = _DialogProbe();
        bool? result;
        await tester.pumpWidget(
          TestApp(
            locale: locale,
            child: Center(
              child: GestureDetector(
                onTap: () async {
                  result = await probe.open();
                },
                child: const Text('Open synthetic review'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final strings = currentAppLocalizations;
        await tester.tap(find.text('Open synthetic review'));
        await tester.pumpAndSettle();
        expect(find.text(strings.compositionReviewTitle), findsOneWidget);
        expect(find.text(strings.compositionBaselineUnknown), findsOneWidget);
        expect(find.text(strings.compositionCandidateNote), findsOneWidget);
        expect(
          find.text('tun.enable: true · ${strings.sourcePage}'),
          findsOneWidget,
        );
        expect(find.text('hosts: {} · ${strings.sourcePage}'), findsOneWidget);
        expect(
          find.text('dns.use-hosts: false · ${strings.sourceBase}'),
          findsOneWidget,
        );
        expect(
          find.text(
            'dns.generated-zero: 0 · ${strings.compositionSourceUnconfirmed}',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('synthetic-secret-never-display'),
          findsNothing,
        );
        expect(find.textContaining('hidden-bulk-proxy'), findsNothing);
        expect(find.text(strings.followBaseProfile), findsNothing);
        expect(find.text(strings.keepPageSetting), findsNothing);
        await tester.tap(find.text(strings.cancel));
        await tester.pumpAndSettle();
        expect(result, false);
        await tester.tap(find.text('Open synthetic review'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(strings.applyAction));
        await tester.pumpAndSettle();
        expect(result, true);
      },
    );
  }
}
