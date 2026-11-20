// The status card's type and quality tags open the IP detail of the exit
// shown, without switching the exit or asking anything.
import 'dart:ui' show Tristate;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/common/service_probe.dart'
    show directOutbound, routedOutbound;
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/ipx_report.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/dashboard/layout.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/views/dashboard/widgets/current_outbound.dart';
import 'package:fl_clash/views/dashboard/widgets/ip_detail_tag.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/prism_ui.dart';
import 'package:prism_ui/shapes/shapes.dart';

import '../../helpers/host_scaffold.dart';
import '../../helpers/test_app.dart';

const _ip = '203.0.113.9';
const _localIp = '58.152.33.18';

const _profile = Profile(id: 1, autoUpdateDuration: Duration.zero);

const _report = IpxReport(
  ip: _ip,
  score: 35,
  type: IpxIpType.hosting,
  nativity: IpxNativity.native,
  countryCode: 'DE',
  city: 'Brandenburg',
  organization: 'TORSERVERS-NET',
);

const _localReport = IpxReport(
  ip: _localIp,
  score: 88,
  type: IpxIpType.residential,
  nativity: IpxNativity.native,
  countryCode: 'HK',
  city: 'Hong Kong',
  organization: 'HKBN',
);

const _stamp = RouteStamp(
  coreEpoch: 1,
  routeVersion: 1,
  hostEpoch: 1,
  proxied: true,
);

const _liveRoute = RouteState(
  coreEpoch: 1,
  routeVersion: 1,
  hostEpoch: 1,
  proxied: true,
  synced: true,
  live: true,
);

ProbeEntry<IpInfo> _fresh(String ip, String country) => ProbeEntry(
  phase: ProbePhase.fresh,
  value: IpInfo(ip: ip, countryCode: country),
  stamp: _stamp,
);

/// Every address lookup the card or the detail asks for.
class _Ips extends OutboundIpProbe {
  final refreshed = <String>[];

  @override
  RoutedProbeState<String, IpInfo> build() => RoutedProbeState({
    routedOutbound: _fresh(_ip, 'GB'),
    directOutbound: _fresh(_localIp, 'HK'),
  });

  @override
  void watch(String target) {}

  @override
  void unwatch(String target) {}

  @override
  void refresh(Iterable<String> targets) => refreshed.addAll(targets);
}

/// An ipx.al lookup that has answered; every build, reload and retry is
/// counted.
class _Ipx extends IpxLookup {
  _Ipx(this.answer);

  final IpxLookupState answer;
  static final built = <String>[];
  static var reloads = 0;
  static var retries = 0;

  @override
  IpxLookupState build(String ip) {
    built.add(ip);
    return answer;
  }

  @override
  void reload() => reloads++;

  @override
  void retry() => retries++;
}

class _Running extends RunTime {
  @override
  int? build() => 1000;
}

/// The network ipx.al is reached over: every request is counted.
class _Fetch {
  final urls = <String>[];

  Future<IpxAnswer?> call(
    String url, {
    required Duration timeout,
    int? maxBody,
  }) async {
    urls.add(url);
    return null;
  }
}

class _Spy {
  final ips = _Ips();
  final fetch = _Fetch();

  /// The IP quality sources, asked by address.
  final quality = <String>[];

  int get queries =>
      ips.refreshed.length +
      fetch.urls.length +
      quality.length +
      _Ipx.built.length +
      _Ipx.reloads +
      _Ipx.retries;

  @override
  String toString() =>
      'refreshed ${ips.refreshed} fetch ${fetch.urls} quality $quality '
      'ipx built ${_Ipx.built} reloads ${_Ipx.reloads} retries ${_Ipx.retries}';
}

/// Esc goes back as it does in the app, where HotKeyManager binds it above
/// the navigator.
Widget _escapeBack(Widget child) => Shortcuts(
  shortcuts: const {
    SingleActivator(LogicalKeyboardKey.escape): EscapeBackIntent(),
  },
  child: Actions(
    actions: {
      EscapeBackIntent: CallbackAction<EscapeBackIntent>(
        onInvoke: (_) => globalState.navigatorKey.currentState?.maybePop(),
      ),
    },
    child: child,
  ),
);

Widget _app(
  _Spy spy, {
  bool localCached = false,
  bool hideIp = false,
  DashboardDensity density = DashboardDensity.standard,
  // Wide enough for both tags in the test font, which is wider than any
  // the app uses.
  double width = 780,
  double textScale = 1,
  Locale locale = const Locale('en'),
}) {
  return _escapeBack(
    TestApp(
      locale: locale,
      overrides: [
        if (hideIp) appSettingProvider.overrideWith(_HideIp.new),
        profilesProvider.overrideWithValue(const [_profile]),
        suspendProvider.overrideWithValue(false),
        runTimeProvider.overrideWith(_Running.new),
        routeTrackerProvider.overrideWithBuild((_, _) => _liveRoute),
        outboundIpProbeProvider.overrideWith(() => spy.ips),
        ipxFetchProvider.overrideWithValue(spy.fetch.call),
        ipQualityProvider.overrideWith((_, ip) {
          spy.quality.add(ip);
          return Future.any(const []);
        }),
        ipxLookupProvider(_ip).overrideWith(
          () =>
              _Ipx(const IpxLookupState(phase: IpxPhase.done, report: _report)),
        ),
        if (localCached)
          ipxLookupProvider(_localIp).overrideWith(
            () => _Ipx(
              const IpxLookupState(phase: IpxPhase.done, report: _localReport),
            ),
          ),
      ],
      child: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: HostScaffold(
          body: SizedBox(
            width: width,
            child: DashboardDensityScope(
              density: density,
              scale: 1,
              child: const CurrentOutboundCard(),
            ),
          ),
        ),
      ),
    ),
  );
}

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _tag(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(IpDetailTag));

Finder _ipRegion(String ip) =>
    find.ancestor(of: find.text(ip), matching: find.byType(PressRegion));

Finder _badge() => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) =>
        widget is ShapeBadge && widget.shape == MaterialShapes.clover4Leaf,
  ),
  matching: find.byType(PressRegion),
);

Finder _tagRegion(String label) =>
    find.descendant(of: _tag(label), matching: find.byType(PressRegion));

/// The detail sheet's page, whatever it shows.
Finder _detail(String title) => find.descendant(
  of: find.byType(NestedPagedSheet),
  matching: find.text(title),
);

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CurrentOutboundCard)));

/// The card shows the proxy exit, nothing switched.
void _expectProxyShown() {
  expect(
    find.descendant(
      of: find.byType(CurrentOutboundCard),
      matching: find.text(_ip),
    ),
    findsOneWidget,
  );
  expect(find.text('Local exit'), findsNothing);
}

void main() {
  setUp(() {
    mitmFeature = true;
    _Ipx.built.clear();
    _Ipx.reloads = 0;
    _Ipx.retries = 0;
    addTearDown(() => mitmFeature = false);
  });

  for (final label in ['Data center', 'Quality Poor']) {
    testWidgets('the "$label" tag opens the shown exit\'s detail, switching '
        'and asking nothing, then or later', (tester) async {
      _tallView(tester);
      final spy = _Spy();
      await tester.pumpWidget(_app(spy));
      await _settle(tester);
      final before = spy.queries;
      final ipxBefore = List.of(_Ipx.built);

      await tester.tap(find.text(label));
      await _settle(tester);

      // The exit's own detail, from what is already known.
      expect(_detail('Exit IP'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NestedPagedSheet),
          matching: find.text(_ip),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(NestedPagedSheet),
          matching: find.text('Data center'),
        ),
        findsOneWidget,
      );
      expect(find.text('Not queried yet'), findsNothing);
      // The type and quality explained.
      expect(find.textContaining('Type: '), findsOneWidget);
      expect(find.textContaining('Quality: '), findsOneWidget);
      expect(spy.queries, before, reason: 'asked on opening: $spy');
      expect(_Ipx.built, ipxBefore);
      expect(spy.ips.refreshed, isEmpty);
      expect(spy.quality, isEmpty);
      expect(_containerOf(tester).exists(ipQualityProvider(_ip)), isFalse);

      // Nothing put off for later either.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(minutes: 1));
      }
      expect(spy.queries, before, reason: 'asked after a delay');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(find.byType(NestedPagedSheet), findsNothing);
      _expectProxyShown();
      expect(spy.queries, before);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('both tags open the same address, the one shown at the tap', (
    tester,
  ) async {
    _tallView(tester);
    final spy = _Spy();
    // On a narrow card every tag shows: the test font is too wide for
    // the local exit's three chips to share the desktop card's one line.
    await tester.pumpWidget(
      _app(
        spy,
        localCached: true,
        density: DashboardDensity.mobile,
        width: 380,
      ),
    );
    await _settle(tester);
    // The local exit's report was looked up before, from its badge.
    _containerOf(tester).read(ipxLookupProvider(_localIp));
    await tester.tap(find.text(_ip));
    await _settle(tester);
    expect(find.text('Local exit'), findsOneWidget);
    final before = spy.queries;

    for (final label in ['Residential', 'Quality Excellent']) {
      await tester.tap(find.text(label));
      await _settle(tester);
      expect(_detail('Local public IP'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NestedPagedSheet),
          matching: find.text(_localIp),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(NestedPagedSheet),
          matching: find.text(_ip),
        ),
        findsNothing,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      // Still on the local exit.
      expect(find.text('Local exit'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(CurrentOutboundCard),
          matching: find.text(_localIp),
        ),
        findsOneWidget,
      );
    }
    expect(spy.queries, before);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an exit never looked up opens as not yet queried, and stays '
      'so', (tester) async {
    _tallView(tester);
    final spy = _Spy();
    await tester.pumpWidget(_app(spy));
    await _settle(tester);
    await tester.tap(find.text(_ip));
    await _settle(tester);
    // Switched to the local exit: nothing asked, nothing known.
    expect(find.text('Not looked up'), findsOneWidget);
    final before = spy.queries;
    final container = _containerOf(tester);
    expect(container.exists(ipxLookupProvider(_localIp)), isFalse);

    await tester.tap(find.text('Not looked up'));
    await _settle(tester);
    expect(_detail('Local public IP'), findsOneWidget);
    expect(find.text('Not queried yet'), findsWidgets);
    // What the badge fetches is said once, below the basic information,
    // not under the score: it names no quality source.
    final note = find.textContaining(
      'Select the country badge on the card to look up the exit IP',
    );
    expect(note, findsOneWidget);
    final noteTop = tester.getRect(note).top;
    final notQueried = find.text('Not queried yet');
    for (var i = 0; i < notQueried.evaluate().length; i++) {
      expect(noteTop, greaterThan(tester.getRect(notQueried.at(i)).bottom));
    }
    expect(
      tester.getRect(note).top,
      greaterThan(tester.getRect(find.text('Quality').last).bottom),
    );
    // Neither loading nor failed.
    expect(find.byType(SkeletonText), findsNothing);
    expect(find.text('Couldn’t get the report'), findsNothing);
    expect(find.text('Type lookup failed'), findsNothing);
    expect(container.exists(ipxLookupProvider(_localIp)), isFalse);
    expect(container.exists(ipQualityProvider(_localIp)), isFalse);
    expect(spy.queries, before);

    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(minutes: 1));
    }
    expect(find.text('Not queried yet'), findsWidgets);
    expect(container.exists(ipxLookupProvider(_localIp)), isFalse);
    expect(spy.queries, before);
    expect(spy.fetch.urls.where((url) => url.contains(_localIp)), isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.text('Local exit'), findsOneWidget);
    expect(spy.queries, before);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the address still switches and the badge still looks up', (
    tester,
  ) async {
    _tallView(tester);
    final spy = _Spy();
    await tester.pumpWidget(_app(spy, localCached: true));
    await _settle(tester);
    _containerOf(tester).read(ipxLookupProvider(_localIp));

    await tester.tap(find.text(_ip));
    await _settle(tester);
    expect(find.text(_localIp), findsOneWidget);
    expect(find.byType(NestedPagedSheet), findsNothing);
    await tester.tap(find.text(_localIp));
    await _settle(tester);
    _expectProxyShown();
    expect(spy.ips.refreshed, isEmpty);

    await tester.tap(_badge());
    await tester.pump();
    expect(spy.ips.refreshed, [routedOutbound]);
    expect(find.byType(NestedPagedSheet), findsNothing);
    _expectProxyShown();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final density in DashboardDensity.values) {
    testWidgets('each tag is a 44 target apart from the address, the badge '
        'and the other (${density.name})', (tester) async {
      final spy = _Spy();
      await tester.pumpWidget(
        _app(spy, density: density, width: density.isDesktop ? 780 : 380),
      );
      await _settle(tester);
      final type = tester.getRect(_tagRegion('Data center'));
      final quality = tester.getRect(_tagRegion('Quality Poor'));
      final ip = tester.getRect(_ipRegion(_ip));
      final badge = tester.getRect(_badge());
      for (final tag in [type, quality]) {
        expect(tag.width, greaterThanOrEqualTo(44));
        expect(tag.height, greaterThanOrEqualTo(44));
        expect(tag.overlaps(ip), isFalse);
        expect(tag.overlaps(badge), isFalse);
      }
      expect(type.overlaps(quality), isFalse);
      // 8 apart, across or, wrapped, down.
      if (quality.top == type.top) {
        expect(quality.left - type.right, greaterThanOrEqualTo(8));
      } else {
        expect(quality.top - type.bottom, greaterThanOrEqualTo(8));
      }
      // The chip sits where it did, right under the address.
      expect(
        tester.getRect(find.text('Data center')).top,
        lessThan(type.top + 14),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wraps whole tags on a narrow card at a large text size', (
    tester,
  ) async {
    final spy = _Spy();
    await tester.pumpWidget(
      _app(
        spy,
        density: DashboardDensity.mobile,
        width: 360,
        textScale: 1.6,
        locale: const Locale('zh'),
      ),
    );
    await _settle(tester);
    final type = tester.getRect(_tagRegion('机房'));
    final quality = tester.getRect(_tagRegion('质量 较差'));
    expect(type.overlaps(quality), isFalse);
    expect(type.height, greaterThanOrEqualTo(44));
    // Whole: no label is cut short.
    for (final label in ['机房', '质量 较差']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, isFalse);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('wrapped tags keep their 44 targets apart: the pills show '
      'about 24 between them, not the 8 between targets', (tester) async {
    final spy = _Spy();
    // Narrow enough for the two tags to take a line each.
    await tester.pumpWidget(
      _app(spy, density: DashboardDensity.mobile, width: 380),
    );
    await _settle(tester);
    final typeTarget = tester.getRect(_tagRegion('Data center'));
    final qualityTarget = tester.getRect(_tagRegion('Quality Poor'));
    expect(qualityTarget.top, greaterThan(typeTarget.top), reason: 'wraps');
    // The targets: 44 high, 8 apart, never overlapping.
    expect(typeTarget.height, IpDetailTagStyle.minHit);
    expect(qualityTarget.top - typeTarget.bottom, IpDetailTagStyle.gap);
    expect(typeTarget.overlaps(qualityTarget), isFalse);
    // The pills, 28 high on a narrow card, sit at the top of their
    // targets: 44 - 28 + 8 = 24 between them, as designed.
    Rect pill(String label) => tester.getRect(
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first,
    );
    final typePill = pill('Data center');
    final qualityPill = pill('Quality Poor');
    expect(typePill.height, 28);
    expect(qualityPill.top - typePill.bottom, 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reads as two buttons, each naming the address; the chevron '
      'is not read', (tester) async {
    final spy = _Spy();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(spy));
    await _settle(tester);
    for (final label in ['Data center', 'Quality Poor']) {
      final node = find.semantics.byLabel('$label, view IP details for $_ip');
      expect(node, findsOne);
      final data = node.evaluate().single.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, Tristate.isTrue);
      expect(data.hint, contains('does not run a lookup'));
      expect(data.hasAction(SemanticsAction.tap), isTrue);
    }
    // The chevron is drawn but adds nothing to read.
    expect(
      find.descendant(
        of: _tag('Data center'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is GlyphIcon && widget.glyph == AppGlyphs.chevronForward,
        ),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('the grade is read in the locale, from its own key, with no '
      'English in it', (tester) async {
    final spy = _Spy();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(spy, locale: const Locale('ru')));
    await _settle(tester);
    expect(find.text('Качество Плохое'), findsOneWidget);
    expect(
      find.semantics.byLabel('Качество Плохое, открыть сведения об IP $_ip'),
      findsOne,
    );
    expect(
      find.semantics.byLabel('Дата-центр, открыть сведения об IP $_ip'),
      findsOne,
    );
    expect(find.semantics.byLabel(RegExp('Poor|Quality')), findsNothing);
    semantics.dispose();
  });

  testWidgets('a screen reader opens the detail without a query', (
    tester,
  ) async {
    _tallView(tester);
    final spy = _Spy();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(spy));
    await _settle(tester);
    final before = spy.queries;
    tester.semantics.tap(
      find.semantics.byLabel('Quality Poor, view IP details for $_ip'),
    );
    await _settle(tester);
    expect(_detail('Exit IP'), findsOneWidget);
    expect(spy.queries, before);
    _expectProxyShown();
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a hidden address is not read out', (tester) async {
    final spy = _Spy();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(spy, hideIp: true));
    await _settle(tester);
    expect(find.semantics.byLabel('Data center, view IP details'), findsOne);
    expect(find.semantics.byLabel('Quality Poor, view IP details'), findsOne);
    // Nowhere in what a screen reader is told: label, value, hint or
    // tooltip, of the tags or of anything else on the card.
    final said = <String>[];
    void visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      said.addAll([data.label, data.value, data.hint, data.tooltip]);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    visit(
      tester
          .binding
          .renderViews
          .first
          .owner!
          .semanticsOwner!
          .rootSemanticsNode!,
    );
    expect(said.where((text) => text.contains(_ip)), isEmpty);
    expect(said.where((text) => text.contains(_localIp)), isEmpty);
    semantics.dispose();
  });

  testWidgets('the tags carry no tooltip, and hovering one shows none', (
    tester,
  ) async {
    final strategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = strategy);
    final spy = _Spy();
    await tester.pumpWidget(_app(spy));
    await _settle(tester);
    for (final label in ['Data center', 'Quality Poor']) {
      expect(
        find.ancestor(of: _tag(label), matching: find.byType(Tooltip)),
        findsNothing,
      );
      expect(
        find.descendant(of: _tag(label), matching: find.byType(Tooltip)),
        findsNothing,
      );
    }
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Data center')));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Press to view exit IP details'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('two tab stops; Enter and Space open; Esc closes back to the '
      'tag', (tester) async {
    _tallView(tester);
    final spy = _Spy();
    await tester.pumpWidget(_app(spy));
    await _settle(tester);
    final before = spy.queries;

    FocusNode focusOf(String label) => Focus.of(
      tester.element(
        find.descendant(of: _tagRegion(label), matching: find.byType(Align)),
      ),
    );
    final type = focusOf('Data center');
    final quality = focusOf('Quality Poor');
    expect(type, isNot(same(quality)));
    expect(type.skipTraversal, isFalse);
    expect(quality.skipTraversal, isFalse);

    type.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(quality.hasPrimaryFocus, isTrue);

    for (final (node, key) in [
      (quality, LogicalKeyboardKey.enter),
      (type, LogicalKeyboardKey.space),
    ]) {
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(key);
      await _settle(tester);
      expect(_detail('Exit IP'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(find.byType(NestedPagedSheet), findsNothing);
      expect(node.hasPrimaryFocus, isTrue, reason: 'focus back on the tag');
    }
    _expectProxyShown();
    expect(spy.queries, before);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a hover and a press tint the chip with the primary colour', (
    tester,
  ) async {
    final strategy = FocusManager.instance.highlightStrategy;
    // As on a Mac, where a pointer hovers.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = strategy);
    final spy = _Spy();
    await tester.pumpWidget(_app(spy));
    await _settle(tester);
    Color fill() {
      final decoration =
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.text('Data center'),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as ShapeDecoration;
      return decoration.color!;
    }

    final rest = fill();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Data center')));
    await tester.pump();
    final hovered = fill();
    expect(hovered, isNot(rest));
    expect(
      tester
          .widget<MouseRegion>(
            find
                .descendant(
                  of: _tagRegion('Data center'),
                  matching: find.byType(MouseRegion),
                )
                .first,
          )
          .cursor,
      SystemMouseCursors.click,
    );
    await mouse.down(tester.getCenter(find.text('Data center')));
    await tester.pump();
    expect(fill(), isNot(hovered));
    await mouse.cancel();
    await tester.pump();
  });

  testWidgets('without an address the tag is off, with no chevron, and says '
      'so', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const TestApp(
        locale: Locale('en'),
        child: HostScaffold(
          body: IpDetailTag(
            label: 'Data center',
            height: 24,
            semanticLabel: 'Data center, No IP to view yet',
            onOpen: null,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(GlyphIcon), findsNothing);
    final data = find.semantics
        .byLabel('Data center, No IP to view yet')
        .evaluate()
        .single
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isEnabled, Tristate.isFalse);
    semantics.dispose();
  });
}

class _HideIp extends AppSetting {
  @override
  AppSettingProps build() => const AppSettingProps(hideIp: true);
}
