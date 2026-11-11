import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/mount.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/preferences.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import 'mount_fixtures.dart';

Future<void> pumpSheet(
  WidgetTester tester,
  FakeMounts mounts, {
  List<Profile> profiles = const [],
  Brightness? brightness,
}) async {
  if (brightness != null) {
    await mockPreferences();
  }
  tester.view.physicalSize = const Size(560, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      profilesProvider.overrideWith(() => TestProfiles([target, ...profiles])),
      currentProfileIdProvider.overrideWithBuild((_, _) => target.id),
      mountActionProvider.overrideWith(() => mounts),
    ],
  );
  addTearDown(container.dispose);
  globalState.container = container;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: brightness == null
          ? TestApp(child: MountSheet(targetId: target.id))
          : Consumer(
              builder: (context, ref, _) => TestApp(
                theme: watchAppTheme(ref, Brightness.light),
                darkTheme: watchAppTheme(ref, Brightness.dark),
                themeMode: brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
                child: MountSheet(targetId: target.id),
              ),
            ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder rowOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(MountSourceRow));

Finder candidateOf(String name) => find.ancestor(
  of: find.text(name),
  matching: find.byType(MountCandidateRow),
);

FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, currentAppLocalizations.mountSave),
);

void main() {
  final air = sub('Air');
  final sea = sub('Sea');
  final odd = sub('Odd');
  final none = sub('None');

  testWidgets('a list that cannot be read is an error, never the empty '
      'state', (tester) async {
    final mounts = FakeMounts(null)..loadError = StateError('db');
    await pumpSheet(tester, mounts);
    final l10n = currentAppLocalizations;

    expect(find.text(l10n.mountListFailed), findsOneWidget);
    expect(find.text(l10n.mountEmptyTitle), findsNothing);
    expect(find.text(l10n.mountFormatHelp), findsNothing);
    expect(saveButton(tester).onPressed, isNull);

    mounts
      ..loadError = null
      ..panel = panelOf([item(air)]);
    await tester.tap(find.text(l10n.mountReadAgain));
    await tester.pumpAndSettle();
    expect(find.text('Air'), findsOneWidget);
    expect(mounts.loads, 2);
  });

  testWidgets('a load with no answer in ten seconds is a failure', (
    tester,
  ) async {
    final never = Completer<MountPanel>();
    final mounts = _SlowMounts(never.future);
    await pumpSheet(tester, mounts);
    expect(find.text(currentAppLocalizations.mountListFailed), findsNothing);
    await tester.pump(mountLoadTimeout);
    await tester.pump();
    expect(find.text(currentAppLocalizations.mountListFailed), findsOneWidget);
  });

  testWidgets('with no subscription it offers an import', (tester) async {
    await pumpSheet(tester, FakeMounts(panelOf(const [])));
    final l10n = currentAppLocalizations;

    expect(find.text(l10n.mountTarget('Home')), findsOneWidget);
    expect(find.text(l10n.mountEmptyTitle), findsOneWidget);
    expect(find.text(l10n.mountImport), findsOneWidget);
    expect(find.text(l10n.mountImportHint), findsOneWidget);
    expect(find.text(l10n.mountFormatHelp), findsNothing);
  });

  testWidgets('each row says what state its source is in', (tester) async {
    final mounts = FakeMounts(
      panelOf(
        [
          item(air, mounted: true, failure: MountSourceFailure.fetch),
          item(sea, state: MountSourceState.empty, count: 0),
          item(odd, state: MountSourceState.unsupported, count: 0),
          item(none, state: MountSourceState.notFetched, count: 0),
        ],
        stored: MountTargetState(
          targetId: target.id,
          sourceIds: [air.id],
          version: 1,
        ),
        groups: MountTarget(
          groups: [groupInfo('Auto', kind: MountGroupKind.auto)],
        ),
      ),
    );
    await pumpSheet(tester, mounts, profiles: [air, sea, odd, none]);
    final l10n = currentAppLocalizations;

    Finder inRow(String name, Finder matching) =>
        find.descendant(of: rowOf(name), matching: matching);
    expect(inRow('Air', find.text(l10n.mountMountedTag)), findsOneWidget);
    expect(inRow('Air', find.text(l10n.mountUpdateFailedInUse)), findsOne);
    expect(inRow('Air', find.byTooltip(l10n.mountUpdateNodes)), findsOne);
    expect(inRow('Sea', find.text(l10n.mountMountedTag)), findsNothing);
    expect(inRow('Sea', find.text(l10n.mountSourceEmpty)), findsOneWidget);
    expect(
      inRow('Sea', find.textContaining(l10n.mountNodeCount(0))),
      findsOneWidget,
    );
    expect(inRow('Sea', find.byTooltip(l10n.mountUpdateNodes)), findsNothing);
    expect(inRow('Odd', find.text(l10n.mountSourceNoNodeList)), findsOne);
    expect(inRow('None', find.text(l10n.mountNotFetched)), findsOneWidget);
    expect(find.text(l10n.mountFormatHelp), findsOneWidget);

    await tester.tap(find.text('Odd'));
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);

    await tester.tap(inRow('Air', find.byTooltip(l10n.mountUpdateNodes)));
    await tester.pumpAndSettle();
    expect(mounts.refreshed, [air.id]);
  });

  testWidgets('auto groups are listed with how they collect, extras are '
      'optional and typed', (tester) async {
    final mounts = FakeMounts(
      panelOf(
        [item(air)],
        groups: MountTarget(
          groups: [
            groupInfo(
              'All',
              kind: MountGroupKind.auto,
              collects: MountGroupCollects.all,
            ),
            groupInfo(
              'Subs',
              kind: MountGroupKind.auto,
              collects: MountGroupCollects.providers,
            ),
            groupInfo(
              'HK',
              kind: MountGroupKind.auto,
              collects: MountGroupCollects.all,
              filter: true,
            ),
            groupInfo('Pick'),
            groupInfo('Fast', type: 'url-test', filter: true),
            groupInfo('Spread', type: 'load-balance'),
          ],
        ),
      ),
    )..saveResult = const MountSaveResult(outcome: MountSaveOutcome.saved);
    await pumpSheet(tester, mounts, profiles: [air]);
    final l10n = currentAppLocalizations;

    expect(find.text(l10n.mountAutoSubtitle), findsOneWidget);
    expect(find.text(l10n.mountHintCollectsAll), findsOneWidget);
    expect(find.text(l10n.mountHintCollectsProviders), findsOneWidget);
    expect(find.text(l10n.mountHintFiltered), findsOneWidget);
    expect(find.text(l10n.mountExtraTitle), findsOneWidget);
    expect(find.text(l10n.mountTypeSelect), findsOneWidget);
    expect(find.text(l10n.mountTypeSelectDesc), findsOneWidget);
    expect(find.text(l10n.mountTypeUrlTest), findsOneWidget);
    expect(find.text(l10n.mountTypeLoadBalance), findsOneWidget);
    expect(find.text(l10n.mountFilterNotice), findsNothing);

    await tester.tap(find.text('Fast'));
    await tester.pump();
    expect(find.text(l10n.mountFilterNotice), findsOneWidget);
    await tester.tap(find.text('Fast'));
    await tester.pump();

    // Leaving the extras unchecked never blocks a save.
    expect(saveButton(tester).onPressed, isNull);
    await tester.tap(find.text('Air'));
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);
    await tester.tap(find.text(l10n.mountSave));
    await tester.pumpAndSettle();

    expect(mounts.saves.single.version, isNull);
    expect(mounts.saves.single.sources, [air.id]);
    expect(mounts.saves.single.groups, isEmpty);
    expect(find.text(l10n.mountSavedUnconfirmed), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('a box one can check is outlined in ${brightness.name}, one '
        'that cannot is a faint fill, a checked one is filled', (tester) async {
      final mounts = FakeMounts(
        panelOf(
          [
            item(air, mounted: true),
            item(sea),
            item(odd, state: MountSourceState.unsupported, count: 0),
          ],
          stored: MountTargetState(
            targetId: target.id,
            sourceIds: [air.id],
            version: 1,
          ),
          groups: MountTarget(
            groups: [
              groupInfo('All', kind: MountGroupKind.auto),
              groupInfo('Pick'),
            ],
          ),
        ),
      );
      await pumpSheet(
        tester,
        mounts,
        profiles: [air, sea, odd],
        brightness: brightness,
      );
      final colorScheme = tester.element(find.byType(MountSheet)).colorScheme;

      ({Color? color, BorderSide side}) boxOf(Finder row) {
        final decoration =
            tester
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: row,
                        matching: find.byType(AnimatedContainer),
                      ),
                    )
                    .decoration!
                as ShapeDecoration;
        return (
          color: decoration.color,
          side: (decoration.shape as OutlinedBorder).side,
        );
      }

      Color fillOf(Finder finder) =>
          (tester.widget<DecoratedBox>(finder.first).decoration
                  as ShapeDecoration)
              .color!;
      double contrast(Color a, Color b) {
        final (hi, lo) = (
          a.computeLuminance() > b.computeLuminance() ? a : b,
          a.computeLuminance() > b.computeLuminance() ? b : a,
        );
        return (hi.computeLuminance() + 0.05) / (lo.computeLuminance() + 0.05);
      }

      final checked = boxOf(rowOf('Air'));
      expect(checked.color, colorScheme.primary);
      expect(checked.side.color.a, 0);

      final rowFill = fillOf(
        find.descendant(of: rowOf('Sea'), matching: find.byType(DecoratedBox)),
      );
      final blockFill = fillOf(
        find.descendant(
          of: find.byType(MountGroupsBlock),
          matching: find.byType(DecoratedBox),
        ),
      );
      for (final (box, background) in [
        (boxOf(rowOf('Sea')), rowFill),
        (boxOf(candidateOf('Pick')), blockFill),
      ]) {
        expect(box.color!.a, 0);
        expect(box.side.width, 1.5);
        expect(box.side.color, colorScheme.onSurfaceVariant);
        final ratio = contrast(box.side.color, background);
        printOnFailure('${brightness.name} stroke contrast $ratio');
        expect(ratio, greaterThanOrEqualTo(3));
      }

      final disabled = boxOf(rowOf('Odd'));
      expect(disabled.color, SurfaceLevel.inset.colorOf(colorScheme));
      expect(disabled.side.color.a, 0);
    });
  }

  testWidgets('the groups area has a section label like the sources, and '
      'its sub-headings are row-sized', (tester) async {
    final mounts = FakeMounts(
      panelOf(
        [item(air)],
        groups: MountTarget(
          groups: [
            groupInfo('All', kind: MountGroupKind.auto),
            groupInfo('Pick'),
          ],
        ),
      ),
    );
    await pumpSheet(tester, mounts, profiles: [air]);
    final l10n = currentAppLocalizations;

    TextStyle? styleOf(String text) =>
        tester.widget<Text>(find.text(text)).style;
    final label = find.text(l10n.mountGroupsTitle);
    expect(label, findsOneWidget);
    expect(
      find.ancestor(of: label, matching: find.byType(MountGroupsBlock)),
      findsNothing,
    );
    expect(styleOf(l10n.mountGroupsTitle), styleOf(l10n.mountChooseSources));
    final row = styleOf('All')!;
    for (final heading in [l10n.mountAutoSubtitle, l10n.mountExtraTitle]) {
      final style = styleOf(heading)!;
      expect(style.fontSize, row.fontSize);
      expect(style.fontWeight, FontWeight.w600);
    }
  });

  testWidgets('without an auto group at least one group is needed, except '
      'to remove', (tester) async {
    final mounts = FakeMounts(
      panelOf(
        [item(air), item(sea, mounted: true)],
        stored: MountTargetState(
          targetId: target.id,
          sourceIds: [sea.id],
          groups: const ['Proxy'],
          version: 3,
        ),
        groups: MountTarget(
          groups: [
            groupInfo('Proxy'),
            groupInfo('Fallback', type: 'fallback'),
          ],
        ),
      ),
    );
    await pumpSheet(tester, mounts, profiles: [air, sea]);
    final l10n = currentAppLocalizations;

    expect(find.text(l10n.mountPickTitle), findsOneWidget);
    expect(find.text(l10n.mountPickRequired), findsNothing);

    await tester.tap(find.text('Proxy'));
    await tester.tap(find.text('Air'));
    await tester.pump();
    expect(find.text(l10n.mountPickRequired), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.tap(find.text('Fallback'));
    await tester.pump();
    expect(find.text(l10n.mountPickRequired), findsNothing);
    expect(find.text(l10n.mountTypeFallback), findsOneWidget);
    expect(saveButton(tester).onPressed, isNotNull);

    // Back to the stored groups: unchecking Sea alone needs none.
    await tester.tap(find.text('Fallback'));
    await tester.tap(find.text('Proxy'));
    await tester.tap(find.text('Air'));
    await tester.tap(find.text('Sea'));
    await tester.pump();
    expect(find.text(l10n.mountPickRequired), findsNothing);
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('a profile without groups blocks mounting but still unmounts, '
      'after asking', (tester) async {
    final mounts = FakeMounts(
      panelOf(
        [item(air), item(sea, mounted: true)],
        stored: MountTargetState(
          targetId: target.id,
          sourceIds: [sea.id],
          version: 2,
        ),
      ),
    );
    await pumpSheet(tester, mounts, profiles: [air, sea]);
    final l10n = currentAppLocalizations;

    expect(find.text(l10n.mountNoGroupTitle), findsOneWidget);
    await tester.tap(find.text('Air'));
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);
    await tester.tap(find.text('Air'));
    await tester.tap(find.text('Sea'));
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text(l10n.mountSave));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mountUnmountTitle), findsOneWidget);
    expect(find.text(l10n.mountUnmountBody('Sea', 'Home')), findsOneWidget);
    await tester.tap(find.text(l10n.cancel).last);
    await tester.pumpAndSettle();
    expect(mounts.saves, isEmpty);
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text(l10n.mountSave));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.mountUnmount));
    await tester.pumpAndSettle();
    expect(mounts.saves.single.version, 2);
    expect(mounts.saves.single.sources, isEmpty);
    expect(mounts.saves.single.groups, isEmpty);
  });

  testWidgets('groups that cannot be read never pass for no groups', (
    tester,
  ) async {
    final mounts = FakeMounts(panelOf([item(air)], groups: null));
    await pumpSheet(tester, mounts, profiles: [air]);
    final l10n = currentAppLocalizations;

    expect(find.text(l10n.mountGroupsFailed), findsOneWidget);
    expect(find.text(l10n.mountNoGroupTitle), findsNothing);
    await tester.tap(find.text('Air'));
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);

    mounts.panel = panelOf(
      [item(air)],
      groups: MountTarget(groups: [groupInfo('A', kind: MountGroupKind.auto)]),
    );
    await tester.tap(find.text(l10n.mountReadAgain));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mountAutoSubtitle), findsOneWidget);
    // The staged choice survives the reread.
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('a mixed change asks with the primary save and lists both', (
    tester,
  ) async {
    final mounts = FakeMounts(
      panelOf(
        [item(air), item(sea, mounted: true), item(odd, mounted: true)],
        stored: MountTargetState(
          targetId: target.id,
          sourceIds: [sea.id, odd.id],
          version: 4,
        ),
        groups: MountTarget(
          groups: [groupInfo('A', kind: MountGroupKind.auto)],
        ),
      ),
    );
    await pumpSheet(tester, mounts, profiles: [air, sea, odd]);
    final l10n = currentAppLocalizations;

    await tester.tap(find.text('Air'));
    await tester.tap(find.text('Sea'));
    await tester.tap(find.text('Odd'));
    await tester.pump();
    await tester.tap(find.text(l10n.mountSave));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mountUpdateTitle), findsOneWidget);
    expect(find.text(l10n.mountUnmountManyBody(2, 'Home')), findsOneWidget);
    expect(find.text(l10n.mountAlsoMounts(1)), findsOneWidget);
    expect(find.text(l10n.mountUnmount), findsNothing);
    await tester.tap(find.text(l10n.mountSave).last);
    await tester.pumpAndSettle();
    expect(mounts.saves.single.sources, [air.id]);
  });

  testWidgets('saving locks the controls and reports the apply', (
    tester,
  ) async {
    final mounts =
        FakeMounts(
            panelOf(
              [item(air)],
              groups: MountTarget(
                groups: [groupInfo('A', kind: MountGroupKind.auto)],
              ),
            ),
          )
          ..saveGate = Completer()
          ..saveResult = const MountSaveResult(
            outcome: MountSaveOutcome.applyFailedKept,
          );
    await pumpSheet(tester, mounts, profiles: [air]);
    final l10n = currentAppLocalizations;

    await tester.tap(find.text('Air'));
    await tester.pump();
    await tester.tap(find.text(l10n.mountSave));
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.mountSaving), findsOneWidget);
    expect(find.text(l10n.mountApplying), findsOneWidget);
    final cancel = tester.widget<TonalButton>(
      find.widgetWithText(TonalButton, l10n.cancel),
    );
    expect(cancel.onPressed, isNull);

    mounts.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text(l10n.mountApplyKept), findsOneWidget);
    expect(find.text(l10n.mountApplying), findsNothing);
  });

  testWidgets('an unknown outcome locks the sheet until a readback resolves '
      'it', (tester) async {
    final stored = MountTargetState(
      targetId: target.id,
      sourceIds: [air.id],
      version: 5,
      pending: const MountOperation(kind: MountOperationKind.save, version: 5),
    );
    final mounts = FakeMounts(
      panelOf(
        [item(air, mounted: true), item(sea)],
        stored: stored,
        groups: MountTarget(
          groups: [groupInfo('A', kind: MountGroupKind.auto)],
        ),
      ),
    );
    await pumpSheet(tester, mounts, profiles: [air, sea]);
    final l10n = currentAppLocalizations;

    expect(find.text(l10n.mountUnknown), findsOneWidget);
    expect(find.text(l10n.mountSave), findsNothing);
    expect(find.text(l10n.mountReadStatus), findsOneWidget);
    expect(find.text(l10n.close), findsOneWidget);
    expect(
      find.descendant(
        of: rowOf('Air'),
        matching: find.text(l10n.mountMountedTag),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Sea'));
    await tester.pump();
    expect(find.text(l10n.mountReadStatus), findsOneWidget);

    await tester.tap(find.text(l10n.mountReadStatus));
    await tester.pumpAndSettle();
    expect(mounts.rechecks, 1);
    expect(find.text(l10n.mountUnknown), findsOneWidget);

    mounts
      ..recheckOutcome = MountSaveOutcome.applied
      ..panel = mounts.panel!.copyWith(stored: stored.copyWith(pending: null));
    await tester.tap(find.text(l10n.mountReadStatus));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mountUnknown), findsNothing);
    expect(find.text(l10n.mountSave), findsOneWidget);
    expect(
      find.descendant(
        of: rowOf('Air'),
        matching: find.text(l10n.mountMountedTag),
      ),
      findsOneWidget,
    );
  });

  testWidgets('group status: a block tag, an empty group warning, and the '
      'base profile fallback', (tester) async {
    final mounts =
        FakeMounts(
            panelOf(
              [item(air, mounted: true)],
              stored: MountTargetState(
                targetId: target.id,
                sourceIds: [air.id],
                version: 1,
              ),
              groups: MountTarget(
                groups: [
                  groupInfo('Guarded', kind: MountGroupKind.auto),
                  groupInfo('Empty', kind: MountGroupKind.auto),
                  groupInfo(
                    'Own',
                    kind: MountGroupKind.auto,
                    emptyFallback: 'DIRECT',
                  ),
                ],
              ),
            ),
          )
          ..runtime = const MountRuntimeState(
            report: MountReport(
              target: 1,
              groups: [
                MountGroupReport(
                  name: 'Guarded',
                  via: MountGroupVia.auto,
                  protection: MountProtection.reject,
                ),
                MountGroupReport(
                  name: 'Empty',
                  via: MountGroupVia.auto,
                  protection: MountProtection.reject,
                ),
                MountGroupReport(
                  name: 'Own',
                  via: MountGroupVia.auto,
                  protection: MountProtection.base,
                  emptyFallback: 'DIRECT',
                ),
              ],
            ),
            groups: [
              MountRuntimeGroup(name: 'Guarded', present: true, members: 3),
              MountRuntimeGroup(name: 'Empty', present: true, empty: true),
              MountRuntimeGroup(name: 'Own', present: true, empty: true),
            ],
          );
    await pumpSheet(tester, mounts, profiles: [air]);
    final l10n = currentAppLocalizations;

    expect(find.text(l10n.mountBlockTag), findsNWidgets(2));
    expect(find.text(l10n.mountBlockDesc), findsOneWidget);
    final empty = tester.widget<Text>(find.text(l10n.mountGroupEmpty('Empty')));
    final colorScheme = tester.element(find.byType(MountSheet)).colorScheme;
    expect(empty.style?.color, colorScheme.warning);
    final own = tester.widget<Text>(
      find.text('${l10n.mountBaseFallback('DIRECT')} ${l10n.mountBaseDirect}'),
    );
    expect(own.style?.color, colorScheme.onSurfaceVariant);
  });

  testWidgets('renamed and Tailscale nodes share one neutral banner, and a '
      'lost selection is said', (tester) async {
    final mounts =
        FakeMounts(
            panelOf(
              [item(air, mounted: true, tailscaleExcluded: 2)],
              stored: MountTargetState(
                targetId: target.id,
                sourceIds: [air.id],
                version: 1,
              ),
              groups: MountTarget(
                groups: [groupInfo('A', kind: MountGroupKind.auto)],
              ),
            ),
          )
          ..runtime = const MountRuntimeState(report: MountReport(renamed: 3))
          ..refreshResult = const MountSourceRefresh(
            updated: true,
            application: MountSaveOutcome.applied,
            lostSelections: ['A'],
          );
    await pumpSheet(tester, mounts, profiles: [air]);
    final l10n = currentAppLocalizations;

    final banner = find.byType(MountBanner);
    expect(banner, findsOneWidget);
    expect(
      find.descendant(of: banner, matching: find.text(l10n.mountSameName)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: banner,
        matching: find.text(l10n.mountTailscaleExcluded),
      ),
      findsOneWidget,
    );
    final sameName = tester.getRect(find.text(l10n.mountSameName));
    final tailscale = tester.getRect(find.text(l10n.mountTailscaleExcluded));
    expect(tailscale.top, greaterThan(sameName.top));

    await tester.tap(find.byTooltip(l10n.mountUpdateNodes));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mountSelectionLost), findsOneWidget);
  });

  testWidgets('nodes relaying through Tailscale are counted, and a source of '
      'nothing else cannot be mounted', (tester) async {
    final relayed = sub('Relayed');
    final mixed = sub('Mixed');
    final mounts = FakeMounts(
      panelOf(
        [
          item(air, mounted: true, relayExcluded: 1),
          item(sea, mounted: true, relayExcluded: 2),
          item(
            relayed,
            state: MountSourceState.relayOnly,
            count: 0,
            relayExcluded: 3,
          ),
          item(
            mixed,
            state: MountSourceState.isolatedOnly,
            count: 0,
            tailscaleExcluded: 1,
            relayExcluded: 1,
          ),
        ],
        stored: MountTargetState(
          targetId: target.id,
          sourceIds: [air.id, sea.id],
          version: 1,
        ),
        groups: MountTarget(
          groups: [groupInfo('A', kind: MountGroupKind.auto)],
        ),
      ),
    );
    await pumpSheet(tester, mounts, profiles: [air, sea, relayed, mixed]);
    final l10n = currentAppLocalizations;

    final banner = find.byType(MountBanner);
    expect(
      find.descendant(
        of: banner,
        matching: find.text(l10n.mountUnsupportedExcluded(3)),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.mountTailscaleExcluded), findsNothing);
    Finder inRow(String name, Finder matching) =>
        find.descendant(of: rowOf(name), matching: matching);
    expect(inRow('Relayed', find.text(l10n.mountSourceRelayOnly)), findsOne);
    expect(inRow('Mixed', find.text(l10n.mountSourceIsolatedOnly)), findsOne);
    expect(find.text(l10n.mountSourceEmpty), findsNothing);

    await tester.tap(find.text('Relayed'));
    await tester.tap(find.text('Mixed'));
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('the neutral banner says same names, Tailscale nodes, then '
      'relays, one line each', (tester) async {
    final mounts = FakeMounts(
      panelOf(
        [
          item(air, mounted: true, tailscaleExcluded: 1),
          item(sea, mounted: true, relayExcluded: 2),
        ],
        stored: MountTargetState(
          targetId: target.id,
          sourceIds: [air.id, sea.id],
          version: 1,
        ),
        groups: MountTarget(
          groups: [groupInfo('A', kind: MountGroupKind.auto)],
        ),
      ),
    )..runtime = const MountRuntimeState(report: MountReport(renamed: 1));
    await pumpSheet(tester, mounts, profiles: [air, sea]);
    final l10n = currentAppLocalizations;

    final banner = tester.widget<MountBanner>(find.byType(MountBanner));
    expect(banner.level, MountBannerLevel.info);
    expect(banner.lines, [
      l10n.mountSameName,
      l10n.mountTailscaleExcluded,
      l10n.mountUnsupportedExcluded(2),
    ]);
  });

  for (final (name, state, tailscale, relay) in [
    ('relay-only', MountSourceState.relayOnly, 0, 3),
    ('isolated-only', MountSourceState.isolatedOnly, 1, 2),
    ('Tailscale-only', MountSourceState.tailscaleOnly, 3, 0),
    ('unsupported', MountSourceState.unsupported, 0, 0),
  ]) {
    testWidgets('a mounted $name source can be unchecked and saved as a pure '
        'removal, an unmounted one cannot be checked', (tester) async {
      final kept = sub('Kept');
      final mounts = FakeMounts(
        panelOf(
          [
            item(
              kept,
              state: state,
              count: 0,
              mounted: true,
              tailscaleExcluded: tailscale,
              relayExcluded: relay,
            ),
            item(
              air,
              state: state,
              count: 0,
              tailscaleExcluded: tailscale,
              relayExcluded: relay,
            ),
          ],
          stored: MountTargetState(
            targetId: target.id,
            sourceIds: [kept.id],
            version: 2,
          ),
        ),
      );
      await pumpSheet(tester, mounts, profiles: [kept, air]);
      final l10n = currentAppLocalizations;
      final colorScheme = tester.element(find.byType(MountSheet)).colorScheme;

      double opacityOf(String row) => tester
          .widget<Opacity>(
            find
                .ancestor(
                  of: find.descendant(
                    of: rowOf(row),
                    matching: find.byType(MountCheckbox),
                  ),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      Text stateLine(String row) => tester.widget<Text>(
        find
            .descendant(
              of: rowOf(row),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Text && widget.style?.color == colorScheme.error,
              ),
            )
            .first,
      );

      expect(find.text(l10n.mountNoGroupTitle), findsOneWidget);
      expect(opacityOf('Kept'), 1);
      expect(opacityOf('Air'), 0.4);
      expect(
        find.descendant(
          of: rowOf('Kept'),
          matching: find.text(l10n.mountMountedTag),
        ),
        findsOneWidget,
      );
      expect(stateLine('Kept').data, switch (state) {
        MountSourceState.relayOnly => l10n.mountSourceRelayOnly,
        MountSourceState.isolatedOnly => l10n.mountSourceIsolatedOnly,
        MountSourceState.tailscaleOnly => l10n.mountSourceTailscaleOnly,
        _ => l10n.mountSourceNoNodeList,
      });
      expect(stateLine('Air').data, stateLine('Kept').data);
      // The nodes the source lists, not the none it may mount.
      expect(
        find.descendant(
          of: rowOf('Kept'),
          matching: find.textContaining(l10n.mountNodeCount(3)),
        ),
        state == MountSourceState.unsupported ? findsNothing : findsOneWidget,
      );

      await tester.tap(find.text('Air'));
      await tester.pump();
      expect(saveButton(tester).onPressed, isNull);

      // Unchecked, a mounted row keeps full strength and checks again.
      await tester.tap(find.text('Kept'));
      await tester.pump();
      expect(opacityOf('Kept'), 1);
      expect(saveButton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Kept'));
      await tester.pump();
      expect(saveButton(tester).onPressed, isNull);
      await tester.tap(find.text('Kept'));
      await tester.pump();
      expect(opacityOf('Kept'), 1);
      expect(saveButton(tester).onPressed, isNotNull);
      await tester.tap(find.text(l10n.mountSave));
      await tester.pumpAndSettle();
      expect(find.text(l10n.mountUnmountTitle), findsOneWidget);
      await tester.tap(find.text(l10n.mountUnmount));
      await tester.pumpAndSettle();
      expect(mounts.saves.single.version, 2);
      expect(mounts.saves.single.sources, isEmpty);
      expect(mounts.saves.single.groups, isEmpty);
    });
  }

  for (final (state, application, says) in [
    (MountSourceState.nodes, MountSaveOutcome.applied, true),
    (MountSourceState.empty, null, true),
    (MountSourceState.nodes, MountSaveOutcome.unknown, false),
    (MountSourceState.nodes, MountSaveOutcome.applyFailedKept, false),
    (MountSourceState.relayOnly, MountSaveOutcome.applied, false),
    (MountSourceState.isolatedOnly, MountSaveOutcome.applied, false),
    (MountSourceState.tailscaleOnly, MountSaveOutcome.applied, false),
    (MountSourceState.unsupported, null, false),
  ]) {
    testWidgets('an update that leaves ${state.name} applied as '
        '${application?.name} ${says ? 'says' : 'never says'} nodes updated', (
      tester,
    ) async {
      final mounts =
          FakeMounts(
              panelOf(
                [item(air, mounted: true)],
                stored: MountTargetState(
                  targetId: target.id,
                  sourceIds: [air.id],
                  version: 1,
                ),
                groups: MountTarget(
                  groups: [groupInfo('A', kind: MountGroupKind.auto)],
                ),
              ),
            )
            ..refreshResult = MountSourceRefresh(
              updated: true,
              item: item(air, state: state, mounted: true),
              application: application,
            );
      await pumpSheet(tester, mounts, profiles: [air]);
      final l10n = currentAppLocalizations;

      await tester.tap(find.byTooltip(l10n.mountUpdateNodes));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.mountNodesUpdated), says ? findsOne : findsNothing);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('the running report counts relays over the inspection', (
    tester,
  ) async {
    final mounts =
        FakeMounts(
            panelOf(
              [item(air, mounted: true, relayExcluded: 5)],
              stored: MountTargetState(
                targetId: target.id,
                sourceIds: [air.id],
                version: 1,
              ),
              groups: MountTarget(
                groups: [groupInfo('A', kind: MountGroupKind.auto)],
              ),
            ),
          )
          ..runtime = const MountRuntimeState(
            report: MountReport(
              sources: [
                MountSourceReport(
                  id: 1,
                  provider: 'flash-mount-1',
                  status: MountSourceStatus.nodes,
                  relayExcluded: 1,
                ),
              ],
            ),
          );
    await pumpSheet(tester, mounts, profiles: [air]);
    final l10n = currentAppLocalizations;

    expect(find.text(l10n.mountUnsupportedExcluded(1)), findsOneWidget);
    expect(find.text(l10n.mountUnsupportedExcluded(5)), findsNothing);
  });

  testWidgets('groups kept out for Tailscale share one counted info line '
      'with their names', (tester) async {
    final mounts = FakeMounts(
      panelOf(
        [item(air)],
        groups: MountTarget(
          groups: [
            groupInfo('A', kind: MountGroupKind.auto),
            groupInfo('B'),
            isolatedGroup('Lan', MountGroupReason.holds),
            isolatedGroup('Hop', MountGroupReason.dialer),
            isolatedGroup('Set', MountGroupReason.ruleUnknown),
            groupInfo(
              'Hidden',
              kind: MountGroupKind.excluded,
              excluded: MountGroupExclusion.hidden,
            ),
          ],
        ),
      ),
    );
    await pumpSheet(tester, mounts, profiles: [air]);
    final l10n = currentAppLocalizations;

    final line = find.text(l10n.mountGroupsExcluded(3));
    expect(line, findsOneWidget);
    final banner = tester.widget<MountBanner>(
      find.ancestor(of: line, matching: find.byType(MountBanner)),
    );
    expect(banner.level, MountBannerLevel.info);
    expect(banner.lines, [
      l10n.mountGroupsExcluded(3),
      l10n.mountGroupsExcludedNames('Lan, Hop, Set'),
    ]);
    expect(find.text('Hidden'), findsNothing);
    expect(find.text(l10n.mountNoGroupIsolatedTitle), findsNothing);
  });

  testWidgets('no excluded or unreadable groups means no isolation line', (
    tester,
  ) async {
    final mounts = FakeMounts(
      panelOf(
        [item(air)],
        groups: MountTarget(
          groups: [groupInfo('A', kind: MountGroupKind.auto)],
        ),
      ),
    );
    await pumpSheet(tester, mounts, profiles: [air]);
    expect(find.byType(MountBanner), findsNothing);
  });

  testWidgets('unreadable groups show no isolation count', (tester) async {
    await pumpSheet(
      tester,
      FakeMounts(panelOf([item(air)], groups: null)),
      profiles: [air],
    );
    expect(find.byType(MountBanner), findsNothing);
  });

  testWidgets('every group kept out for Tailscale is told apart from a '
      'profile without groups', (tester) async {
    final mounts = FakeMounts(
      panelOf(
        [item(air)],
        groups: MountTarget(
          groups: [
            isolatedGroup('Lan', MountGroupReason.rule),
            isolatedGroup('Hop', MountGroupReason.dialer),
          ],
        ),
      ),
    );
    await pumpSheet(tester, mounts, profiles: [air]);
    final l10n = currentAppLocalizations;

    final banner = tester.widget<MountBanner>(
      find.ancestor(
        of: find.text(l10n.mountNoGroupIsolatedTitle),
        matching: find.byType(MountBanner),
      ),
    );
    expect(banner.level, MountBannerLevel.warn);
    expect(banner.lines, [l10n.mountNoGroupIsolatedDesc]);
    expect(find.text(l10n.mountNoGroupTitle), findsNothing);
    expect(find.text(l10n.mountGroupsExcluded(2)), findsNothing);
    await tester.tap(find.text('Air'));
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('hidden groups alone still read as a profile without groups', (
    tester,
  ) async {
    final mounts = FakeMounts(
      panelOf(
        [item(air)],
        groups: MountTarget(
          groups: [
            groupInfo(
              'Hidden',
              kind: MountGroupKind.excluded,
              excluded: MountGroupExclusion.hidden,
            ),
          ],
        ),
      ),
    );
    await pumpSheet(tester, mounts, profiles: [air]);
    final l10n = currentAppLocalizations;
    expect(find.text(l10n.mountNoGroupTitle), findsOneWidget);
    expect(find.text(l10n.mountNoGroupIsolatedTitle), findsNothing);
  });

  Future<FakeMounts> refreshWith(
    WidgetTester tester,
    MountSourceRefresh result,
  ) async {
    final mounts = FakeMounts(
      panelOf(
        [item(air, mounted: true)],
        stored: MountTargetState(
          targetId: target.id,
          sourceIds: [air.id],
          version: 1,
        ),
        groups: MountTarget(
          groups: [groupInfo('A', kind: MountGroupKind.auto)],
        ),
      ),
    )..refreshResult = result;
    await pumpSheet(tester, mounts, profiles: [air]);
    await tester.tap(find.byTooltip(currentAppLocalizations.mountUpdateNodes));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return mounts;
  }

  String readDetail(WidgetTester tester, int count) {
    final l10n = currentAppLocalizations;
    final context = tester.element(find.byType(MountSheet));
    return [
      l10n.mountNodesRead(count),
      l10n.mountNodesReadAt(updated.getLastUpdateTimeDesc(context)),
    ].join(' · ');
  }

  testWidgets('nodes read but kept from running say so and never look '
      'updated', (tester) async {
    await refreshWith(
      tester,
      MountSourceRefresh(
        updated: true,
        item: item(air, count: 7, mounted: true),
        application: MountSaveOutcome.applyFailedKept,
      ),
    );
    final l10n = currentAppLocalizations;
    final colorScheme = tester.element(find.byType(MountSheet)).colorScheme;

    expect(find.text(l10n.mountNodesUpdated), findsNothing);
    Finder inRow(Finder matching) =>
        find.descendant(of: rowOf('Air'), matching: matching);
    expect(inRow(find.text(readDetail(tester, 7))), findsOneWidget);
    expect(
      inRow(find.textContaining(l10n.mountLastUpdated('').trim())),
      findsNothing,
    );
    final line = tester.widget<Text>(
      inRow(find.text(l10n.mountUpdateReadNotAppliedKept)),
    );
    expect(line.style?.color, colorScheme.warning);
    expect(find.text(l10n.mountApplyBlocked), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('nodes read while every connection is rejected say so and '
      'offer a status read', (tester) async {
    final mounts = await refreshWith(
      tester,
      MountSourceRefresh(
        updated: true,
        item: item(air, count: 7, mounted: true),
        application: MountSaveOutcome.applyFailedBlocked,
      ),
    );
    await tester.pumpAndSettle();
    final l10n = currentAppLocalizations;
    final colorScheme = tester.element(find.byType(MountSheet)).colorScheme;

    expect(find.text(l10n.mountNodesUpdated), findsNothing);
    final line = tester.widget<Text>(
      find.descendant(
        of: rowOf('Air'),
        matching: find.text(l10n.mountUpdateReadNotAppliedBlocked),
      ),
    );
    expect(line.style?.color, colorScheme.error);
    final banner = find.ancestor(
      of: find.text(l10n.mountApplyBlocked),
      matching: find.byType(MountBanner),
    );
    expect(banner, findsOneWidget);
    final read = find.descendant(
      of: banner,
      matching: find.text(l10n.mountReadStatus),
    );
    expect(read, findsOneWidget);
    await tester.tap(read);
    await tester.pumpAndSettle();
    expect(mounts.rechecks, 1);
  });

  testWidgets('an empty list read but not applied is not the legal empty '
      'line alone', (tester) async {
    await refreshWith(
      tester,
      MountSourceRefresh(
        updated: true,
        item: item(air, state: MountSourceState.empty, count: 0, mounted: true),
        application: MountSaveOutcome.applyFailedKept,
      ),
    );
    await tester.pumpAndSettle();
    final l10n = currentAppLocalizations;
    Finder inRow(Finder matching) =>
        find.descendant(of: rowOf('Air'), matching: matching);

    expect(inRow(find.text(l10n.mountUpdateReadEmptyNotApplied)), findsOne);
    expect(inRow(find.text(l10n.mountRunningKept)), findsOne);
    expect(inRow(find.text(l10n.mountSourceEmpty)), findsNothing);
    expect(inRow(find.text(readDetail(tester, 0))), findsOne);
  });

  testWidgets('a failed fetch is no read-but-not-applied state', (
    tester,
  ) async {
    await refreshWith(
      tester,
      MountSourceRefresh(
        updated: false,
        item: item(air, mounted: true, failure: MountSourceFailure.fetch),
        message: 'offline',
      ),
    );
    await tester.pumpAndSettle();
    final l10n = currentAppLocalizations;

    expect(find.text(l10n.mountUpdateFailedInUse), findsOneWidget);
    expect(find.text(l10n.mountUpdateReadNotAppliedKept), findsNothing);
    expect(find.text(l10n.mountUpdateReadNotAppliedBlocked), findsNothing);
  });

  test('only a read update with a refused apply is a refusal', () {
    for (final (updated, application, want) in [
      (true, MountSaveOutcome.applyFailedKept, MountRefreshRefusal.kept),
      (true, MountSaveOutcome.applyFailedBlocked, MountRefreshRefusal.blocked),
      (false, MountSaveOutcome.applyFailedKept, null),
      (true, MountSaveOutcome.applied, null),
      (true, MountSaveOutcome.unknown, null),
      (true, null, null),
    ]) {
      expect(
        mountRefreshRefusalOf(
          MountSourceRefresh(updated: updated, application: application),
        ),
        want,
      );
    }
  });

  testWidgets('relays and unsupported nodes share one count, Tailscale nodes '
      'their own line', (tester) async {
    final mounts = FakeMounts(
      panelOf(
        [
          item(air, mounted: true, tailscaleExcluded: 2, relayExcluded: 1),
          item(sea, mounted: true, unsupportedExcluded: 3),
        ],
        stored: MountTargetState(
          targetId: target.id,
          sourceIds: [air.id, sea.id],
          version: 1,
        ),
        groups: MountTarget(
          groups: [groupInfo('A', kind: MountGroupKind.auto)],
        ),
      ),
    );
    await pumpSheet(tester, mounts, profiles: [air, sea]);
    final l10n = currentAppLocalizations;

    final banner = tester.widget<MountBanner>(find.byType(MountBanner));
    expect(banner.lines, [
      l10n.mountTailscaleExcluded,
      l10n.mountUnsupportedExcluded(4),
    ]);
  });
}

class _SlowMounts extends FakeMounts {
  _SlowMounts(this.future) : super(null);

  final Future<MountPanel> future;

  @override
  Future<MountPanel> loadPanel(int targetId) => future;
}
