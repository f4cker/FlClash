import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_ui/shapes/shapes.dart';

import '../../tool/src/icons/ico.dart';

/// Renders the tray's status_1..3 from the home toggle's running shape.
///
/// `UPDATE_TRAY_ICONS=1 flutter test test/tool/tray_icons_test.dart` rewrites
/// the assets; a plain run checks the committed ones still match.
const _base = 18;
const _scales = [1, 2, 3, 4];
const _inset = 1 / _base;

typedef _Fill = ({ui.Color from, ui.Color to});

const _black = (from: ui.Color(0xFF000000), to: ui.Color(0xFF000000));
const _fills = <String, _Fill>{
  'status_1': (from: ui.Color(0xFF7A8496), to: ui.Color(0xFF7A8496)),
  'status_2': (from: ui.Color(0xFF6D68ED), to: ui.Color(0xFF317DEA)),
  'status_3': (from: ui.Color(0xFF128DA4), to: ui.Color(0xFF0F9494)),
};

/// The curve's own extent: `normalized()` fits the control points, which sit
/// a little outside the lobes.
ui.Rect _tightBounds(RoundedPolygon shape) {
  final b = shape.calculateBounds(approximate: false);
  return ui.Rect.fromLTRB(b[0], b[1], b[2], b[3]);
}

Future<ui.Image> _renderCookie(int size, _Fill fill) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final shape = MaterialShapes.cookie9Sided;
  final path = shapePathOf(shape);
  final bounds = _tightBounds(shape);
  final scale = size * (1 - 2 * _inset) / bounds.longestSide;
  final paint = ui.Paint()
    ..isAntiAlias = true
    ..shader = ui.Gradient.linear(bounds.topRight, bounds.bottomLeft, [
      fill.from,
      fill.to,
    ]);
  canvas
    ..translate(size / 2, size / 2)
    ..scale(scale, scale)
    ..translate(-bounds.center.dx, -bounds.center.dy)
    ..drawPath(path, paint);
  return recorder.endRecording().toImage(size, size);
}

Future<Uint8List> _png(int size, _Fill fill) async {
  final image = await _renderCookie(size, fill);
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
  return data!.buffer.asUint8List();
}

String _variant(String dir, String name, int scale) =>
    scale == 1 ? '$dir/$name.png' : '$dir/$scale.0x/$name.png';

Map<String, Future<Uint8List> Function()> _outputs() => {
  for (final scale in _scales) ...{
    _variant('assets/images/tray/macos', 'status_1', scale): () =>
        _png(_base * scale, _black),
    for (final MapEntry(key: name, value: fill) in _fills.entries)
      _variant('assets/images/tray/unix', name, scale): () =>
          _png(_base * scale, fill),
  },
  for (final MapEntry(key: name, value: fill) in _fills.entries)
    'assets/images/tray/windows/$name.ico': () async => buildIco([
      for (final size in trayIcoSizes)
        IcoEntry(size: size, png: await _png(size, fill)),
    ]),
};

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

Future<void> _expectSamePixels(Uint8List actual, Uint8List expected) async {
  final a = await _pixels(actual);
  final b = await _pixels(expected);
  expect(a.length, b.length);
  var worst = 0;
  for (var i = 0; i < a.length; i++) {
    final d = (a[i] - b[i]).abs();
    if (d > worst) worst = d;
  }
  expect(worst, lessThanOrEqualTo(2));
}

void main() {
  final update = Platform.environment['UPDATE_TRAY_ICONS'] == '1';

  for (final MapEntry(key: path, value: render) in _outputs().entries) {
    test(path, () async {
      final bytes = await render();
      final file = File(path);
      if (update) {
        await file.writeAsBytes(bytes);
        return;
      }
      final committed = await file.readAsBytes();
      if (path.endsWith('.ico')) {
        final want = _icoImages(bytes);
        final have = _icoImages(committed);
        expect(have.length, want.length);
        for (var i = 0; i < want.length; i++) {
          await _expectSamePixels(have[i], want[i]);
        }
      } else {
        await _expectSamePixels(committed, bytes);
      }
    });
  }

  test('the macOS template is black with alpha only', () async {
    for (final scale in _scales) {
      final rgba = await _pixels(
        await File(
          _variant('assets/images/tray/macos', 'status_1', scale),
        ).readAsBytes(),
      );
      for (var i = 0; i < rgba.length; i += 4) {
        expect(rgba.sublist(i, i + 3), [0, 0, 0]);
      }
    }
  });
}
