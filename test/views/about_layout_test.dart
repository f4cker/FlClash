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

  testWidgets('version sits under the name with a smaller build', (
    tester,
  ) async {
    await pump(tester, _beta);
    final name = find.text('Flash');
    final version = find.byKey(const ValueKey('about-version'));
    expect(find.text('1.0.0-beta.1 (2026111903)'), findsOneWidget);
    expect(
      tester.getTopLeft(version).dy - tester.getBottomLeft(name).dy,
      closeTo(8, 0.5),
    );
    expect(tester.getCenter(version).dx, closeTo(tester.getCenter(name).dx, 1));
    final text = tester.widget<Text>(version);
    expect(text.textAlign, TextAlign.center);
    final span = text.textSpan! as TextSpan;
    final secondary = tester.element(version).colorScheme.onSurfaceVariant;
    expect(span.text, '1.0.0-beta.1');
    expect(span.style!.fontSize, 16);
    expect(span.style!.fontWeight, FontWeight.w400);
    expect(span.style!.color, secondary);
    expect(span.children, hasLength(1));
    final build = span.children!.single as TextSpan;
    expect(build.text, ' (2026111903)');
    expect(build.style!.fontSize, 12);
    expect(build.style!.fontWeight, FontWeight.w400);
    expect(build.style!.color, secondary);
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

  testWidgets('icon artwork fills the icon area without a tile', (
    tester,
  ) async {
    await pump(tester, _stable);
    final area = find.byKey(const ValueKey('about-icon'));
    expect(tester.getSize(area), const Size.square(96));
    expect(
      find.descendant(of: area, matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    final image = tester.getRect(icon());
    expect(image.center, tester.getCenter(area));
    expect(image.width * 442 / 550, closeTo(96, 0.01));
    expect(tester.widget<Image>(icon()).fit, BoxFit.contain);
    expect(
      tester.getTopLeft(find.text('Flash')).dy - tester.getBottomLeft(area).dy,
      closeTo(24, 0.5),
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
    final iconBox = tester.getRect(find.byKey(const ValueKey('about-icon')));
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
    expect(find.text('1.0.0 (2026111902)'), findsOneWidget);
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
      closeTo(16, 0.5),
    );
    expect(tester.getTopLeft(subtitle).dx, tester.getTopLeft(title).dx);
    expect(
      tester.getTopLeft(title).dx,
      tester.getTopLeft(find.text('FlClash 上游项目')).dx,
    );
    expect(
      tester.getTopLeft(subtitle).dy,
      greaterThan(tester.getBottomLeft(title).dy - 1),
    );
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

  for (final width in [300.0, 340.0]) {
    testWidgets('at $width dp the beta description spans the card', (
      tester,
    ) async {
      await pump(tester, _beta, size: Size(width, 1000));
      expect(tester.takeException(), isNull);
      final row = find.byKey(const ValueKey('receive-beta-updates'));
      final slot = find
          .ancestor(
            of: find.byWidgetPredicate(
              (widget) =>
                  widget is GlyphIcon && widget.glyph == AppGlyphs.flask,
            ),
            matching: find.byType(SizedBox),
          )
          .first;
      final title = find.text('接收测试版更新');
      final subtitle = find.text('开启后也会检查测试版；关闭后不会自动降级。');
      final toggle = find.descendant(of: row, matching: find.byType(Switch));
      final slotRect = tester.getRect(slot);
      final switchRect = tester.getRect(toggle);
      final titleRect = tester.getRect(title);
      final subtitleRect = tester.getRect(subtitle);
      expect(titleRect.left - slotRect.right, closeTo(16, 0.5));
      expect(switchRect.center.dy, closeTo(slotRect.center.dy, 1));
      expect(titleRect.center.dy, closeTo(slotRect.center.dy, 1));
      expect(subtitleRect.top, greaterThanOrEqualTo(slotRect.bottom));
      expect(subtitleRect.left, closeTo(slotRect.left, 0.5));
      expect(subtitleRect.width, greaterThan(titleRect.width));
      expect(subtitleRect.right, greaterThan(switchRect.left));
      final style = tester.widget<Text>(subtitle).style!;
      expect(
        style.fontSize,
        AppTextStyle.subheadline.of(tester.element(subtitle)).fontSize,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(container.read(appSettingProvider).receiveBetaUpdates, isTrue);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(container.read(appSettingProvider).receiveBetaUpdates, isFalse);
    });
  }

  testWidgets('wide rows keep the description beside the switch', (
    tester,
  ) async {
    await pump(tester, _beta, size: const Size(700, 1000));
    final slot = find
        .ancestor(
          of: find.byWidgetPredicate(
            (widget) => widget is GlyphIcon && widget.glyph == AppGlyphs.flask,
          ),
          matching: find.byType(SizedBox),
        )
        .first;
    final subtitle = find.text('开启后也会检查测试版；关闭后不会自动降级。');
    expect(
      tester.getTopLeft(subtitle).dx,
      greaterThan(tester.getTopRight(slot).dx),
    );
  });
}
