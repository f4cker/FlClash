import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

const _ink = Color(0xFF000000);
const _paper = Color(0xFFFFFFFF);

Widget _stripes() => Row(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (var i = 0; i < 120; i++)
      Expanded(child: ColoredBox(color: i.isEven ? _ink : _paper)),
  ],
);

class _Shot {
  _Shot(this.width, this.data);

  final int width;
  final ByteData data;

  double lum(int x, int y) {
    final i = (y * width + x) * 4;
    return 0.2126 * data.getUint8(i) +
        0.7152 * data.getUint8(i + 1) +
        0.0722 * data.getUint8(i + 2);
  }

  double contrast(int y, int x0, int x1) {
    var lo = 255.0, hi = 0.0;
    for (var x = x0; x < x1; x++) {
      final v = lum(x, y);
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    return hi - lo;
  }
}

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in [const Size(1100, 800), const Size(390, 844)]) {
      testWidgets('original gradient lets rows scroll under the bar '
          '(${mode.name}, ${size.width.toInt()} wide)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final boundary = GlobalKey();
        late double barFoot;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: TestApp(
              themeMode: mode,
              wrapInProviderScope: true,
              child: Scaffold(
                title: '',
                body: Builder(
                  builder: (context) {
                    barFoot = context.appBarInset;
                    return ListView.builder(
                      controller: controller,
                      padding: EdgeInsets.only(
                        top: context.contentTopPadding,
                        left: 16,
                        right: 16,
                      ),
                      itemCount: 60,
                      itemExtent: 40,
                      itemBuilder: (_, _) => _stripes(),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final header = find.byType(FloatingHeader);
        final original = tester.widget<FloatingHeader>(header);
        expect(original.fadeStart, 0);
        expect(original.overhang, 16);
        expect(tester.getTopLeft(find.byType(ListView)).dy, 0);
        final gradient = tester
            .widgetList<DecoratedBox>(
              find.descendant(of: header, matching: find.byType(DecoratedBox)),
            )
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .map((box) => box.gradient)
            .whereType<LinearGradient>()
            .single;
        expect(gradient.colors.first.a, closeTo(0.9, 0.00001));
        expect(gradient.colors.last.a, 0);
        final stops = List<double>.of(gradient.stops!);
        final colors = List<Color>.of(gradient.colors);

        Future<_Shot> capture() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          return (await tester.runAsync(() async {
            final image = await render.toImage();
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final shot = _Shot(image.width, data!);
            image.dispose();
            return shot;
          }))!;
        }

        final top = await capture();
        final width = size.width.toInt();
        final x0 = (width * 0.3).round(), x1 = (width * 0.6).round();
        expect(top.contrast(barFoot ~/ 2, x0, x1), lessThan(2));
        controller.jumpTo(500);
        await tester.pumpAndSettle();
        final scrolled = await capture();
        expect(scrolled.contrast(barFoot ~/ 2, x0, x1), greaterThan(60));
        expect(
          scrolled.contrast(barFoot.ceil() + 17, x0, x1),
          greaterThan(240),
        );
        final after = tester
            .widgetList<DecoratedBox>(
              find.descendant(of: header, matching: find.byType(DecoratedBox)),
            )
            .map((box) => box.decoration)
            .whereType<BoxDecoration>()
            .map((box) => box.gradient)
            .whereType<LinearGradient>()
            .single;
        expect(after.stops, stops);
        expect(after.colors, colors);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
