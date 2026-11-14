import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:fl_clash/common/string.dart';
import 'package:fl_clash/widgets/icon.dart';
import 'package:flutter_svg/svg.dart';

const _extent = 48;
const _maxPngBytes = 32 << 10;
const _maxConversions = 128;
const _maxRasterDimension = 4096;
const _maxRasterPixels = 4 << 20;
const _maxSvgBytes = 128 << 10;
final _conversions = <String, Future<Uint8List?>>{};
final _pendingSources = <String, Future<Uint8List?>>{};

/// Original-color, cache-only PNG for a 16 dp menu icon at up to 3x.
Future<Uint8List?> readTrayIconPng(String src) {
  if (src.isEmpty || src.length > maxTrayIconSourceBytes * 3 + 512) {
    return Future.value(null);
  }
  final pending = _pendingSources[src];
  if (pending != null) {
    return pending;
  }
  if (_pendingSources.length >= 4) {
    return Future.value(null);
  }
  final completer = Completer<Uint8List?>();
  _pendingSources[src] = completer.future;
  unawaited(_prepareSource(src, completer));
  return completer.future;
}

Future<void> _prepareSource(String src, Completer<Uint8List?> completer) async {
  Uint8List? result;
  try {
    result = await _readAndConvert(src);
  } catch (_) {
    result = null;
  } finally {
    // Caller timeouts must not release an acquisition that is still running.
    _pendingSources.remove(src);
    completer.complete(result);
  }
}

Future<Uint8List?> _readAndConvert(String src) async {
  final bytes = await readTargetIconBytesFromCache(src);
  if (bytes == null) {
    return null;
  }
  final isSvg = src.isSvg;
  final key = '${isSvg ? 'svg' : 'raster'}:${sha256.convert(bytes)}';
  final cached = _conversions.remove(key);
  if (cached != null) {
    _conversions[key] = cached;
    return cached;
  }
  while (_conversions.length >= _maxConversions) {
    _conversions.remove(_conversions.keys.first);
  }
  final result = _convert(bytes, isSvg);
  _conversions[key] = result;
  return result;
}

Future<Uint8List?> _convert(Uint8List bytes, bool isSvg) async {
  try {
    final image = isSvg ? await _svgImage(bytes) : await _rasterImage(bytes);
    if (image == null) {
      return null;
    }
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || data.lengthInBytes > _maxPngBytes) {
        return null;
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  } catch (_) {
    return null;
  }
}

bool _safeDimensions(int width, int height) =>
    width > 0 &&
    height > 0 &&
    width <= _maxRasterDimension &&
    height <= _maxRasterDimension &&
    width * height <= _maxRasterPixels;

Future<ui.Image?> _rasterImage(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      if (!_safeDimensions(descriptor.width, descriptor.height)) {
        return null;
      }
      final scale = _extent / math.max(descriptor.width, descriptor.height);
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          return await _drawSquare(
            ui.Size(
              frame.image.width.toDouble(),
              frame.image.height.toDouble(),
            ),
            (canvas) =>
                canvas.drawImage(frame.image, ui.Offset.zero, ui.Paint()),
          );
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}

final _svgComments = RegExp(r'<!--[\s\S]*?-->');
final _localSvgPaint = RegExp(
  r'''url\(\s*(['"]?)#[a-zA-Z_][\w.:-]*\1\s*\)''',
  caseSensitive: false,
);
final _unsafeSvg = RegExp(
  r'<!|<\s*(?:[\w.-]+:)?(?:image|script|style|foreignObject|use)\b|[&\\@]|\bhref\s*=|\burl\s*\(',
  caseSensitive: false,
);

Future<ui.Image?> _svgImage(Uint8List bytes) async {
  if (bytes.lengthInBytes > _maxSvgBytes) {
    return null;
  }
  final source = utf8.decode(bytes);
  final checked = source.replaceAll(_svgComments, '');
  // No external references or embedded images can reach the SVG loader.
  if (_unsafeSvg.hasMatch(checked.replaceAll(_localSvgPaint, '')) ||
      !RegExp(r'<svg\b', caseSensitive: false).hasMatch(source) ||
      '<'.allMatches(source).length > 2048) {
    return null;
  }
  final info = await vg.loadPicture(SvgBytesLoader(bytes), null);
  try {
    final size = info.size;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0 ||
        size.width > _maxRasterDimension ||
        size.height > _maxRasterDimension) {
      return null;
    }
    return await _drawSquare(
      size,
      (canvas) => canvas.drawPicture(info.picture),
    );
  } finally {
    info.picture.dispose();
  }
}

Future<ui.Image> _drawSquare(
  ui.Size size,
  void Function(ui.Canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final scale = _extent / math.max(size.width, size.height);
  canvas.clipRect(const ui.Rect.fromLTWH(0, 0, 48, 48));
  canvas.translate(
    (_extent - size.width * scale) / 2,
    (_extent - size.height * scale) / 2,
  );
  canvas.scale(scale);
  draw(canvas);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(_extent, _extent);
  } finally {
    picture.dispose();
  }
}
