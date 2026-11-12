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
  if (mono) {
    paint.color = const ui.Color(0xFF000000);
  } else if (state == 0) {
    paint.color = const ui.Color(0xFF7A8496);
  } else {
    paint.shader = ui.Gradient.linear(
      const ui.Offset(17, 1),
      const ui.Offset(1, 17),
      tun
          ? const [ui.Color(0xFF128DA4), ui.Color(0xFF0F9494)]
          : const [ui.Color(0xFF6D68ED), ui.Color(0xFF317DEA)],
    );
  }
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
  }
  canvas.restore();
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
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
          for (final tun in [false, if (!mono && state > 0) true]) {
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
              for (final size in [16, 20, 24, 32, 40, 48, 64, 256]) {
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
}
