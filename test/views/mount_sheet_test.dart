import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/mount.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import 'mount_fixtures.dart';

Future<void> pumpSheet(
  WidgetTester tester,
  FakeMounts mounts, {
  List<Profile> profiles = const [],
}) async {
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
      child: TestApp(child: MountSheet(targetId: target.id)),
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
}

class _SlowMounts extends FakeMounts {
  _SlowMounts(this.future) : super(null);

  final Future<MountPanel> future;

  @override
  Future<MountPanel> loadPanel(int targetId) => future;
}
