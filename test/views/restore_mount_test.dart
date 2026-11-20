// Widget tests for the restore mount confirmation, refusal and result views.
// Screenshots are off by default:
//   RESTORE_MOUNT_SHOTS=/private/tmp/flash-restore-mount/shots-r2 flutter test \
//     test/views/restore_mount_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/restore_journal.dart';
import 'package:fl_clash/common/restore_mount_plan.dart';
import 'package:fl_clash/common/restore_result.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/manager/theme_manager.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/backup_and_restore.dart';
import 'package:fl_clash/views/restore_mount.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

final _outDir = Platform.environment['RESTORE_MOUNT_SHOTS'];
const _cjkCollection = '/System/Library/Fonts/Hiragino Sans GB.ttc';

List<ByteData> _collectionFaces(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final faces = <ByteData>[];
  for (var face = 0; face < data.getUint32(8); face++) {
    final header = data.getUint32(12 + face * 4);
    final tables = data.getUint16(header + 4);
    final out = BytesBuilder()..add(bytes.sublist(header, header + 12));
    final body = BytesBuilder();
    var at = 12 + tables * 16;
    for (var i = 0; i < tables; i++) {
      final entry = header + 12 + i * 16;
      final offset = data.getUint32(entry + 8);
      final length = data.getUint32(entry + 12);
      final record = ByteData(16)
        ..setUint32(0, data.getUint32(entry))
        ..setUint32(4, data.getUint32(entry + 4))
        ..setUint32(8, at)
        ..setUint32(12, length);
      out.add(record.buffer.asUint8List());
      final padded = (length + 3) & ~3;
      body
        ..add(bytes.sublist(offset, offset + length))
        ..add(Uint8List(padded - length));
      at += padded;
    }
    out.add(body.takeBytes());
    faces.add(ByteData.sublistView(out.takeBytes()));
  }
  return faces;
}

Profile _file(int id, String label) =>
    Profile(id: id, label: label, autoUpdateDuration: Duration.zero);

Profile _sub(int id, String label) => _file(
  id,
  label,
).copyWith(type: ProfileType.url, url: 'https://example.invalid/$id');

/// The mockup's compatible restore, with fictional names.
RestoreMountPlan _mergePlan() => planRestoreMounts(
  isOverride: false,
  localTargets: {
    10: const MountTargetState(targetId: 10, sourceIds: [11, 12], version: 3),
    20: const MountTargetState(targetId: 20, sourceIds: [20], version: 1),
    30: const MountTargetState(targetId: 30, sourceIds: [31], version: 1),
    40: const MountTargetState(targetId: 40, sourceIds: [41], version: 2),
  },
  localProfiles: [
    _file(10, '晨光配置'),
    _sub(11, '海岸订阅'),
    _sub(12, '旧海岸订阅'),
    _sub(13, '山岚订阅'),
    _file(20, '夜航配置'),
    _file(30, '山岚配置'),
    _file(31, '本地节点集'),
    _file(40, '远行配置'),
    _sub(41, '远行订阅'),
  ],
  backupProfiles: [
    _file(10, '晨光配置'),
    _file(20, '夜航配置'),
    _sub(41, '远行订阅'),
    _file(30, '山岚配置'),
  ],
  backupTargets: {
    10: const MountTargetState(targetId: 10, sourceIds: [11, 13], version: 5),
    30: const MountTargetState(targetId: 30, sourceIds: [31, 99], version: 1),
  },
);

/// An override restore with mount data: the backup's relations win, local
/// ones it does not carry go, and one relation is new from the backup.
RestoreMountPlan _overridePlan() => planRestoreMounts(
  isOverride: true,
  localTargets: {
    10: const MountTargetState(targetId: 10, sourceIds: [11, 12], version: 3),
    20: const MountTargetState(targetId: 20, sourceIds: [21], version: 1),
    40: const MountTargetState(targetId: 40, sourceIds: [41], version: 2),
  },
  localProfiles: [
    _file(10, '晨光配置'),
    _sub(11, '海岸订阅'),
    _sub(12, '旧海岸订阅'),
    _file(20, '夜航配置'),
    _sub(21, '夜航订阅'),
    _file(40, '远行配置'),
    _sub(41, '远行订阅'),
  ],
  backupProfiles: [
    _file(10, '晨光配置'),
    _sub(11, '海岸订阅'),
    _sub(13, '山岚订阅'),
    _file(40, '远行配置'),
    _sub(41, '远行订阅'),
  ],
  backupTargets: {
    10: const MountTargetState(targetId: 10, sourceIds: [11, 13], version: 5),
    40: const MountTargetState(targetId: 40, sourceIds: [41], version: 2),
  },
);

/// MITM modules a backup carries; two share a name.
const _mitm = [
  RestoreMitmModule(41, '广告过滤'),
  RestoreMitmModule(42, '广告过滤'),
  RestoreMitmModule(50, '比价助手'),
];

/// An old backup without mount data, as in the narrow mockup.
RestoreMountPlan _legacyPlan() => planRestoreMounts(
  isOverride: true,
  localTargets: {
    1: const MountTargetState(targetId: 1, sourceIds: [2], version: 1),
    3: const MountTargetState(targetId: 3, sourceIds: [3], version: 1),
    4: const MountTargetState(targetId: 4, sourceIds: [5], version: 1),
    6: const MountTargetState(targetId: 6, sourceIds: [7], version: 1),
  },
  localProfiles: [
    _file(1, '远行与工作专用配置（本地示例）'),
    _sub(2, '海岸区域长期订阅（本地示例）'),
    _file(3, '夜航配置'),
    _file(4, '山岚配置'),
    _file(5, '本地节点集'),
    _file(6, '远行配置'),
    _sub(7, '旧海岸订阅'),
  ],
  backupProfiles: [
    _file(1, '远行与工作专用配置（本地示例）'),
    _sub(2, '海岸区域长期订阅（本地示例）'),
    _file(3, '夜航配置'),
    _file(4, '山岚配置'),
    _file(5, '本地节点集'),
    _file(6, '远行配置'),
  ],
  backupTargets: null,
);

RestoreMountPlan _bigPlan(int count) => planRestoreMounts(
  isOverride: true,
  localTargets: {
    for (var i = 0; i < count; i++)
      1000 + i: MountTargetState(
        targetId: 1000 + i,
        sourceIds: const [1],
        version: 1,
      ),
  },
  localProfiles: [
    _sub(1, 'A subscription with a rather long English name that wraps'),
    for (var i = 0; i < count; i++) _file(1000 + i, '配置 $i'),
  ],
  backupProfiles: const [],
  backupTargets: const {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shots = _outDir != null && _outDir!.isNotEmpty;

  setUpAll(() async {
    if (!shots) return;
    WidgetsApp.debugAllowBannerOverride = false;
    final loader = FontLoader('Roboto');
    for (final face in _collectionFaces(
      File(_cjkCollection).readAsBytesSync(),
    )) {
      loader.addFont(Future.value(face));
    }
    await loader.load();
    Directory(_outDir!).createSync(recursive: true);
  });

  final boundary = GlobalKey();

  Future<void> host(
    WidgetTester tester,
    Widget Function() child, {
    Locale locale = const Locale('en'),
    Size size = const Size(900, 1000),
    double textScale = 1,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    globalState.container = container;
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    loadAppLocalizations(locale);
    addTearDown(() => loadAppLocalizations(const Locale('en')));
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => TestApp(
              locale: locale,
              theme: watchAppTheme(ref, Brightness.light),
              darkTheme: watchAppTheme(ref, Brightness.dark),
              themeMode: themeMode,
              child: MediaQuery.withClampedTextScaling(
                minScaleFactor: textScale,
                maxScaleFactor: textScale,
                child: ColoredBox(
                  color: themeMode == ThemeMode.dark
                      ? const Color(0xFF1C1C1E)
                      : const Color(0xFFE8E9ED),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: child(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    if (!shots) return;
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File('$_outDir/$name.png').writeAsBytes(data!.buffer.asUint8List());
    });
  }

  /// Pushes [sheet] as a route so its pop value can be read.
  /// The returned list holds the pop value once the route is gone, so a
  /// sheet that never pops fails the test instead of hanging it.
  Future<List<bool?>> pushSheet(WidgetTester tester, Widget sheet) async {
    await host(tester, () => const SizedBox.shrink());
    final result = <bool?>[];
    unawaited(
      globalState.navigatorKey.currentState!
          .push<bool>(PageRouteBuilder<bool>(pageBuilder: (_, _, _) => sheet))
          .then(result.add),
    );
    await tester.pumpAndSettle();
    return result;
  }

  group('the plan as rows', () {
    test('a name with its id reads name first', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      expect(
        restoreProfileName(
          const RestoreMountProfile(7, label: '旧海岸订阅'),
          l10n,
          withId: true,
        ),
        '旧海岸订阅（标识 7）',
      );
    });

    test('groups and reason ids follow the plan', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final rows = restoreMountRows(_mergePlan(), l10n);
      expect(rows[RestoreMountGroup.replace]!.single.owner!.label, '晨光配置');
      expect(rows[RestoreMountGroup.replace]!.single.note, contains('旧海岸订阅'));
      expect(
        {for (final r in rows[RestoreMountGroup.remove]!) r.reasonId},
        {'self', 'source-not-subscription'},
        reason:
            'a compatible restore keeps every local profile, so no '
            'target goes missing',
      );
      expect(
        rows[RestoreMountGroup.invalid]!.single.reasonId,
        'source-missing',
      );
      expect(
        rows[RestoreMountGroup.invalid]!.single.source,
        '名称不可用（标识 99）',
        reason: 'a missing source is never given a guessed name',
      );
    });
  });

  group('kept and restored relations', () {
    test('kept holds only local relations left as they are; the backup\'s '
        'new relations are their own group and never count as kept', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final plan = _mergePlan();
      final rows = restoreMountRows(plan, l10n);
      String pair(RestoreMountRow r) => '${r.owner!.label}←${r.source}';
      expect(
        {for (final r in rows[RestoreMountGroup.keep]!) pair(r)},
        {'晨光配置←海岸订阅', '远行配置←远行订阅'},
      );
      expect(
        {for (final r in rows[RestoreMountGroup.restore]!) pair(r)},
        {'晨光配置←山岚订阅'},
      );
      expect(
        {for (final r in rows[RestoreMountGroup.keep]!) r.tag},
        {l10n.restoreMountTagKeep},
      );
      expect(
        {for (final r in rows[RestoreMountGroup.restore]!) r.tag},
        {l10n.restoreMountTagRestore},
      );
      expect(plan.keptLocally, hasLength(2));
      expect(plan.restoredFromBackup, hasLength(1));
      expect(
        plan.keptLocally.length + plan.restoredFromBackup.length,
        plan.kept.length,
        reason: 'every relation after the restore is in exactly one group',
      );
    });

    testWidgets('chips and headings count each group on its own', (
      tester,
    ) async {
      await host(
        tester,
        () => RestoreMountConfirmSheet(plan: _mergePlan()),
        locale: const Locale('zh'),
        size: const Size(860, 1400),
      );
      expect(find.text('保留 2 条'), findsOne);
      expect(find.text('从备份恢复 1 条'), findsOne);
      expect(find.text('保留的关系 · 2'), findsOne);
      expect(find.text('从备份恢复 · 1'), findsOne);
      expect(find.text('保留 3 条'), findsNothing);
      // Inside 保留 no row is tagged as coming from the backup.
      expect(find.text('来自备份'), findsOne);
    });

    testWidgets('an override says same before and after, never kept', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final rows = restoreMountRows(_overridePlan(), l10n);
      String pair(RestoreMountRow r) => '${r.owner!.label}←${r.source}';
      expect(rows[RestoreMountGroup.keep], isEmpty);
      expect(
        {for (final r in rows[RestoreMountGroup.same]!) pair(r)},
        {'晨光配置←海岸订阅', '远行配置←远行订阅'},
      );
      expect(
        {for (final r in rows[RestoreMountGroup.same]!) r.tag},
        {l10n.restoreMountTagSame},
      );
      // A merge never uses the override's wording.
      expect(
        restoreMountRows(_mergePlan(), l10n)[RestoreMountGroup.same],
        isEmpty,
      );
      await host(
        tester,
        () => RestoreMountConfirmSheet(plan: _overridePlan()),
        locale: const Locale('zh'),
        size: const Size(860, 1400),
      );
      expect(find.text('恢复前后相同的关系 2 条'), findsOne);
      expect(find.text('恢复前后相同的关系 · 2'), findsOne);
      expect(find.text('关系相同'), findsNWidgets(2));
      expect(find.textContaining('保留的关系'), findsNothing);
      expect(find.textContaining(RegExp(r'^保留 \d+ 条$')), findsNothing);
      expect(find.text('保留'), findsNothing);
    });

    test('the same group is exactly the override relations with the same '
        'target and source before and after, rewritten from the backup', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final plan = _overridePlan();
      expect(plan.rewritesFromBackup, isTrue);
      final same = restoreMountRows(plan, l10n)[RestoreMountGroup.same]!;
      expect(
        {for (final r in same) (r.owner!.id, r.source)},
        {(10, '海岸订阅'), (40, '远行订阅')},
      );
      for (final k in plan.keptLocally) {
        expect(
          plan.writes.any(
            (w) =>
                w.targetId == k.relation.target.id &&
                w.sourceIds.contains(k.relation.source.id),
          ),
          isTrue,
          reason: '$k is rewritten',
        );
      }
      // An old backup without mount data keeps the local relations, as a
      // merge does; that is kept, not same.
      final legacy = _legacyPlan();
      expect(legacy.isOverride, isTrue);
      expect(legacy.rewritesFromBackup, isFalse);
      final rows = restoreMountRows(legacy, l10n);
      expect(rows[RestoreMountGroup.same], isEmpty);
      expect(rows[RestoreMountGroup.keep]!.length, legacy.keptLocally.length);
    });

    testWidgets('a plan with nothing new from the backup shows no restore '
        'chip or group', (tester) async {
      await host(
        tester,
        () => RestoreMountConfirmSheet(plan: _legacyPlan()),
        locale: const Locale('zh'),
      );
      expect(find.textContaining('从备份恢复'), findsNothing);
    });
  });

  group('long lists reach the bottom', () {
    Future<void> expectLastRowReachable(
      WidgetTester tester,
      Finder last, {
      required bool pinned,
      Finder? footer,
    }) async {
      final scrollView = find.byType(CustomScrollView);
      final scrollable = find
          .descendant(of: scrollView, matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      for (var i = 0; i < 200 && last.evaluate().isEmpty; i++) {
        final before = position.pixels;
        await tester.drag(scrollView, const Offset(0, -500));
        await tester.pump();
        if (position.pixels == before) break;
      }
      expect(last, findsOne, reason: 'scrolling down reaches the last row');
      final viewport = tester.getRect(scrollView);
      void expectInside(String when) {
        final row = tester.getRect(last);
        expect(
          row.top >= viewport.top - 0.5 && row.bottom <= viewport.bottom + 0.5,
          isTrue,
          reason: '$when: the last row $row lies inside $viewport',
        );
        if (footer != null && tester.getRect(footer).top > row.top) {
          expect(
            row.bottom <= tester.getRect(footer).top + 0.5,
            isTrue,
            reason: '$when: the footer does not cover the last row',
          );
        }
      }

      // Brought fully into view by scrolling alone, never cut off.
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      expectInside('scrolled to');
      // And on to the very end, as a user flinging down would.
      await tester.drag(scrollView, const Offset(0, -100000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(position.pixels, position.maxScrollExtent);
      if (footer != null) {
        final screen = Offset.zero & tester.view.physicalSize / 2;
        expect(screen.contains(tester.getRect(footer).center), isTrue);
      }
      // With a pinned footer the last row is still in view at the end; in
      // a paged sheet the footer, in the flow, may have pushed it up.
      if (pinned) {
        expect(last, findsOne);
        expectInside('at the end');
      }
    }

    for (final (name, size, scale) in [
      ('desktop', const Size(900, 1000), 1.0),
      ('393 pt', const Size(393, 852), 1.0),
      ('393 pt at 200%', const Size(393, 852), 2.0),
    ]) {
      testWidgets('confirm, $name', (tester) async {
        await host(
          tester,
          () => RestoreMountConfirmSheet(plan: _bigPlan(120)),
          locale: const Locale('zh'),
          size: size,
          textScale: scale,
        );
        await expectLastRowReachable(
          tester,
          find.text('所属配置：配置 119'),
          pinned: name == 'desktop',
          footer: find.text(
            currentAppLocalizations.restoreMountConfirmOverride,
          ),
        );
      });

      testWidgets('result, $name', (tester) async {
        await host(
          tester,
          () => RestoreResultView(
            evidence: RestoreEvidence.committed(
              pendingChecks: [
                for (var i = 0; i < 120; i++)
                  RestoreMountProfile(i + 1, label: '配置 $i'),
              ],
            ),
            onOpenProfiles: () {},
          ),
          locale: const Locale('zh'),
          size: size,
          textScale: scale,
        );
        await expectLastRowReachable(
          tester,
          find.text('所属配置：配置 119'),
          pinned: name == 'desktop',
          footer: find.text(currentAppLocalizations.restoreBlockedViewProfiles),
        );
      });
    }
  });

  group('confirmation', () {
    testWidgets('losses need the checkbox; Enter never confirms; cancel '
        'writes nothing', (tester) async {
      final plan = _mergePlan();
      expect(plan.hasLosses, isTrue);
      final popped = await pushSheet(
        tester,
        RestoreMountConfirmSheet(plan: plan),
      );
      final l10n = currentAppLocalizations;
      final confirm = find.widgetWithText(
        FilledButton,
        l10n.restoreMountConfirmMerge,
      );
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(find.byType(Checkbox), findsOne);
      expect(find.text(l10n.restoreIrreversible), findsOne);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(RestoreMountConfirmSheet), findsOne);

      // The label is the checkbox's: tapping it checks.
      await tester.tap(
        find.textContaining(
          l10n.restoreMountAcknowledge(
            '${plan.removalCount}',
            '${plan.replacementCount}',
          ),
        ),
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.byType(RestoreMountConfirmSheet),
        findsOne,
        reason: 'Enter is not bound to the destructive action',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(popped, [false]);
    });

    testWidgets('confirming pops true once', (tester) async {
      final plan = _mergePlan();
      final popped = await pushSheet(
        tester,
        RestoreMountConfirmSheet(plan: plan),
      );
      final l10n = currentAppLocalizations;
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text(l10n.restoreMountConfirmMerge));
      await tester.pumpAndSettle();
      expect(popped, [true], reason: 'pops true exactly once');
    });

    testWidgets('no losses: no checkbox, and still an explicit confirm', (
      tester,
    ) async {
      final plan = planRestoreMounts(
        isOverride: false,
        localTargets: {
          1: const MountTargetState(targetId: 1, sourceIds: [2], version: 1),
        },
        localProfiles: [_file(1, 'T'), _sub(2, 'S')],
        backupProfiles: [_sub(2, 'S')],
        backupTargets: const {},
      );
      expect(plan.hasLosses, isFalse);
      await pushSheet(tester, RestoreMountConfirmSheet(plan: plan));
      expect(find.byType(Checkbox), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                currentAppLocalizations.restoreMountConfirmMerge,
              ),
            )
            .onPressed,
        isNotNull,
      );
    });

    test('MITM rows: backup order, a shared or missing name carries the '
        'id, each off after the restore', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      final rows = restoreMitmRows([
        ..._mitm,
        const RestoreMitmModule(60, ''),
      ], l10n);
      expect(
        [for (final r in rows) r.title],
        ['广告过滤（标识 41）', '广告过滤（标识 42）', '比价助手', '名称不可用（标识 60）'],
      );
      expect({for (final r in rows) r.tag}, {'恢复后关闭'});
    });

    testWidgets('with mount changes the MITM modules are their own group, '
        'and absent without modules', (tester) async {
      await host(
        tester,
        () => RestoreMountConfirmSheet(plan: _mergePlan(), mitmModules: _mitm),
        locale: const Locale('zh'),
        size: const Size(860, 2000),
      );
      expect(find.text('需要在本机重新同意的解密模块 · 3'), findsOne);
      expect(find.text('这些模块恢复后默认关闭，需在本机重新同意后才能运行。'), findsOne);
      expect(find.text('比价助手'), findsOne);
      expect(find.text('恢复后关闭'), findsNWidgets(3));
      // The mount parts and their action stay as they are.
      expect(find.text('保留 2 条'), findsOne);
      expect(find.text('恢复并替换'), findsOne);
      expect(find.byType(Checkbox), findsOne);
      await host(
        tester,
        () => RestoreMountConfirmSheet(plan: _mergePlan()),
        locale: const Locale('zh'),
      );
      expect(find.textContaining('解密模块'), findsNothing);
      expect(find.text('恢复后关闭'), findsNothing);
    });

    testWidgets('a MITM-only restore shows only the modules: no mount '
        'banner, chips or no-change line; plain Restore, no checkbox; '
        'cancel pops false', (tester) async {
      final popped = await pushSheet(
        tester,
        const RestoreMountConfirmSheet(
          plan: RestoreMountPlan(isOverride: false, mountsCarried: true),
          mitmModules: _mitm,
        ),
      );
      final l10n = currentAppLocalizations;
      expect(find.text(l10n.restoreMitmSection('3')), findsOne);
      expect(find.text(l10n.restoreMitmNote), findsOne);
      expect(find.text(l10n.restoreMitmTagOff), findsNWidgets(3));
      expect(find.text(l10n.restoreIrreversible), findsOne);
      expect(find.text(l10n.restoreMountMergeLead), findsNothing);
      expect(find.text(l10n.restoreMountNoChanges), findsNothing);
      expect(find.text(l10n.restoreMountKeepCount('0')), findsNothing);
      expect(find.text(l10n.restoreMountRemoveCount('0')), findsNothing);
      expect(find.text(l10n.restoreMountConfirmMerge), findsNothing);
      expect(find.text(l10n.restoreOverrideDeletesLocal), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
      expect(popped, [false]);
    });

    testWidgets('without a backup name or date the identity line is gone, '
        'leaving no gap', (tester) async {
      double gap() =>
          tester.getTopLeft(find.text('操作不可撤销，没有撤销或还原入口。')).dy -
          tester.getBottomLeft(find.text('兼容恢复备份？')).dy;
      await host(
        tester,
        () => const RestoreMountConfirmSheet(
          plan: RestoreMountPlan(isOverride: false, mountsCarried: true),
          backupName: '示例备份 · 2026年11月18日 10:30',
          mitmModules: _mitm,
        ),
        locale: const Locale('zh'),
      );
      expect(find.text('示例备份 · 2026年11月18日 10:30'), findsOne);
      final header = find.ancestor(
        of: find.text('兼容恢复备份？'),
        matching: find.byType(Column),
      );
      int lines() => find
          .descendant(of: header.first, matching: find.byType(Text))
          .evaluate()
          .length;
      expect(lines(), 3);
      for (final name in [null, '', '  ']) {
        await host(
          tester,
          () => RestoreMountConfirmSheet(
            plan: const RestoreMountPlan(
              isOverride: false,
              mountsCarried: true,
            ),
            backupName: name,
            mitmModules: _mitm,
          ),
          locale: const Locale('zh'),
        );
        expect(lines(), 2, reason: 'title and irreversible line only: $name');
        // Only the line's own top spacing, as when it follows the title.
        expect(gap(), 4, reason: 'no gap for $name');
      }
    });

    testWidgets('a MITM-only restore confirms with plain Restore', (
      tester,
    ) async {
      final popped = await pushSheet(
        tester,
        const RestoreMountConfirmSheet(
          plan: RestoreMountPlan(isOverride: false, mountsCarried: true),
          mitmModules: _mitm,
        ),
      );
      await tester.tap(find.text(currentAppLocalizations.restoreMitmConfirm));
      await tester.pumpAndSettle();
      expect(popped, [true]);
    });

    testWidgets('a MITM-only override still says it deletes what the '
        'backup lacks', (tester) async {
      await pushSheet(
        tester,
        const RestoreMountConfirmSheet(
          plan: RestoreMountPlan(isOverride: true, mountsCarried: true),
          mitmModules: _mitm,
        ),
      );
      final l10n = currentAppLocalizations;
      expect(find.text(l10n.restoreOverrideDeletesLocal), findsOne);
      expect(find.text(l10n.restoreOverrideScopeNote), findsOne);
      expect(find.text(l10n.restoreMountOverrideLead), findsNothing);
      // It deletes local items, so it is not a plain Restore.
      expect(find.text(l10n.restoreMountConfirmOverride), findsOne);
      expect(find.text(l10n.restoreMitmConfirm), findsNothing);
    });

    for (final (name, plan, modules) in [
      ('mount changes and backup modules', _overridePlan(), _mitm),
      (
        'mount changes, no backup modules',
        _overridePlan(),
        const <RestoreMitmModule>[],
      ),
      ('no mount data', _legacyPlan(), _mitm),
      (
        'nothing else to list',
        const RestoreMountPlan(isOverride: true, mountsCarried: true),
        const <RestoreMitmModule>[],
      ),
    ]) {
      testWidgets('every override says what it deletes: $name', (tester) async {
        expect(plan.isOverride, isTrue);
        await host(
          tester,
          () => RestoreMountConfirmSheet(plan: plan, mitmModules: modules),
          size: const Size(900, 1400),
        );
        final l10n = currentAppLocalizations;
        expect(find.text(l10n.restoreOverrideDeletesLocal), findsOne);
        expect(find.text(l10n.restoreOverrideScopeNote), findsOne);
        expect(find.text(l10n.restoreMountConfirmOverride), findsOne);
        if (!plan.isEmpty) {
          expect(
            find.text(
              plan.mountsCarried
                  ? l10n.restoreMountOverrideLead
                  : l10n.restoreMountLegacyLead,
            ),
            findsOne,
            reason: 'the mount banner stays',
          );
        }
      });
    }

    for (final (name, plan) in [
      ('with mount data', _overridePlan()),
      ('without mount data', _legacyPlan()),
    ]) {
      testWidgets('an override has one callout; its mount lines are plain '
          'text 12 below it and 8 above the counts: $name', (tester) async {
        await host(
          tester,
          () => RestoreMountConfirmSheet(plan: plan),
          size: const Size(900, 1400),
        );
        final l10n = currentAppLocalizations;
        final callout = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_Callout',
        );
        expect(callout, findsOne);
        expect(
          find.descendant(
            of: callout,
            matching: find.text(l10n.restoreOverrideDeletesLocal),
          ),
          findsOne,
        );
        final lead = plan.mountsCarried
            ? l10n.restoreMountOverrideLead
            : l10n.restoreMountLegacyLead;
        expect(
          find.ancestor(of: find.text(lead), matching: callout),
          findsNothing,
        );
        final explanation = find.byKey(
          const ValueKey('restore-mount-explanation'),
        );
        expect(
          find.descendant(of: explanation, matching: find.text(lead)),
          findsOne,
        );
        final chips = find.ancestor(
          of: find.text(l10n.restoreMountRemoveCount('${plan.removalCount}')),
          matching: find.byType(Wrap),
        );
        final text = tester.getRect(explanation);
        expect(text.top - tester.getRect(callout).bottom, 12);
        expect(tester.getRect(chips).top - text.bottom, 8);
      });
    }

    testWidgets('a compatible sheet keeps its mount callout', (tester) async {
      await host(
        tester,
        () => RestoreMountConfirmSheet(plan: _mergePlan()),
        size: const Size(900, 1400),
      );
      final l10n = currentAppLocalizations;
      expect(
        find.ancestor(
          of: find.text(l10n.restoreMountMergeLead),
          matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_Callout',
          ),
        ),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('restore-mount-explanation')),
        findsNothing,
      );
    });

    testWidgets('a compatible restore never shows the override line', (
      tester,
    ) async {
      await host(
        tester,
        () => RestoreMountConfirmSheet(plan: _mergePlan(), mitmModules: _mitm),
        size: const Size(900, 1400),
      );
      final l10n = currentAppLocalizations;
      expect(find.text(l10n.restoreOverrideDeletesLocal), findsNothing);
      expect(find.text(l10n.restoreMountConfirmMerge), findsOne);
    });

    for (final (name, size, scale) in [
      ('narrow, normal text', const Size(393, 852), 1.0),
      ('narrow, 200% text', const Size(393, 852), 2.0),
      ('wide, 200% text', const Size(900, 1000), 2.0),
    ]) {
      testWidgets('buttons stack, full width and uncut: $name', (tester) async {
        await host(
          tester,
          () => const RestoreMountConfirmSheet(
            plan: RestoreMountPlan(isOverride: true, mountsCarried: true),
            mitmModules: _mitm,
          ),
          size: size,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        final l10n = currentAppLocalizations;
        final cancel = find.widgetWithText(TextButton, l10n.cancel);
        final confirm = find.widgetWithText(
          FilledButton,
          l10n.restoreMountConfirmOverride,
        );
        await tester.scrollUntilVisible(
          confirm,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        final a = tester.getRect(cancel);
        final b = tester.getRect(confirm);
        expect(b.top, greaterThanOrEqualTo(a.bottom), reason: 'stacked');
        expect(a.width, b.width);
        expect(a.left, b.left);
        for (final (label, button) in [
          (l10n.cancel, a),
          (l10n.restoreMountConfirmOverride, b),
        ]) {
          final text = find.text(label);
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          final rect = tester.getRect(text);
          expect(
            button.inflate(0.5).contains(rect.topLeft) &&
                button.inflate(0.5).contains(rect.bottomRight),
            isTrue,
            reason: '$label is inside its button, not cut',
          );
        }
      });
    }

    testWidgets('wide with normal text keeps the buttons in a row', (
      tester,
    ) async {
      await host(
        tester,
        () => RestoreMountConfirmSheet(plan: _overridePlan()),
        size: const Size(900, 1000),
      );
      final l10n = currentAppLocalizations;
      final a = tester.getRect(find.widgetWithText(TextButton, l10n.cancel));
      final b = tester.getRect(
        find.widgetWithText(FilledButton, l10n.restoreMountConfirmOverride),
      );
      expect(a.center.dy, closeTo(b.center.dy, 1));
      expect(b.left, greaterThan(a.right));
    });

    testWidgets('an empty plan says no relation changes', (tester) async {
      await pushSheet(
        tester,
        const RestoreMountConfirmSheet(
          plan: RestoreMountPlan(isOverride: true, mountsCarried: true),
        ),
      );
      expect(
        find.text(currentAppLocalizations.restoreMountNoChanges),
        findsOne,
      );
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('1000 rows at 393 pt and 200% text lay out without '
        'overflow', (tester) async {
      await host(
        tester,
        () => RestoreMountConfirmSheet(plan: _bigPlan(1000)),
        size: const Size(393, 852),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      // At 200% the header alone is taller than the window; the heading is
      // built once scrolled to.
      final heading = find.text(
        currentAppLocalizations.restoreMountRemoveSection('1000'),
      );
      await tester.scrollUntilVisible(
        heading,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(heading, findsOne, reason: 'the group shows its real total');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('result', () {
    test('the title follows the evidence table', () {
      const pending = RestoreEvidence(
        writeStarted: true,
        committed: true,
        pendingSteps: [RestoreStep.mitm],
        skippedSteps: [],
        pendingChecks: [],
      );
      expect(pending.kind, RestoreResultKind.committedLocked);
      expect(
        const RestoreEvidence(
          writeStarted: true,
          committed: true,
          pendingChecks: [],
        ).kind,
        RestoreResultKind.committedLocked,
        reason: 'missing pendingItems/skippedSteps is not success',
      );
      expect(
        const RestoreEvidence(
          writeStarted: true,
          committed: true,
          foreignWrites: true,
          pendingSteps: [],
          skippedSteps: [RestoreStep.settings],
        ).kind,
        RestoreResultKind.foreignSkipped,
      );
      expect(
        const RestoreEvidence.committed(pendingChecks: []).kind,
        RestoreResultKind.completed,
      );
      expect(
        const RestoreEvidence(
          writeStarted: true,
          committed: true,
          pendingSteps: [],
          skippedSteps: [],
        ).kind,
        RestoreResultKind.needsCheck,
        reason: 'unknown checks are not success either',
      );
      expect(
        const RestoreEvidence(committed: false).kind,
        RestoreResultKind.notStarted,
      );
      expect(
        const RestoreEvidence(
          writeStarted: true,
          committed: false,
          rollbackVerified: true,
        ).kind,
        RestoreResultKind.rolledBack,
      );
      expect(
        const RestoreEvidence(writeStarted: true, committed: false).kind,
        RestoreResultKind.rollbackUnverified,
      );
      expect(
        const RestoreEvidence(writeStarted: true).kind,
        RestoreResultKind.rollbackUnverified,
      );
      expect(
        const RestoreEvidence(refusedForPending: true).kind,
        RestoreResultKind.refusedPending,
      );
    });

    test('the two approved titles are used verbatim', () {
      final zh = lookupAppLocalizations(const Locale('zh'));
      expect(
        restoreResultTitle(RestoreResultKind.committedLocked, zh),
        '数据已恢复，后续处理尚未完成。',
      );
      expect(
        restoreResultTitle(RestoreResultKind.foreignSkipped, zh),
        '恢复后数据又被修改过，为保留这些修改，已跳过部分恢复步骤。',
        reason: 'it no longer blames an older version that may not exist',
      );
    });

    testWidgets('a locked result lists the real items and offers no '
        'continue without the capability', (tester) async {
      await host(
        tester,
        () => RestoreResultView(
          evidence: const RestoreEvidence(
            writeStarted: true,
            committed: true,
            pendingSteps: [RestoreStep.mitm],
            skippedSteps: [],
            pendingChecks: [RestoreMountProfile(1, label: '晨光配置')],
          ),
          onOpenProfiles: () {},
          onContinue: () async => const RestoreEvidence(),
        ),
        locale: const Locale('zh'),
        size: const Size(860, 760),
      );
      final l10n = currentAppLocalizations;
      expect(find.text('数据已恢复，后续处理尚未完成。'), findsOne);
      expect(find.text(l10n.restoreContinue), findsNothing);
      expect(find.text(l10n.restoreBlockedViewProfiles), findsOne);
      await shoot(tester, 'restore-result-locked-zh');
    });

    testWidgets('steps and profiles are two groups with their own counts; '
        'a step never reads as a profile', (tester) async {
      await host(
        tester,
        () => const RestoreResultView(
          evidence: RestoreEvidence(
            writeStarted: true,
            committed: true,
            pendingSteps: [RestoreStep.settings, RestoreStep.mitm],
            skippedSteps: [RestoreStep.caches],
            pendingChecks: [RestoreMountProfile(1, label: '晨光配置')],
          ),
        ),
        locale: const Locale('zh'),
        size: const Size(860, 900),
      );
      expect(find.text('后续步骤 · 2'), findsOne);
      expect(find.text('待检查配置 · 1'), findsOne);
      expect(find.text('已跳过的步骤 · 1'), findsOne);
      expect(find.text('重新检查 MITM 模块'), findsOne);
      expect(find.text('应用备份中的设置'), findsOne);
      expect(find.text('清理旧的规则缓存'), findsOne);
      expect(find.text('所属配置：晨光配置'), findsOne);
      expect(find.textContaining('所属配置：重新检查'), findsNothing);
      expect(find.textContaining('所属配置：应用'), findsNothing);
      expect(find.textContaining('所属配置：清理'), findsNothing);
      expect(find.text('当前仍有 3 项未完成。不要再次发起恢复。'), findsOne);
      expect(find.text('未完成'), findsNWidgets(2));
      expect(find.text('已跳过'), findsOne);
      expect(find.text('待检查'), findsOne);
    });

    testWidgets('a partial failure lists the profiles still to check, and '
        'says so when they are unknown', (tester) async {
      await host(
        tester,
        () => RestoreResultView(
          evidence: restorePartialEvidence(
            const RestorePartialException(
              'x',
              steps: [RestoreStep.mitm],
              pendingChecks: [RestoreMountProfile(7, label: '晨光配置')],
            ),
          ),
        ),
        locale: const Locale('zh'),
        size: const Size(860, 760),
      );
      expect(find.text('数据已恢复，后续处理尚未完成。'), findsOne);
      expect(find.text('后续步骤 · 1'), findsOne);
      expect(find.text('待检查配置 · 1'), findsOne);
      expect(find.text('所属配置：晨光配置'), findsOne);
      expect(find.text('无法读取待处理项，暂不能确认后续处理是否完成。'), findsNothing);
      await shoot(tester, 'restore-result-partial-zh');

      await host(
        tester,
        () => RestoreResultView(
          evidence: restorePartialEvidence(
            const RestorePartialException('x', steps: [RestoreStep.mitm]),
          ),
        ),
        locale: const Locale('zh'),
        size: const Size(860, 760),
      );
      expect(find.text('无法读取待处理项，暂不能确认后续处理是否完成。'), findsOne);
      expect(find.textContaining('待检查配置'), findsNothing);
      expect(
        find.text('已确认：本次恢复的数据已写入数据库。'),
        findsOne,
        reason: 'the known commit state is said on its own',
      );
      expect(
        find.textContaining('当前仍有'),
        findsNothing,
        reason: 'a partly known list is never given a total',
      );
      expect(find.text('恢复已完成。'), findsNothing);
      expect(find.textContaining('· 0'), findsNothing);
    });

    testWidgets('without a verified commit the commit line never shows', (
      tester,
    ) async {
      for (final evidence in const [
        RestoreEvidence(writeStarted: true),
        RestoreEvidence(writeStarted: true, committed: false),
      ]) {
        await host(
          tester,
          () => RestoreResultView(evidence: evidence),
          locale: const Locale('zh'),
          size: const Size(860, 600),
        );
        expect(find.textContaining('已写入数据库'), findsNothing);
        expect(find.textContaining('无法读取待处理项'), findsNothing);
      }
    });

    testWidgets('nothing known at all still never reads as zero items or '
        'completed', (tester) async {
      const evidence = RestoreEvidence(writeStarted: true, committed: true);
      expect(evidence.kind, isNot(RestoreResultKind.completed));
      await host(
        tester,
        () => const RestoreResultView(evidence: evidence),
        locale: const Locale('zh'),
        size: const Size(860, 600),
      );
      expect(find.text('数据已恢复，后续处理尚未完成。'), findsOne);
      final known = find.text('已确认：本次恢复的数据已写入数据库。');
      final unknown = find.text('无法读取待处理项，暂不能确认后续处理是否完成。');
      expect(known, findsOne);
      expect(unknown, findsOne);
      expect(
        tester.getTopLeft(known).dy,
        lessThan(tester.getTopLeft(unknown).dy),
        reason: 'the verified commit first, the unknown right after',
      );
      expect(find.text('恢复已完成。'), findsNothing);
      expect(find.textContaining('· 0'), findsNothing);
      expect(find.textContaining('0 项'), findsNothing);
    });

    test('the data-changed title needs a change seen and steps really '
        'skipped', () {
      RestoreEvidence foreign(List<RestoreStep>? skipped) => RestoreEvidence(
        writeStarted: true,
        committed: true,
        foreignWrites: true,
        pendingSteps: const [],
        skippedSteps: skipped,
        pendingChecks: const [],
      );
      expect(
        foreign([RestoreStep.settings]).kind,
        RestoreResultKind.foreignSkipped,
      );
      expect(foreign(const []).kind, RestoreResultKind.completed);
      expect(foreign(null).kind, RestoreResultKind.committedLocked);
    });

    testWidgets('the data-changed title is followed by the steps it '
        'skipped', (tester) async {
      await host(
        tester,
        () => const RestoreResultView(
          evidence: RestoreEvidence(
            writeStarted: true,
            committed: true,
            foreignWrites: true,
            pendingSteps: [RestoreStep.mitm],
            skippedSteps: [RestoreStep.settings],
            pendingChecks: [],
          ),
        ),
        locale: const Locale('zh'),
        size: const Size(860, 900),
      );
      final title = find.text('恢复后数据又被修改过，为保留这些修改，已跳过部分恢复步骤。');
      expect(title, findsOne);
      final skipped = find.text('已跳过的步骤 · 1');
      final steps = find.text('后续步骤 · 1');
      expect(
        tester.getTopLeft(skipped).dy,
        lessThan(tester.getTopLeft(steps).dy),
      );
      expect(find.text('应用备份中的设置'), findsOne);
    });

    RestoreEvidence partial({List<RestoreMountProfile> checks = const []}) =>
        RestoreEvidence(
          writeStarted: true,
          committed: true,
          pendingSteps: const [RestoreStep.mitm],
          skippedSteps: const [],
          pendingChecks: checks,
          canContinue: true,
        );

    testWidgets('continue shows what is known afterwards', (tester) async {
      var calls = 0;
      final done = Completer<RestoreEvidence>();
      await host(
        tester,
        () => RestoreResultView(
          evidence: partial(),
          onContinue: () {
            calls++;
            return done.future;
          },
        ),
        locale: const Locale('zh'),
        size: const Size(860, 760),
      );
      final l10n = currentAppLocalizations;
      await tester.tap(find.text(l10n.restoreContinue));
      await tester.pump();
      await tester.tap(find.text(l10n.restoreContinue));
      await tester.pump();
      expect(calls, 1, reason: 'a running continue cannot start twice');
      done.complete(
        const RestoreEvidence.committed(
          pendingChecks: [RestoreMountProfile(1, label: '晨光配置')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.restoreResultNeedsCheck), findsOne);
      expect(find.textContaining('后续步骤'), findsNothing);
      expect(find.text('待检查配置 · 1'), findsOne);
      expect(find.text(l10n.restoreContinue), findsNothing);
      expect(find.text(l10n.restoreContinueFailed), findsNothing);
    });

    testWidgets('a continue that fails or throws says so and can be tried '
        'again', (tester) async {
      var calls = 0;
      await host(
        tester,
        () => RestoreResultView(
          evidence: partial(),
          onContinue: () async {
            calls++;
            if (calls == 1) throw StateError('boom');
            return partial(checks: const [RestoreMountProfile(2, label: 'B')]);
          },
        ),
        locale: const Locale('zh'),
        size: const Size(860, 760),
      );
      final l10n = currentAppLocalizations;
      await tester.tap(find.text(l10n.restoreContinue));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.restoreContinueFailed), findsOne);
      expect(find.text('数据已恢复，后续处理尚未完成。'), findsOne);
      expect(find.text('后续步骤 · 1'), findsOne);
      await tester.tap(find.text(l10n.restoreContinue));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text(l10n.restoreContinueFailed), findsOne);
      expect(find.text('待检查配置 · 1'), findsOne);
      await shoot(tester, 'restore-result-continue-failed-zh');
    });
  });

  group('pending refusal', () {
    testWidgets('offers only an explicit check, which goes idle → checking → '
        'passed and cannot run twice', (tester) async {
      var calls = 0;
      await host(
        tester,
        () => RestorePendingRefusal(
          profiles: const [RestoreMountProfile(1, label: '晨光配置')],
          onCheck: () {
            calls++;
            return Future<RestoreRecheckOutcome>.delayed(
              const Duration(milliseconds: 100),
              () => (state: RestoreRecheckState.passed, failure: null),
            );
          },
        ),
        locale: const Locale('zh'),
        size: const Size(860, 560),
      );
      final l10n = currentAppLocalizations;
      expect(find.text(l10n.macHelperCheckAgain), findsOne);
      expect(find.text(l10n.restoreContinue), findsNothing);
      await shoot(tester, 'restore-pending-refusal-zh');
      await tester.tap(find.text(l10n.macHelperCheckAgain));
      await tester.pump();
      expect(find.text(l10n.restoreRecheckChecking), findsOne);
      await tester.tap(find.text(l10n.macHelperCheckAgain));
      await tester.pump();
      expect(calls, 1);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text(l10n.restoreRecheckPassed), findsOne);
    });

    testWidgets('a failed check shows its reason', (tester) async {
      await host(
        tester,
        () => RestorePendingRefusal(
          profiles: const [RestoreMountProfile(1)],
          onCheck: () async =>
              (state: RestoreRecheckState.failed, failure: 'Apply failed.'),
        ),
      );
      final l10n = currentAppLocalizations;
      expect(
        find.textContaining(l10n.restoreMountNameUnavailable('1')),
        findsWidgets,
        reason: 'a profile without a name is shown by its id, not guessed',
      );
      await tester.tap(find.text(l10n.macHelperCheckAgain));
      await tester.pumpAndSettle();
      expect(find.text(l10n.restoreRecheckFailed('Apply failed.')), findsOne);
    });
  });

  group('screenshots', () {
    testWidgets('confirm desktop zh', skip: !shots, (tester) async {
      await host(
        tester,
        () => RestoreMountConfirmSheet(
          plan: _mergePlan(),
          backupName: '示例备份 · 2026年11月18日 10:30',
          mitmModules: _mitm,
        ),
        locale: const Locale('zh'),
        size: const Size(860, 1240),
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'restore-confirm-desktop-zh');
    });

    testWidgets('confirm override zh', skip: !shots, (tester) async {
      await host(
        tester,
        () => RestoreMountConfirmSheet(
          plan: _overridePlan(),
          backupName: '示例备份 · 2026年11月18日 10:30',
        ),
        locale: const Locale('zh'),
        size: const Size(860, 1220),
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'restore-confirm-override-zh');
    });

    testWidgets('confirm old backup desktop zh', skip: !shots, (tester) async {
      await host(
        tester,
        () => RestoreMountConfirmSheet(plan: _legacyPlan()),
        locale: const Locale('zh'),
        size: const Size(860, 1000),
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'restore-confirm-legacy-zh');
    });

    testWidgets('confirm dark zh', skip: !shots, (tester) async {
      await host(
        tester,
        () => RestoreMountConfirmSheet(plan: _mergePlan(), mitmModules: _mitm),
        locale: const Locale('zh'),
        size: const Size(860, 1240),
        themeMode: ThemeMode.dark,
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'restore-confirm-dark-zh');
    });

    testWidgets('result locked dark zh', skip: !shots, (tester) async {
      await host(
        tester,
        () => RestoreResultView(
          evidence: const RestoreEvidence(
            writeStarted: true,
            committed: true,
            pendingSteps: [RestoreStep.settings, RestoreStep.mitm],
            skippedSteps: [],
            pendingChecks: [
              RestoreMountProfile(1, label: '晨光配置'),
              RestoreMountProfile(2, label: '远行配置'),
            ],
          ),
          onOpenProfiles: () {},
        ),
        locale: const Locale('zh'),
        size: const Size(860, 820),
        themeMode: ThemeMode.dark,
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'restore-result-locked-dark-zh');
    });

    testWidgets('result locked narrow zh 200%', skip: !shots, (tester) async {
      await host(
        tester,
        () => RestoreResultView(
          evidence: const RestoreEvidence(
            writeStarted: true,
            committed: true,
            pendingSteps: [RestoreStep.settings, RestoreStep.mitm],
            skippedSteps: [],
            pendingChecks: [
              RestoreMountProfile(1, label: '晨光配置'),
              RestoreMountProfile(2, label: '远行配置'),
            ],
          ),
          onOpenProfiles: () {},
        ),
        locale: const Locale('zh'),
        size: const Size(393, 1900),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'restore-result-locked-narrow-zh-200');
    });

    testWidgets('confirm desktop en', skip: !shots, (tester) async {
      await host(
        tester,
        () => RestoreMountConfirmSheet(plan: _mergePlan()),
        size: const Size(860, 1000),
      );
      await shoot(tester, 'restore-confirm-desktop-en');
    });

    testWidgets('confirm narrow zh', skip: !shots, (tester) async {
      await host(
        tester,
        () => RestoreMountConfirmSheet(plan: _legacyPlan()),
        locale: const Locale('zh'),
        size: const Size(393, 1280),
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'restore-confirm-narrow-zh');
    });

    testWidgets('confirm narrow zh 200%', skip: !shots, (tester) async {
      await host(
        tester,
        () => RestoreMountConfirmSheet(plan: _legacyPlan()),
        locale: const Locale('zh'),
        size: const Size(393, 1600),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'restore-confirm-narrow-zh-200');
    });

    testWidgets(
      'confirm narrow zh 200% scrolled to the actions',
      skip: !shots,
      (tester) async {
        await host(
          tester,
          () => RestoreMountConfirmSheet(
            plan: _mergePlan(),
            backupName: '示例备份 · 2026年11月18日 10:30',
            mitmModules: _mitm,
          ),
          locale: const Locale('zh'),
          size: const Size(393, 852),
          textScale: 2,
        );
        final scrollable = find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        // Lazy rows refine the extent as they are built: go to the end
        // until it holds.
        for (var i = 0; i < 20; i++) {
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          if (find.byType(Checkbox).evaluate().isNotEmpty &&
              position.pixels == position.maxScrollExtent) {
            break;
          }
        }
        expect(position.pixels, greaterThan(0));
        // The whole action area is on screen: checkbox and both buttons.
        final screen = Offset.zero & const Size(393, 852);
        for (final part in [
          find.byType(Checkbox),
          find.text('取消'),
          find.text('恢复并替换'),
        ]) {
          final rect = tester.getRect(part);
          expect(
            rect.top >= screen.top && rect.bottom <= screen.bottom,
            isTrue,
            reason: '$part at $rect',
          );
        }
        // The primary label is laid out whole, not cut.
        final label = tester.renderObject<RenderParagraph>(find.text('恢复并替换'));
        expect(label.didExceedMaxLines, isFalse);
        final text = tester.getRect(find.text('恢复并替换'));
        final button = tester.getRect(find.byType(FilledButton));
        expect(
          button.contains(text.topLeft) &&
              button.contains(text.bottomRight - const Offset(0.5, 0.5)),
          isTrue,
          reason: 'label $text inside button $button',
        );
        expect(tester.takeException(), isNull);
        await shoot(tester, 'restore-confirm-narrow-zh-200-bottom');
      },
    );

    testWidgets('confirm MITM only zh', skip: !shots, (tester) async {
      await host(
        tester,
        () => const RestoreMountConfirmSheet(
          plan: RestoreMountPlan(isOverride: false, mountsCarried: true),
          backupName: '示例备份 · 2026年11月18日 10:30',
          mitmModules: _mitm,
        ),
        locale: const Locale('zh'),
        size: const Size(860, 640),
      );
      await shoot(tester, 'restore-confirm-mitm-only-zh');
    });

    testWidgets('confirm MITM only override zh', skip: !shots, (tester) async {
      await host(
        tester,
        () => const RestoreMountConfirmSheet(
          plan: RestoreMountPlan(isOverride: true, mountsCarried: true),
          backupName: '示例备份 · 2026年11月18日 10:30',
          mitmModules: _mitm,
        ),
        locale: const Locale('zh'),
        size: const Size(860, 760),
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'restore-confirm-override-mitm-only-zh');
    });

    testWidgets('confirm empty zh', skip: !shots, (tester) async {
      await host(
        tester,
        () => const RestoreMountConfirmSheet(
          plan: RestoreMountPlan(isOverride: true, mountsCarried: true),
        ),
        locale: const Locale('zh'),
        size: const Size(860, 640),
      );
      await shoot(tester, 'restore-confirm-empty-zh');
    });

    testWidgets('result foreign zh', skip: !shots, (tester) async {
      await host(
        tester,
        () => RestoreResultView(
          evidence: const RestoreEvidence(
            writeStarted: true,
            committed: true,
            foreignWrites: true,
            pendingSteps: [],
            skippedSteps: [RestoreStep.settings, RestoreStep.mitm],
          ),
          onOpenProfiles: () {},
        ),
        locale: const Locale('zh'),
        size: const Size(860, 700),
      );
      await shoot(tester, 'restore-result-foreign-zh');
    });

    testWidgets('result needs check zh', skip: !shots, (tester) async {
      await host(
        tester,
        () => RestoreResultView(
          evidence: const RestoreEvidence.committed(
            pendingChecks: [RestoreMountProfile(1, label: '晨光配置')],
          ),
          onOpenProfiles: () {},
        ),
        locale: const Locale('zh'),
        size: const Size(860, 600),
      );
      await shoot(tester, 'restore-result-needs-check-zh');
    });
  });
}
