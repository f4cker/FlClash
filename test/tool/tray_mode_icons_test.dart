import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/shapes/shapes.dart';

import '../../tool/src/icons/ico.dart';

const _names = ['stopped', 'direct', 'rule', 'global'];
const _letters = ['', 'D', 'R', 'G'];
const _icoSizes = [16, 20, 24, 32, 40, 48, 64, 256];
const _colors = [
  ui.Color(0xFF7A8496),
  ui.Color(0xFF7A7A7A),
  ui.Color(0xFF007AFF),
  ui.Color(0xFFB86900),
];

Future<Uint8List> _render(int size, int state, bool mono, bool tun) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.scale(size / 18);
  final shape = MaterialShapes.cookie9Sided;
  final b = shape.calculateBounds(approximate: false);
  final bounds = ui.Rect.fromLTRB(b[0], b[1], b[2], b[3]);
  final scale = (state == 0 ? 14.4 : 16) / bounds.longestSide;
  final matrix = Float64List.fromList([
    scale,
    0,
    0,
    0,
    0,
    scale,
    0,
    0,
    0,
    0,
    1,
    0,
    9 - bounds.center.dx * scale,
    9 - bounds.center.dy * scale,
    0,
    1,
  ]);
  final path = shapePathOf(shape).transform(matrix);
  final paint = ui.Paint()..isAntiAlias = true;
  paint.color = mono ? const ui.Color(0xFF000000) : _colors[state];
  canvas.saveLayer(const ui.Rect.fromLTWH(0, 0, 18, 18), ui.Paint());
  if (state == 0) {
    paint
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.6;
  }
  canvas.drawPath(path, paint);
  if (state > 0) {
    final text = TextPainter(
      text: TextSpan(
        text: _letters[state],
        style: const TextStyle(
          fontFamily: 'TrayRounded',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: ui.Color(0xFFFFFFFF),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    canvas.saveLayer(
      const ui.Rect.fromLTWH(0, 0, 18, 18),
      ui.Paint()..blendMode = ui.BlendMode.dstOut,
    );
    text.paint(
      canvas,
      ui.Offset((18 - text.width) / 2, (18 - text.height) / 2),
    );
    canvas.restore();
    text.dispose();
    if (tun) {
      canvas
        ..drawCircle(
          const ui.Offset(16, 16),
          2.6,
          ui.Paint()..blendMode = ui.BlendMode.clear,
        )
        ..drawCircle(const ui.Offset(16, 16), 1.5, paint);
    }
  }
  canvas.restore();
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<Uint8List> _pixels(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  image.dispose();
  codec.dispose();
  return data!.buffer.asUint8List();
}

List<int> _alpha(Uint8List rgba) => [
  for (var i = 3; i < rgba.length; i += 4) rgba[i],
];

void _expectColor(Uint8List rgba, ui.Color color) {
  final rgb = [
    (color.r * 255).round(),
    (color.g * 255).round(),
    (color.b * 255).round(),
  ];
  var opaque = 0;
  for (var i = 0; i < rgba.length; i += 4) {
    if (rgba[i + 3] < 250) continue;
    opaque++;
    for (var channel = 0; channel < 3; channel++) {
      expect((rgba[i + channel] - rgb[channel]).abs(), lessThanOrEqualTo(2));
    }
  }
  expect(opaque, greaterThan(0));
}

List<Uint8List> _icoImages(Uint8List ico) {
  final data = ByteData.sublistView(ico);
  return [
    for (var i = 0; i < data.getUint16(4, Endian.little); i++)
      ico.sublist(
        data.getUint32(6 + 16 * i + 12, Endian.little),
        data.getUint32(6 + 16 * i + 12, Endian.little) +
            data.getUint32(6 + 16 * i + 8, Endian.little),
      ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'generate mode icons using the actual cookie path and system rounded font',
    () async {
      if (Platform.environment['UPDATE_TRAY_MODE_ICONS'] != '1') return;
      final font = FontLoader('TrayRounded')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File('/System/Library/Fonts/SFNSRounded.ttf').readAsBytes(),
            ),
          ),
        );
      await font.load();
      for (var state = 0; state < _names.length; state++) {
        for (final mono in [true, false]) {
          for (final tun in [false, if (state > 0) true]) {
            final name = '${_names[state]}${tun ? '_tun' : ''}';
            final dir = 'assets/images/tray/${mono ? 'macos' : 'unix'}';
            for (final scale in [1, 2, 3, 4]) {
              final path = scale == 1
                  ? '$dir/$name.png'
                  : '$dir/$scale.0x/$name.png';
              await File(
                path,
              ).writeAsBytes(await _render(18 * scale, state, mono, tun));
            }
            if (!mono) {
              final entries = <IcoEntry>[];
              for (final size in _icoSizes) {
                entries.add(
                  IcoEntry(
                    size: size,
                    png: await _render(size, state, false, tun),
                  ),
                );
              }
              await File(
                'assets/images/tray/windows/$name.ico',
              ).writeAsBytes(buildIco(entries));
            }
          }
        }
      }
    },
  );

  for (final scale in [1, 2, 3, 4]) {
    test(
      'mode colors preserve monochrome letter masks at scale $scale',
      () async {
        final masks = <List<int>>[];
        for (var state = 0; state < _names.length; state++) {
          final variant = scale == 1 ? '' : '$scale.0x/';
          final name = '$variant${_names[state]}.png';
          final color = await _pixels(
            await File('assets/images/tray/unix/$name').readAsBytes(),
          );
          final mono = await _pixels(
            await File('assets/images/tray/macos/$name').readAsBytes(),
          );
          _expectColor(color, _colors[state]);
          _expectColor(mono, const ui.Color(0xFF000000));
          expect(_alpha(color), _alpha(mono));
          masks.add(_alpha(color));
        }
        for (var a = 0; a < masks.length; a++) {
          for (var b = a + 1; b < masks.length; b++) {
            expect(masks[a], isNot(orderedEquals(masks[b])));
          }
        }
        final size = 18 * scale;
        for (var y = 6 * scale; y < 12 * scale; y++) {
          for (var x = 6 * scale; x < 12 * scale; x++) {
            expect(masks[0][y * size + x], 0);
          }
        }
        expect(
          masks[1].fold<int>(0, (a, b) => a + b),
          greaterThan(masks[0].fold<int>(0, (a, b) => a + b)),
        );
      },
    );
  }

  for (final scale in [1, 2, 3, 4]) {
    test(
      'TUN dot is separated and preserves mode glyphs at scale $scale',
      () async {
        final variant = scale == 1 ? '' : '$scale.0x/';
        final size = 18 * scale;
        for (var state = 1; state < _names.length; state++) {
          final name = _names[state];
          final off = await _pixels(
            await File(
              'assets/images/tray/unix/$variant$name.png',
            ).readAsBytes(),
          );
          final on = await _pixels(
            await File(
              'assets/images/tray/unix/$variant${name}_tun.png',
            ).readAsBytes(),
          );
          final mono = await _pixels(
            await File(
              'assets/images/tray/macos/$variant${name}_tun.png',
            ).readAsBytes(),
          );
          _expectColor(on, _colors[state]);
          _expectColor(mono, const ui.Color(0xFF000000));
          expect(_alpha(on), _alpha(mono));
          expect(on[(16 * scale * size + 16 * scale) * 4 + 3], 255);
          expect(
            on[((14.5 * scale).floor() * size + (14.5 * scale).floor()) * 4 +
                3],
            lessThanOrEqualTo(32),
          );
          expect(_alpha(on), isNot(orderedEquals(_alpha(off))));
          for (var y = 0; y < size; y++) {
            for (var x = 0; x < size; x++) {
              if (x >= 12 * scale && y >= 12 * scale) continue;
              final alpha = (y * size + x) * 4 + 3;
              expect(on[alpha], off[alpha]);
            }
          }
        }
      },
    );
  }

  test('Windows mode and TUN colors cover every ICO size', () async {
    for (var state = 0; state < _names.length; state++) {
      for (final tun in [false, if (state > 0) true]) {
        final name = '${_names[state]}${tun ? '_tun' : ''}';
        final images = _icoImages(
          await File('assets/images/tray/windows/$name.ico').readAsBytes(),
        );
        expect(images, hasLength(_icoSizes.length));
        for (var i = 0; i < images.length; i++) {
          final header = ByteData.sublistView(images[i]);
          expect(header.getUint32(16), _icoSizes[i]);
          expect(header.getUint32(20), _icoSizes[i]);
          _expectColor(await _pixels(images[i]), _colors[state]);
        }
      }
    }
  });

  test('mode colors remain legible on light and dark mock menu bars', () {
    for (final color in _colors.skip(1)) {
      for (final background in [
        const ui.Color(0xFFF2F2F2),
        const ui.Color(0xFF242424),
      ]) {
        final luminances = [
          color.computeLuminance(),
          background.computeLuminance(),
        ]..sort();
        expect(
          (luminances[1] + 0.05) / (luminances[0] + 0.05),
          greaterThanOrEqualTo(3),
        );
      }
    }
  });
}
