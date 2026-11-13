import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/widgets/page_source_rows.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('obsolete page versus file source choices are absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      const TestApp(
        locale: Locale('zh', 'CN'),
        child: PageSourceRows(
          changes: (
            pageRows: [
              PageSourceRow(
                key: PageConfigKey.allowLan,
                pageValue: false,
                fileValue: true,
              ),
            ],
            hiddenRows: [],
          ),
          choices: {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('跟随基础配置'), findsNothing);
    expect(find.text('保留页面设置'), findsNothing);
    expect(find.textContaining('文件：'), findsNothing);
  });
}
