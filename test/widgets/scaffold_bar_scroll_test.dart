// The shared page bar is an opaque band of the page's colour and the body is
// cut at its foot: a list scrolled up never shows through or under it.
import 'dart:ui' as ui;

import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

const _red = Color(0xFFFF0000);

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in [const Size(1100, 800), const Size(390, 844)]) {
      testWidgets(
        'scrolled content stays below the bar (${mode.name}, '
        '${size.width.toInt()} wide)',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          late double barFoot;
          late Color page;
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: TestApp(
                themeMode: mode,
                wrapInProviderScope: true,
                child: Scaffold(
                  title: 'Rules',
                  body: Builder(
                    builder: (context) {
                      barFoot = context.appBarInset;
                      page = SurfaceLevel.page.colorOf(context.colorScheme);
                      return ListView.builder(
                        padding: EdgeInsets.only(
                          top: context.contentTopPadding,
                        ),
                        itemCount: 60,
                        itemBuilder: (_, _) => const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: SizedBox(
                            height: 40,
                            child: ColoredBox(color: _red),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pumpAndSettle();

          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final bytes = (await tester.runAsync(() async {
            final image = await render.toImage();
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            return (image.width, data!);
          }))!;
          final (width, data) = bytes;
          Color at(int x, int y) {
            final i = (y * width + x) * 4;
            return Color.fromARGB(
              data.getUint8(i + 3),
              data.getUint8(i),
              data.getUint8(i + 1),
              data.getUint8(i + 2),
            );
          }

          bool reddish(Color c) =>
              (c.r * 255) > 160 && (c.g * 255) < 140 && (c.b * 255) < 140;

          expect(barFoot, greaterThan(0));
          // Nothing of the list over or under the bar: its whole height, past
          // the title and buttons, is the page's colour where it is not ink,
          // and has no trace of the list's red.
          for (var y = 0; y < barFoot.floor(); y++) {
            for (var x = 0; x < width; x += 3) {
              // The checked-mode banner's red ribbon crosses the top end.
              if (x > width - 90 && y < 90) continue;
              final c = at(x, y);
              expect(reddish(c), isFalse, reason: 'red under the bar at $x,$y');
            }
            for (final x in [1, 6, 11]) {
              expect(
                at(x, y).toARGB32(),
                page.toARGB32(),
                reason: 'bar edge at $x,$y is not the page colour',
              );
            }
          }
          // The list starts right at the bar's foot: cut there, not faded.
          expect(reddish(at(width ~/ 2, barFoot.ceil() + 1)), isTrue);
        },
      );
    }
  }
}
