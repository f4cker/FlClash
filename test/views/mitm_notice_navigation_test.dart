import 'dart:io';
import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/mitm/rewrite.dart';
import 'package:fl_clash/features/mitm/script.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/mitm.dart';
import 'package:fl_clash/views/navigation.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/app_paths.dart';
import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _Core extends Mock implements CoreHandlerInterface {}

void main() {
  setUpAll(() async {
    await useAppPaths(Directory.systemTemp.createTempSync('mitm-navigation'));
  });

  setUp(() {
    final previousMitm = mitmFeature;
    final previousModules = mitmModulesFeature;
    mitmFeature = true;
    mitmModulesFeature = true;
    navigationPort = navigation;
    addTearDown(() {
      mitmFeature = previousMitm;
      mitmModulesFeature = previousModules;
      navigationPort = null;
    });
  });

  for (final script in [false, true]) {
    for (final entry in ['sidebar', 'root', 'nested']) {
      for (final width in switch (entry) {
        'sidebar' => [1220.0],
        'root' => [390.0],
        _ => [390.0, 1220.0],
      }) {
        testWidgets(
          '${script ? 'scripts' : 'rewrite'} $entry ${width.toInt()} opens settings without enabling',
          (tester) async {
            final size = Size(width, 1100);
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final core = _Core();
            when(() => core.getMitmCertificate()).thenAnswer((_) async => null);
            when(
              () => core.getMitmStatus(),
            ).thenAnswer((_) async => const MitmStatus());
            final container = ProviderContainer(
              overrides: [
                coreHandlerProvider.overrideWithValue(
                  CoreController.scoped(core),
                ),
                mitmSignerProvider.overrideWithValue(null),
                mitmTrustStoreProvider.overrideWithValue(null),
                profilesProvider.overrideWith(
                  () => TestProfiles([
                    const Profile(
                      id: 1,
                      label: 'Daily',
                      autoUpdateDuration: Duration.zero,
                    ),
                  ]),
                ),
                profileMitmScriptsProvider(
                  1,
                ).overrideWithBuild((_, _) => Stream.value([])),
                profileMitmRewritesProvider(
                  1,
                ).overrideWithBuild((_, _) => Stream.value([])),
                enabledMitmModuleRulesProvider.overrideWith(
                  (ref) async => MitmModuleRules.empty,
                ),
                mitmModulesProvider.overrideWithBuild(
                  (_, _) => Stream.value([]),
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
            container.listen(currentPageLabelProvider, (_, _) {});
            container.listen(patchClashConfigProvider, (_, _) {});
            container.read(currentProfileIdProvider.notifier).value = 1;
            container.read(currentPageLabelProvider.notifier).value =
                PageLabel.logs;
            container.read(viewSizeProvider.notifier).value = size;
            container
                .read(appSettingProvider.notifier)
                .update(
                  (state) => state.copyWith(
                    openLogs: true,
                    sidebarExpanded: true,
                    sidebarCollapsedGroups: {'mitm': false},
                  ),
                );
            final original = container.read(patchClashConfigProvider);
            expect(original.mitm.enable, isFalse);
            final writes = <PatchClashConfig>[];
            container.listen(
              patchClashConfigProvider,
              (_, next) => writes.add(next),
            );
            final page = script
                ? const MitmScriptView()
                : const MitmRewriteView();
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: TestApp(
                  locale: const Locale('en'),
                  child: switch (entry) {
                    'sidebar' => const HomePage(),
                    'nested' => const MitmView(isAndroid: false),
                    _ => page,
                  },
                ),
              ),
            );
            await tester.pumpAndSettle();
            State? settingsState;
            if (entry == 'sidebar') {
              final sidebar = find.byType(NavigationSidebar);
              expect(sidebar, findsOneWidget);
              final destination = find.descendant(
                of: sidebar,
                matching: find.byGlyph(
                  script ? AppGlyphs.code : AppGlyphs.wand,
                ),
              );
              if (destination.hitTestable().evaluate().isEmpty) {
                await tester.tap(
                  find.descendant(
                    of: sidebar,
                    matching: find.text(
                      NavigationGroup.of(PageLabel.mitmScripts)!.label,
                    ),
                  ),
                );
                await tester.pumpAndSettle();
              }
              await tester.tap(destination);
              await tester.pumpAndSettle();
              expect(
                container.read(currentPageLabelProvider),
                script ? PageLabel.mitmScripts : PageLabel.mitmRewrite,
              );
            } else if (entry == 'nested') {
              settingsState = tester.state(find.byType(MitmView));
              final item = script
                  ? find.byType(MitmScriptEntryItem)
                  : find.byType(MitmRewriteEntryItem);
              if (width == 390) {
                await tester.ensureVisible(item);
                await tester.pumpAndSettle();
                await tester.tap(item);
              } else {
                unawaited(
                  Navigator.of(
                    tester.element(find.byType(MitmView)),
                  ).push(HostPageRoute<void>(builder: (_) => page)),
                );
              }
              await tester.pumpAndSettle();
            }
            final view = script
                ? find.byType(MitmScriptView)
                : find.byType(MitmRewriteView);
            expect(view, findsOneWidget);
            expect(
              Navigator.of(tester.element(view)).canPop(),
              entry == 'nested',
            );
            final action = find.descendant(
              of: view,
              matching: find.text(currentAppLocalizations.mitmRewriteGoTurnOn),
            );
            expect(action.hitTestable(), findsOneWidget);
            await tester.tap(action);
            await tester.pumpAndSettle();
            expect(find.byType(MitmView), findsOneWidget);
            if (entry == 'sidebar') {
              expect(container.read(currentPageLabelProvider), PageLabel.mitm);
              final sidebar = tester.widget<NavigationSidebar>(
                find.byType(NavigationSidebar),
              );
              expect(
                sidebar.destinations[sidebar.selectedIndex].label,
                PageLabel.mitm.label,
              );
            } else if (entry == 'nested') {
              expect(tester.state(find.byType(MitmView)), same(settingsState));
              expect(view, findsNothing);
              expect(
                Navigator.of(tester.element(find.byType(MitmView))).canPop(),
                isFalse,
              );
            }
            expect(container.read(patchClashConfigProvider), original);
            expect(writes, isEmpty);
            expect(
              tester.widget<Switch>(find.byType(Switch).first).value,
              isFalse,
            );
            verify(() => core.getMitmCertificate()).called(1);
            verify(() => core.getMitmStatus()).called(greaterThan(0));
            verifyNoMoreInteractions(core);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(seconds: 2));
          },
          variant: TargetPlatformVariant.only(TargetPlatform.macOS),
        );
      }
    }
  }
}
