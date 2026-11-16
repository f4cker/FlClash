import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/mount.dart';
import 'package:fl_clash/views/profiles/mount_delete.dart';
import 'package:fl_clash/views/profiles/profiles.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../helpers/context_menu.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

Profile urlProfile(String label) =>
    Profile.normal(label: label, url: 'https://example.com/sub').copyWith(
      subscriptionInfo: const SubscriptionInfo(
        upload: 1024,
        download: 2048,
        total: 4096,
        expire: 1234567890,
      ),
    );

class _RecordingProfilesAction extends ProfilesAction {
  final List<Profile> users;
  final deleted = <int>[];

  _RecordingProfilesAction(this.users);

  @override
  Future<List<Profile>> providerUsers(Profile profile) async => users;

  @override
  Future<TailscaleUnlinkOutcome> deleteProfile(int id) async {
    deleted.add(id);
    return TailscaleUnlinkOutcome.done;
  }
}

class _FakeMountAction extends MountAction {
  final List<Profile> targets;
  final List<MountSourceDeletion> results;
  final deleted = <int>[];
  final rechecked = <int>[];
  final opened = <int>[];
  bool pending;

  _FakeMountAction(
    this.targets, [
    this.results = const [],
    this.pending = false,
  ]);

  @override
  Future<bool> hasPendingRemoval(int sourceId) async => pending;

  @override
  Future<MountPanel> loadPanel(int targetId) async {
    opened.add(targetId);
    return MountPanel(
      target: ref.read(profilesProvider).getProfile(targetId)!,
      groups: const MountTarget(),
    );
  }

  @override
  Future<MountRuntimeState?> readRuntime(int targetId) async => null;

  @override
  Future<List<Profile>> sourceTargets(int sourceId) async => targets;

  @override
  Future<({MountSourceDeletion result, TailscaleUnlinkOutcome? unlink})>
  deleteSource(int sourceId) async {
    deleted.add(sourceId);
    return (result: results[deleted.length - 1], unlink: null);
  }

  @override
  Future<MountSaveResult> recheck(int targetId) async {
    rechecked.add(targetId);
    return const MountSaveResult(outcome: MountSaveOutcome.applied);
  }
}

Future<ProviderContainer> pumpProfiles(
  WidgetTester tester, {
  required List<Profile> profiles,
  int? currentProfileId,
  ValueListenable<bool>? isActive,
  bool picker = false,
  bool firstFrameOnly = false,
  List<Override> overrides = const [],
  Map<int, Future<MountCardSummary?> Function()> summaries = const {},
}) async {
  tester.view.physicalSize = const Size(900, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      profilesProvider.overrideWith(() => TestProfiles(profiles)),
      currentProfileIdProvider.overrideWithBuild(
        (_, _) => currentProfileId ?? profiles.first.id,
      ),
      for (final profile in profiles)
        if (profile.type != ProfileType.custom)
          mountCardSummaryProvider(profile.id).overrideWith(
            (_) => summaries[profile.id]?.call() ?? Future.value(null),
          ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  globalState.container = container;
  container.read(viewSizeProvider.notifier).value = const Size(900, 800);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: HostApp(
        navigatorKey: globalState.navigatorKey,
        builder: (context, child) {
          return wrapAppScopes(context, child!);
        },
        home: isActive == null
            ? ProfilesView(picker: picker)
            : ValueListenableBuilder(
                valueListenable: isActive,
                builder: (_, isActive, child) =>
                    PageActivityScope(isActive: isActive, child: child!),
                child: ProfilesView(picker: picker),
              ),
      ),
    ),
  );
  if (!firstFrameOnly) {
    await tester.pump();
  }
  return container;
}

void main() {
  testWidgets('a focused profile card opens its menu', (tester) async {
    final profiles = [
      urlProfile('url 1'),
      Profile.normal(label: 'file 1'),
      urlProfile('url 2'),
    ];
    await pumpProfiles(tester, profiles: profiles);

    final cards = find
        .byType(Card)
        .evaluate()
        .map((element) => element.widget)
        .toList();

    Future<void> focusCard(int index) async {
      for (var tab = 0; tab < 50; tab++) {
        final context = FocusManager.instance.primaryFocus?.context;
        final focusedCard = context?.findAncestorWidgetOfExactType<Card>();
        if (identical(focusedCard, cards[index])) {
          return;
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      fail('Profile card $index was not reachable');
    }

    for (var profileIndex = 0; profileIndex < profiles.length; profileIndex++) {
      await focusCard(profileIndex);

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(PopupMenu),
          matching: find.text(currentAppLocalizations.delete),
        ),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenu), findsNothing);
    }
  });

  testWidgets('a card shows its traffic under the title and its update time '
      'at the end, without an edit button', (tester) async {
    final file = Profile.normal(label: 'file');
    final url = urlProfile('url').copyWith(
      lastUpdateDate: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    final container = await pumpProfiles(tester, profiles: [url, file]);

    expect(find.byTooltip(currentAppLocalizations.edit), findsNothing);
    expect(find.text('3KB / 4KB'), findsOneWidget);
    expect(find.text('5m ago'), findsOneWidget);

    container.read(updatingKeysProvider.notifier).start(url.updatingKey);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('5m ago'), findsNothing);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('url'),
          matching: find.byType(ProfileItem),
        ),
        matching: find.byType(ActivityIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a card without traffic names its source under the title and '
      'has no subscription info button', (tester) async {
    final l = currentAppLocalizations;
    await pumpProfiles(
      tester,
      profiles: [
        Profile.normal(label: 'url', url: 'https://example.com/sub'),
        Profile.normal(label: 'file'),
        Profile.custom(label: 'mine'),
      ],
    );

    for (final (label, source) in [
      ('url', l.remote),
      ('file', l.local),
      ('mine', l.custom),
    ]) {
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text(label),
            matching: find.byType(ProfileItem),
          ),
          matching: find.text(source),
        ),
        findsOneWidget,
      );
    }
    expect(
      find.byTooltip(currentAppLocalizations.subscriptionInfo),
      findsNothing,
    );
  });

  testWidgets('a custom card counts its groups in place of an update time', (
    tester,
  ) async {
    await pumpProfiles(
      tester,
      profiles: [Profile.custom(label: 'mine')],
      overrides: [
        profileGroupsCountProvider.overrideWith((_, _) => Stream.value(6)),
      ],
    );
    await tester.pump();

    Finder inCard(Finder matching) =>
        find.descendant(of: find.byType(ProfileItem), matching: matching);
    expect(inCard(find.widgetWithText(TonalChip, '6')), findsOneWidget);
    expect(
      inCard(find.byTooltip(currentAppLocalizations.proxyGroupsCount(6, '6'))),
      findsOneWidget,
    );
    expect(inCard(find.byType(LastUpdateTimeText)), findsNothing);
  });

  Future<void> openProfileMenu(WidgetTester tester, String label) async {
    await rightClick(tester, find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('an external profile lists extend and keeps its final config '
      'under more', (tester) async {
    final l = currentAppLocalizations;
    await pumpProfiles(tester, profiles: [urlProfile('url')]);

    await openProfileMenu(tester, 'url');
    expect(find.text(l.extend), findsOneWidget);
    expect(find.text(l.runtimeConfig), findsNothing);
    expect(find.text(l.rename), findsNothing);

    await tester.tap(find.text(l.more).last);
    await tester.pumpAndSettle();
    expect(find.text(l.runtimeConfig), findsOneWidget);
    expect(find.text(l.subscriptionInfo), findsNothing);
  });

  testWidgets('a custom profile lists its final config and no extend', (
    tester,
  ) async {
    final l = currentAppLocalizations;
    await pumpProfiles(tester, profiles: [Profile.custom(label: 'mine')]);

    await openProfileMenu(tester, 'mine');
    expect(find.text(l.runtimeConfig), findsOneWidget);
    expect(find.text(l.extend), findsNothing);
    expect(find.text(l.more), findsNothing);
  });

  testWidgets('a custom profile renames from its menu', (tester) async {
    final l = currentAppLocalizations;
    await pumpProfiles(tester, profiles: [Profile.custom(label: 'mine')]);

    await openProfileMenu(tester, 'mine');
    await tester.tap(find.text(l.rename));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ours');
    await tester.tap(find.text(l.submit));
    await tester.pumpAndSettle();

    expect(find.text('ours'), findsOneWidget);
    expect(find.text('mine'), findsNothing);
  });

  testWidgets('a profile another one uses as a provider is deleted once '
      'confirmed', (tester) async {
    final action = _RecordingProfilesAction([Profile.normal(label: 'Work')]);
    final home = urlProfile('Home');
    await pumpProfiles(
      tester,
      profiles: [home],
      overrides: [
        profilesActionProvider.overrideWith(() => action),
        mountActionProvider.overrideWith(() => _FakeMountAction(const [])),
      ],
    );

    await openProfileMenu(tester, 'Home');
    await tester.tap(find.text(currentAppLocalizations.delete));
    await tester.pumpAndSettle();

    expect(find.textContaining('Home is still used'), findsOneWidget);
    expect(find.textContaining('used by Work'), findsOneWidget);
    await tester.tap(find.text(currentAppLocalizations.delete));
    await tester.pumpAndSettle();

    expect(action.deleted, [home.id]);
  });

  testWidgets('a mounted source is unmounted from the profiles it names, '
      'and read again when the result is unknown', (tester) async {
    final action = _RecordingProfilesAction(const []);
    final base = Profile.normal(label: 'Base');
    final air = urlProfile('Air');
    final mounts = _FakeMountAction(
      [base],
      [MountSourceDeletion.unknown, MountSourceDeletion.deleted],
    );
    await pumpProfiles(
      tester,
      profiles: [base, air],
      overrides: [
        profilesActionProvider.overrideWith(() => action),
        mountActionProvider.overrideWith(() => mounts),
      ],
    );
    final l10n = currentAppLocalizations;

    await openProfileMenu(tester, 'Air');
    await tester.tap(find.text(l10n.delete));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mountDeleteSourceTitle), findsOneWidget);
    expect(find.textContaining('mounted on the following 1 profile'), findsOne);
    expect(find.text('Base'), findsNWidgets(2));
    await tester.tap(find.text(l10n.mountDeleteSourceConfirm));
    await tester.pumpAndSettle();

    // Locked: the only way on is a readback.
    expect(find.text(l10n.mountDeleteSourceUnknown), findsOneWidget);
    expect(find.text(l10n.mountDeleteSourceConfirm), findsNothing);
    await tester.tap(find.text(l10n.mountReadStatus));
    await tester.pumpAndSettle();

    expect(mounts.rechecked, [base.id]);
    expect(mounts.deleted, [air.id]);
    await tester.tap(find.text(l10n.mountDeleteSourceConfirm));
    await tester.pumpAndSettle();

    expect(mounts.deleted, [air.id, air.id]);
    expect(find.text(l10n.mountDeleteSourceTitle), findsNothing);
    expect(action.deleted, isEmpty);
  });

  testWidgets('a source whose targets have an operation pending cannot be '
      'deleted until it is read back', (tester) async {
    final base = Profile.normal(label: 'Base');
    final air = urlProfile('Air');
    final mounts = _FakeMountAction([base], const [], true);
    await pumpProfiles(
      tester,
      profiles: [base, air],
      overrides: [mountActionProvider.overrideWith(() => mounts)],
    );
    final l10n = currentAppLocalizations;

    await openProfileMenu(tester, 'Air');
    await tester.tap(find.text(l10n.delete));
    await tester.pumpAndSettle();

    expect(find.text(l10n.mountDeleteSourceBlocked), findsOneWidget);
    final confirm = tester.widget<TextButton>(
      find.widgetWithText(TextButton, l10n.mountDeleteSourceConfirm),
    );
    expect(confirm.onPressed, isNull);

    mounts.pending = false;
    await tester.tap(find.text(l10n.mountReadStatus));
    await tester.pumpAndSettle();
    expect(mounts.rechecked, [base.id]);
    expect(find.text(l10n.mountDeleteSourceBlocked), findsNothing);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, l10n.mountDeleteSourceConfirm),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('same-name targets are told apart in the delete dialog', (
    tester,
  ) async {
    final l10n = currentAppLocalizations;
    final names = mountTargetNames([
      Profile.normal(label: 'Home'),
      urlProfile('Home'),
      Profile.normal(label: 'Work'),
    ], l10n);
    expect(names, ['Home · ${l10n.local}', 'Home · ${l10n.remote}', 'Work']);
    final twins = mountTargetNames([
      Profile.normal(label: 'Home'),
      Profile.normal(label: 'Home'),
    ], l10n);
    expect(twins, ['Home · ${l10n.local} · 1', 'Home · ${l10n.local} · 2']);
  });

  group('the mount pill', () {
    Finder pillOf(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(ProfileItem),
      ),
      matching: find.byType(MountPill),
    );

    testWidgets('shows on the current profile and on mounted ones, never on '
        'custom profiles', (tester) async {
      final l10n = currentAppLocalizations;
      final current = Profile.normal(label: 'current');
      final mounted = Profile.normal(label: 'mounted');
      final plain = urlProfile('plain');
      final custom = Profile.custom(label: 'mine');
      await pumpProfiles(
        tester,
        profiles: [current, mounted, plain, custom],
        currentProfileId: current.id,
        summaries: {
          mounted.id: () async => const MountCardSummary(mounted: 2, failed: 0),
        },
      );
      await tester.pump();

      expect(pillOf('current'), findsOneWidget);
      expect(
        find.descendant(
          of: pillOf('current'),
          matching: find.text(l10n.mountEntry),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: pillOf('mounted'),
          matching: find.text(l10n.mountedCount(2)),
        ),
        findsOneWidget,
      );
      expect(pillOf('plain'), findsNothing);
      expect(pillOf('mine'), findsNothing);
    });

    testWidgets('warns of failed updates and of an unreadable status', (
      tester,
    ) async {
      final l10n = currentAppLocalizations;
      final failing = Profile.normal(label: 'failing');
      final unknown = Profile.normal(label: 'unknown');
      await pumpProfiles(
        tester,
        profiles: [failing, unknown],
        summaries: {
          failing.id: () async => const MountCardSummary(mounted: 3, failed: 2),
          unknown.id: () async => throw StateError('unreadable'),
        },
      );
      await tester.pump();

      expect(
        find.text('${l10n.local} · ${l10n.mountCardFailed(2)}'),
        findsOneWidget,
      );
      expect(
        find.text('${l10n.local} · ${l10n.mountCardUnreadable}'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: pillOf('unknown'),
          matching: find.text(l10n.mountEntry),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape(l10n.mountPillFailedSemantics)),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('opens the sheet of its own profile without switching to it', (
      tester,
    ) async {
      final mounts = _FakeMountAction(const []);
      final current = Profile.normal(label: 'current');
      final other = Profile.normal(label: 'other');
      final container = await pumpProfiles(
        tester,
        profiles: [current, other],
        currentProfileId: current.id,
        summaries: {
          other.id: () async => const MountCardSummary(mounted: 1, failed: 0),
        },
        overrides: [mountActionProvider.overrideWith(() => mounts)],
      );
      await tester.pump();

      await tester.tap(pillOf('other'));
      await tester.pumpAndSettle();

      expect(mounts.opened, [other.id]);
      expect(container.read(currentProfileIdProvider), current.id);
      expect(
        find.text(currentAppLocalizations.mountTarget('other')),
        findsOneWidget,
      );
    });

    testWidgets('moves under the subtitle when the card is narrow', (
      tester,
    ) async {
      final current = Profile.normal(label: 'current');
      await pumpProfiles(tester, profiles: [current]);
      tester.view.physicalSize = const Size(380, 600);
      await tester.pump();

      final pill = tester.getRect(pillOf('current'));
      final title = tester.getRect(find.text('current'));
      final subtitle = tester.getRect(find.text(currentAppLocalizations.local));
      expect(pill.top, greaterThan(subtitle.bottom));
      expect(pill.left, title.left);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the menu of a non-custom profile opens the mount sheet', (
    tester,
  ) async {
    final l10n = currentAppLocalizations;
    final mounts = _FakeMountAction(const []);
    final file = Profile.normal(label: 'file');
    await pumpProfiles(
      tester,
      profiles: [
        file,
        Profile.custom(label: 'mine'),
      ],
      overrides: [mountActionProvider.overrideWith(() => mounts)],
    );

    await openProfileMenu(tester, 'mine');
    expect(find.text(l10n.mountEntryMenu), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await openProfileMenu(tester, 'file');
    await tester.tap(find.text(l10n.mountEntryMenu));
    await tester.pumpAndSettle();
    expect(mounts.opened, [file.id]);
  });

  group('the selected profile is revealed', () {
    final profiles = [
      for (var index = 0; index < 40; index++) urlProfile('profile $index'),
    ];
    final selected = profiles[36];

    Rect selectedRect(WidgetTester tester) => tester.getRect(
      find.ancestor(
        of: find.text(selected.label),
        matching: find.byType(ProfileItem),
      ),
    );

    void expectRevealed(WidgetTester tester) {
      final viewport = tester.getRect(find.byKey(profilesStoreKey));
      final rect = selectedRect(tester);
      expect(rect.top, greaterThanOrEqualTo(viewport.top));
      expect(rect.bottom, lessThanOrEqualTo(viewport.bottom));
    }

    testWidgets('in its first frame, which a tab switch snapshots', (
      tester,
    ) async {
      await pumpProfiles(
        tester,
        profiles: profiles,
        currentProfileId: selected.id,
        firstFrameOnly: true,
      );

      expectRevealed(tester);

      await tester.pumpAndSettle();
      expectRevealed(tester);
    });

    testWidgets('not in a picker, whose bar is left empty', (tester) async {
      await pumpProfiles(
        tester,
        profiles: profiles,
        currentProfileId: selected.id,
        picker: true,
      );
      await tester.pumpAndSettle();

      expect(find.text(profiles.first.label), findsOneWidget);
      expect(find.text(selected.label), findsNothing);
      expect(find.byType(AppBarActionButton), findsNothing);
    });

    testWidgets('not when the kept page becomes active again', (tester) async {
      final isActive = ValueNotifier(true);
      addTearDown(isActive.dispose);
      await pumpProfiles(
        tester,
        profiles: profiles,
        currentProfileId: selected.id,
        isActive: isActive,
      );
      await tester.pumpAndSettle();

      isActive.value = false;
      await tester.pump();
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(profilesStoreKey),
          matching: find.byType(Scrollable),
        ),
      );
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text(selected.label), findsNothing);

      isActive.value = true;
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, 0);
      expect(find.text(selected.label), findsNothing);
    });
  });
}
