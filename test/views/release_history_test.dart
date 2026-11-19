import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:dio/dio.dart';
import 'package:fl_clash/common/request.dart';
import 'package:fl_clash/common/app_update.dart';
import 'package:fl_clash/common/release_history.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/ui.dart' show TextButton;
import 'package:fl_clash/views/about.dart';
import 'package:fl_clash/views/release_history.dart';
import 'package:fl_clash/widgets/release_notes.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/test_app.dart';
import '../helpers/preferences.dart';

PublishedRelease release(String tag, int day, String body) => PublishedRelease(
  tag: tag,
  published: DateTime.utc(2026, 11, day),
  body: body,
);
ReleaseHistory history(
  List<PublishedRelease> releases, {
  bool truncated = false,
}) => ReleaseHistory(
  releases,
  fetchedAt: DateTime.utc(2026, 11, 20),
  truncated: truncated,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late ReleaseHistoryStore store;
  late ReleaseHistory result;
  late bool fail;

  setUp(() async {
    await mockPreferences();
    globalState.packageInfo = PackageInfo(
      appName: 'Flash',
      packageName: 'test.flash',
      version: '1.0.0',
      buildNumber: '2026111902',
    );
    container = ProviderContainer();
    globalState.container = container;
    result = history([
      release('v0.9.0', 17, 'Historical body'),
      release('v1.1.0', 20, 'Newest body'),
      release('v1.0.0', 19, 'Installed body'),
    ]);
    fail = false;
    store = ReleaseHistoryStore(
      fetch: () async {
        if (fail) throw StateError('offline');
        return result;
      },
      readCache: () async => null,
      writeCache: (_) async {},
    );
  });
  tearDown(() {
    store.dispose();
    container.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    double scale = 1,
    Size size = const Size(1000, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          locale: const Locale('en'),
          homeBuilder: (child) => MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: child,
          ),
          child: ReleaseHistoryView(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'descending dates, installed expanded and history toggles independently',
    (tester) async {
      await pump(tester);
      expect(
        tester.getTopLeft(find.text('1.1.0')).dy,
        lessThan(tester.getTopLeft(find.text('1.0.0 (2026111902)')).dy),
      );
      expect(
        find.textContaining('Installed body', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Newest body', findRichText: true),
        findsNothing,
      );
      await tester.tap(find.text('1.1.0'));
      await tester.pump();
      await tester.tap(find.text('0.9.0'));
      await tester.pump();
      expect(
        find.textContaining('Newest body', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Historical body', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Installed body', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.text('1.0.0 (2026111902)'));
      await tester.pump();
      expect(
        find.textContaining('Installed body', findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining('Newest body', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets('exact build wins over a same-version historical tag', (
    tester,
  ) async {
    result = history([
      release('v1.0.0', 18, 'Old build'),
      release('v1.0.0+2026111902', 19, 'Exact build'),
    ]);
    await pump(tester);
    expect(find.text('Current version'), findsOneWidget);
    expect(
      find.textContaining('Exact build', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Old build', findRichText: true), findsNothing);
  });

  testWidgets('missing installed never marks newest current', (tester) async {
    result = history([release('v1.1.0', 20, 'Newest body')]);
    await pump(tester);
    expect(find.text('Installed version 1.0.0 (2026111902)'), findsOneWidget);
    expect(
      find.text('The installed version is not in the loaded release history.'),
      findsOneWidget,
    );
    expect(find.text('Current version'), findsNothing);
    expect(find.byType(ReleaseNotes), findsNothing);
  });

  testWidgets(
    'available version is separate and deduplicated without starting update',
    (tester) async {
      container
          .read(availableUpdateStateProvider.notifier)
          .value = const UpdateAvailable({
        'tag_name': 'v1.1.0',
        'body': 'Available body',
      });
      await pump(tester);
      expect(find.text('New version 1.1.0'), findsOneWidget);
      expect(find.text('1.1.0'), findsNothing);
      expect(
        find.textContaining('Available body', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Installed body', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Current version'), findsOneWidget);
      expect(container.read(updateInstallBusyProvider), isFalse);
    },
  );

  testWidgets(
    'successful empty body and empty history are not fetch failures',
    (tester) async {
      result = history([release('v1.0.0', 19, '')]);
      await pump(tester);
      expect(
        find.textContaining(
          'No release notes were provided',
          findRichText: true,
        ),
        findsOneWidget,
      );
      result = history([]);
      await store.refresh();
      await tester.pump();
      expect(find.text('No published releases found.'), findsOneWidget);
      expect(find.textContaining('Unable to fetch'), findsNothing);
      expect(find.text('Current version'), findsNothing);
    },
  );

  testWidgets(
    'refresh failure retains expanded notes, announces stale cache and retries',
    (tester) async {
      await pump(tester);
      fail = true;
      await store.refresh();
      await tester.pump();
      expect(
        find.textContaining('Installed body', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('Unable to fetch release history · Retry'),
        findsOneWidget,
      );
      expect(find.textContaining('Cached release history'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Unable to fetch release history · Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cached release history'), findsNothing);
    },
  );

  testWidgets(
    'first failure is retryable and bounded history discloses limit',
    (tester) async {
      fail = true;
      await pump(tester);
      expect(
        find.text('Unable to fetch release history · Retry'),
        findsOneWidget,
      );
      expect(find.text('Current version'), findsNothing);
      fail = false;
      result = history([], truncated: true);
      await tester.tap(find.text('Unable to fetch release history · Retry'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Only loaded releases are shown · View the complete release list',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('2x narrow layout and expanded state have one accessible action', (
    tester,
  ) async {
    result = history([
      release(
        'v1.0.0',
        19,
        'A paragraph.\n\n- A **bold** change\n- [Details](https://example.com/notes)',
      ),
    ]);
    final semantics = tester.ensureSemantics();
    await pump(tester, scale: 2, size: const Size(390, 1000));
    expect(tester.takeException(), isNull);
    final node = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label?.startsWith('Version 1.0.0 (') ?? false),
      ),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(node.getSemanticsData().flagsCollection.isExpanded, Tristate.isTrue);
    expect(node.label, contains('Current version'));
    expect(node.label, contains('Expanded'));
    expect(find.textContaining('**', findRichText: true), findsNothing);
    expect(find.text('Details'), findsOneWidget);
    final link = find.ancestor(
      of: find.text('Details'),
      matching: find.byType(TextButton),
    );
    expect(tester.getSize(link), tester.getSize(find.text('Details')));
    await tester.ensureVisible(find.text('Details'));
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(
      find.text('https://example.com/notes', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets(
    'historical prerelease labels do not infer the installed channel',
    (tester) async {
      globalState.packageInfo = PackageInfo(
        appName: 'Flash',
        packageName: 'test.flash',
        version: '1.1.0-beta.1',
        buildNumber: '42',
      );
      result = history([
        PublishedRelease(
          tag: 'v1.1.0-beta.1',
          published: DateTime.utc(2026, 11, 20),
          prerelease: true,
          body: 'Installed beta notes',
        ),
        PublishedRelease(
          tag: 'v1.0.0',
          published: DateTime.utc(2026, 11, 19),
          prerelease: false,
        ),
        PublishedRelease(
          tag: 'v0.9.0-beta.unknown',
          published: DateTime.utc(2026, 11, 18),
        ),
      ]);
      await pump(tester);
      expect(find.text('Beta'), findsNothing);
      expect(find.text('Current version'), findsOneWidget);
      expect(
        find.textContaining('Installed beta notes', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('1.0.0'), findsOneWidget);
      expect(find.text('0.9.0-beta.unknown'), findsOneWidget);
    },
  );

  testWidgets('historical beta label sits beside version rather than date', (
    tester,
  ) async {
    result = history([
      PublishedRelease(
        tag: 'v0.9.0-beta.1',
        published: DateTime.utc(2026, 11, 18),
        prerelease: true,
      ),
    ]);
    await pump(tester);
    final beta = tester.getRect(find.text('Beta'));
    final version = tester.getRect(find.text('0.9.0-beta.1'));
    final date = tester.getRect(find.text('2026-11-18'));
    expect(beta.center.dy, closeTo(version.center.dy, 0.1));
    expect(beta.left, greaterThan(version.right));
    expect(beta.bottom, lessThan(date.top));
  });

  testWidgets('long version wraps at 2x without truncation', (tester) async {
    result = history([
      release('v1.0.0', 19, ''),
      release('v0.9.15-mitm.12+202611190123456789', 18, ''),
    ]);
    await pump(tester, scale: 2, size: const Size(390, 1000));
    final text = tester.widget<Text>(
      find.text('0.9.15-mitm.12 (202611190123456789)'),
    );
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'About navigation is at least 44 dp and opens separate shared-header page',
    (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TestApp(locale: Locale('en'), child: AboutView()),
        ),
      );
      await tester.pumpAndSettle();
      final entry = find.byKey(const ValueKey('release-history-entry'));
      expect(tester.getSize(entry).height, greaterThanOrEqualTo(44));
      expect(find.text('1.0.0 (2026111902)'), findsOneWidget);
      final pending = Completer<void>();
      final interceptor = InterceptorsWrapper(
        onRequest: (options, handler) async {
          await pending.future;
          handler.resolve(
            Response(
              requestOptions: options,
              data: <dynamic>[],
              statusCode: 200,
            ),
          );
        },
      );
      request.dio.interceptors.add(interceptor);
      addTearDown(() => request.dio.interceptors.remove(interceptor));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(ReleaseHistoryView), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Loading release history',
        ),
        findsOneWidget,
      );
      final title = find.text('Release history').last;
      final installed = find.text('Installed version 1.0.0 (2026111902)');
      expect(
        tester.getTopLeft(installed).dy,
        greaterThan(tester.getBottomLeft(title).dy),
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pump(const Duration(seconds: 1));
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ReleaseHistoryView), findsNothing);
      expect(find.byType(AboutView), findsOneWidget);
    },
  );
}
