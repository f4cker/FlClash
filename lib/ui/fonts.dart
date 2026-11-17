import 'package:flutter/widgets.dart';

/// The fonts FlClash bundles, declared in its `pubspec.yaml`.
enum FontFamily {
  twEmoji('Twemoji'),
  jetBrainsMono('JetBrainsMono');

  final String value;

  const FontFamily(this.value);
}

/// The CJK family monospace text falls back to first, so Chinese in rule
/// text, group and node names reads in the system's CJK face, not as boxes.
const cjkMonoFallback = 'PingFang SC';

extension FontFamilyTextStyle on TextStyle {
  /// JetBrains Mono, falling back for what it lacks to the system CJK face,
  /// then to the family and fallbacks this style had.
  TextStyle get toJetBrainsMono {
    final family = fontFamily;
    return copyWith(
      fontFamily: FontFamily.jetBrainsMono.value,
      fontFamilyFallback: [
        cjkMonoFallback,
        if (family != null && family != FontFamily.jetBrainsMono.value) family,
        ...?fontFamilyFallback?.where(
          (fallback) => fallback != cjkMonoFallback,
        ),
      ],
    );
  }
}
