import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'labels.dart';

class IpQualityText extends ConsumerWidget {
  const IpQualityText({
    super.key,
    required this.ip,
    this.style,
    this.tinted = true,
  });

  final String ip;
  final TextStyle? style;

  /// Colours the address by its quality level; a detail that states the
  /// level elsewhere leaves it plain.
  final bool tinted;

  static const _mask = '*****';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quality = ref.watch(ipQualityProvider(ip)).value;
    final hideIp = ref.watch(
      appSettingProvider.select((state) => state.hideIp),
    );
    final shownIp = hideIp ? _mask : ip;
    final color = tinted ? quality?.level.color(context) : null;
    var style = this.style;
    if (hideIp) {
      style = (style ?? const TextStyle()).toJetBrainsMono;
    }
    if (color != null) {
      style = (style ?? const TextStyle()).copyWith(color: color);
    }
    return Tooltip(
      preferBelow: false,
      message: shownIp,
      child: Text(
        shownIp,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
