import 'dart:math';
import 'dart:ui' show BoxHeightStyle;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/read_failure.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/hct/hct.dart';

import '../helpers/test_app.dart';

double _contrast(Color a, Color b) {
  final lighter = max(a.computeLuminance(), b.computeLuminance());
  final darker = min(a.computeLuminance(), b.computeLuminance());
  return (lighter + 0.05) / (darker + 0.05);
}

/// The scheme the app resolves for an accent, as genColorScheme builds it.
ColorScheme _scheme(
  int seed,
  Brightness brightness,
  ColorStyle style,
  bool pureBlack,
) => seededColorScheme(
  seedColor: Color(seed),
  brightness: brightness,
  style: style,
).toPureBlack(pureBlack);

const _shortMessage = 'Couldn’t refresh connections.';

/// About as long as the longest translation, ru, runs.
const _longMessage =
    'Не удалось обновить список подключений. Показан последний полученный '
    'результат; повторите попытку, когда ядро снова будет доступно.';

void main() {
  Future<void> pumpBanner(
    WidgetTester tester, {
    required double width,
    String message = _shortMessage,
    double textScale = 1,
    Brightness brightness = Brightness.light,
    bool retrying = false,
  }) async {
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TestApp(
        theme: ThemeData(
          colorScheme: _scheme(
            defaultPrimaryColor,
            Brightness.light,
            ColorStyle.vivid,
            false,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: _scheme(
            defaultPrimaryColor,
            Brightness.dark,
            ColorStyle.vivid,
            false,
          ),
        ),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Align(
              alignment: Alignment.topCenter,
              child: ReadFailureBanner(
                message: message,
                retrying: retrying,
                onRetry: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder retry() => find.byType(RetryButton);
  Finder messageText() => find.descendant(
    of: find.byType(ReadFailureBanner),
    matching: find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText().length > 10,
    ),
  );

  void expectWhole(WidgetTester tester) {
    final paragraph = tester.renderObject<RenderParagraph>(messageText());
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.debugHasOverflowShader, isFalse);
    final retrySize = tester.getSize(retry());
    expect(retrySize.width, greaterThanOrEqualTo(minRetryTapTarget));
    expect(retrySize.height, greaterThanOrEqualTo(minRetryTapTarget));
    // The retry stays inside the banner, uncut.
    final banner = tester.getRect(find.byType(ReadFailureBanner));
    final button = tester.getRect(retry());
    expect(banner.contains(button.topLeft), isTrue);
    expect(banner.contains(button.bottomRight - const Offset(1, 1)), isTrue);
    expect(tester.takeException(), null);
  }

  bool stacked(WidgetTester tester) =>
      tester.getTopLeft(retry()).dy >=
      tester.getBottomLeft(messageText()).dy - 0.5;

  testWidgets('a short message sits beside a retry of at least 44x44 on a '
      'wide banner', (tester) async {
    await pumpBanner(tester, width: 900);
    expect(stacked(tester), isFalse);
    expectWhole(tester);
  });

  testWidgets('below 440dp the retry goes under the message', (tester) async {
    await pumpBanner(tester, width: 400);
    expect(stacked(tester), isTrue);
    expectWhole(tester);
  });

  for (final (label, message, scale) in [
    ('a long translation', _longMessage, 1.0),
    ('large text', _shortMessage + _shortMessage, 2.0),
    ('a long translation in large text', _longMessage, 2.0),
  ]) {
    testWidgets('$label at 440dp and wider wraps the retry under the whole '
        'message, neither cut nor squeezed', (tester) async {
      for (final width in [440.0, 600.0]) {
        await pumpBanner(
          tester,
          width: width,
          message: message,
          textScale: scale,
        );
        expect(stacked(tester), isTrue, reason: 'at $width');
        expectWhole(tester);
        // Busy, the retry keeps its size.
        final busy = tester.getSize(retry());
        await pumpBanner(
          tester,
          width: width,
          message: message,
          textScale: scale,
          retrying: true,
        );
        expect(tester.getSize(retry()), busy);
        expectWhole(tester);
      }
    });
  }

  for (final (scale, size) in [
    (1.0, 16.0),
    (1.25, 20.0),
    (1.5, 24.0),
    (2.0, 24.0),
  ]) {
    testWidgets('at ${scale}x text the error icon is ${size}dp and centers on '
        'the first line', (tester) async {
      await pumpBanner(
        tester,
        width: 600,
        message: _longMessage,
        textScale: scale,
      );
      final icon = find.descendant(
        of: find.byType(ReadFailureBanner),
        matching: find.byType(GlyphIcon),
      );
      expect(tester.widget<GlyphIcon>(icon).size, size);
      final paragraph = tester.renderObject<RenderParagraph>(messageText());
      // The first line's box, as tall as the line: its glyph's box spans it.
      final firstLine = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 1),
            boxHeightStyle: BoxHeightStyle.max,
          )
          .first;
      final lineCenter =
          paragraph.localToGlobal(Offset.zero).dy +
          (firstLine.top + firstLine.bottom) / 2;
      expect(tester.getCenter(icon).dy, closeTo(lineCenter, 1));
      // More than one line, so centring on the first is not the whole text.
      expect(paragraph.size.height, greaterThan(firstLine.bottom * 1.5));
      expectWhole(tester);
    });
  }

  testWidgets('dark uses the grouped surface, not a red block', (tester) async {
    await pumpBanner(tester, width: 900, brightness: Brightness.dark);
    final context = tester.element(find.byType(ReadFailureBanner));
    final colorScheme = context.colorScheme;
    expect(colorScheme.brightness, Brightness.dark);
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(ReadFailureBanner),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as ShapeDecoration;
    expect(decoration.color, colorScheme.surfaceContainerHigh);
    expect(
      tester.renderObject<RenderParagraph>(messageText()).text.style?.color,
      colorScheme.onSurface,
    );
    final colors = ReadFailureBannerColors.of(colorScheme);
    expect(colors.icon, colorScheme.error);
    // The primary hue, lifted only as far as text on this surface needs;
    // fitting the lighter tone into sRGB moves the hue by about 3.5°.
    expect(
      Hct.fromInt(colors.action.toARGB32()).hue,
      closeTo(Hct.fromInt(colorScheme.primary.toARGB32()).hue, 4),
    );
    expect(colors.action.tone, greaterThanOrEqualTo(colorScheme.primary.tone));
    expectWhole(tester);
  });

  test('banner contrast holds for every default accent, light and dark', () {
    final rows = <String>[];
    var worstText = double.infinity;
    var worstAction = double.infinity;
    var worstIcon = double.infinity;
    for (final pureBlack in [false, true]) {
      for (final brightness in Brightness.values) {
        if (pureBlack && brightness == Brightness.light) continue;
        for (final seed in defaultPrimaryColors) {
          final colors = ReadFailureBannerColors.of(
            _scheme(seed, brightness, ColorStyle.vivid, pureBlack),
          );
          final text = _contrast(colors.foreground, colors.background);
          final action = _contrast(colors.action, colors.background);
          final icon = _contrast(colors.icon, colors.background);
          final scheme = _scheme(seed, brightness, ColorStyle.vivid, pureBlack);
          final rawPrimary = _contrast(scheme.primary, colors.background);
          worstText = min(worstText, text);
          worstAction = min(worstAction, action);
          worstIcon = min(worstIcon, icon);
          rows.add(
            '| ${brightness.name}${pureBlack ? ' (pure black)' : ''} '
            '| #${seed.toRadixString(16).substring(2).toUpperCase()} '
            '| ${text.toStringAsFixed(4)} | ${action.toStringAsFixed(4)} '
            '| ${icon.toStringAsFixed(4)} '
            '| ${brightness == Brightness.dark ? rawPrimary.toStringAsFixed(4) : '–'} |',
          );
          expect(
            text,
            greaterThanOrEqualTo(minTextContrast),
            reason: rows.last,
          );
          expect(
            action,
            greaterThanOrEqualTo(minTextContrast),
            reason: rows.last,
          );
          expect(icon, greaterThanOrEqualTo(3), reason: rows.last);
          if (brightness == Brightness.dark) {
            if (rawPrimary >= retryContrastTarget) {
              // Already there: left as it is.
              expect(colors.action, scheme.primary, reason: rows.last);
            } else {
              // Lifted to the target, and no further than a step past it.
              expect(
                action,
                greaterThanOrEqualTo(retryContrastTarget),
                reason: rows.last,
              );
              expect(
                action,
                lessThan(retryContrastTarget + 0.1),
                reason: rows.last,
              );
            }
          }
        }
      }
    }
    // Read by the report.
    // ignore: avoid_print
    print(
      'BANNER-CONTRAST\n| theme | accent | text | retry | icon | unadjusted primary |\n'
      '| --- | --- | --- | --- | --- | --- |\n${rows.join('\n')}\n'
      'worst text ${worstText.toStringAsFixed(4)}, retry '
      '${worstAction.toStringAsFixed(4)}, icon ${worstIcon.toStringAsFixed(4)}',
    );
  });

  test('the other color styles hold too', () {
    final rows = <String>[];
    for (final style in ColorStyle.values.where((s) => s != ColorStyle.vivid)) {
      for (final brightness in Brightness.values) {
        var text = double.infinity, action = double.infinity;
        var icon = double.infinity;
        for (final seed in defaultPrimaryColors) {
          final colors = ReadFailureBannerColors.of(
            _scheme(seed, brightness, style, false),
          );
          text = min(text, _contrast(colors.foreground, colors.background));
          action = min(action, _contrast(colors.action, colors.background));
          icon = min(icon, _contrast(colors.icon, colors.background));
        }
        expect(
          text,
          greaterThanOrEqualTo(minTextContrast),
          reason: '$style $brightness',
        );
        expect(
          action,
          greaterThanOrEqualTo(minTextContrast),
          reason: '$style $brightness',
        );
        expect(icon, greaterThanOrEqualTo(3), reason: '$style $brightness');
        rows.add(
          '| ${style.name} ${brightness.name} | ${text.toStringAsFixed(4)} '
          '| ${action.toStringAsFixed(4)} | ${icon.toStringAsFixed(4)} |',
        );
      }
    }
    // ignore: avoid_print
    print('BANNER-CONTRAST-STYLES (worst over accents)\n${rows.join('\n')}');
  });
}
