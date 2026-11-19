import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/features/mitm/rewrite.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/features/mitm/script.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/mount.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/app_paths.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _NoCore extends Mock implements CoreHandlerInterface {}

class _Scripts extends ProfileMitmScripts {
  _Scripts(this.items);
  final List<MitmScript> items;

  void clear() => state = const AsyncData([]);

  @override
  Stream<List<MitmScript>> build(int profileId) => Stream.value(items);

  @override
  Future<void> commit(List<MitmScript> scripts) async =>
      throw Exception('script write failed');
}

class _Rewrites extends ProfileMitmRewrites {
  _Rewrites(this.items);
  final List<MitmRewrite> items;

  void clear() => state = const AsyncData([]);

  @override
  Stream<List<MitmRewrite>> build(int profileId) => Stream.value(items);

  @override
  Future<void> commit(List<MitmRewrite> rewrites) async =>
      throw Exception('rewrite write failed');
}

void main() {
  final output = Platform.environment['MITM_NOTICE_SCREENSHOTS'];
  final boundary = GlobalKey();

  setUpAll(() async {
    WidgetsApp.debugAllowBannerOverride = false;
    await useAppPaths(Directory.systemTemp.createTempSync('mitm-notices'));
    if (output != null) {
      Directory(output).createSync(recursive: true);
      final font = ByteData.sublistView(
        File('/System/Library/Fonts/Hiragino Sans GB.ttc').readAsBytesSync(),
      );
      for (final family in ['Roboto', 'PingFang SC']) {
        await (FontLoader(family)..addFont(Future.value(font))).load();
      }
    }
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (output == null) return;
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      File('$output/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      File('$output/$name.json').writeAsStringSync(
        jsonEncode({
          'toolbarBottom': tester.getBottomLeft(find.byType(ScaffoldBar)).dy,
          'notices': [
            for (final element in find.byType(MountBanner).evaluate())
              tester.getRect(find.byWidget(element.widget)).toString(),
          ],
          'enableActionHitTestable': find
              .text(currentAppLocalizations.mitmRewriteGoTurnOn)
              .hitTestable()
              .evaluate()
              .isNotEmpty,
        }),
      );
    });
  }

  for (final script in [false, true]) {
    for (final populated in [false, true]) {
      for (final enabled in [false, true]) {
        for (final width in [390.0, 1220.0]) {
          for (final scale in [1.0, 2.0]) {
            for (final brightness in Brightness.values) {
              final name =
                  '${script ? 'scripts' : 'rewrite'}-'
                  '${populated ? 'populated' : 'empty'}-'
                  '${enabled ? 'on' : 'off'}-'
                  '${width.toInt()}-${scale.toInt()}x-${brightness.name}';
              testWidgets(name, (tester) async {
                const height = 900.0;
                tester.view.physicalSize = Size(width, height);
                tester.view.devicePixelRatio = 1;
                addTearDown(tester.view.resetPhysicalSize);
                addTearDown(tester.view.resetDevicePixelRatio);
                final container = ProviderContainer(
                  overrides: [
                    coreHandlerProvider.overrideWithValue(
                      CoreController.scoped(_NoCore()),
                    ),
                    profilesProvider.overrideWith(
                      () => TestProfiles([
                        const Profile(
                          id: 1,
                          label: '日常',
                          autoUpdateDuration: Duration.zero,
                        ),
                      ]),
                    ),
                    profileMitmScriptsProvider(1).overrideWith(
                      () => _Scripts([
                        if (populated)
                          for (var i = 1; i <= 20; i++)
                            MitmScript(
                              id: i,
                              profileId: 1,
                              line:
                                  'Test$i = type=http-request,pattern=^https://example.com/,script-path=s$i.js',
                              source: 's$i.js',
                              file: 's$i.js',
                            ),
                      ]),
                    ),
                    profileMitmRewritesProvider(1).overrideWith(
                      () => _Rewrites([
                        if (populated)
                          for (var i = 1; i <= 20; i++)
                            MitmRewrite(
                              id: i,
                              section: MitmList.urlRewrite,
                              line: '^https://example.com/$i - reject',
                            ),
                      ]),
                    ),
                    enabledMitmModuleRulesProvider.overrideWith(
                      (ref) async => MitmModuleRules.empty,
                    ),
                    mitmRewriteIssuesProvider(
                      1,
                    ).overrideWith((ref) async => const {}),
                    mitmRewriteBodyLimitProvider.overrideWith(
                      (ref) async => 1 << 20,
                    ),
                  ],
                );
                addTearDown(container.dispose);
                globalState.container = container;
                container.listen(currentProfileIdProvider, (_, _) {});
                container.listen(patchClashConfigProvider, (_, _) {});
                container.read(currentProfileIdProvider.notifier).value = 1;
                container.read(viewSizeProvider.notifier).value = Size(
                  width,
                  height,
                );
                container
                    .read(patchClashConfigProvider.notifier)
                    .value = PatchClashConfig(
                  mitm: Mitm(enable: enabled, hostname: const ['example.com']),
                );
                final page = script
                    ? const MitmScriptView()
                    : const MitmRewriteView();
                await tester.pumpWidget(
                  RepaintBoundary(
                    key: boundary,
                    child: UncontrolledProviderScope(
                      container: container,
                      child: Consumer(
                        builder: (context, ref, _) => TestApp(
                          locale: const Locale('zh', 'CN'),
                          theme: watchAppTheme(ref, Brightness.light),
                          darkTheme: watchAppTheme(ref, Brightness.dark),
                          themeMode: brightness == Brightness.light
                              ? ThemeMode.light
                              : ThemeMode.dark,
                          child: const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                unawaited(
                  globalState.navigatorKey.currentState!.push(
                    HostPageRoute<void>(
                      builder: (context) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(scale),
                          padding: EdgeInsets.only(top: scale == 2 ? 28 : 0),
                        ),
                        child: page,
                      ),
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                final bar = find.byType(ScaffoldBar);
                final barBottom = tester.getBottomLeft(bar).dy;
                final notice = find.byType(MountBanner);
                final action = find.text(
                  currentAppLocalizations.mitmRewriteGoTurnOn,
                );
                if (!enabled) {
                  expect(notice, findsOneWidget);
                  expect(
                    tester.getTopLeft(notice).dy,
                    greaterThanOrEqualTo(barBottom),
                    reason:
                        'The entire notice must start below the actual toolbar',
                  );
                  expect(tester.getBottomRight(notice).dy, lessThan(height));
                  expect(action.hitTestable(), findsOneWidget);
                  final text = find.text(
                    script
                        ? currentAppLocalizations.mitmScriptsOff
                        : currentAppLocalizations.mitmRewriteOff,
                  );
                  final paragraph = tester.renderObject<RenderParagraph>(
                    find.descendant(of: text, matching: find.byType(RichText)),
                  );
                  expect(paragraph.didExceedMaxLines, isFalse);
                } else {
                  expect(notice, findsNothing);
                }
                if (populated) {
                  final subtitle = find
                      .textContaining('日常', findRichText: true)
                      .first;
                  final scrollView = find.byType(SingleChildScrollView).first;
                  expect(
                    tester.getTopLeft(subtitle).dy,
                    tester.element(scrollView).contentTopPadding,
                  );
                } else if (!enabled) {
                  expect(
                    tester.getTopLeft(notice).dy,
                    tester.element(notice).contentTopPadding,
                  );
                }
                await capture(tester, '$name-top');
                if (populated) {
                  final scroll = find
                      .descendant(
                        of: find.byWidget(page),
                        matching: find.byType(Scrollable),
                      )
                      .first;
                  final position = tester
                      .state<ScrollableState>(scroll)
                      .position;
                  expect(position.pixels, 0);
                  position.jumpTo(200);
                  await tester.pumpAndSettle();
                  expect(position.pixels, 200);
                  expect(tester.getBottomLeft(bar).dy, barBottom);
                  await capture(tester, '$name-scrolled');
                  position.jumpTo(0);
                  await tester.pumpAndSettle();
                  if (!enabled) expect(action.hitTestable(), findsOneWidget);
                  await tester.tap(find.byType(Switch).first);
                  await tester.pump(const Duration(milliseconds: 500));
                  await tester.pumpAndSettle();
                  final error = find.byWidgetPredicate(
                    (widget) =>
                        widget is MountBanner &&
                        widget.level == MountBannerLevel.error,
                  );
                  expect(error, findsOneWidget);
                  expect(
                    tester.getTopLeft(error).dy,
                    greaterThanOrEqualTo(barBottom),
                  );
                  expect(tester.getBottomRight(error).dy, lessThan(height));
                  if (!enabled) expect(action.hitTestable(), findsOneWidget);
                  await capture(tester, '$name-error');
                  if (script) {
                    (container.read(profileMitmScriptsProvider(1).notifier)
                            as _Scripts)
                        .clear();
                  } else {
                    (container.read(profileMitmRewritesProvider(1).notifier)
                            as _Rewrites)
                        .clear();
                  }
                  await tester.pumpAndSettle();
                  expect(
                    tester.getTopLeft(error).dy,
                    tester.element(error).contentTopPadding,
                  );
                  expect(tester.getBottomRight(error).dy, lessThan(height));
                  if (!enabled) expect(action.hitTestable(), findsOneWidget);
                  await capture(tester, '$name-error-empty');
                }
                if (!enabled) {
                  await tester.tap(action);
                  await tester.pumpAndSettle();
                  expect(find.byWidget(page), findsNothing);
                }
                expect(tester.takeException(), isNull);
                await tester.pumpWidget(const SizedBox.shrink());
                await tester.pumpAndSettle();
              }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
            }
          }
        }
      }
    }
  }
}
