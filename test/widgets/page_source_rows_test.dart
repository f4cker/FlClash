import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/page_source_rows.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';

const PagePriorityChanges _changes = (
  pageRows: [
    PageSourceRow(
      key: PageConfigKey.logLevel,
      pageValue: 'error',
      fileValue: 'silent',
    ),
    PageSourceRow(
      key: PageConfigKey.findProcessMode,
      pageValue: 'off',
      fileValue: 'always',
    ),
    PageSourceRow(
      key: PageConfigKey.allowLan,
      pageValue: true,
      fileValue: configKeyMissing,
    ),
  ],
  hiddenRows: [
    HiddenOverrideRow(
      path: 'profile.store-selected',
      oldValue: false,
      newValue: true,
    ),
  ],
);

Future<Set<PageConfigKey>> _pump(WidgetTester tester) async {
  final choices = <PageConfigKey>{};
  await tester.pumpWidget(
    TestApp(
      locale: const Locale('zh', 'CN'),
      overrides: [
        viewSizeProvider.overrideWithBuild((_, _) => const Size(420, 900)),
      ],
      child: HostScaffold(
        body: Center(
          child: AlertDialog(
            title: '确认设置来源',
            actions: [
              TextButton(onPressed: () {}, child: const Text('取消')),
              TextButton(onPressed: () {}, child: const Text('应用')),
            ],
            child: PageSourceRows(changes: _changes, choices: choices),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return choices;
}

void main() {
  testWidgets('each row compares the page with the file in field terms', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('页面：错误 · 文件：静默'), findsOneWidget);
    expect(find.text('页面：关闭 · 文件：总是'), findsOneWidget);
    expect(find.text('页面：开启 · 文件：未填写，默认 关闭'), findsOneWidget);
    expect(find.text('记住节点选择：关闭 → 开启'), findsOneWidget);
    expect(find.text('保留页面设置'), findsNWidgets(3));
    expect(find.text('跟随基础配置'), findsNWidgets(3));
  });

  testWidgets('every row starts on the page and switches on its own', (
    tester,
  ) async {
    final choices = await _pump(tester);
    expect(choices, isEmpty);

    await tester.tap(find.text('跟随基础配置').at(1));
    await tester.pumpAndSettle();

    expect(choices, {PageConfigKey.findProcessMode});
  });

  testWidgets('golden', (tester) async {
    await _pump(tester);

    await expectLater(
      find.byType(AlertDialog),
      matchesGoldenFile('goldens/page_source_dialog.png'),
    );
  });
}
