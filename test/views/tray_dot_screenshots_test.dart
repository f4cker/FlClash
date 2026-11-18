// Renders the menu bar icon's MITM dot in each state, on a light and a dark
// menu bar, with and without the TUN dot, to PNG for review, with the
// geometry the macOS host draws: the TUN icons' dot mirrored to the top-right
// corner, a 3pt dot centred 2pt in from the corner in a cut 2.5pt in radius.
// Off by default:
//   UI6_SCREENSHOTS=<dir> flutter test test/views/tray_dot_screenshots_test.dart
// With RULES_REQUESTS_PAIR=<rules.png>,<requests.png> it also sets the two
// pages side by side in rules-vs-requests-scrolled.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust_api/tray.dart';

final _outDir = Platform.environment['UI6_SCREENSHOTS'];
final _pair = Platform.environment['RULES_REQUESTS_PAIR'];

/// Points to pixels; 4x so the 1pt gap reads.
const _scale = 4.0;
const _icon = 18.0;
const _barHeight = 24.0;
const _cell = Size(64, _barHeight);
const _label = 14.0;

const _dotDiameter = 3.0;
const _dotInset = 2.0;
const _dotGap = 1.0;

/// The icon the menu bar shows, with the TUN dot or without.
const _icons = [
  ('plain', 'assets/images/tray/macos/4.0x/rule.png'),
  ('tun', 'assets/images/tray/macos/4.0x/rule_tun.png'),
];

final class _Bar {
  const _Bar(this.name, this.background, this.foreground);

  final String name;
  final Color background;
  final Color foreground;
}

const _bars = [
  _Bar('light', Color(0xFFECECEC), Color(0xFF000000)),
  _Bar('dark', Color(0xFF2A2A2C), Color(0xFFFFFFFF)),
];

/// A state, the dot the app hands the host for it, and the breathing
/// opacity the frame shows.
typedef _State = (String, MitmIndicator?, double);

const List<_State> _states = [
  ('off', null, 1),
  ('on-idle', MitmIndicator.on(), 1),
  ('decrypting-peak', MitmIndicator.decrypting(), 1),
  ('decrypting-trough', MitmIndicator.decrypting(), 0.4),
  ('paused', MitmIndicator.paused(MitmPauseReason.notTrusted), 1),
];

Future<ui.Image> _decode(List<int> bytes) async {
  final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
  return (await codec.getNextFrame()).image;
}

Future<void> _write(ui.Image image, String name) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File('$_outDir/$name.png').writeAsBytes(data!.buffer.asUint8List());
}

/// One menu bar cell with the icon centred, in points.
void _paintCell(
  Canvas canvas,
  Offset origin,
  _Bar bar,
  ui.Image icon,
  TrayDot? dot,
  double opacity,
) {
  canvas.drawRect(origin & _cell, Paint()..color = bar.background);
  final iconRect = Rect.fromLTWH(
    origin.dx + (_cell.width - _icon) / 2,
    origin.dy + (_cell.height - _icon) / 2,
    _icon,
    _icon,
  );
  // The template icon takes the menu bar's foreground; the ring is cleared
  // from it alone, so the bar shows through.
  canvas.saveLayer(iconRect.inflate(4), Paint());
  paintImage(
    canvas: canvas,
    rect: iconRect,
    image: icon,
    filterQuality: FilterQuality.high,
    colorFilter: ColorFilter.mode(bar.foreground, BlendMode.srcIn),
  );
  final centre = iconRect.topRight + const Offset(-_dotInset, _dotInset);
  if (dot != null) {
    canvas.drawCircle(
      centre,
      _dotDiameter / 2 + _dotGap,
      Paint()..blendMode = BlendMode.clear,
    );
  }
  canvas.restore();
  if (dot != null) {
    canvas.drawCircle(
      centre,
      _dotDiameter / 2,
      Paint()..color = Color(dot.color).withValues(alpha: opacity),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _outDir == null || _outDir!.isEmpty
      ? 'set UI6_SCREENSHOTS to an output directory'
      : null;

  test('tray dot states', skip: skip, () async {
    Directory(_outDir!).createSync(recursive: true);
    // Test fonts draw boxes; the labels need real glyphs.
    await (FontLoader('JetBrainsMono')..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/JetBrainsMono-Regular.ttf').readAsBytesSync(),
            ),
          ),
        ))
        .load();
    final icons = [
      for (final (name, path) in _icons)
        (name, await _decode(File(path).readAsBytesSync())),
    ];
    final rows = [
      for (final bar in _bars)
        for (final icon in icons) (bar, icon),
    ];
    final labels = <(String, Offset)>[];
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_scale);
    final width = _cell.width * _states.length;
    final height = (_cell.height + _label) * rows.length;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    for (final (row, (bar, (iconName, icon))) in rows.indexed) {
      for (final (column, (name, indicator, opacity)) in _states.indexed) {
        final origin = Offset(
          column * _cell.width,
          row * (_cell.height + _label) + _label,
        );
        labels.add(('${bar.name} $iconName\n$name', origin));
        _paintCell(canvas, origin, bar, icon, mitmTrayDot(indicator), opacity);
        // Each cell on its own too.
        final single = ui.PictureRecorder();
        _paintCell(
          Canvas(single)..scale(_scale),
          Offset.zero,
          bar,
          icon,
          mitmTrayDot(indicator),
          opacity,
        );
        final image = await single.endRecording().toImage(
          (_cell.width * _scale).round(),
          (_cell.height * _scale).round(),
        );
        await _write(image, 'tray-dot-${bar.name}-$iconName-$name');
        image.dispose();
      }
    }
    for (final (text, origin) in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 5,
            color: Color(0xFF333333),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _cell.width);
      painter.paint(canvas, origin - const Offset(-2, _label - 1));
    }
    final sheet = await recorder.endRecording().toImage(
      (width * _scale).round(),
      (height * _scale).round(),
    );
    await _write(sheet, 'tray-dot-all');
    sheet.dispose();
  });

  test(
    'rules and requests side by side',
    skip: skip ?? (_pair == null ? 'set RULES_REQUESTS_PAIR' : null),
    () async {
      final [left, right] = [
        for (final path in _pair!.split(','))
          await _decode(File(path).readAsBytesSync()),
      ];
      const gap = 24.0;
      final height = left.height > right.height ? left.height : right.height;
      final width = left.width + gap + right.width;
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..drawRect(
          Rect.fromLTWH(0, 0, width, height.toDouble()),
          Paint()..color = const Color(0xFF808080),
        )
        ..drawImage(left, Offset.zero, Paint())
        ..drawImage(right, Offset(left.width + gap, 0), Paint());
      final image = await recorder.endRecording().toImage(
        width.round(),
        height,
      );
      await _write(image, 'rules-vs-requests-scrolled');
      image.dispose();
    },
  );
}
