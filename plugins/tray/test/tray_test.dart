import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray/tray.dart';

const MethodChannel _channel = MethodChannel('tray');
const StandardMethodCodec _codec = StandardMethodCodec();

TraySpec _spec({List<TrayMenuItem> menu = const []}) {
  return TraySpec(
    icon: const TrayIcon.asset('assets/icon.ico'),
    toolTip: 'FlClash',
    menu: menu,
  );
}

Future<void> _emit(String method, Object? arguments) {
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _channel.name,
        _codec.encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;
  late bool showResult;
  Completer<void>? showGate;
  List<int> Function(int generation)? nativeGenerationsForShow;
  int? nativeTrackingGeneration;

  int showCount() => calls.where((call) => call.method == 'show').length;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    calls = [];
    showResult = true;
    showGate = null;
    nativeGenerationsForShow = null;
    nativeTrackingGeneration = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          if (call.method == 'show') {
            await showGate?.future;
            if (showResult &&
                debugDefaultTargetPlatformOverride == TargetPlatform.macOS) {
              final generation =
                  (call.arguments as Map)['menuGeneration'] as int;
              await _emit('onMenuGenerations', {
                'generations':
                    nativeGenerationsForShow?.call(generation) ?? [generation],
                'trackingGeneration': ?nativeTrackingGeneration,
              });
            }
            return showResult;
          }
          return true;
        });
    Tray.instance.resetForTesting();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    Tray.instance.resetForTesting();
    debugDefaultTargetPlatformOverride = null;
  });

  test('a rejected show stays invisible and is retried', () async {
    showResult = false;
    await Tray.instance.show(_spec());

    expect(showCount(), 1);
    expect(Tray.instance.isVisible, isFalse);

    showResult = true;
    await Tray.instance.show(_spec());

    expect(showCount(), 2);
    expect(Tray.instance.isVisible, isTrue);
  });

  test(
    'an unchanged payload is suppressed only after an accepted show',
    () async {
      showResult = true;
      await Tray.instance.show(_spec());
      await Tray.instance.show(_spec());

      expect(showCount(), 1);

      showResult = false;
      await Tray.instance.show(_spec(menu: const [TrayMenuAction(label: 'a')]));
      await Tray.instance.show(_spec(menu: const [TrayMenuAction(label: 'a')]));

      expect(showCount(), 3);
    },
  );

  test('titles queued behind a stalled call collapse to the newest', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await Tray.instance.show(_spec());

    final gate = Completer<void>();
    showGate = gate;
    final stalled = Tray.instance.show(
      _spec(menu: const [TrayMenuAction(label: 'a')]),
    );
    unawaited(Tray.instance.setTitle('1'));
    unawaited(Tray.instance.setTitle('2'));
    final settled = Tray.instance.setTitle('3');
    gate.complete();
    await stalled;
    await settled;

    final titles = calls
        .where((call) => call.method == 'setTitle')
        .map((call) => (call.arguments as Map)['title'])
        .toList();
    expect(
      titles,
      ['3'],
      reason:
          'a native call that blocks the queue must not replay every title '
          'that piled up behind it',
    );
  });

  test('menu selection dispatches only for known integer ids', () async {
    var selected = 0;
    await Tray.instance.show(
      _spec(
        menu: [TrayMenuAction(label: 'a', onSelected: () => selected++)],
      ),
    );

    await _emit('onMenuItemSelected', <String, Object?>{'id': 1024});
    expect(selected, 1);

    await _emit('onMenuItemSelected', <String, Object?>{'id': 4096});
    await _emit('onMenuItemSelected', <String, Object?>{'id': '1024'});
    await _emit('onMenuItemSelected', null);
    expect(selected, 1);
  });

  test(
    'disabled actions and checkboxes never dispatch programmatically',
    () async {
      var selected = 0;
      final events = <TrayEvent>[];
      final subscription = Tray.instance.events.listen(events.add);
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuAction(
              label: 'disabled',
              enabled: false,
              onSelected: () => selected++,
            ),
            TrayMenuCheckbox(
              label: 'disabled check',
              checked: true,
              enabled: false,
              onSelected: () => selected++,
            ),
          ],
        ),
      );
      await _emit('onMenuItemSelected', {'id': 1024});
      await _emit('onMenuItemSelected', {'id': 1025});
      await Future<void>.delayed(Duration.zero);
      expect(selected, 0);
      expect(events, isEmpty);
      await subscription.cancel();
    },
  );

  test(
    'macOS rejects stale positional IDs after replacing a tracked menu',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      var oldSelected = 0;
      var newSelected = 0;
      await Tray.instance.show(
        _spec(
          menu: [TrayMenuAction(label: 'old', onSelected: () => oldSelected++)],
        ),
      );
      final oldGeneration = (calls.last.arguments as Map)['menuGeneration'];
      await Tray.instance.show(
        _spec(
          menu: [TrayMenuAction(label: 'new', onSelected: () => newSelected++)],
        ),
      );
      final generation = (calls.last.arguments as Map)['menuGeneration'];
      expect(generation, isNot(oldGeneration));
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': oldGeneration,
      });
      await _emit('onMenuItemSelected', {'id': 1024});
      expect([oldSelected, newSelected], [0, 0]);
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': generation,
      });
      expect([oldSelected, newSelected], [0, 1]);
    },
  );

  test(
    'macOS unchanged payload refreshes callbacks without changing generation',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      var selected = 0;
      await Tray.instance.show(
        _spec(menu: const [TrayMenuAction(label: 'same')]),
      );
      final generation = (calls.last.arguments as Map)['menuGeneration'];
      await Tray.instance.show(
        _spec(
          menu: [TrayMenuAction(label: 'same', onSelected: () => selected++)],
        ),
      );
      expect(showCount(), 1);
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': generation,
      });
      expect(selected, 1);
      await Tray.instance.hide();
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': generation,
      });
      expect(selected, 1);
    },
  );

  test(
    'macOS rejected show retains the visible generation and callbacks',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      var oldSelected = 0;
      var newSelected = 0;
      await Tray.instance.show(
        _spec(
          menu: [TrayMenuAction(label: 'old', onSelected: () => oldSelected++)],
        ),
      );
      final generation = (calls.last.arguments as Map)['menuGeneration'];
      showResult = false;
      await Tray.instance.show(
        _spec(
          menu: [TrayMenuAction(label: 'new', onSelected: () => newSelected++)],
        ),
      );
      final rejectedGeneration =
          (calls.last.arguments as Map)['menuGeneration'];
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': rejectedGeneration,
      });
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': generation,
      });
      expect([oldSelected, newSelected], [1, 0]);
      await Tray.instance.hide();
      showResult = true;
      await Tray.instance.show(
        _spec(
          menu: [TrayMenuAction(label: 'new', onSelected: () => newSelected++)],
        ),
      );
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': generation,
      });
      expect([oldSelected, newSelected], [1, 0]);
      final newGeneration = (calls.last.arguments as Map)['menuGeneration'];
      expect(newGeneration, isNot(generation));
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': newGeneration,
      });
      expect([oldSelected, newSelected], [1, 1]);
    },
  );

  test(
    'macOS badge-only live refresh dispatches the reconciled same row',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      var oldSelected = 0;
      var refreshedSelected = 0;
      const pending = TrayMenuBadge(
        label: 'Testing…',
        background: 1,
        foreground: 2,
      );
      const ready = TrayMenuBadge(
        label: '10000 ms',
        background: 3,
        foreground: 4,
      );
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuCheckbox(
              label: 'HK',
              checked: false,
              badge: pending,
              accessibilityLabel: 'HK, testing',
              onSelected: () => oldSelected++,
            ),
          ],
        ),
      );
      final oldGeneration = (calls.last.arguments as Map)['menuGeneration'];
      await Tray.instance.openMenu();
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuCheckbox(
              label: 'HK',
              checked: true,
              badge: ready,
              accessibilityLabel: 'HK, selected, 10000 milliseconds',
              onSelected: () => refreshedSelected++,
            ),
          ],
        ),
      );
      final arguments = calls.last.arguments as Map;
      final generation = arguments['menuGeneration'];
      final row = (arguments['menu'] as List).single as Map;
      expect(row['checked'], isTrue);
      expect(row['badge'], {
        'label': '10000 ms',
        'background': 3,
        'foreground': 4,
      });
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': generation,
      });
      expect([oldSelected, refreshedSelected], [0, 1]);
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': oldGeneration,
      });
      expect([oldSelected, refreshedSelected], [0, 1]);
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuCheckbox(
              label: 'HK',
              checked: true,
              enabled: false,
              badge: ready,
              onSelected: () => refreshedSelected++,
            ),
          ],
        ),
      );
      final disabledGeneration =
          (calls.last.arguments as Map)['menuGeneration'];
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': disabledGeneration,
      });
      expect(refreshedSelected, 1);
    },
  );

  test(
    'macOS structural shifts preserve tracked callbacks even after close',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      var trackedSelected = 0;
      var insertedSelected = 0;
      var shiftedSelected = 0;
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuAction(label: 'HK', onSelected: () => trackedSelected++),
          ],
        ),
      );
      final trackedGeneration =
          (calls.last.arguments as Map)['menuGeneration'] as int;
      await Tray.instance.openMenu();
      nativeTrackingGeneration = trackedGeneration;
      nativeGenerationsForShow = (generation) => [
        trackedGeneration,
        generation,
      ];
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuAction(
              label: 'Inserted',
              onSelected: () => insertedSelected++,
            ),
            TrayMenuAction(label: 'HK', onSelected: () => shiftedSelected++),
          ],
        ),
      );
      final desiredGeneration =
          (calls.last.arguments as Map)['menuGeneration'] as int;
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': trackedGeneration,
      });
      expect([trackedSelected, insertedSelected, shiftedSelected], [1, 0, 0]);
      await _emit('onMenuGenerations', [trackedGeneration, desiredGeneration]);
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': trackedGeneration,
      });
      expect(
        [trackedSelected, insertedSelected, shiftedSelected],
        [2, 0, 0],
        reason: 'AppKit may send the selection after menuDidClose',
      );
      await _emit('onMenuItemSelected', {
        'id': 1025,
        'menuGeneration': desiredGeneration,
      });
      expect([trackedSelected, insertedSelected, shiftedSelected], [2, 0, 1]);
      await _emit('onMenuGenerations', [desiredGeneration]);
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': trackedGeneration,
      });
      expect([trackedSelected, insertedSelected, shiftedSelected], [2, 0, 1]);
    },
  );

  test(
    'macOS superseded desired generations are retired while tracking stays usable',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final selected = <int>[];
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuAction(
              label: 'tracked',
              onSelected: () => selected.add(-1),
            ),
          ],
        ),
      );
      final trackedGeneration =
          (calls.last.arguments as Map)['menuGeneration'] as int;
      nativeTrackingGeneration = trackedGeneration;
      nativeGenerationsForShow = (generation) => [
        trackedGeneration,
        generation,
      ];
      final generations = <int>[];
      for (var index = 0; index < 12; index++) {
        final captured = index;
        await Tray.instance.show(
          _spec(
            menu: [
              const TrayMenuAction(label: 'tracked'),
              TrayMenuAction(
                label: 'desired $captured',
                onSelected: () => selected.add(captured),
              ),
            ],
          ),
        );
        generations.add((calls.last.arguments as Map)['menuGeneration'] as int);
      }
      for (final generation in generations.take(generations.length - 1)) {
        await _emit('onMenuItemSelected', {
          'id': 1024,
          'menuGeneration': generation,
        });
      }
      expect(selected, isEmpty);
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': trackedGeneration,
      });
      await _emit('onMenuItemSelected', {
        'id': 1025,
        'menuGeneration': generations.last,
      });
      expect(selected, [-1, 11]);
    },
  );

  test(
    'macOS structural status insertion patches shared rows without retargeting callbacks',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      var selected = 0;
      var removedSelected = 0;
      var newSelected = 0;
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuSubmenu(
              label: 'group',
              detail: 'Ready',
              items: [
                TrayMenuCheckbox(
                  label: 'HK',
                  checked: false,
                  onSelected: () => selected++,
                ),
                TrayMenuAction(
                  label: 'Removed',
                  onSelected: () => removedSelected++,
                ),
              ],
            ),
          ],
        ),
      );
      final tracked = (calls.last.arguments as Map)['menuGeneration'] as int;
      nativeTrackingGeneration = tracked;
      nativeGenerationsForShow = (generation) => [tracked, generation];
      await Tray.instance.openMenu();
      TraySpec updated({bool enabled = true, bool duplicate = false}) => _spec(
        menu: [
          TrayMenuSubmenu(
            label: 'group',
            detail: 'Failed',
            items: [
              const TrayMenuAction(label: 'Failure status', enabled: false),
              TrayMenuCheckbox(
                label: 'HK',
                checked: true,
                enabled: enabled,
                badge: const TrayMenuBadge(
                  label: '10000 ms',
                  background: 1,
                  foreground: 2,
                ),
                onSelected: () => newSelected++,
              ),
              if (duplicate) const TrayMenuCheckbox(label: 'HK', checked: true),
            ],
          ),
        ],
      );
      await Tray.instance.show(updated());
      await _emit('onMenuItemSelected', {
        'id': 1025,
        'menuGeneration': tracked,
      });
      await _emit('onMenuItemSelected', {
        'id': 1026,
        'menuGeneration': tracked,
      });
      expect(
        [selected, removedSelected, newSelected],
        [1, 0, 0],
        reason:
            'the retained HK tag keeps its original callback; removed rows never target desired IDs',
      );
      await Tray.instance.show(updated(enabled: false));
      await _emit('onMenuItemSelected', {
        'id': 1025,
        'menuGeneration': tracked,
      });
      expect(
        selected,
        1,
        reason: 'live disabled state must also reject programmatic events',
      );
      await Tray.instance.show(updated(duplicate: true));
      await _emit('onMenuItemSelected', {
        'id': 1025,
        'menuGeneration': tracked,
      });
      expect(
        selected,
        1,
        reason: 'ambiguous sibling identities are disabled, not guessed',
      );
      await Tray.instance.show(updated());
      await _emit('onMenuItemSelected', {
        'id': 1025,
        'menuGeneration': tracked,
      });
      expect(
        selected,
        2,
        reason:
            'a row initially enabled can re-enable after a temporary disable',
      );
    },
  );

  test(
    'macOS originally-disabled retained rows stay disabled until reopen',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      var oldSelected = 0;
      var newSelected = 0;
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuSubmenu(
              label: 'group',
              items: [
                const TrayMenuAction(label: 'Pending', enabled: false),
                TrayMenuCheckbox(
                  label: 'HK',
                  checked: false,
                  enabled: false,
                  onSelected: () => oldSelected++,
                ),
              ],
            ),
          ],
        ),
      );
      final tracked = (calls.last.arguments as Map)['menuGeneration'] as int;
      nativeTrackingGeneration = tracked;
      nativeGenerationsForShow = (generation) => [tracked, generation];
      await Tray.instance.openMenu();
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuSubmenu(
              label: 'group',
              items: [
                TrayMenuCheckbox(
                  label: 'HK',
                  checked: true,
                  onSelected: () => newSelected++,
                ),
              ],
            ),
          ],
        ),
      );
      final desired = (calls.last.arguments as Map)['menuGeneration'] as int;
      await _emit('onMenuItemSelected', {
        'id': 1026,
        'menuGeneration': tracked,
      });
      expect([oldSelected, newSelected], [0, 0]);
      await _emit('onMenuGenerations', {
        'generations': [tracked, desired],
        'trackingGeneration': desired,
      });
      await _emit('onMenuItemSelected', {
        'id': 1025,
        'menuGeneration': desired,
      });
      expect([oldSelected, newSelected], [0, 1]);
    },
  );

  test(
    'macOS old-only tracking events cannot reconcile an unaccepted pending show',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      var selected = 0;
      await Tray.instance.show(
        _spec(
          menu: [TrayMenuAction(label: 'A', onSelected: () => selected++)],
        ),
      );
      final generation = (calls.last.arguments as Map)['menuGeneration'] as int;
      final entered = Completer<void>();
      final gate = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            if (call.method == 'show') {
              entered.complete();
              await gate.future;
              return false;
            }
            return true;
          });
      final rejected = Tray.instance.show(
        _spec(menu: const [TrayMenuAction(label: 'B')]),
      );
      await entered.future;
      await _emit('onMenuGenerations', {
        'generations': [generation],
        'trackingGeneration': generation,
      });
      gate.complete();
      await rejected;
      await _emit('onMenuItemSelected', {
        'id': 1024,
        'menuGeneration': generation,
      });
      expect(
        selected,
        1,
        reason: 'unaccepted B must not disable callbacks of still-visible A',
      );
    },
  );

  test('a rejected show keeps callbacks for the visible menu', () async {
    var oldSelected = 0;
    var newSelected = 0;
    await Tray.instance.show(
      _spec(
        menu: [TrayMenuAction(label: 'old', onSelected: () => oldSelected++)],
      ),
    );

    showResult = false;
    await Tray.instance.show(
      _spec(
        menu: [TrayMenuAction(label: 'new', onSelected: () => newSelected++)],
      ),
    );
    await _emit('onMenuItemSelected', <String, Object?>{'id': 1024});

    expect([oldSelected, newSelected], [1, 0]);
  });

  test(
    'an unchanged accepted show refreshes callbacks without a native show',
    () async {
      var oldSelected = 0;
      var newSelected = 0;
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuAction(label: 'item', onSelected: () => oldSelected++),
          ],
        ),
      );
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuAction(label: 'item', onSelected: () => newSelected++),
          ],
        ),
      );
      await _emit('onMenuItemSelected', <String, Object?>{'id': 1024});

      expect(showCount(), 1);
      expect([oldSelected, newSelected], [0, 1]);
    },
  );
}
