import 'dart:typed_data';

typedef TrayMenuItemSelectedCallback = void Function();

sealed class TrayMenuItem {
  const TrayMenuItem();
}

final class TrayMenuIcon {
  const TrayMenuIcon({
    required this.monogram,
    required this.background,
    required this.foreground,
    this.pngBytes,
  });

  final String monogram;
  final int background;
  final int foreground;
  final Uint8List? pngBytes;
}

final class TrayMenuBadge {
  const TrayMenuBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final int background;
  final int foreground;
}

final class TrayMenuAction extends TrayMenuItem {
  const TrayMenuAction({
    required this.label,
    this.detail,
    this.icon,
    this.badge,
    this.accessibilityLabel,
    this.enabled = true,
    this.onSelected,
  });

  final String label;
  final String? detail;
  final TrayMenuIcon? icon;
  final TrayMenuBadge? badge;
  final String? accessibilityLabel;
  final bool enabled;
  final TrayMenuItemSelectedCallback? onSelected;
}

final class TrayMenuCheckbox extends TrayMenuItem {
  const TrayMenuCheckbox({
    required this.label,
    required this.checked,
    this.detail,
    this.segmentGroup,
    this.segmentError,
    this.icon,
    this.badge,
    this.accessibilityLabel,
    this.enabled = true,
    this.onSelected,
  });

  final String label;
  final bool checked;
  final String? detail;
  final String? segmentGroup;
  final String? segmentError;
  final TrayMenuIcon? icon;
  final TrayMenuBadge? badge;
  final String? accessibilityLabel;
  final bool enabled;
  final TrayMenuItemSelectedCallback? onSelected;
}

final class TrayMenuSubmenu extends TrayMenuItem {
  const TrayMenuSubmenu({
    required this.label,
    required this.items,
    this.detail,
    this.icon,
    this.badge,
    this.accessibilityLabel,
    this.enabled = true,
  });

  final String label;
  final List<TrayMenuItem> items;
  final String? detail;
  final TrayMenuIcon? icon;
  final TrayMenuBadge? badge;
  final String? accessibilityLabel;
  final bool enabled;
}

final class TrayMenuSeparator extends TrayMenuItem {
  const TrayMenuSeparator();
}
