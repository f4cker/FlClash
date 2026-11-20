import 'dart:async';

import 'package:drift/native.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/form/form.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/backup_and_restore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';
import '../helpers/host_scaffold.dart';

const _existing = DAVProps(
  uri: 'https://dav.example.com/remote',
  user: 'alice',
  password: 'secret',
  fileName: 'custom.zip',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [profilesProvider.overrideWith(TestProfiles.new)],
    );
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(1200, 1400);
    container.listen(davSettingProvider, (_, _) {}, fireImmediately: true);
  });

  tearDown(() => container.dispose());

  Future<void> pumpForm(WidgetTester tester, Widget form) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Builder(
            builder: (context) => HostScaffold(
              body: TextButton(
                onPressed: () =>
                    showFormSheet<void>(context: context, builder: (_) => form),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(String title) => find.descendant(
    of: find.widgetWithText(FormRow, title),
    matching: find.byType(TextFormField),
  );

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
  }

  group('RestoreOptionsDialog', () {
    Future<RestoreOption?> openAndChoose(
      WidgetTester tester,
      String label,
    ) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      RestoreOption? chosen;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            child: Builder(
              builder: (context) => HostScaffold(
                body: TextButton(
                  onPressed: () async {
                    chosen = await showDialog<RestoreOption>(
                      context: context,
                      builder: (_) => const RestoreOptionsDialog(),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Backups retain rule set settings. After restoring, connect to the '
          'internet to download rule sets again; everyday restarts and profile '
          'switches do not require another download.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      return chosen;
    }

    testWidgets('returns onlyProfiles for the config-only option', (
      tester,
    ) async {
      expect(
        await openAndChoose(tester, 'Restore profiles only'),
        RestoreOption.onlyProfiles,
      );
    });

    testWidgets('returns all for the full-data option', (tester) async {
      expect(
        await openAndChoose(tester, 'Restore all data'),
        RestoreOption.all,
      );
    });
  });

  group('WebDAVForm', () {
    testWidgets('rejects an empty form and stores nothing', (tester) async {
      await pumpForm(tester, const WebDAVForm());

      await save(tester);

      expect(container.read(davSettingProvider), isNull);
      expect(find.byType(WebDAVForm), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ErrorBanner),
          matching: find.text('Please enter a valid WebDAV address'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('names the password toggle by what pressing it does', (
      tester,
    ) async {
      await pumpForm(tester, const WebDAVForm());

      final toggle = find.descendant(
        of: find.widgetWithText(FormRow, 'Password'),
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(toggle).tooltip, 'Show password');

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(tester.widget<IconButton>(toggle).tooltip, 'Hide password');
    });

    testWidgets('rejects a malformed address', (tester) async {
      await pumpForm(tester, const WebDAVForm());

      await tester.enterText(field('Address'), 'not-a-url');
      await tester.enterText(field('Account'), 'alice');
      await tester.enterText(field('Password'), 'secret');
      await save(tester);

      expect(container.read(davSettingProvider), isNull);
      expect(find.byType(WebDAVForm), findsOneWidget);
    });

    testWidgets('stores a valid binding with the default file name', (
      tester,
    ) async {
      await pumpForm(tester, const WebDAVForm());

      await tester.enterText(
        field('Address'),
        'https://dav.example.com/remote',
      );
      await tester.enterText(field('Account'), 'alice');
      await tester.enterText(field('Password'), 'secret');
      await save(tester);

      final dav = container.read(davSettingProvider);
      expect(dav?.uri, 'https://dav.example.com/remote');
      expect(dav?.user, 'alice');
      expect(dav?.password, 'secret');
      expect(dav?.fileName, defaultDavFileName);
      expect(find.byType(WebDAVForm), findsNothing);
    });

    testWidgets('editing preserves the previously chosen file name', (
      tester,
    ) async {
      container.read(davSettingProvider.notifier).update((_) => _existing);
      await pumpForm(tester, const WebDAVForm(dav: _existing));

      await tester.enterText(field('Account'), 'bob');
      await save(tester);

      final dav = container.read(davSettingProvider);
      expect(dav?.user, 'bob');
      expect(dav?.fileName, 'custom.zip');
    });

    testWidgets('offers delete only when editing an existing binding', (
      tester,
    ) async {
      await pumpForm(tester, const WebDAVForm());
      expect(find.widgetWithText(FormRow, 'Delete'), findsNothing);
      Navigator.of(tester.element(find.byType(WebDAVForm))).pop();
      await tester.pumpAndSettle();

      await pumpForm(tester, const WebDAVForm(dav: _existing));
      expect(find.widgetWithText(FormRow, 'Delete'), findsOneWidget);
    });

    testWidgets('delete clears the stored binding', (tester) async {
      container.read(davSettingProvider.notifier).update((_) => _existing);
      await pumpForm(tester, const WebDAVForm(dav: _existing));

      await tester.tap(find.widgetWithText(FormRow, 'Delete'));
      await tester.pumpAndSettle();

      expect(container.read(davSettingProvider), isNull);
    });

    testWidgets('toggles password visibility', (tester) async {
      await pumpForm(tester, const WebDAVForm(dav: _existing));

      expect(find.byGlyph(AppGlyphs.eye), findsOneWidget);
      await tester.tap(find.byGlyph(AppGlyphs.eye));
      await tester.pumpAndSettle();
      expect(find.byGlyph(AppGlyphs.eyeOff), findsOneWidget);
    });
  });

  group('restore blocked dialog', () {
    late Database db;
    const backupPage = 'backup page';

    setUp(() async {
      db = Database(NativeDatabase.memory());
      database = db;
      await db.profilesDao.putAll([
        const Profile(
          id: 1,
          label: 'Target',
          autoUpdateDuration: Duration.zero,
        ).toCompanion(0),
        const Profile(
          id: 2,
          label: 'Source',
          autoUpdateDuration: Duration.zero,
        ).toCompanion(1),
      ]);
      final mount = await db.mountsDao.save(
        targetId: 1,
        expectedVersion: null,
        sourceIds: [2],
        pending: (version) =>
            MountOperation(kind: MountOperationKind.save, version: version),
      );
      await db.mountsDao.settle(1, mount.version);
    });

    tearDown(() => db.close());

    Future<Object> snapshot() async => (
      await db.profilesDao.query().get(),
      await db.mountsDao.targets(),
    ).toString();

    Future<(Future<void>,)> show(
      WidgetTester tester,
      RestoreBlockedException blocked,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(child: HostScaffold(body: SizedBox.shrink())),
        ),
      );
      unawaited(
        globalState.navigatorKey.currentState!.push(
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => const Text(backupPage),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final shown = showRestoreBlocked(blocked, container.read);
      await tester.pumpAndSettle();
      return (shown,);
    }

    RestoreBlockedException merge() => RestoreBlockedException(
      currentAppLocalizations.restoreBlockedMountStateChanged,
      reason: RestoreBlockedReason.mountStateChanged,
      profileIds: const [1],
    );

    testWidgets('viewing opens the profiles page and changes nothing', (
      tester,
    ) async {
      final before = await tester.runAsync(snapshot);
      final l10n = currentAppLocalizations;
      final (shown,) = await show(tester, merge());

      expect(find.text(l10n.restoreBlockedMountStateChanged), findsOne);
      expect(find.textContaining(l10n.delete), findsNothing);
      await tester.tap(find.text(l10n.restoreBlockedViewProfiles));
      await tester.pumpAndSettle();
      await shown;

      expect(container.read(currentPageLabelProvider), PageLabel.profiles);
      expect(find.text(backupPage), findsNothing);
      expect(await tester.runAsync(snapshot), before);
    });

    testWidgets('closing stays on the page', (tester) async {
      final l10n = currentAppLocalizations;
      final (shown,) = await show(tester, merge());

      await tester.tap(find.text(l10n.close));
      await tester.pumpAndSettle();
      await shown;

      expect(container.read(currentPageLabelProvider), PageLabel.dashboard);
      expect(find.text(backupPage), findsOne);
    });

    testWidgets('offers only close when no conflicting profile is here', (
      tester,
    ) async {
      final l10n = currentAppLocalizations;
      await show(
        tester,
        RestoreBlockedException(
          l10n.restoreBlockedMountStateChanged,
          reason: RestoreBlockedReason.mountStateChanged,
        ),
      );

      expect(find.byType(TextButton), findsOne);
      expect(find.text(l10n.close), findsOne);
      expect(find.text(l10n.restoreBlockedViewProfiles), findsNothing);
    });
  });
}
