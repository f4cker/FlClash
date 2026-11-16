import 'package:fl_clash/common/app_localizations.dart';
import 'package:fl_clash/common/tray.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:rust_api/tray.dart';

import '../helpers/fake_tray_host.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

TrayState _trayState({bool isStart = false}) {
  return TrayState(
    mode: Mode.rule,
    port: 7890,
    autoLaunch: false,
    systemProxy: false,
    tunEnable: false,
    isStart: isStart,
    groups: const [],
    selectedMap: const {},
    showTrayTitle: false,
    safeMode: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTrayHost host;
  late ProviderContainer container;
  late _MockCore core;

  setUpAll(() async {
    loadAppLocalizations(const Locale('en'));
  });

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    host = FakeTrayHost();
    core = _MockCore();
    container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    Tray.instance.resetForTesting(host);
  });

  tearDown(() {
    container.dispose();
    verifyZeroInteractions(core);
    debugDefaultTargetPlatformOverride = null;
  });

  test('shutdown stops any later update from resurrecting the tray', () async {
    final tray = AppTray.forPlatform(isMacOS: false, isWindows: false);
    await tray.update(
      trayState: _trayState(),
      traffic: const Traffic(),
      read: container.read,
    );
    expect(host.shown, hasLength(1));

    await tray.shutdown();
    expect(host.hideCount, 1);

    host.clear();
    await tray.update(
      trayState: _trayState(isStart: true),
      traffic: const Traffic(),
      read: container.read,
    );
    await tray.updateTitle(showTrayTitle: true, traffic: const Traffic());

    expect(host.callCount, 0);
  });

  test('macOS shutdown leaves the status item to the process', () async {
    final tray = AppTray.forPlatform(isMacOS: true, isWindows: false);
    await tray.update(
      trayState: _trayState(),
      traffic: const Traffic(),
      read: container.read,
    );

    await tray.shutdown();
    expect(host.hideCount, 0);

    host.clear();
    await tray.update(
      trayState: _trayState(isStart: true),
      traffic: const Traffic(),
      read: container.read,
    );

    expect(host.callCount, 0);
  });
}
