import 'dart:io';

import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:test/test.dart';

void main() {
  for (final (mac, win, directory, extension, monochrome) in [
    (true, false, 'macos', 'png', true),
    (true, false, 'unix', 'png', false),
    (false, false, 'unix', 'png', true),
    (false, true, 'windows', 'ico', true),
  ]) {
    final tray = AppTray.forPlatform(isMacOS: mac, isWindows: win);
    for (final mode in Mode.values) {
      for (final running in [false, true]) {
        for (final tun in [false, true]) {
          for (final safe in [false, true]) {
            test('$directory $mode running=$running tun=$tun safe=$safe', () {
              final name = safe
                  ? 'status_4'
                  : !running
                  ? 'stopped'
                  : '${mode.name}${directory != 'macos' && tun ? '_tun' : ''}';
              final path = tray.getTrayIcon(
                isStart: running,
                tunEnable: tun,
                safeMode: safe,
                monochrome: monochrome,
                mode: mode,
              );
              expect(path, 'assets/images/tray/$directory/$name.$extension');
              expect(File(path).existsSync(), isTrue);
            });
          }
        }
      }
    }
  }
}
