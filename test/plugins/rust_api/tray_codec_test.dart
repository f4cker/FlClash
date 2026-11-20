import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rust_api/src/tray/tray_codec.dart';
import 'package:rust_api/tray.dart';

// Flash's menu decorations, transient status rows and segment groups, as
// they reach the Rust host.

TraySpec _spec({List<TrayMenuItem> menu = const []}) {
  return TraySpec(
    icon: const TrayIcon.asset('assets/icon.png'),
    toolTip: 'Flash',
    menu: menu,
  );
}

void main() {
  test('transient status has a semantic key but no action callback', () {
    const status = TrayMenuAction.status(
      statusKey: 'outbound-mode',
      label: 'Switching to Global',
      accessibilityLabel: 'Switching to Global mode',
    );
    final encoded = TrayCodec.encode(
      _spec(
        menu: const [
          status,
          TrayMenuAction(label: 'ordinary'),
        ],
      ),
    );
    final first = encoded.menu.first;
    expect(first.id, 1024);
    expect(first.kind, TrayItemKind.action);
    expect(first.transientStatusKey, 'outbound-mode');
    expect(first.label, 'Switching to Global');
    expect(first.accessibilityLabel, 'Switching to Global mode');
    expect(first.enabled, isFalse);
    expect(status.enabled, isFalse);
    expect(status.onSelected, isNull);
    expect(encoded.menu.last.transientStatusKey, isNull);
    expect(encoded.menu.last.id, 1025);
    expect(encoded.itemsById[1024], same(status));
  });

  test('signature distinguishes a transient status from an ordinary row', () {
    final status = TrayCodec.encode(
      _spec(
        menu: const [
          TrayMenuAction.status(statusKey: 'mode', label: 'Pending'),
        ],
      ),
    );
    final ordinary = TrayCodec.encode(
      _spec(menu: const [TrayMenuAction(label: 'Pending', enabled: false)]),
    );
    expect(status.signature, isNot(ordinary.signature));
  });

  test(
    'segment metadata preserves per-option callback ids and checked state',
    () {
      final encoded = TrayCodec.encode(
        _spec(
          menu: const [
            TrayMenuCheckbox(
              label: 'Rule',
              checked: true,
              segmentGroup: 'mode',
              segmentError: 'reason',
            ),
            TrayMenuCheckbox(
              label: 'Global',
              checked: false,
              segmentGroup: 'mode',
              enabled: false,
            ),
            TrayMenuCheckbox(
              label: 'Direct',
              checked: false,
              segmentGroup: 'mode',
            ),
          ],
        ),
      );
      final rows = encoded.menu;
      expect(rows.map((row) => row.segmentGroup), everyElement('mode'));
      expect(rows.map((row) => row.id), [1024, 1025, 1026]);
      expect(rows.first.segmentError, 'reason');
      expect(rows.first.checked, isTrue);
      expect(rows[1].enabled, isFalse);
      expect(encoded.itemsById[1026], isA<TrayMenuCheckbox>());
    },
  );

  test('decorations encode additively on every actionable row type', () {
    final bytes = Uint8List.fromList([137, 80, 78, 71]);
    final icon = TrayMenuIcon(
      monogram: 'HK',
      background: 0xffeeeeee,
      foreground: 0xff222222,
      pngBytes: bytes,
    );
    const badge = TrayMenuBadge(
      label: '10000 ms',
      background: 0xff112233,
      foreground: 0xffeeeeee,
    );
    final encoded = TrayCodec.encode(
      _spec(
        menu: [
          TrayMenuAction(
            label: 'a',
            icon: icon,
            badge: badge,
            accessibilityLabel: 'Full action',
          ),
          TrayMenuCheckbox(
            label: 'b',
            checked: true,
            icon: icon,
            badge: badge,
            accessibilityLabel: 'Full checkbox',
          ),
          TrayMenuSubmenu(
            label: 'c',
            items: const [],
            icon: icon,
            badge: badge,
            accessibilityLabel: 'Full group',
          ),
          const TrayMenuAction(label: 'plain'),
        ],
      ),
    );
    for (final item in encoded.menu.take(3)) {
      expect(item.icon!.monogram, 'HK');
      expect(item.icon!.background, 0xffeeeeee);
      expect(item.icon!.foreground, 0xff222222);
      expect(item.icon!.png, bytes);
      expect(
        item.badge,
        const TrayItemBadge(
          label: '10000 ms',
          background: 0xff112233,
          foreground: 0xffeeeeee,
        ),
      );
      expect(item.accessibilityLabel, startsWith('Full'));
    }
    final plain = encoded.menu.last;
    expect(plain.icon, isNull);
    expect(plain.badge, isNull);
    expect(plain.accessibilityLabel, isNull);
    expect(plain.transientStatusKey, isNull);
    expect(plain.segmentGroup, isNull);
  });

  test('signature tracks every decoration field and enabled state', () {
    String signature({
      String monogram = 'A',
      int background = 1,
      int foreground = 2,
      Uint8List? png,
      String badgeLabel = '8 ms',
      int badgeBackground = 3,
      int badgeForeground = 4,
      String accessibilityLabel = 'Full',
      bool enabled = true,
    }) => TrayCodec.encode(
      _spec(
        menu: [
          TrayMenuAction(
            label: 'a',
            enabled: enabled,
            accessibilityLabel: accessibilityLabel,
            icon: TrayMenuIcon(
              monogram: monogram,
              background: background,
              foreground: foreground,
              pngBytes: png,
            ),
            badge: TrayMenuBadge(
              label: badgeLabel,
              background: badgeBackground,
              foreground: badgeForeground,
            ),
          ),
        ],
      ),
    ).signature;
    final base = signature();
    for (final changed in [
      signature(monogram: 'B'),
      signature(background: 5),
      signature(foreground: 5),
      signature(png: Uint8List.fromList([1])),
      signature(badgeLabel: '9 ms'),
      signature(badgeBackground: 5),
      signature(badgeForeground: 5),
      signature(accessibilityLabel: 'Other'),
      signature(enabled: false),
    ]) {
      expect(changed, isNot(base));
    }
  });

  test('signature follows the dot colour and breathing', () {
    String signature(TrayDot? dot) => TrayCodec.encode(
      TraySpec(icon: TrayIcon.asset('assets/icon.png', dot: dot)),
    ).signature;
    const red = TrayDot(color: 0xFFFF3B30, breathing: false);
    const breathing = TrayDot(color: 0xFFFF3B30, breathing: true);
    const amber = TrayDot(color: 0xFFFF9F0A, breathing: false);
    final signatures = {
      signature(null),
      signature(red),
      signature(breathing),
      signature(amber),
    };
    expect(signatures, hasLength(4));
    expect(signature(red), signature(red));
  });

  test('an action that keeps the menu open says so, and nothing else does', () {
    String signature(bool keepsMenuOpen) => TrayCodec.encode(
      _spec(
        menu: [TrayMenuAction(label: 'Test', keepsMenuOpen: keepsMenuOpen)],
      ),
    ).signature;
    final encoded = TrayCodec.encode(
      _spec(
        menu: const [
          TrayMenuAction(label: 'Test', keepsMenuOpen: true),
          TrayMenuAction(label: 'Show'),
          TrayMenuAction.status(statusKey: 'mode', label: 'Pending'),
        ],
      ),
    );
    expect(encoded.menu.map((item) => item.keepsMenuOpen), [
      true,
      false,
      false,
    ]);
    expect(signature(true), isNot(signature(false)));
  });
}
