import 'dart:io';

import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart' show mitmIndicatorOf;
import 'package:rust_api/tray.dart';
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
                  : '${mode.name}${tun ? '_tun' : ''}';
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

  test('mode changes retain their names with an independent TUN variant', () {
    final tray = AppTray.forPlatform(isMacOS: true, isWindows: false);
    final paths = <String>{};
    for (final mode in [Mode.rule, Mode.global, Mode.direct, Mode.rule]) {
      final path = tray.getTrayIcon(
        isStart: true,
        tunEnable: false,
        safeMode: false,
        monochrome: false,
        mode: mode,
      );
      expect(path, 'assets/images/tray/unix/${mode.name}.png');
      expect(
        tray.getTrayIcon(
          isStart: true,
          tunEnable: true,
          safeMode: false,
          monochrome: false,
          mode: mode,
        ),
        'assets/images/tray/unix/${mode.name}_tun.png',
      );
      paths.add(path);
    }
    expect(paths, hasLength(3));
  });

  test('the MITM status maps onto the menu bar dot', () {
    expect(mitmTrayDot(null), isNull);
    expect(
      mitmTrayDot(const MitmIndicator.decrypting()),
      const TrayDot(color: 0xFFFF3B30, breathing: true),
    );
    expect(
      mitmTrayDot(const MitmIndicator.on()),
      const TrayDot(color: 0xFFFF3B30, breathing: true),
    );
    for (final indicator in const [
      MitmIndicator.paused(MitmPauseReason.notTrusted),
      MitmIndicator.unconfirmed(),
    ]) {
      expect(
        mitmTrayDot(indicator),
        const TrayDot(color: 0xFFFF9F0A, breathing: false),
      );
    }
  });

  test('the Core\'s partialConnections caveat is a breathing red dot', () {
    final indicator = mitmIndicatorOf(
      enabled: true,
      coreConnected: true,
      coreRefused: false,
      status: const MitmStatus(enable: true, paused: 'partialConnections'),
      trusted: true,
      hostsListed: true,
    );
    expect(indicator, const MitmIndicator.on());
    expect(
      mitmTrayDot(indicator),
      const TrayDot(color: 0xFFFF3B30, breathing: true),
    );
  });
}
