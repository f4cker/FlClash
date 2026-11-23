import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/release_history.dart';
import 'package:fl_clash/widgets/beta_update_setting.dart';
import 'package:fl_clash/widgets/config_item.dart';
import 'package:fl_clash/widgets/version_label.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class Contributor {
  final String avatar;
  final String name;

  const Contributor({required this.avatar, required this.name});
}

class AboutView extends ConsumerWidget {
  const AboutView({super.key});

  static const _contributors = [
    Contributor(avatar: 'assets/images/avatar/june2.jpg', name: 'June2'),
    Contributor(avatar: 'assets/images/avatar/arue.jpg', name: 'Arue'),
  ];

  Future<void> _checkUpdate(BuildContext context, WidgetRef ref) async {
    if (ref.read(loadingProvider(LoadingTag.checkUpdate))) return;
    final commonAction = ref.read(commonActionProvider.notifier);
    final result = await globalState.loadingRun(
      commonAction.checkForAppUpdate,
      title: context.appLocalizations.checkUpdate,
      tag: LoadingTag.checkUpdate,
    );
    if (result == null) return;
    unawaited(commonAction.checkUpdateResultHandle(result, isUser: true));
  }

  Widget _buildLinkItem({
    required Glyph glyph,
    required String title,
    required String url,
    required String label,
  }) {
    return ListItem(
      leading: _LinkBadge(glyph: glyph),
      title: Text(title),
      subtitle: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const GlyphIcon(AppGlyphs.openExternal),
      onTap: () {
        dialogs.openUrl(url);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final isLoading = ref.watch(loadingProvider(LoadingTag.checkUpdate));
    return Scaffold(
      isLoading: isLoading,
      title: appLocalizations.about,
      body: ListView(
        padding: context.listInsets.page().copyWith(
          top: context.contentTopPadding,
          bottom: 32 + context.bottomInset,
        ),
        children: [
          _AboutHero(
            isCheckingUpdate: isLoading,
            onCheckUpdate: () {
              _checkUpdate(context, ref);
            },
            onEnterDeveloperMode: () {
              ref
                  .read(appSettingProvider.notifier)
                  .update((state) => state.copyWith(developerMode: true));
              dialogs.showBanner(
                appLocalizations.developerModeEnableTip,
                level: BannerLevel.success,
              );
            },
          ),
          const SizedBox(height: 16),
          generateSection(
            items: [
              ConfigToggleItem(
                key: const ValueKey('auto-check-update'),
                leading: const _LinkBadge(glyph: AppGlyphs.cloudSync),
                title: (l) => l.autoCheckUpdate,
                selector: appSettingProvider.select(
                  (state) => state.autoCheckUpdate,
                ),
                onChanged: (ref, value) => ref
                    .read(appSettingProvider.notifier)
                    .update((state) => state.copyWith(autoCheckUpdate: value)),
              ),
              if (system.isMacOS)
                const BetaUpdateSetting(
                  leading: _LinkBadge(glyph: AppGlyphs.flask, glyphSize: 24),
                  stackable: true,
                ),
            ],
          ),
          const SizedBox(height: 8),
          generateSection(
            title: appLocalizations.more,
            items: [
              _buildLinkItem(
                glyph: AppGlyphs.code,
                title: appLocalizations.project,
                url: 'https://github.com/$upstreamRepository',
                label: 'github.com/$upstreamRepository',
              ),
              _buildLinkItem(
                glyph: AppGlyphs.cpu,
                title: appLocalizations.core,
                url: 'https://github.com/chen08209/Clash.Meta/tree/FlClash',
                label: 'github.com/chen08209/Clash.Meta',
              ),
              _buildLinkItem(
                glyph: AppGlyphs.send,
                title: appLocalizations.upstreamTelegram,
                url: 'https://t.me/FlClash',
                label: 't.me/FlClash',
              ),
            ],
          ),
          generateSection(
            title: appLocalizations.otherContributors,
            items: [
              for (final contributor in _contributors)
                ListItem(
                  leading: Container(
                    width: 40,
                    height: 40,
                    foregroundDecoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: AssetImage(contributor.avatar),
                        fit: BoxFit.cover,
                      ),
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.colorScheme.primaryContainer,
                    ),
                  ),
                  title: Text(contributor.name),
                  subtitle: Text(appLocalizations.appIconDesign),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutHero extends ConsumerWidget {
  final bool isCheckingUpdate;
  final VoidCallback onCheckUpdate;
  final VoidCallback onEnterDeveloperMode;

  const _AboutHero({
    required this.isCheckingUpdate,
    required this.onCheckUpdate,
    required this.onEnterDeveloperMode,
  });

  static const _logoSize = 96.0;

  // icon.png artwork: centred 442 of 550 pixels, the rest grid margin/shadow.
  static const _artworkFraction = 442 / 550;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(installedMacReleaseProvider).value;
    final colorScheme = context.colorScheme;
    final appLocalizations = context.appLocalizations;
    return Padding(
      padding: context.listInsets.page(top: infoSectionSpacing),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _DeveloperModeDetector(
                onEnterDeveloperMode: onEnterDeveloperMode,
                child: SizedBox.square(
                  key: const ValueKey('about-icon'),
                  dimension: _logoSize,
                  child: OverflowBox(
                    maxWidth: _logoSize / _artworkFraction,
                    maxHeight: _logoSize / _artworkFraction,
                    child: Image.asset(
                      'assets/images/icon.png',
                      width: _logoSize / _artworkFraction,
                      height: _logoSize / _artworkFraction,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              if (identity?.channel == ReleaseChannel.beta)
                const Positioned(
                  right: -_BetaBadge.overhangRight - _BetaBadge.outline,
                  bottom: -_BetaBadge.overhangBottom - _BetaBadge.outline,
                  child: _BetaBadge(),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            appName,
            style: AppTextStyle.title2.of(context, emphasized: true),
          ),
          const SizedBox(height: 8),
          Text.rich(
            key: const ValueKey('about-version'),
            versionLabelSpan(
              identity?.fullVersion ??
                  appVersionLabel(
                    globalState.packageInfo.version,
                    globalState.packageInfo.buildNumber,
                  ),
              style: AppTextStyle.callout
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
              buildStyle: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          _Pill(
            label: 'GPL-3.0',
            color: context.raisedSurfaceLevel.colorOf(colorScheme),
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              appLocalizations.desc,
              textAlign: TextAlign.center,
              style: AppTextStyle.subheadline
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            key: const ValueKey('about-actions'),
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              TonalButton(
                size: TonalButtonSize.bar,
                glyph: AppGlyphs.sync,
                label: appLocalizations.checkUpdate,
                onPressed: isCheckingUpdate ? null : onCheckUpdate,
              ),
              TonalButton(
                key: const ValueKey('release-history-entry'),
                size: TonalButtonSize.bar,
                glyph: AppGlyphs.clock,
                label: appLocalizations.releaseHistory,
                onPressed: () {
                  showNestedExtend<void>(
                    context,
                    builder: (_) => const ReleaseHistoryView(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BetaBadge extends StatelessWidget {
  const _BetaBadge();

  static const outline = 2.0;
  static const overhangRight = 8.0;
  static const overhangBottom = 4.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Semantics(
      key: const ValueKey('about-beta-badge'),
      container: true,
      excludeSemantics: true,
      label: context.appLocalizations.installedBetaBadge,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: context.surfaceLevel.colorOf(colorScheme),
          shape: AppShape.full,
        ),
        child: Padding(
          padding: const EdgeInsets.all(outline),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: colorScheme.primary,
              shape: AppShape.full,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                context.appLocalizations.releaseBeta,
                maxLines: 1,
                style: AppTextStyle.caption1
                    .of(context, emphasized: true)
                    .copyWith(color: colorScheme.onPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final Color foregroundColor;

  const _Pill({
    required this.label,
    required this.color,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(color: color, shape: AppShape.full),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          label,
          style: AppTextStyle.caption1
              .of(context, emphasized: true)
              .copyWith(color: foregroundColor),
        ),
      ),
    );
  }
}

class _LinkBadge extends StatelessWidget {
  final Glyph glyph;
  final double glyphSize;

  const _LinkBadge({required this.glyph, this.glyphSize = 20});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: context.raisedSurfaceLevel.colorOf(colorScheme),
        shape: AppShape.md,
      ),
      child: SizedBox.square(
        dimension: 40,
        child: Center(
          child: GlyphIcon(
            glyph,
            size: glyphSize,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _DeveloperModeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onEnterDeveloperMode;

  const _DeveloperModeDetector({
    required this.child,
    required this.onEnterDeveloperMode,
  });

  @override
  State<_DeveloperModeDetector> createState() => _DeveloperModeDetectorState();
}

class _DeveloperModeDetectorState extends State<_DeveloperModeDetector> {
  int _counter = 0;
  Timer? _timer;

  void _handleTap() {
    _counter++;
    if (_counter >= 5) {
      widget.onEnterDeveloperMode();
      _resetCounter();
    } else {
      _timer?.cancel();
      _timer = Timer(const Duration(seconds: 1), _resetCounter);
    }
  }

  void _resetCounter() {
    _counter = 0;
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: _handleTap, child: widget.child);
  }
}
