import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/profiles/profiles.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

Profile _remote(String label) =>
    Profile.normal(label: label, url: 'https://example.com/$label');

/// Holds every update until the test answers it.
class _HeldProfilesAction extends ProfilesAction {
  final calls = <Profile>[];
  final pending = <int, Completer<void>>{};

  @override
  Future<void> updateProfile(Profile profile, {bool showLoading = false}) {
    calls.add(profile);
    return (pending[profile.id] = Completer<void>()).future;
  }

  void answer(Profile profile, [Object? error]) {
    final completer = pending.remove(profile.id)!;
    if (error == null) {
      completer.complete();
    } else {
      completer.completeError(error);
    }
  }
}

void main() {
  late _HeldProfilesAction action;

  Future<ProviderContainer> pumpProfiles(
    WidgetTester tester,
    List<Profile> profiles,
  ) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    action = _HeldProfilesAction();
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles(profiles)),
        currentProfileIdProvider.overrideWithBuild((_, _) => profiles.first.id),
        profilesActionProvider.overrideWith(() => action),
        for (final profile in profiles)
          if (profile.type != ProfileType.custom)
            mountCardSummaryProvider(
              profile.id,
            ).overrideWith((_) => Future.value(null)),
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
          builder: (context, child) => wrapAppScopes(context, child!),
          home: const ProfilesView(),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  Finder updateButton() => find.byTooltip(currentAppLocalizations.update);
  Finder busyButton() =>
      find.byTooltip(currentAppLocalizations.profilesUpdating);
  Finder sortButton() => find.byTooltip(currentAppLocalizations.profilesSort);

  List<String> cardOrder() => [
    for (final element in find.byType(Card).evaluate())
      for (final label in ['a', 'b', 'local', 'custom'])
        if (find
            .descendant(
              of: find.byWidget(element.widget),
              matching: find.text(label),
            )
            .evaluate()
            .isNotEmpty)
          label,
  ];

  testWidgets('only local and custom profiles: no batch update, sorting '
      'stays', (tester) async {
    await pumpProfiles(tester, [
      Profile.normal(label: 'local'),
      Profile.custom(label: 'custom'),
    ]);

    expect(updateButton(), findsNothing);
    expect(busyButton(), findsNothing);
    expect(sortButton(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a single remote profile: one batch however often it is '
      'tapped, busy in place until it answers', (tester) async {
    final a = _remote('a');
    await pumpProfiles(tester, [a]);
    expect(updateButton(), findsOneWidget);
    final idle = tester.getRect(updateButton());

    await tester.tap(updateButton());
    await tester.pump();
    expect(action.calls, [a]);
    expect(updateButton(), findsNothing);
    expect(busyButton(), findsOneWidget);
    expect(tester.getRect(busyButton()), idle);
    expect(
      find.descendant(
        of: busyButton(),
        matching: find.byType(ActivityIndicator),
      ),
      findsOneWidget,
    );

    await tester.tap(busyButton(), warnIfMissed: false);
    await tester.pump();
    await tester.tap(busyButton(), warnIfMissed: false);
    await tester.pump();
    expect(action.calls, [a]);

    action.answer(a);
    await tester.pump();
    expect(busyButton(), findsNothing);
    expect(updateButton(), findsOneWidget);
    // Success adds no message, least of all one saying it was applied.
    expect(find.textContaining('a:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mixed profiles: only the remote ones update, and rows keep '
      'their order', (tester) async {
    final a = _remote('a');
    final local = Profile.normal(label: 'local');
    final b = _remote('b');
    final custom = Profile.custom(label: 'custom');
    await pumpProfiles(tester, [a, local, b, custom]);
    final before = cardOrder();
    expect(before, hasLength(4));

    await tester.tap(updateButton());
    await tester.pump();
    expect(action.calls.map((p) => p.id), [a.id, b.id]);
    expect(cardOrder(), before);

    action.answer(a);
    await tester.pump();
    expect(busyButton(), findsOneWidget, reason: 'b is still updating');
    action.answer(b);
    await tester.pump();
    expect(updateButton(), findsOneWidget);
    expect(cardOrder(), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed update ends the batch, reports it and lets it run '
      'again', (tester) async {
    final a = _remote('a');
    final b = _remote('b');
    await pumpProfiles(tester, [a, b]);

    await tester.tap(updateButton());
    await tester.pump();
    action.answer(a, StateError('boom'));
    action.answer(b);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(busyButton(), findsNothing);
    expect(updateButton(), findsOneWidget);
    final l10n = currentAppLocalizations;
    expect(
      find.text(
        l10n.failedItem('a', userFacingErrorMessage(StateError('boom'), l10n)),
      ),
      findsOneWidget,
    );

    await tester.tap(updateButton());
    await tester.pump();
    expect(action.calls.length, 4);
    action.answer(a);
    action.answer(b);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving the page mid-update sets no state after dispose', (
    tester,
  ) async {
    final a = _remote('a');
    await pumpProfiles(tester, [a]);
    await tester.tap(updateButton());
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    action.answer(a, StateError('late'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });
}
