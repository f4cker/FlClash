import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust_api/tray.dart';

import '../../helpers/fake_tray_host.dart';

// Flash's macOS menu generations: an open menu may outlive the content that
// built it, so selections name the generation they were made in.

TraySpec _spec({List<TrayMenuItem> menu = const []}) {
  return TraySpec(
    icon: const TrayIcon.asset('assets/images/tray/unix/status_1.png'),
    toolTip: 'Flash',
    menu: menu,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTrayHost host;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    host = FakeTrayHost();
    Tray.instance.resetForTesting(host);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> select(int id, [int menuGeneration = 0]) async {
    host.emit(TraySignalKind.itemSelected, id, menuGeneration);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> generations(List<int> generations, {int? tracking}) async {
    host.emitMenuGenerations(generations, tracking: tracking);
    await Future<void>.delayed(Duration.zero);
  }

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
      await select(1024);
      await select(1025);
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
      final oldGeneration = host.lastShown!.menuGeneration;
      await Tray.instance.show(
        _spec(
          menu: [TrayMenuAction(label: 'new', onSelected: () => newSelected++)],
        ),
      );
      final generation = host.lastShown!.menuGeneration;
      expect(generation, isNot(oldGeneration));
      await select(1024, oldGeneration);
      await select(1024);
      expect([oldSelected, newSelected], [0, 0]);
      await select(1024, generation);
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
      final generation = host.lastShown!.menuGeneration;
      await Tray.instance.show(
        _spec(
          menu: [TrayMenuAction(label: 'same', onSelected: () => selected++)],
        ),
      );
      expect(host.shown, hasLength(1));
      await select(1024, generation);
      expect(selected, 1);
      await Tray.instance.hide();
      await select(1024, generation);
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
      final generation = host.lastShown!.menuGeneration;
      host.showResult = false;
      await Tray.instance.show(
        _spec(
          menu: [TrayMenuAction(label: 'new', onSelected: () => newSelected++)],
        ),
      );
      final rejectedGeneration = host.lastShown!.menuGeneration;
      await select(1024, rejectedGeneration);
      await select(1024, generation);
      expect([oldSelected, newSelected], [1, 0]);
      await Tray.instance.hide();
      host.showResult = true;
      await Tray.instance.show(
        _spec(
          menu: [TrayMenuAction(label: 'new', onSelected: () => newSelected++)],
        ),
      );
      await select(1024, generation);
      expect([oldSelected, newSelected], [1, 0]);
      final newGeneration = host.lastShown!.menuGeneration;
      expect(newGeneration, isNot(generation));
      await select(1024, newGeneration);
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
      final oldGeneration = host.lastShown!.menuGeneration;
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
      final generation = host.lastShown!.menuGeneration;
      final row = host.lastShown!.menu.single;
      expect(row.checked, isTrue);
      expect(
        row.badge,
        const TrayItemBadge(label: '10000 ms', background: 3, foreground: 4),
      );
      await select(1024, generation);
      expect([oldSelected, refreshedSelected], [0, 1]);
      await select(1024, oldGeneration);
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
      final disabledGeneration = host.lastShown!.menuGeneration;
      await select(1024, disabledGeneration);
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
      final trackedGeneration = host.lastShown!.menuGeneration;
      await Tray.instance.openMenu();
      host.trackingGeneration = trackedGeneration;
      host.generationsForShow = (generation) => [trackedGeneration, generation];
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
      final desiredGeneration = host.lastShown!.menuGeneration;
      await select(1024, trackedGeneration);
      expect([trackedSelected, insertedSelected, shiftedSelected], [1, 0, 0]);
      await generations([trackedGeneration, desiredGeneration]);
      await select(1024, trackedGeneration);
      expect(
        [trackedSelected, insertedSelected, shiftedSelected],
        [2, 0, 0],
        reason: 'AppKit may send the selection after menuDidClose',
      );
      await select(1025, desiredGeneration);
      expect([trackedSelected, insertedSelected, shiftedSelected], [2, 0, 1]);
      await generations([desiredGeneration]);
      await select(1024, trackedGeneration);
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
      final trackedGeneration = host.lastShown!.menuGeneration;
      host.trackingGeneration = trackedGeneration;
      host.generationsForShow = (generation) => [trackedGeneration, generation];
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
        generations.add(host.lastShown!.menuGeneration);
      }
      for (final generation in generations.take(generations.length - 1)) {
        await select(1024, generation);
      }
      expect(selected, isEmpty);
      await select(1024, trackedGeneration);
      await select(1025, generations.last);
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
      final tracked = host.lastShown!.menuGeneration;
      host.trackingGeneration = tracked;
      host.generationsForShow = (generation) => [tracked, generation];
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
      await select(1025, tracked);
      await select(1026, tracked);
      expect(
        [selected, removedSelected, newSelected],
        [1, 0, 0],
        reason:
            'the retained HK tag keeps its original callback; removed rows never target desired IDs',
      );
      await Tray.instance.show(updated(enabled: false));
      await select(1025, tracked);
      expect(
        selected,
        1,
        reason: 'live disabled state must also reject programmatic events',
      );
      await Tray.instance.show(updated(duplicate: true));
      await select(1025, tracked);
      expect(
        selected,
        1,
        reason: 'ambiguous sibling identities are disabled, not guessed',
      );
      await Tray.instance.show(updated());
      await select(1025, tracked);
      expect(
        selected,
        2,
        reason:
            'a row initially enabled can re-enable after a temporary disable',
      );
    },
  );

  test(
    'macOS mode segments opened pending can re-enable in a retained generation',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      var selected = 0;
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuCheckbox(
              label: 'Direct',
              checked: false,
              enabled: false,
              segmentGroup: 'mode',
              onSelected: () => selected++,
            ),
            const TrayMenuAction.status(statusKey: 'mode', label: 'Pending'),
          ],
        ),
      );
      final tracked = host.lastShown!.menuGeneration;
      host.trackingGeneration = tracked;
      host.generationsForShow = (generation) => [tracked, generation];
      await Tray.instance.openMenu();
      await select(1024, tracked);
      expect(selected, 0);
      await Tray.instance.show(
        _spec(
          menu: [
            TrayMenuCheckbox(
              label: 'Direct',
              checked: false,
              segmentGroup: 'mode',
              onSelected: () => selected += 100,
            ),
          ],
        ),
      );
      await select(1024, tracked);
      expect(selected, 1);
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
      final tracked = host.lastShown!.menuGeneration;
      host.trackingGeneration = tracked;
      host.generationsForShow = (generation) => [tracked, generation];
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
      final desired = host.lastShown!.menuGeneration;
      await select(1026, tracked);
      expect([oldSelected, newSelected], [0, 0]);
      await generations([tracked, desired], tracking: desired);
      await select(1025, desired);
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
      final generation = host.lastShown!.menuGeneration;
      // The tracking signal for A arrives while B is still pending, and
      // the host then refuses B.
      host.onShow = (_) {
        host.emitMenuGenerations([generation], tracking: generation);
        return false;
      };
      await Tray.instance.show(_spec(menu: const [TrayMenuAction(label: 'B')]));
      host.onShow = null;
      await select(1024, generation);
      expect(
        selected,
        1,
        reason: 'unaccepted B must not disable callbacks of still-visible A',
      );
    },
  );
}
