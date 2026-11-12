import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/views/tailscale/state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/icons/icons.dart' show GlyphIcon, Glyphs;
import 'package:prism_ui/prism_ui.dart' show BuildContextExtension, Tooltip;

import '../helpers/preferences.dart';
import '../helpers/test_app.dart';
import 'tailscale_devices_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(mockPreferences);

  Future<void> pump(
    WidgetTester tester,
    TailscaleStatus status, {
    List<String>? copied,
  }) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('zh', 'CN'),
        child: DevicesHarness(status: status, copied: copied),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder rowOf(String name) => find
      .ancestor(of: find.text(name), matching: find.byType(MouseRegion))
      .first;

  Future<TestGesture> hover(WidgetTester tester, String name) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text(name)));
    await tester.pump();
    return gesture;
  }

  double opacityOf(WidgetTester tester, Finder button) => tester
      .widget<Opacity>(
        find.ancestor(of: button, matching: find.byType(Opacity)).first,
      )
      .opacity;

  Finder copyIn(String name, String tooltip) =>
      find.descendant(of: rowOf(name), matching: find.byTooltip(tooltip));

  testWidgets('no status or copy column; online and offline by dot and text '
      'color', (tester) async {
    await pump(tester, devicesStatus());

    expect(find.text('状态'), findsNothing);
    expect(find.text('在线'), findsNothing);
    expect(find.text('离线'), findsNothing);
    expect(find.text('Tailscale 地址'), findsOneWidget);

    final context = tester.element(find.byType(DevicesHarness));
    final variant = context.colorScheme.onSurfaceVariant;
    for (final text in ['office-hk', '100.72.40.9']) {
      expect(tester.widget<Text>(find.text(text)).style?.color, variant);
    }
    for (final text in ['studio-mac', '100.94.68.92']) {
      expect(tester.widget<Text>(find.text(text)).style?.color, isNot(variant));
    }
    final dots = tester
        .widgetList<Container>(find.byType(Container))
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .where((shape) => shape.shape is CircleBorder)
        .map((shape) => shape.color)
        .toList();
    expect(
      dots.where((c) => c == DashboardColors.of(context).online),
      hasLength(2),
    );
    expect(dots.where((c) => c == context.colorScheme.outline), hasLength(2));

    final semantics = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(RegExp(r'studio-mac，100\.94\.68\.92，在线')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'office-hk，100\.72\.40\.9，离线')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('the address shows its MagicDNS name under it, one line '
      'without one', (tester) async {
    await pump(tester, devicesStatus());

    final ip = tester.getRect(find.text('100.94.68.92'));
    final dns = tester.getRect(find.text('studio-mac.example.ts.net'));
    expect(dns.top, greaterThan(ip.bottom - 1));
    expect(dns.left, ip.left);
    final dnsText = tester.widget<Text>(find.text('studio-mac.example.ts.net'));
    expect(dnsText.style?.fontFamily, 'JetBrainsMono');
    expect(dnsText.maxLines, 1);
    expect(dnsText.overflow, TextOverflow.ellipsis);
    expect(
      find.ancestor(
        of: find.text('studio-mac.example.ts.net'),
        matching: find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == 'studio-mac.example.ts.net',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.getSize(rowOf('studio-mac')).height, 60);
    expect(find.textContaining('old-phone.'), findsNothing);
    expect(tester.getSize(rowOf('old-phone')).height, 52);
    expect(copyIn('old-phone', '复制名称'), findsNothing);
    expect(copyIn('old-phone', '复制地址'), findsOneWidget);
  });

  testWidgets('a tailnet without MagicDNS shows only the address', (
    tester,
  ) async {
    await pump(tester, devicesStatus(magicDns: false));

    expect(find.textContaining('.example.ts.net'), findsNothing);
    expect(find.byTooltip('复制名称'), findsNothing);
    expect(tester.getSize(rowOf('studio-mac')).height, 52);
  });

  testWidgets('copy icons show on hover and on focus, each beside its value', (
    tester,
  ) async {
    await pump(tester, devicesStatus());

    final address = copyIn('studio-mac', '复制地址');
    final name = copyIn('studio-mac', '复制名称');
    expect(opacityOf(tester, address), 0);
    expect(opacityOf(tester, name), 0);

    final gesture = await hover(tester, 'studio-mac');
    expect(opacityOf(tester, address), 1);
    expect(opacityOf(tester, name), 1);
    expect(opacityOf(tester, copyIn('nas-sg', '复制地址')), 0);

    final ip = tester.getRect(find.text('100.94.68.92'));
    final addressBox = tester.getRect(address);
    expect(addressBox.size, const Size.square(24));
    expect(addressBox.left - ip.right, moreOrLessEquals(6, epsilon: 0.5));
    final dns = tester.getRect(find.text('studio-mac.example.ts.net'));
    expect(
      tester.getRect(name).left - dns.right,
      moreOrLessEquals(6, epsilon: 0.5),
    );
    final glyph = tester.widget<GlyphIcon>(
      find.descendant(of: address, matching: find.byType(GlyphIcon)),
    );
    expect(glyph.size, 14);

    await gesture.moveTo(const Offset(990, 690));
    await tester.pump();
    expect(opacityOf(tester, address), 0);

    final focus = Focus.of(
      tester.element(
        find.descendant(
          of: copyIn('nas-sg', '复制地址'),
          matching: find.byType(GlyphIcon),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(opacityOf(tester, copyIn('nas-sg', '复制地址')), 1);
    expect(opacityOf(tester, copyIn('nas-sg', '复制名称')), 1);
  });

  testWidgets('each icon copies its own full value and turns into a check '
      'for 1.2 s', (tester) async {
    final copied = <String>[];
    await pump(tester, devicesStatus(), copied: copied);

    await hover(tester, 'studio-mac');
    final name = copyIn('studio-mac', '复制名称');
    await tester.tap(name);
    await tester.pump();
    await tester.tap(copyIn('studio-mac', '复制地址'));
    await tester.pump();
    expect(copied, ['name:studio-mac.example.ts.net', 'address:100.94.68.92']);

    GlyphIcon glyphOf(Finder button) => tester.widget<GlyphIcon>(
      find.descendant(of: button, matching: find.byType(GlyphIcon)),
    );
    expect(glyphOf(name).glyph, Glyphs.check);
    await tester.pump(const Duration(milliseconds: 1100));
    expect(glyphOf(name).glyph, Glyphs.check);
    await tester.pump(const Duration(milliseconds: 200));
    expect(glyphOf(name).glyph, Glyphs.copy);
  });

  testWidgets('search finds a device by its MagicDNS name', (tester) async {
    await pump(tester, devicesStatus());

    expect(
      filterTailscaleDevices(
        tailscaleDevicesOf(devicesStatus()),
        query: 'nas-sg.example.ts',
      ).map((device) => device.name),
      ['nas-sg'],
    );
  });

  testWidgets('an owner missing from the status names the network, else '
      'stays 归属未知; 我 is unchanged', (tester) async {
    await pump(tester, devicesStatus());

    expect(find.text('未知 · 网络 alice@example.com'), findsOneWidget);
    expect(find.text('归属未知'), findsNothing);
    expect(
      find.descendant(of: rowOf('studio-mac'), matching: find.text('我')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: rowOf('nas-sg'),
        matching: find.text('bob@example.com'),
      ),
      findsOneWidget,
    );

    await pump(tester, devicesStatus(network: ''));
    expect(find.textContaining('未知 · 网络'), findsNothing);
    expect(
      find.descendant(of: rowOf('office-hk'), matching: find.text('归属未知')),
      findsOneWidget,
    );
  });

  test('missing owners are counted, never named', () {
    expect(tailscaleMissingOwnerCount(devicesStatus()), 1);
    final all = devicesStatus(
      peers: [
        for (final peer in devicesPeers())
          if (peer.userId != '777') peer,
      ],
    );
    expect(tailscaleMissingOwnerCount(all), 0);
  });

  testWidgets('the English copy', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('en'),
        child: DevicesHarness(status: devicesStatus()),
      ),
    );
    await tester.pump();
    expect(find.text('Unknown · Network alice@example.com'), findsOneWidget);
    expect(find.byTooltip('Copy address'), findsNWidgets(4));
    expect(find.byTooltip('Copy name'), findsNWidgets(3));
  });

  test('a MagicDNS name is the full name without its root dot', () {
    expect(
      tailscaleMagicDnsName(devicesPeers().first, enabled: true),
      'studio-mac.example.ts.net',
    );
    expect(tailscaleMagicDnsName(devicesPeers().first, enabled: false), null);
    expect(tailscaleMagicDnsName(devicesPeers().last, enabled: true), null);
  });
}
