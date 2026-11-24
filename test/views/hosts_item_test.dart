import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  Future<void> openHosts(
    WidgetTester tester, {
    Map<String, String> hosts = const {},
  }) async {
    const size = Size(1200, 1000);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).update((_) => size);
    container.listen(patchClashConfigProvider, (_, _) {});
    container.read(patchClashConfigProvider.notifier).value = PatchClashConfig(
      hosts: hosts,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: HostsItem()),
      ),
    );
    await tester.tap(find.byType(HostsItem));
    await tester.pumpAndSettle();
  }

  testWidgets('a value that mixes a domain into IPs is refused in place', (
    tester,
  ) async {
    await openHosts(tester);
    final l = currentAppLocalizations;
    await tester.tap(
      find.descendant(
        of: find.byType(MapEditView),
        matching: find.byTooltip(l.add),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(PopupMenu), matching: find.text(l.add)),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(FormRowTextField);
    await tester.enterText(fields.first, 'example.com');
    await tester.enterText(fields.last, '1.1.1.1 example.org');
    tester.widget<FormPage>(find.byType(FormPage)).onSave();
    await tester.pumpAndSettle();

    expect(find.text(l.hostsValueTip), findsOneWidget);
  });

  testWidgets('a cycle will not save', (tester) async {
    const hosts = {'a.com': 'b.com', 'b.com': 'a.com', 'x.com': '1.1.1.1'};
    await openHosts(tester, hosts: hosts);
    final printed = <String>[];
    final original = debugPrint;
    debugPrint = (text, {wrapWidth}) => printed.add(text ?? '');
    addTearDown(() => debugPrint = original);
    final l = currentAppLocalizations;

    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    await tester.tap(find.byTooltip(l.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, l.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l.save));
    await tester.pumpAndSettle();

    expect(printed, contains('[APP] banner: ${l.hostsCycleTip('a.com')}'));
    expect(find.byType(MapEditView), findsOneWidget, reason: 'stays open');
  });
}
