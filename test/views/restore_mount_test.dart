// Widget tests for the restore mount confirmation, refusal and result views.
// Screenshots are off by default:
//   RESTORE_MOUNT_SHOTS=/private/tmp/flash-restore-mount/shots flutter test \
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
              themeMode: ThemeMode.light,
              child: MediaQuery.withClampedTextScaling(
                minScaleFactor: textScale,
                maxScaleFactor: textScale,
                child: ColoredBox(
                  color: const Color(0xFFE8E9ED),
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
      expect(rows[RestoreMountGroup.replace]!.single.owner.label, '晨光配置');
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
        '检测到旧版本修改了数据，已跳过部分恢复步骤。',
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
          onContinue: () async {},
        ),
        locale: const Locale('zh'),
        size: const Size(860, 760),
      );
      final l10n = currentAppLocalizations;
      expect(find.text('数据已恢复，后续处理尚未完成。'), findsOne);
      expect(find.text(l10n.restoreResultPendingSection('2')), findsOne);
      expect(find.text(l10n.restoreContinue), findsNothing);
      expect(find.text(l10n.restoreBlockedViewProfiles), findsOne);
      await shoot(tester, 'restore-result-locked-zh');
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
        ),
        locale: const Locale('zh'),
        size: const Size(860, 1000),
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'restore-confirm-desktop-zh');
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

    testWidgets('confirm empty zh', skip: !shots, (tester) async {
      await host(
        tester,
        () => const RestoreMountConfirmSheet(
          plan: RestoreMountPlan(isOverride: true, mountsCarried: true),
        ),
        locale: const Locale('zh'),
        size: const Size(860, 520),
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
