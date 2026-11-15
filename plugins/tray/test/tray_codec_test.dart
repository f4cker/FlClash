import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tray/src/tray_codec.dart';
import 'package:tray/tray.dart';

TraySpec _spec({
  String asset = 'assets/icon.png',
  String toolTip = 'FlClash',
  List<TrayMenuItem> menu = const [],
}) {
  return TraySpec(icon: TrayIcon.asset(asset), toolTip: toolTip, menu: menu);
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
    final rows = encoded.menu.cast<Map<String, Object?>>();
    expect(rows.first, {
      'id': 1024,
      'type': 'action',
      'transientStatusKey': 'outbound-mode',
      'label': 'Switching to Global',
      'accessibilityLabel': 'Switching to Global mode',
      'enabled': false,
    });
    expect(status.enabled, isFalse);
    expect(status.onSelected, isNull);
    expect(rows.last.containsKey('transientStatusKey'), isFalse);
    expect(rows.last['id'], 1025);
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
      final rows = encoded.menu.cast<Map<String, Object?>>();
      expect(rows.map((row) => row['segmentGroup']), everyElement('mode'));
      expect(rows.map((row) => row['id']), [1024, 1025, 1026]);
      expect(rows.first['segmentError'], 'reason');
      expect(rows.first['checked'], true);
      expect(rows[1]['enabled'], false);
      expect(encoded.itemsById[1026], isA<TrayMenuCheckbox>());
    },
  );

  test('assigns ids in pre-order starting at the first id', () {
    final encoded = TrayCodec.encode(
      _spec(
        menu: const [
          TrayMenuAction(label: 'a'),
          TrayMenuSubmenu(
            label: 'group',
            items: [
              TrayMenuAction(label: 'child'),
              TrayMenuAction(label: 'other'),
            ],
          ),
          TrayMenuAction(label: 'b'),
        ],
      ),
    );

    final top = encoded.menu.cast<Map<String, Object?>>();
    expect(top.map((item) => item['id']), [1024, 1025, 1028]);

    final children = (top[1]['items']! as List).cast<Map<String, Object?>>();
    expect(children.map((item) => item['id']), [1026, 1027]);
    expect(encoded.itemsById.keys, [1024, 1025, 1026, 1027, 1028]);
  });

  test('resolves every dispatchable id back to its item', () {
    const action = TrayMenuAction(label: 'a');
    const checkbox = TrayMenuCheckbox(label: 'b', checked: true);
    final encoded = TrayCodec.encode(_spec(menu: const [action, checkbox]));

    expect(encoded.itemsById[1024], same(action));
    expect(encoded.itemsById[1025], same(checkbox));
  });

  test('signature ignores callback identity', () {
    String signatureWith(void Function() onSelected) {
      return TrayCodec.encode(
        _spec(
          menu: [TrayMenuAction(label: 'a', onSelected: onSelected)],
        ),
      ).signature;
    }

    expect(signatureWith(() {}), signatureWith(() {}));
  });

  test('signature tracks label, checked state, tooltip and icon', () {
    final base = TrayCodec.encode(
      _spec(menu: const [TrayMenuCheckbox(label: 'a', checked: false)]),
    ).signature;

    expect(
      TrayCodec.encode(
        _spec(menu: const [TrayMenuCheckbox(label: 'a', checked: true)]),
      ).signature,
      isNot(base),
    );
    expect(
      TrayCodec.encode(
        _spec(menu: const [TrayMenuCheckbox(label: 'b', checked: false)]),
      ).signature,
      isNot(base),
    );
    expect(
      TrayCodec.encode(
        _spec(
          toolTip: 'other',
          menu: const [TrayMenuCheckbox(label: 'a', checked: false)],
        ),
      ).signature,
      isNot(base),
    );
    expect(
      TrayCodec.encode(
        _spec(
          asset: 'assets/other.png',
          menu: const [TrayMenuCheckbox(label: 'a', checked: false)],
        ),
      ).signature,
      isNot(base),
    );
  });

  test('detail is serialized only when it has text', () {
    final encoded = TrayCodec.encode(
      _spec(
        menu: const [
          TrayMenuAction(label: 'a', detail: '⌃⌥S'),
          TrayMenuCheckbox(label: 'b', checked: true, detail: '88 ms'),
          TrayMenuSubmenu(label: 'c', detail: 'HK', items: []),
          TrayMenuAction(label: 'd'),
          TrayMenuAction(label: 'e', detail: ''),
        ],
      ),
    );

    final items = encoded.menu.cast<Map<String, Object?>>();
    expect(items.map((item) => item['detail']), [
      '⌃⌥S',
      '88 ms',
      'HK',
      null,
      null,
    ]);
    expect(items[3].containsKey('detail'), isFalse);
    expect(items[4].containsKey('detail'), isFalse);
  });

  test('signature tracks the detail', () {
    String signatureWith(String? detail) {
      return TrayCodec.encode(
        _spec(
          menu: [TrayMenuAction(label: 'a', detail: detail)],
        ),
      ).signature;
    }

    expect(signatureWith('88 ms'), isNot(signatureWith('90 ms')));
    expect(signatureWith(null), isNot(signatureWith('88 ms')));
  });

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
    final items = encoded.menu.cast<Map<String, Object?>>();
    for (final item in items.take(3)) {
      expect(item['icon'], {
        'monogram': 'HK',
        'background': 0xffeeeeee,
        'foreground': 0xff222222,
        'png': base64Encode(bytes),
      });
      expect(item['badge'], {
        'label': '10000 ms',
        'background': 0xff112233,
        'foreground': 0xffeeeeee,
      });
      expect(item['accessibilityLabel'], startsWith('Full'));
    }
    expect(items.last.keys, ['id', 'type', 'label', 'enabled']);
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
    expect(
      (jsonDecode(base) as Map)['menu'][0]['icon'],
      isNot(contains('png')),
    );
  });

  test('separators serialize without label or state', () {
    final encoded = TrayCodec.encode(_spec(menu: const [TrayMenuSeparator()]));

    expect(encoded.menu.single, {'id': 1024, 'type': 'separator'});
  });
}
