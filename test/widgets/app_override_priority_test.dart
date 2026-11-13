import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/views/config/override.dart';
import 'package:fl_clash/views/config/tun.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/host_scaffold.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

void main() {
  testWidgets('empty legacy app keys still show every exposed TUN control', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final spec = appTunOverrideSpec(isLinux: false, isWindows: false);
    await tester.pumpWidget(
      TestApp(
        overrides: [profilesProvider.overrideWith(() => TestProfiles([]))],
        child: HostScaffold(
          body: OverrideSection(title: 'TUN', spec: spec),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(
      find.byType(OverrideSection<TunOverrideKey, ProfileTun>),
    );
    final container = ProviderScope.containerOf(context);
    expect(container.read(patchClashConfigProvider).tunOverrideKeys, isEmpty);
    expect(
      find.byType(OverrideEntry<TunOverrideKey, ProfileTun>),
      findsNWidgets(spec.values.length),
    );
    expect(find.byKey(const ValueKey(#add)), findsNothing);
    expect(find.byType(EntryButton), findsNothing);
  });

  testWidgets('profile editor retains opt-in add/remove semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        overrides: [
          profilesProvider.overrideWith(
            () => TestProfiles([
              const Profile(
                id: 1,
                type: ProfileType.custom,
                autoUpdateDuration: Duration.zero,
              ),
            ]),
          ),
        ],
        child: TunView(1, isLinux: false, isWindows: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(currentAppLocalizations.addSettingEntry), findsOneWidget);
    expect(
      find.byType(OverrideEntry<TunOverrideKey, ProfileTun>),
      findsNothing,
    );
  });
}
