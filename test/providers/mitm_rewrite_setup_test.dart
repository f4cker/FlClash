import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart' as db;
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  late db.Database testDatabase;
  late bool feature;

  setUp(() async {
    feature = mitmFeature;
    mitmFeature = true;
    testDatabase = db.Database(NativeDatabase.memory());
    db.database = testDatabase;
    await testDatabase.profilesDao.putAll([
      const Profile(id: 1, autoUpdateDuration: Duration.zero).toCompanion(),
      const Profile(id: 2, autoUpdateDuration: Duration.zero).toCompanion(),
    ]);
    await testDatabase.batch(
      (b) => testDatabase.mitmRewritesDao.setProfileWithBatch(1, b, const [
        MitmRewrite(
          id: 10,
          section: MitmList.urlRewrite,
          line: r'^https:\/\/a\.com\/ad - reject',
        ),
        MitmRewrite(
          id: 11,
          section: MitmList.bodyRewrite,
          line: r'http-response ^https:\/\/a\.com a b',
          enabled: false,
        ),
      ]),
    );
    await testDatabase.mitmRewritesDao.put(
      const MitmRewrite(
        id: 20,
        section: MitmList.mapLocal,
        line: r'^https:\/\/b\.com data-type=text data="x"',
      ),
      profileId: 2,
    );
  });

  tearDown(() async {
    mitmFeature = feature;
    await testDatabase.close();
  });

  Future<Map<String, Object?>?> settledSetup(
    ProviderContainer container,
  ) async {
    final profileId = container.read(currentProfileIdProvider);
    if (profileId != null) {
      await container.read(profileMitmRewritesProvider(profileId).future);
    }
    return container.read(mitmSetupProvider);
  }

  test('the setup carries the current profile\'s enabled rules', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(mitmSetupProvider, (_, _) {});
    container.read(patchClashConfigProvider.notifier).value =
        const PatchClashConfig(mitm: Mitm(enable: true));
    container.read(currentProfileIdProvider.notifier).value = 1;
    var setup = await settledSetup(container);
    expect(setup?['rewrite'], [
      {
        'id': '10',
        'section': 'url-rewrite',
        'line': r'^https:\/\/a\.com\/ad - reject',
      },
    ]);
    expect(setup?['enable'], isTrue);

    // Switching profiles switches the rules.
    container.read(currentProfileIdProvider.notifier).value = 2;
    setup = await settledSetup(container);
    expect((setup?['rewrite'] as List).single, {
      'id': '20',
      'section': 'map-local',
      'line': r'^https:\/\/b\.com data-type=text data="x"',
    });

    // An edit reaches the setup.
    container
        .read(profileMitmRewritesProvider(2).notifier)
        .setEnabled(20, false);
    await pumpEventQueue();
    expect(container.read(mitmSetupProvider)?.containsKey('rewrite'), isFalse);

    // MITM off: nothing at all is sent.
    container.read(patchClashConfigProvider.notifier).value =
        const PatchClashConfig(mitm: Mitm(enable: false));
    expect(container.read(mitmSetupProvider), isNull);
  });

  test('rules added through the notifier persist in order', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(profileMitmRewritesProvider(2), (_, _) {});
    await container.read(profileMitmRewritesProvider(2).future);
    final notifier = container.read(profileMitmRewritesProvider(2).notifier);
    notifier.addAll(const [
      MitmRewrite(id: 21, section: MitmList.urlRewrite, line: 'a - reject'),
      MitmRewrite(id: 22, section: MitmList.urlRewrite, line: 'b - reject'),
    ]);
    await pumpEventQueue();
    final stored = await testDatabase.mitmRewritesDao.queryProfile(2).get();
    expect(stored.map((item) => item.id), [20, 21, 22]);
    notifier.order(2, 0);
    notifier.delAll([20]);
    await pumpEventQueue();
    expect(
      (await testDatabase.mitmRewritesDao.queryProfile(2).get()).map(
        (item) => item.id,
      ),
      [22, 21],
    );
  });
}
