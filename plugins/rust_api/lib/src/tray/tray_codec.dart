import 'dart:convert';

import '../rust/api/tray.dart';
import 'tray_menu.dart';
import 'tray_spec.dart';

final class EncodedTray {
  const EncodedTray({
    required this.menu,
    required this.itemsById,
    required this.signature,
  });

  final List<TrayItem> menu;
  final Map<int, TrayMenuItem> itemsById;
  final String signature;
}

abstract final class TrayCodec {
  static const int firstItemId = 1024;

  static EncodedTray encode(TraySpec spec) {
    final itemsById = <int, TrayMenuItem>{};
    final menu = _encodeItems(spec.menu, itemsById, _IdAllocator());
    return EncodedTray(
      menu: menu,
      itemsById: itemsById,
      signature: jsonEncode(<Object?>[
        spec.icon.asset,
        spec.icon.isTemplate,
        spec.icon.size,
        spec.icon.position.name,
        if (spec.icon.dot case final dot?) [dot.color, dot.breathing],
        spec.toolTip,
        _describe(menu),
      ]),
    );
  }

  static List<TrayItem> _encodeItems(
    List<TrayMenuItem> items,
    Map<int, TrayMenuItem> sink,
    _IdAllocator allocator,
  ) {
    return items.map((item) {
      final id = allocator.next();
      sink[id] = item;
      return switch (item) {
        TrayMenuSeparator() => TrayItem(
          id: id,
          kind: TrayItemKind.separator,
          label: '',
          enabled: true,
          checked: false,
          items: const [],
        ),
        TrayMenuAction(
          :final transientStatusKey,
          :final label,
          :final detail,
          :final icon,
          :final badge,
          :final accessibilityLabel,
          :final enabled,
          :final keepsMenuOpen,
        ) =>
          TrayItem(
            id: id,
            kind: TrayItemKind.action,
            label: label,
            detail: _detail(detail),
            enabled: enabled,
            checked: false,
            items: const [],
            transientStatusKey: transientStatusKey,
            icon: _icon(icon),
            badge: _badge(badge),
            accessibilityLabel: accessibilityLabel,
            keepsMenuOpen: keepsMenuOpen,
          ),
        TrayMenuCheckbox(
          :final segmentGroup,
          :final segmentError,
          :final label,
          :final detail,
          :final icon,
          :final badge,
          :final accessibilityLabel,
          :final enabled,
          :final checked,
        ) =>
          TrayItem(
            id: id,
            kind: TrayItemKind.checkbox,
            label: label,
            detail: _detail(detail),
            enabled: enabled,
            checked: checked,
            items: const [],
            segmentGroup: segmentGroup,
            segmentError: segmentError,
            icon: _icon(icon),
            badge: _badge(badge),
            accessibilityLabel: accessibilityLabel,
          ),
        TrayMenuSubmenu(
          :final label,
          :final detail,
          :final icon,
          :final badge,
          :final accessibilityLabel,
          :final enabled,
          :final items,
        ) =>
          TrayItem(
            id: id,
            kind: TrayItemKind.submenu,
            label: label,
            detail: _detail(detail),
            enabled: enabled,
            checked: false,
            items: _encodeItems(items, sink, allocator),
            icon: _icon(icon),
            badge: _badge(badge),
            accessibilityLabel: accessibilityLabel,
          ),
      };
    }).toList();
  }

  static String? _detail(String? detail) {
    return detail == null || detail.isEmpty ? null : detail;
  }

  static TrayItemIcon? _icon(TrayMenuIcon? icon) {
    if (icon == null) {
      return null;
    }
    return TrayItemIcon(
      monogram: icon.monogram,
      background: icon.background & 0xFFFFFFFF,
      foreground: icon.foreground & 0xFFFFFFFF,
      png: icon.pngBytes,
    );
  }

  static TrayItemBadge? _badge(TrayMenuBadge? badge) {
    if (badge == null) {
      return null;
    }
    return TrayItemBadge(
      label: badge.label,
      background: badge.background & 0xFFFFFFFF,
      foreground: badge.foreground & 0xFFFFFFFF,
    );
  }

  static List<Object?> _describe(List<TrayItem> items) {
    return [
      for (final item in items)
        [
          item.id,
          item.kind.name,
          item.label,
          item.detail,
          item.enabled,
          item.checked,
          item.transientStatusKey,
          item.segmentGroup,
          item.segmentError,
          item.accessibilityLabel,
          item.keepsMenuOpen,
          if (item.icon case final icon?)
            [
              icon.monogram,
              icon.background,
              icon.foreground,
              if (icon.png case final png?) base64Encode(png),
            ]
          else
            null,
          if (item.badge case final badge?)
            [badge.label, badge.background, badge.foreground]
          else
            null,
          _describe(item.items),
        ],
    ];
  }
}

final class _IdAllocator {
  int _next = TrayCodec.firstItemId;

  int next() {
    final id = _next;
    _next = _next + 1;
    return id;
  }
}
