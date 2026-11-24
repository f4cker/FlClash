import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/general.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> openForm(
    WidgetTester tester, {
    required ExternalControllerStatus controller,
  }) async {
    const size = Size(1200, 1000);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).update((_) => size);
    container.listen(patchClashConfigProvider, (_, _) {});
    container.read(patchClashConfigProvider.notifier).value = PatchClashConfig(
      externalController: controller,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: PortItem()),
      ),
    );
    await tester.tap(find.byType(PortItem));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(FormRowTextField).first, '9090');
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('the mixed port cannot take the open controller\'s 9090', (
    tester,
  ) async {
    final container = await openForm(
      tester,
      controller: ExternalControllerStatus.open,
    );
    final l = currentAppLocalizations;

    expect(find.text(l.controllerPortConflictTip), findsOneWidget);
    tester.widget<FormPage>(find.byType(FormPage)).onSave();
    await tester.pumpAndSettle();
    expect(find.byType(FormPage), findsOneWidget, reason: 'stays open');
    expect(
      container.read(patchClashConfigProvider).mixedPort,
      defaultClashConfig.mixedPort,
    );
  });

  testWidgets('with the controller closed, 9090 is free', (tester) async {
    await openForm(tester, controller: ExternalControllerStatus.close);

    expect(
      find.text(currentAppLocalizations.controllerPortConflictTip),
      findsNothing,
    );
  });
}
