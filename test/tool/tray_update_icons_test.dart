import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _states = {
  'stopped': ui.Color(0xFF7A8496),
  'direct': ui.Color(0xFF7A7A7A),
  'direct_tun': ui.Color(0xFF7A7A7A),
  'rule': ui.Color(0xFF007AFF),
  'rule_tun': ui.Color(0xFF007AFF),
  'global': ui.Color(0xFFB86900),
  'global_tun': ui.Color(0xFFB86900),
  'status_4': ui.Color(0xFFFF9500),
};

Future<ui.Image> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Future<Uint8List> _pixels(ui.Image image) async {
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  return data!.buffer.asUint8List();
}

Future<ui.Image> _withArrow(ui.Image base, ui.Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(base.width / 18);
  canvas.saveLayer(const ui.Rect.fromLTWH(0, 0, 18, 18), ui.Paint());
  paintImage(
    canvas: canvas,
    rect: const ui.Rect.fromLTWH(0, 0, 18, 18),
    image: base,
    filterQuality: FilterQuality.none,
  );
  final path = ui.Path()
    ..moveTo(3, 17)
    ..lineTo(3, 12.5)
    ..moveTo(1, 14.5)
    ..lineTo(3, 12.5)
    ..lineTo(5, 14.5);
  final paint = ui.Paint()
    ..isAntiAlias = true
    ..style = ui.PaintingStyle.stroke
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round;
  canvas.drawPath(
    path,
    paint
      ..strokeWidth = 3.25
      ..blendMode = ui.BlendMode.clear,
  );
  canvas.drawPath(
    path,
    paint
      ..strokeWidth = 1.25
      ..blendMode = ui.BlendMode.srcOver
      ..color = color,
  );
  canvas.restore();
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(base.width, base.height);
  } finally {
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final scale in [1, 2, 3, 4]) {
    for (final mono in [true, false]) {
      test('approved update arrow preserves base pixels at ${scale}x '
          '${mono ? 'template' : 'color'}', () async {
        final directory = 'assets/images/tray/${mono ? 'macos' : 'unix'}';
        final variant = scale == 1 ? '' : '$scale.0x/';
        for (final state in _states.entries) {
          final base = await _decode('$directory/$variant${state.key}.png');
          final expected = await _withArrow(
            base,
            mono ? const ui.Color(0xFF000000) : state.value,
          );
          final path = '$directory/$variant${state.key}_update.png';
          if (Platform.environment['UPDATE_TRAY_UPDATE_ICONS'] == '1') {
            final png = await expected.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(path).writeAsBytes(png!.buffer.asUint8List());
          }
          final actual = await _decode(path);
          try {
            expect(actual.width, 18 * scale);
            expect(actual.height, 18 * scale);
            final pixels = await _pixels(actual);
            final original = await _pixels(base);
            expect(pixels, orderedEquals(await _pixels(expected)));
            expect(pixels, isNot(orderedEquals(original)));
            for (var y = 0; y < actual.height; y++) {
              for (var x = 0; x < actual.width; x++) {
                final offset = (y * actual.width + x) * 4;
                if (x >= 7 * scale || y < 10 * scale) {
                  expect(
                    pixels.sublist(offset, offset + 4),
                    original.sublist(offset, offset + 4),
                    reason:
                        '${state.key}: original letters and right-side '
                        'TUN/MITM area stay unchanged at ($x, $y)',
                  );
                }
                if (mono && pixels[offset + 3] != 0) {
                  expect(pixels.sublist(offset, offset + 3), [0, 0, 0]);
                }
              }
            }
            final arrowCenter = (15 * scale * actual.width + 3 * scale) * 4;
            expect(pixels[arrowCenter + 3], greaterThan(0));
          } finally {
            base.dispose();
            expected.dispose();
            actual.dispose();
          }
        }
      });
    }
  }
}
