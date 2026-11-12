import 'package:fl_clash/widgets/info_button.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  const paragraph = 'An explanation that stays out of the normal state.';

  Future<void> pumpAt(WidgetTester tester, Alignment alignment) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      TestApp(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Align(
            alignment: alignment,
            child: const InfoButton(paragraphs: [paragraph], label: 'About'),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('About'));
    await tester.pumpAndSettle();
  }

  Rect glyphOf(WidgetTester tester) => Rect.fromCenter(
    center: tester.getCenter(find.byTooltip('About')),
    width: 16,
    height: 16,
  );

  Rect popoverOf(WidgetTester tester) => tester.getRect(
    find
        .ancestor(of: find.text(paragraph), matching: find.byType(DecoratedBox))
        .first,
  );

  testWidgets('hangs 8 below the glyph with their left edges aligned', (
    tester,
  ) async {
    await pumpAt(tester, Alignment.topLeft);
    final glyph = glyphOf(tester);
    final popover = popoverOf(tester);
    expect(popover.top, glyph.bottom + 8);
    expect(popover.left, glyph.left);
  });

  testWidgets('shifts left only as far as the right edge needs', (
    tester,
  ) async {
    await pumpAt(tester, Alignment.topRight);
    final glyph = glyphOf(tester);
    final popover = popoverOf(tester);
    expect(popover.top, glyph.bottom + 8);
    expect(popover.right, 800 - 8);
    expect(popover.left, lessThan(glyph.left));
  });

  testWidgets('opens above the glyph when the room below is too short', (
    tester,
  ) async {
    await pumpAt(tester, Alignment.bottomLeft);
    final glyph = glyphOf(tester);
    final popover = popoverOf(tester);
    expect(popover.bottom, glyph.top - 8);
    expect(popover.left, glyph.left);
  });

  testWidgets('scrolls what the room cannot hold', (tester) async {
    tester.view.physicalSize = const Size(400, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final long = List.filled(12, paragraph);
    await tester.pumpWidget(
      TestApp(
        child: Align(
          alignment: Alignment.topLeft,
          child: InfoButton(paragraphs: long, label: 'About'),
        ),
      ),
    );
    await tester.tap(find.byTooltip('About'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final scroll = find.byType(SingleChildScrollView);
    expect(scroll, findsOneWidget);
    expect(tester.getRect(scroll).bottom, lessThanOrEqualTo(200 - 8));
    await tester.drag(scroll, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );
  });

  testWidgets('gives focus back to the button once dismissed', (tester) async {
    await pumpAt(tester, Alignment.topLeft);
    expect(find.text(paragraph), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text(paragraph), findsNothing);
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(
      focused?.findAncestorWidgetOfExactType<InfoButton>(),
      isNotNull,
      reason: 'focus went to ${focused?.widget}',
    );
  });
}
