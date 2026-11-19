import 'package:dio/dio.dart';
import 'package:fl_clash/common/mac_update.dart';
import 'package:fl_clash/common/request.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/about.dart';
import 'package:fl_clash/views/release_history.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/preferences.dart';
import '../helpers/test_app.dart';

const _beta = MacInstalledIdentity(
  version: '1.0.0-beta.1',
  build: 2026111903,
  channel: ReleaseChannel.beta,
);
const _stable = MacInstalledIdentity(
  version: '1.0.0',
  build: 2026111902,
  channel: ReleaseChannel.stable,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;

  setUp(() async {
    await mockPreferences();
    globalState.packageInfo = PackageInfo(
      appName: 'Flash',
      packageName: 'test.flash',
      version: '1.0.0',
      buildNumber: '2026111902',
    );
  });
  tearDown(() => container.dispose());

  Future<void> pump(
    WidgetTester tester,
    MacInstalledIdentity identity, {
    Size size = const Size(1220, 1000),
  }) async {
    container = ProviderContainer(
      overrides: [
        installedMacReleaseProvider.overrideWith((ref) async => identity),
      ],
    );
    globalState.container = container;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(locale: Locale('zh'), child: AboutView()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder icon() => find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == 'assets/images/icon.png',
  );

  Finder betaFill(WidgetTester tester) {
    final primary = tester.element(find.byType(AboutView)).colorScheme.primary;
    return find.descendant(
      of: find.byKey(const ValueKey('about-beta-badge')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is ShapeDecoration &&
            (widget.decoration as ShapeDecoration).color == primary,
      ),
    );
  }

  testWidgets('version sits under the name in plain body text', (tester) async {
    await pump(tester, _beta);
    final name = find.text('Flash');
    final version = find.byKey(const ValueKey('about-version'));
    expect(find.text('1.0.0-beta.1+2026111903'), findsOneWidget);
    expect(
      tester.getTopLeft(version).dy - tester.getBottomLeft(name).dy,
      closeTo(8, 0.5),
    );
    expect(tester.getCenter(version).dx, closeTo(tester.getCenter(name).dx, 1));
    final context = tester.element(version);
    final style = tester.widget<Text>(version).style!;
    final body = AppTextStyle.body.of(context);
    expect(style.fontSize, body.fontSize);
    expect(style.fontWeight, FontWeight.w400);
    expect(style.color, context.colorScheme.onSurfaceVariant);
    expect(
      find.ancestor(of: version, matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    final license = find.text('GPL-3.0');
    expect(
      tester.getTopLeft(license).dy,
      greaterThan(tester.getBottomLeft(version).dy),
    );
  });

  testWidgets('beta badge overhangs the icon corner, off by default toggle', (
    tester,
  ) async {
    await pump(tester, _beta);
    expect(container.read(appSettingProvider).receiveBetaUpdates, isFalse);
    final badge = find.byKey(const ValueKey('about-beta-badge'));
    expect(badge, findsOneWidget);
    expect(find.bySemanticsLabel('当前安装的是测试版'), findsOneWidget);
    final fill = betaFill(tester);
    final iconBox = tester.getRect(
      find.ancestor(of: icon(), matching: find.byType(DecoratedBox)).first,
    );
    final pill = tester.getRect(fill);
    expect(pill.right - iconBox.right, closeTo(8, 0.5));
    expect(pill.bottom - iconBox.bottom, closeTo(4, 0.5));
    expect(pill.height, closeTo(24, 0.5));
    final text = tester.widget<Text>(
      find.descendant(of: badge, matching: find.text('测试版')),
    );
    expect(text.style!.fontWeight, FontWeight.w600);
    expect(text.style!.fontSize, 12);
    expect(
      find.descendant(of: badge, matching: find.byType(GestureDetector)),
      findsNothing,
    );
  });

  testWidgets('stable install shows no beta badge', (tester) async {
    await pump(tester, _stable);
    expect(find.byKey(const ValueKey('about-beta-badge')), findsNothing);
    expect(find.text('测试版'), findsNothing);
    expect(find.text('1.0.0+2026111902'), findsOneWidget);
  });

  testWidgets('changelog button sits beside check update and opens history', (
    tester,
  ) async {
    await pump(tester, _stable);
    final check = find.ancestor(
      of: find.text('检查更新'),
      matching: find.byType(TonalButton),
    );
    final changelog = find.byKey(const ValueKey('release-history-entry'));
    expect(tester.widget<TonalButton>(changelog).glyph, AppGlyphs.clock);
    expect(tester.widget<TonalButton>(check).onPressed, isNotNull);
    expect(find.text('更新日志'), findsOneWidget);
    final left = tester.getRect(check);
    final right = tester.getRect(changelog);
    expect(left.top, right.top);
    expect(left.height, right.height);
    expect(right.left - left.right, closeTo(12, 0.5));
    expect(
      (left.left + right.right) / 2,
      closeTo(tester.getCenter(find.text('Flash')).dx, 1),
    );
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response(requestOptions: options, data: <dynamic>[], statusCode: 200),
      ),
    );
    request.dio.interceptors.add(interceptor);
    addTearDown(() => request.dio.interceptors.remove(interceptor));
    await tester.tap(changelog);
    await tester.pumpAndSettle();
    expect(find.byType(ReleaseHistoryView), findsOneWidget);
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.byType(ReleaseHistoryView), findsNothing);
  });

  testWidgets('beta toggle row leads with the flask slot and still toggles', (
    tester,
  ) async {
    await pump(tester, _beta);
    final row = find.byKey(const ValueKey('receive-beta-updates'));
    final glyph = find.descendant(
      of: row,
      matching: find.byWidgetPredicate(
        (widget) => widget is GlyphIcon && widget.glyph == AppGlyphs.flask,
      ),
    );
    expect(glyph, findsOneWidget);
    expect(tester.getSize(glyph), const Size.square(24));
    final slot = find
        .ancestor(of: glyph, matching: find.byType(SizedBox))
        .first;
    expect(tester.getSize(slot), const Size.square(40));
    final title = find.text('接收测试版更新');
    final subtitle = find.text('开启后也会检查测试版；关闭后不会自动降级。');
    expect(
      tester.getTopLeft(title).dx - tester.getTopRight(slot).dx,
      closeTo(12, 0.5),
    );
    expect(tester.getTopLeft(subtitle).dx, tester.getTopLeft(title).dx);
    final moreSlot = find
        .ancestor(
          of: find.byWidgetPredicate(
            (widget) => widget is GlyphIcon && widget.glyph == AppGlyphs.code,
          ),
          matching: find.byType(SizedBox),
        )
        .first;
    expect(tester.getTopLeft(slot).dx, tester.getTopLeft(moreSlot).dx);
    await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
    await tester.pumpAndSettle();
    expect(container.read(appSettingProvider).receiveBetaUpdates, isTrue);
  });

  testWidgets('narrow width stacks the buttons without overflow', (
    tester,
  ) async {
    await pump(tester, _beta, size: const Size(300, 1000));
    expect(tester.takeException(), isNull);
    final check = find.ancestor(
      of: find.text('检查更新'),
      matching: find.byType(TonalButton),
    );
    final changelog = find.byKey(const ValueKey('release-history-entry'));
    final top = tester.getRect(check);
    final bottom = tester.getRect(changelog);
    expect(bottom.top - top.bottom, closeTo(8, 0.5));
    expect(top.center.dx, closeTo(bottom.center.dx, 1));
    expect(find.byKey(const ValueKey('about-beta-badge')), findsOneWidget);
  });
}
