import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/config/mitm_status.dart';
import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    mitmFeature = true;
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
    container.listen(patchClashConfigProvider, (_, _) {});
    container.read(patchClashConfigProvider.notifier).value =
        const PatchClashConfig(mitm: Mitm(enable: true));
  });

  tearDown(() {
    mitmFeature = false;
    container.dispose();
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    const size = Size(1220, 900);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(viewSizeProvider.notifier).value = size;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(
          child: DashboardView(platform: SupportPlatform.MacOS),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> teardown(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('the dashboard bar says decryption is on', (tester) async {
    await pumpDashboard(tester);
    expect(find.byType(MitmStatusCapsule), findsOneWidget);
    await teardown(tester);
  });

  testWidgets('a page opened over the dashboard does not', (tester) async {
    await pumpDashboard(tester);
    unawaited(
      Navigator.of(tester.element(find.byType(DashboardView))).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) =>
              const Scaffold(title: 'Requests', body: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DashboardView), findsNothing);
    expect(find.text('Requests'), findsOneWidget);
    expect(find.byType(MitmStatusCapsule), findsNothing);
    await teardown(tester);
  });

  testWidgets('the dashboard bar holds nothing while decryption is off', (
    tester,
  ) async {
    container.read(patchClashConfigProvider.notifier).value =
        const PatchClashConfig();
    await pumpDashboard(tester);
    expect(find.byType(MitmStatusCapsule), findsNothing);
    await teardown(tester);
  });
}
