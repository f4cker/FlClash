import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/mac_update.dart';
import 'package:fl_clash/common/release_history.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/about.dart';
import 'package:fl_clash/views/release_history.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../helpers/test_app.dart';
import '../helpers/preferences.dart';
import '../helpers/mac_release.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final boundary = GlobalKey();
  testWidgets(
    'sealed installed beta remains visible with default-off preference',
    (tester) async {
      await mockPreferences();
      final container = ProviderContainer(
        overrides: [
          installedMacReleaseProvider.overrideWith(
            (ref) async => const MacInstalledIdentity(
              version: '1.1.0-beta.1',
              build: 2026111903,
              channel: ReleaseChannel.beta,
            ),
          ),
        ],
      );
      globalState.container = container;
      globalState.packageInfo = PackageInfo(
        appName: 'Flash',
        packageName: 'test.flash',
        version: '1.1.0',
        buildNumber: '2026111903',
      );
      final history = ReleaseHistory([
        PublishedRelease(
          tag: 'v1.1.0-beta.1',
          published: DateTime.utc(2026, 11, 20),
          body: '当前已安装的测试版本。关闭测试版订阅不会自动降级。',
          prerelease: true,
        ),
        PublishedRelease(
          tag: 'v1.0.0',
          published: DateTime.utc(2026, 11, 19),
          body: '正式版更新记录。',
        ),
      ], fetchedAt: DateTime.utc(2026, 11, 20));
      var fail = false;
      final store = ReleaseHistoryStore(
        fetch: () async {
          if (fail) throw StateError('offline fixture');
          return history;
        },
        readCache: () async => history.encode(),
        writeCache: (_) async {},
      );
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      Future<void> show(Widget child) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: boundary,
              child: TestApp(locale: const Locale('zh'), child: child),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(const AboutView());
      expect(find.text('接收测试版更新'), findsOneWidget);
      expect(find.text('开启后也会检查测试版；关闭后不会自动降级。'), findsOneWidget);
      expect(find.text('测试版'), findsOneWidget);
      expect(container.read(appSettingProvider).receiveBetaUpdates, isFalse);
      await tester.pumpAndSettle();
      container
          .read(appSettingProvider.notifier)
          .update((s) => s.copyWith(receiveBetaUpdates: true));
      await tester.pumpAndSettle();
      final beta = releaseManifest(
        channel: 'beta',
        version: '1.2.0-beta.1',
        build: 2026111904,
      );
      container.read(availableUpdateStateProvider.notifier).value =
          UpdateAvailable({'tag_name': beta.tag}, manifest: beta);
      await show(ReleaseHistoryView(store: store));
      expect(find.textContaining('1.2.0-beta.1 (2026111904)'), findsOneWidget);
      final currentTitle = find.textContaining('当前安装版本');
      final availableTitle = find.textContaining('新版本 1.2.0-beta.1');
      final betaLabels = find.text('测试版');
      expect(
        (tester.getCenter(currentTitle).dy -
                tester.getCenter(betaLabels.at(0)).dy)
            .abs(),
        lessThan(2),
      );
      expect(
        (tester.getCenter(availableTitle).dy -
                tester.getCenter(betaLabels.at(1)).dy)
            .abs(),
        lessThan(2),
      );
      tester.view.physicalSize = const Size(360, 1000);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(betaLabels.at(0)).dy,
        greaterThan(tester.getTopLeft(currentTitle).dy),
      );
      expect(
        tester.getTopLeft(betaLabels.at(1)).dy,
        greaterThan(tester.getTopLeft(availableTitle).dy),
      );
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1000, 1000);
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      final stable = releaseManifest(version: '1.2.0', build: 2026111905);
      container
          .read(availableUpdateStateProvider.notifier)
          .value = UpdateAvailable(
        {'tag_name': stable.tag},
        manifest: stable,
        discoveryIncomplete: true,
      );
      await tester.pumpAndSettle();
      fail = true;
      await store.refresh();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      store.dispose();
      container.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
