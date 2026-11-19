import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/mitm/rewrite.dart';
import 'package:fl_clash/features/mitm/script.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/icons/app_glyphs.dart';
import 'package:fl_clash/views/config/mitm.dart';
import 'package:fl_clash/views/config/mitm_modules.dart';
import 'package:fl_clash/views/views.dart';

class Navigation implements NavigationPort {
  static Navigation? _instance;

  /// Sidebar order: the untitled top three, then each [NavigationGroup] in
  /// turn, then tools, pinned at the foot.
  @override
  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
    bool showRules = false,
  }) {
    return [
      NavigationItem(
        glyph: AppGlyphs.dashboard,
        label: PageLabel.dashboard,
        builder: (_) => const DashboardView(),
      ),
      NavigationItem(
        glyph: AppGlyphs.proxies,
        label: PageLabel.proxies,
        builder: (_) => const ProxiesView(),
        modes: hasProxies
            ? [NavigationItemMode.mobile, NavigationItemMode.desktop]
            : [],
      ),
      NavigationItem(
        glyph: AppGlyphs.profiles,
        label: PageLabel.profiles,
        builder: (_) => const ProfilesView(),
      ),
      NavigationItem(
        glyph: AppGlyphs.rules,
        label: PageLabel.rules,
        builder: (_) => const RulesView(),
        modes: showRules ? [NavigationItemMode.desktop] : [],
      ),
      NavigationItem(
        glyph: AppGlyphs.resources,
        label: PageLabel.resources,
        builder: (_) => const ResourcesView(),
        modes: [NavigationItemMode.desktop, NavigationItemMode.more],
      ),
      // The phone reaches these through the advanced settings instead.
      if (mitmFeature) ...[
        NavigationItem(
          glyph: AppGlyphs.lockOpen,
          label: PageLabel.mitm,
          builder: (_) => MitmView(isAndroid: system.isAndroid),
          modes: [NavigationItemMode.desktop],
        ),
        NavigationItem(
          glyph: AppGlyphs.wand,
          label: PageLabel.mitmRewrite,
          builder: (_) => const MitmRewriteView(),
          modes: [NavigationItemMode.desktop],
        ),
        NavigationItem(
          glyph: AppGlyphs.code,
          label: PageLabel.mitmScripts,
          builder: (_) => const MitmScriptView(),
          modes: [NavigationItemMode.desktop],
        ),
        if (mitmModulesFeature)
          NavigationItem(
            glyph: AppGlyphs.puzzle,
            label: PageLabel.mitmModules,
            builder: (_) => const MitmModulesView(),
            modes: [NavigationItemMode.desktop],
          ),
      ],
      NavigationItem(
        glyph: AppGlyphs.requests,
        label: PageLabel.requests,
        builder: (_) => const RequestsView(),
        modes: [NavigationItemMode.desktop, NavigationItemMode.moreFull],
      ),
      NavigationItem(
        glyph: AppGlyphs.dns,
        label: PageLabel.dns,
        builder: (_) => const DnsQueriesView(),
        modes: [NavigationItemMode.desktop, NavigationItemMode.moreFull],
      ),
      NavigationItem(
        glyph: AppGlyphs.logs,
        label: PageLabel.logs,
        builder: (_) => const LogsView(),
        modes: openLogs
            ? [NavigationItemMode.desktop, NavigationItemMode.more]
            : [],
      ),
      NavigationItem(
        glyph: AppGlyphs.devices,
        label: PageLabel.tailscale,
        builder: (_) => const TailscaleView(),
        modes: [NavigationItemMode.desktop],
      ),
      NavigationItem(
        glyph: AppGlyphs.tools,
        label: PageLabel.tools,
        builder: (_) => const ToolsView(),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
    ];
  }

  Navigation._internal();

  factory Navigation() {
    _instance ??= Navigation._internal();
    return _instance!;
  }
}

final navigation = Navigation();
