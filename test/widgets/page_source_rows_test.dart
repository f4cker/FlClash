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

Future<Set<PageConfigKey>> _pump(
  WidgetTester tester, {
  PagePriorityChanges changes = _changes,
  double width = 800,
  double height = 900,
}) async {
  final choices = <PageConfigKey>{};
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    TestApp(
      locale: const Locale('zh', 'CN'),
      overrides: [
        viewSizeProvider.overrideWithBuild((_, _) => Size(width, height)),
      ],
      child: HostScaffold(
        body: Center(
          child: AlertDialog(
            title: '确认设置来源',
            width: pageSourceDialogWidth,
            actions: [
              TextButton(onPressed: () {}, child: const Text('取消')),
              TextButton(onPressed: () {}, child: const Text('应用')),
            ],
            child: PageSourceRows(changes: changes, choices: choices),
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

  testWidgets('the hidden changes sit under their own title', (tester) async {
    await _pump(tester);

    expect(find.text('改为跟随配置文件'), findsOneWidget);
    expect(find.text('文件未填写的项使用默认值。'), findsNothing);
    final title = tester.getRect(find.text('改为跟随配置文件'));
    final line = tester.getRect(find.text('记住节点选择：关闭 → 开启'));
    expect(line.top, greaterThan(title.bottom));
  });

  testWidgets('a default filled in for a missing key is explained', (
    tester,
  ) async {
    await _pump(
      tester,
      changes: const (
        pageRows: [],
        hiddenRows: [
          HiddenOverrideRow(
            path: 'tun.dns-hijack',
            oldValue: ['any:53'],
            newValue: configKeyMissing,
          ),
        ],
      ),
    );

    expect(find.text('文件未填写的项使用默认值。'), findsOneWidget);
    expect(find.text('DNS劫持：any:53 → 未填写'), findsOneWidget);
  });

  testWidgets('the chosen source is tinted, not filled', (tester) async {
    await _pump(tester);

    final choice = tester.widget<SourceChoice>(find.byType(SourceChoice).first);
    expect(choice.follows, isFalse);
    final keep = tester.widget<Text>(find.text('保留页面设置').first);
    final follow = tester.widget<Text>(find.text('跟随基础配置').first);
    final primary = tester
        .element(find.byType(SourceChoice).first)
        .colorScheme
        .primary;
    expect(keep.style?.color, primary);
    expect(follow.style?.color, isNot(primary));
  });

  testWidgets('many rows scroll between a fixed title and buttons', (
    tester,
  ) async {
    await _pump(
      tester,
      changes: (
        pageRows: [
          for (final key in PageConfigKey.values.take(12))
            PageSourceRow(key: key, pageValue: 1, fileValue: 2),
        ],
        hiddenRows: const [],
      ),
      height: 600,
    );

    final title = tester.getRect(find.text('确认设置来源'));
    final apply = tester.getRect(find.text('应用'));
    expect(apply.bottom, lessThanOrEqualTo(600));
    final desc = find.text('页面与文件中的以下设置不同，请选择使用的来源。');
    final before = tester.getRect(desc).top;
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('确认设置来源')), title);
    expect(tester.getRect(find.text('应用')), apply);
    expect(tester.getRect(desc).top, lessThan(before));
  });

  testWidgets('the dialog is wide enough for the description on one line', (
    tester,
  ) async {
    await _pump(tester, height: 900, width: 800);

    final desc = tester.getSize(find.text('页面与文件中的以下设置不同，请选择使用的来源。'));
    final line = tester.getSize(find.text('改为跟随配置文件'));
    expect(desc.height, lessThan(line.height * 1.6));
    expect(
      tester.getSize(find.byType(AlertDialog)).width,
      greaterThanOrEqualTo(pageSourceDialogWidth),
    );
  });
}
