import '../rust/api/tray.dart';
import 'tray_menu.dart';

enum TrayIconPosition { leading, trailing }

final class TrayIcon {
  const TrayIcon.asset(
    this.asset, {
    this.isTemplate = false,
    this.size = 18,
    this.position = TrayIconPosition.leading,
    this.dot,
  });

  final String asset;
  final bool isTemplate;
  final int size;
  final TrayIconPosition position;

  /// A coloured dot on the icon's top-right corner; shown on macOS only.
  final TrayDot? dot;
}

final class TraySpec {
  const TraySpec({required this.icon, this.toolTip = '', this.menu = const []});

  final TrayIcon icon;
  final String toolTip;
  final List<TrayMenuItem> menu;
}
