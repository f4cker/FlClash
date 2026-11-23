import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/edit.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

class _ValidProfiles extends ProfilesAction {
  @override
  Future<String?> validateConfigWithData(List<int> data) async => null;
}

class _Preflight extends MountAction {
  _Preflight(this.issue);

  final Object? issue;

  @override
  Future<MountEditIssue?> preflightEdit(int targetId, List<int> data) async {
    if (issue case final Exception error) throw error;
    return issue as MountEditIssue?;
  }
}

void main() {
  final data = Uint8List.fromList('proxy-groups: []'.codeUnits);

  Future<({List<Uint8List?> popped, List<String> printed})> save(
    WidgetTester tester,
    Object? issue,
  ) async {
    final popped = <Uint8List?>[];
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (text, {wrapWidth}) => printed.add(text ?? '');
    addTearDown(() => debugPrint = original);
    final container = ProviderContainer(
      overrides: [
        profilesActionProvider.overrideWith(_ValidProfiles.new),
        mountActionProvider.overrideWith(() => _Preflight(issue)),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped.add(
                  await Navigator.of(context).push(
                    CardPageRoute<Uint8List>(
                      builder: (_) => Consumer(
                        builder: (context, ref, _) => TextButton(
                          onPressed: () =>
                              saveProfileEdit(context, ref, 1, data),
                          child: const Text('save'),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('save'));
    await tester.pumpAndSettle();
    return (popped: popped, printed: printed);
  }

  String? banner(List<String> printed) => printed
      .where((line) => line.startsWith('[APP] banner: '))
      .map((line) => line.substring('[APP] banner: '.length))
      .firstOrNull;

  testWidgets('a merged-config refusal holds the edit in the editor', (
    tester,
  ) async {
    final result = await save(tester, (
      reason: 'proxy group G: missing X',
      blocking: true,
    ));
    expect(result.popped, isEmpty);
    expect(find.text('save'), findsOneWidget);
    expect(
      find.textContaining(
        '${currentAppLocalizations.profileEditMountRejected}\n'
        'proxy group G: missing X',
      ),
      findsOneWidget,
    );
    expect(banner(result.printed), isNull);
  });

  testWidgets('a subscription problem saves the edit and warns', (
    tester,
  ) async {
    final reason = currentAppLocalizations.mountSourceMissingReason('Air');
    final result = await save(tester, (reason: reason, blocking: false));
    expect(result.popped, [data]);
    expect(find.text('save'), findsNothing);
    expect(
      banner(result.printed),
      '${currentAppLocalizations.profileEditMountSkipLead}\n$reason',
    );
  });

  testWidgets('without mounts, or a preflight that cannot run, the edit '
      'saves as before', (tester) async {
    var result = await save(tester, null);
    expect(result.popped, [data]);
    expect(banner(result.printed), isNull);

    result = await save(tester, Exception('core gone'));
    expect(result.popped, [data]);
    expect(banner(result.printed), isNull);
  });
}
