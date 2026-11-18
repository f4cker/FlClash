// The shared page bar is frosted (design review 2): unscrolled it is the
// page itself; scrolled, what passes under it is blurred past reading but
// still shows, and the blur eases out past its foot with no edge. The band
// past the foot comes in over the first 20pt of scroll: at rest it covers
// nothing.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

const _ink = Color(0xFF000000);
const _paper = Color(0xFFFFFFFF);

// Stripes as wide as a heading's strokes, the same down every row: what
// changes from one pixel row to the next is the bar, not the content.
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

  Color at(int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(
      data.getUint8(i + 3),
      data.getUint8(i),
      data.getUint8(i + 1),
      data.getUint8(i + 2),
    );
  }

  /// Max minus min luminance along row [y], over [x0, x1).
  double contrast(int y, int x0, int x1) {
    var lo = 255.0, hi = 0.0;
    for (var x = x0; x < x1; x++) {
      final v = lum(x, y);
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    return hi - lo;
  }

  double mean(int y, int x0, int x1) {
    var sum = 0.0;
    for (var x = x0; x < x1; x++) {
      sum += lum(x, y);
    }
    return sum / (x1 - x0);
  }
}

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in [const Size(1100, 800), const Size(390, 844)]) {
      final label = '${mode.name}, ${size.width.toInt()} wide';
      late double barFoot;
      late double listTop;
      late Color page;
      final boundary = GlobalKey();

      Future<_Shot> pumpAndShoot(
        WidgetTester tester, {
        double scroll = 0,
      }) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: TestApp(
              themeMode: mode,
              wrapInProviderScope: true,
              child: Scaffold(
                // No title: the bar's ink is not what is measured.
                title: '',
                body: Builder(
                  builder: (context) {
                    barFoot = context.appBarInset;
                    listTop = context.contentTopPadding;
                    page = SurfaceLevel.page.colorOf(context.colorScheme);
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
        if (scroll > 0) {
          controller.jumpTo(scroll);
          await tester.pumpAndSettle();
        }
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

      testWidgets('unscrolled, the bar is the page colour ($label)', (
        tester,
      ) async {
        final shot = await pumpAndShoot(tester);
        expect(barFoot, greaterThan(0));
        final width = size.width.toInt();
        // The bare page, as this renderer draws it, from the margin beside
        // the list: Impeller does not reproduce the theme colour bit-exact.
        final bare = shot.at(4, size.height.toInt() - 4);
        // The bar's blur is bounded to its own box; Impeller honours that,
        // the Skia test renderer does not, and lets the list resting 12
        // below the foot shade the bar's lowest 3 sigma.
        final bounded = ui.ImageFilter.isShaderFilterSupported;
        for (var y = 0; y < barFoot.floor(); y++) {
          final bleeds = !bounded && y > barFoot - 60;
          for (var x = 0; x < width; x += 7) {
            // The checked-mode banner's ribbon crosses the top end.
            if (x > width - 90 && y < 90) continue;
            final c = shot.at(x, y);
            for (final (got, want) in [
              (c.r, bare.r),
              (c.g, bare.g),
              (c.b, bare.b),
            ]) {
              expect(
                ((got - want) * 255).abs(),
                // Impeller rounds a translucent fill over its own colour up
                // to 2 levels off, blur or not; Skia draws it exact.
                lessThan(bleeds ? 12 : (bounded ? 2.5 : 1.5)),
                reason: 'bar at $x,$y is $c, not the page $bare',
              );
            }
          }
        }
        expect(page, isNotNull);
      });

      testWidgets('scrolled under the bar, rows blur past reading but show, '
          'and the blur eases out with no edge ($label)', (tester) async {
        final shot = await pumpAndShoot(tester, scroll: 500);
        final width = size.width.toInt();
        // The middle of the bar: no title, no buttons, no ribbon.
        final x0 = (width * 0.3).round(), x1 = (width * 0.6).round();
        final foot = barFoot.round();
        const band = 20;
        final pageLum =
            0.2126 * page.r * 255 +
            0.7152 * page.g * 255 +
            0.0722 * page.b * 255;

        // Below the band the stripes are as sharp as drawn.
        final sharp = shot.contrast(foot + band + 10, x0, x1);
        expect(sharp, greaterThan(200));

        // In the bar: unreadable (stripes flattened to a few levels of
        // grey), but there (darker or lighter than the bare page).
        for (var y = foot ~/ 3; y < foot - 1; y++) {
          expect(
            shot.contrast(y, x0, x1),
            lessThan(sharp * 0.05),
            reason: 'row $y under the bar still reads',
          );
          expect(
            (shot.mean(y, x0, x1) - pageLum).abs(),
            greaterThan(4),
            reason: 'row $y under the bar shows nothing of the list',
          );
        }

        // No edge. Through the band the tint moves a few levels a row at
        // most (the blur steps in three strips: a backdrop cannot be masked
        // to a ramp), and the sharpness only ever grows; at the band's foot,
        // where both have eased out, neither jumps.
        var previous = shot.mean(foot - 4, x0, x1);
        var sharpness = shot.contrast(foot - 4, x0, x1);
        for (var y = foot - 3; y <= foot + band + 4; y++) {
          final m = shot.mean(y, x0, x1);
          final atFoot = y >= foot + band - 2;
          expect(
            (m - previous).abs(),
            lessThan(atFoot ? 3 : 10),
            reason: 'a step in the tint at row $y (foot $foot)',
          );
          previous = m;
          final c = shot.contrast(y, x0, x1);
          expect(
            c,
            greaterThanOrEqualTo(sharpness - 4),
            reason: 'sharpness falls at row $y',
          );
          sharpness = c;
        }
      });

      // The band past the foot covers nothing at rest: it would blur and
      // shade the first row. It comes in over the first barFadeExtent of
      // scroll.
      testWidgets('at the top the band past the foot is the bare content, '
          'once scrolled its full extent it blurs ($label)', (tester) async {
        final width = size.width.toInt();
        final x0 = (width * 0.3).round(), x1 = (width * 0.6).round();
        final atTop = await pumpAndShoot(tester);
        final foot = barFoot.ceil();
        const band = 20;
        // The stripes are the same down every row: a row below the band is
        // what each row in it is, unblurred.
        final rowTop = listTop.ceil();
        final bare = atTop.at(4, size.height.toInt() - 4);
        for (var y = foot + 1; y < foot + band; y++) {
          for (var x = x0; x < x1; x++) {
            final got = atTop.at(x, y);
            final want = y < rowTop - 1
                ? bare
                : y <= rowTop
                ? null
                : atTop.at(x, y + 200);
            if (want == null) continue;
            for (final (g, w) in [
              (got.r, want.r),
              (got.g, want.g),
              (got.b, want.b),
            ]) {
              expect(
                ((g - w) * 255).abs(),
                lessThan(2.5),
                reason: 'band at $x,$y is $got, not the content $want',
              );
            }
          }
        }

        final scrolled = await pumpAndShoot(tester, scroll: band.toDouble());
        final sharp = scrolled.contrast(foot + band + 10, x0, x1);
        expect(sharp, greaterThan(200));
        // Rows scrolled into the band's top are blurred and shaded there.
        for (var y = foot + 1; y < foot + band ~/ 3; y++) {
          expect(
            scrolled.contrast(y, x0, x1),
            lessThan(sharp * 0.6),
            reason: 'row $y in the band is still sharp after a full band',
          );
        }
      });
    }
  }
}
