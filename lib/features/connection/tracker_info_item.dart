import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'detail_tabs.dart';
import 'mitm_exchanges.dart';
import 'process_view.dart';

String mitmOutcomeText(BuildContext context, String outcome) {
  final l = context.appLocalizations;
  return switch (outcome) {
    'refused' => l.mitmOutcomeRefused,
    'upstreamCertificate' => l.mitmOutcomeUpstreamCertificate,
    'http2Only' => l.mitmOutcomeHTTP1Unsupported,
    'unsupportedHello' || 'missingSNI' => l.mitmOutcomeHelloPassthrough,
    'upstreamFailed' || 'clientFailed' || 'http1Failed' => l.mitmOutcomeFailed,
    _ => '',
  };
}

String _endpointText(String ip, String port) {
  if (ip.isEmpty) {
    return '';
  }
  if (port.isNotEmpty) {
    return '$ip:$port';
  }
  return ip;
}

void showTrackerInfoDetail(
  BuildContext context,
  TrackerInfo trackerInfo,
  String title,
) {
  showNestedSheet<void>(
    context,
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final status = ref.watch(
          requestsProvider.select((requests) {
            for (final request in requests.list.reversed) {
              if (request.id == trackerInfo.id) {
                return (request.mitmOutcome, request.metadata.mitm);
              }
            }
            return (trackerInfo.mitmOutcome, trackerInfo.metadata.mitm);
          }),
        );
        return Scaffold(
          body: TrackerInfoDetailView(
            trackerInfo: trackerInfo.copyWith(
              mitmOutcome: status.$1,
              metadata: trackerInfo.metadata.copyWith(mitm: status.$2),
            ),
          ),
          title: title,
        );
      },
    ),
  );
}

/// The host a rule lookup reads for a request: its name, else the address
/// it went to.
String trackerLookupHost(TrackerInfo trackerInfo) {
  final metadata = trackerInfo.metadata;
  return metadata.host.isNotEmpty ? metadata.host : metadata.destinationIP;
}

/// Whether the rules page can be opened on a request: it is in the desktop
/// navigation while the Core runs. Read from those two alone, so a request
/// row never builds the profile list the navigation reads.
bool canLookUpTrackerRule(BuildContext context, TrackerInfo trackerInfo) {
  if (trackerLookupHost(trackerInfo).isEmpty) return false;
  final container = ProviderScope.containerOf(context, listen: false);
  return container.read(viewWidthProvider) > maxMobileWidth &&
      container.read(coreStatusProvider) == CoreStatus.connected;
}

/// Opens the rules page on a request's host, compared there with the rule
/// the request took.
void lookUpTrackerRule(BuildContext context, TrackerInfo trackerInfo) {
  final container = ProviderScope.containerOf(context, listen: false);
  rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  container
      .read(rulesLookupRequestProvider.notifier)
      .ask(
        trackerLookupHost(trackerInfo),
        rule: trackerInfo.rule,
        rulePayload: trackerInfo.rulePayload,
      );
}

List<PopupMenuItem> trackerInfoMenuItems(
  BuildContext context,
  TrackerInfo trackerInfo, {
  ValueChanged<TrackerInfo>? onClose,
}) {
  final appLocalizations = context.appLocalizations;
  final metadata = trackerInfo.metadata;
  final destination = _endpointText(
    metadata.destinationIP,
    metadata.destinationPort,
  );
  Future<void> copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    dialogs.showBanner(currentAppLocalizations.copySuccess);
  }

  return [
    if (metadata.host.isNotEmpty)
      PopupMenuItem(
        glyph: AppGlyphs.copy,
        label: appLocalizations.copyHost,
        onPressed: () => copy(metadata.host),
      ),
    if (destination.isNotEmpty)
      PopupMenuItem(
        glyph: AppGlyphs.copy,
        label: appLocalizations.copyDestination,
        onPressed: () => copy(destination),
      ),
    if (canLookUpTrackerRule(context, trackerInfo))
      PopupMenuItem(
        glyph: AppGlyphs.search,
        label: appLocalizations.lookupRule,
        onPressed: () => lookUpTrackerRule(context, trackerInfo),
      ),
    if (onClose != null)
      PopupMenuItem(
        glyph: AppGlyphs.block,
        label: appLocalizations.closeConnection,
        section: const PopupMenuSection(),
        onPressed: () => onClose(trackerInfo),
      ),
  ];
}

class TrackerInfoItem extends ConsumerWidget {
  final TrackerInfo trackerInfo;
  final bool isLive;
  final ValueChanged<TrackerInfo>? onClose;
  final String detailTitle;

  /// What the detail opens on, where a memoized row outlives its traffic.
  final ValueGetter<TrackerInfo>? latest;

  const TrackerInfoItem({
    super.key,
    required this.trackerInfo,
    this.isLive = false,
    this.onClose,
    required this.detailTitle,
    this.latest,
  });

  @override
  Widget build(BuildContext context, ref) {
    final showIcon = ref.watch(
      patchClashConfigProvider.select(
        (state) =>
            state.findProcessMode == FindProcessMode.always && system.isAndroid,
      ),
    );
    return ContextMenuRegion(
      menuItems: trackerInfoMenuItems(context, trackerInfo, onClose: onClose),
      child: RecordListItem(
        onTap: () => showTrackerInfoDetail(
          context,
          latest?.call() ?? trackerInfo,
          detailTitle,
        ),
        header: _buildHeader(context),
        body: _TrackerInfoBody(trackerInfo: trackerInfo, showIcon: showIcon),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final network = Text(
      trackerInfo.metadata.network.toUpperCase(),
      style: AppTextStyle.caption1
          .of(context, emphasized: true)
          .copyWith(color: context.colorScheme.onSurfaceVariant),
    );
    final mitm = trackerInfo.metadata.mitm;
    final outcome = mitmOutcomeText(context, trackerInfo.mitmOutcome);
    if (!isLive) {
      return RecordHeader(
        children: [
          RecordTimestamp(trackerInfo.start.showFull),
          network,
          if (outcome.isNotEmpty)
            RecordLabel(label: outcome)
          else if (mitm)
            const RecordLabel(label: 'MITM'),
        ],
      );
    }
    final color = context.colorScheme.onSurfaceVariant;
    WidgetSpan arrow(Glyph glyph) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: GlyphIcon(glyph, size: 12, color: color),
    );
    return RecordHeader(
      trailing: Text.rich(
        TextSpan(
          children: [
            arrow(AppGlyphs.arrowUp),
            TextSpan(
              text: ' ${(trackerInfo.uploadSpeed ?? 0).traffic.show}/s   ',
            ),
            arrow(AppGlyphs.arrowDown),
            TextSpan(
              text: ' ${(trackerInfo.downloadSpeed ?? 0).traffic.show}/s',
            ),
          ],
        ),
      ),
      children: [
        Text(trackerInfo.start.getLastUpdateTimeDesc(context, compact: true)),
        network,
        if (outcome.isNotEmpty)
          RecordLabel(label: outcome)
        else if (mitm)
          const RecordLabel(label: 'MITM'),
      ],
    );
  }
}

class _TrackerInfoBody extends StatelessWidget {
  final TrackerInfo trackerInfo;
  final bool showIcon;

  const _TrackerInfoBody({required this.trackerInfo, required this.showIcon});

  Widget _buildTitle(BuildContext context, RecordTextStyles styles) {
    final metadata = trackerInfo.metadata;
    final title = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: _endpointText(trackerInfo.title, metadata.destinationPort),
            style: styles.title,
          ),
          if (metadata.host.isNotEmpty && metadata.destinationIP.isNotEmpty)
            TextSpan(
              text: '  ${metadata.destinationIP}',
              style: styles.secondary,
            ),
        ],
      ),
    );
    if (!system.isAndroid) {
      return ConnectionProcessBuilder(
        metadata: metadata,
        builder: (context, process) => Row(
          spacing: 8,
          children: [
            if (process.hasProcess)
              ProcessFilterIcon(process: process, size: 24)
            else
              ProcessIcon(process: process, size: 24),
            Flexible(child: title),
          ],
        ),
      );
    }
    final process = metadata.process;
    if (!showIcon || process.isEmpty) {
      return title;
    }
    return Row(
      spacing: 8,
      children: [
        GestureDetector(
          onTap: () => RecordFilterScope.add(
            context,
            RecordFilter(RecordFacetKind.app, process),
          ),
          child: PackageIcon(packageName: process, size: 24),
        ),
        Flexible(child: title),
      ],
    );
  }

  Widget _buildSource(BuildContext context, RecordTextStyles styles) {
    final metadata = trackerInfo.metadata;
    final endpoint = _endpointText(metadata.sourceIP, metadata.sourcePort);
    if (system.isAndroid) {
      final source = [
        trackerInfo.progressText,
        endpoint,
      ].where((text) => text.isNotEmpty).join('  ·  ');
      return source.isEmpty
          ? const SizedBox.shrink()
          : Text(source, style: styles.secondary);
    }
    return ConnectionProcessBuilder(
      metadata: metadata,
      builder: (context, process) => Text(
        [
          processLabelOf(process),
          endpoint,
        ].where((text) => text.isNotEmpty).join('  ·  '),
        style: styles.secondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final styles = RecordTextStyles.of(context);
    final rule = trackerInfo.ruleText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        _buildTitle(context, styles),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (rule.isNotEmpty) Text(rule, style: styles.secondary),
            for (final (index, chain) in trackerInfo.chains.reversed.indexed)
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  if (index > 0 || rule.isNotEmpty) const RecordArrow(),
                  Flexible(
                    child: TonalChip(
                      label: chain,
                      color: context.raisedSurfaceLevel.colorOf(colorScheme),
                      foregroundColor: colorScheme.onSurfaceVariant,
                      onPressed: () => RecordFilterScope.add(
                        context,
                        RecordFilter(RecordFacetKind.proxy, chain),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        _buildSource(context, styles),
      ],
    );
  }
}

/// Adds the host of a connection to the hostnames or excludes it, so that the
/// list can be filled from what the apps really connect to.
class _MitmHostSection extends ConsumerWidget {
  final Metadata metadata;

  const _MitmHostSection({required this.metadata});

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String tip,
    required Mitm Function(Mitm) update,
  }) async {
    final res = await dialogs.showMessage(
      title: title,
      message: TextSpan(text: tip),
    );
    if (res != true) {
      return;
    }
    ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => state.copyWith(mitm: update(state.mitm)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = metadata.host;
    final (enable, hostname) = ref.watch(
      patchClashConfigProvider.select(
        (state) => (state.mitm.enable, state.mitm.hostname),
      ),
    );
    if (!enable || host.isEmpty || metadata.network.toLowerCase() != 'tcp') {
      return const SizedBox.shrink();
    }
    final appLocalizations = context.appLocalizations;
    final decrypted = metadata.mitm || metadata.mitmRefused;
    final excludes =
        !hostname.contains('-$host') && (decrypted || hostname.contains(host));
    final title = excludes
        ? appLocalizations.mitmExcludeHost
        : appLocalizations.mitmDecryptHost;
    return generateSection(
      title: appLocalizations.mitm,
      items: [
        ListItem(
          title: Text(title),
          onTap: () => _confirm(
            context,
            ref,
            title: title,
            tip: excludes
                ? appLocalizations.mitmExcludeHostTip(host)
                : appLocalizations.mitmDecryptHostTip(host),
            update: (mitm) =>
                excludes ? mitm.excludingHost(host) : mitm.decryptingHost(host),
          ),
        ),
      ],
      footer: metadata.mitmRefused
          ? appLocalizations.mitmClientRefusedCertificate
          : null,
    );
  }
}

class TrackerInfoDetailView extends ConsumerWidget {
  final TrackerInfo trackerInfo;

  const TrackerInfoDetailView({super.key, required this.trackerInfo});

  Widget _buildChains(BuildContext context) {
    return DetailRow(
      title: context.appLocalizations.proxyChains,
      value: Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (index, chain) in trackerInfo.chains.reversed.indexed)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                if (index > 0) const RecordArrow(),
                Flexible(child: MetaChip(label: chain)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRule(BuildContext context) {
    final ruleText = trackerInfo.ruleText;
    if (!canLookUpTrackerRule(context, trackerInfo)) {
      return ruleText.isEmpty
          ? const SizedBox.shrink()
          : DetailRow.text(
              title: context.appLocalizations.rule,
              value: ruleText,
            );
    }
    final colorScheme = context.colorScheme;
    return DetailRow(
      title: context.appLocalizations.rule,
      copyText: ruleText.isEmpty ? null : ruleText,
      value: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          Flexible(child: Text(ruleText)),
          GestureDetector(
            onTap: () => lookUpTrackerRule(context, trackerInfo),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                context.appLocalizations.lookupRule,
                style: AppTextStyle.footnote
                    .of(context, emphasized: true)
                    .copyWith(color: colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRows(List<(String, String)> entries) {
    return [
      for (final (title, value) in entries)
        if (value.isNotEmpty) DetailRow.text(title: title, value: value),
    ];
  }

  Widget _buildOverview(BuildContext context) {
    if (system.isAndroid) {
      return _buildOverviewWith(context, null);
    }
    return ConnectionProcessBuilder(
      metadata: trackerInfo.metadata,
      builder: _buildOverviewWith,
    );
  }

  Widget _buildOverviewWith(BuildContext context, ConnectionProcess? process) {
    final appLocalizations = context.appLocalizations;
    final metadata = trackerInfo.metadata;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
        bottom: 20 + context.bottomInset,
        top: context.sectionsTopPadding,
      ),
      children: [
        generateSection(
          title: appLocalizations.basicInfo,
          items: [
            ..._buildRows([
              (appLocalizations.creationTime, trackerInfo.start.showFull),
              if (trackerInfo.mitmOutcome.isNotEmpty)
                (
                  appLocalizations.mitm,
                  mitmOutcomeText(context, trackerInfo.mitmOutcome),
                ),
              (appLocalizations.networkType, metadata.network),
              if (process == null)
                (appLocalizations.process, trackerInfo.progressText),
            ]),
            if (process != null) ...processDetailRows(context, process),
            _buildRule(context),
            ..._buildRows([
              (appLocalizations.upload, trackerInfo.upload.traffic.show),
              (appLocalizations.download, trackerInfo.download.traffic.show),
            ]),
          ],
        ),
        generateSection(
          title: appLocalizations.address,
          items: _buildRows([
            (appLocalizations.host, metadata.host),
            (
              appLocalizations.source,
              _endpointText(metadata.sourceIP, metadata.sourcePort),
            ),
            (
              appLocalizations.destination,
              _endpointText(metadata.destinationIP, metadata.destinationPort),
            ),
            (
              appLocalizations.destinationGeoIP,
              metadata.destinationGeoIP.join(' '),
            ),
            (appLocalizations.destinationIPASN, metadata.destinationIPASN),
            (appLocalizations.remoteDestination, metadata.remoteDestination),
          ]),
        ),
        generateSection(
          title: appLocalizations.proxies,
          items: [
            ..._buildRows([
              (appLocalizations.specialProxy, metadata.specialProxy),
              (appLocalizations.specialRules, metadata.specialRules),
              (appLocalizations.dnsMode, metadata.dnsMode?.name ?? ''),
            ]),
            _buildChains(context),
          ],
        ),
        if (mitmFeature) _MitmHostSection(metadata: metadata),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final capturing =
        trackerInfo.metadata.mitm &&
        ref.watch(
          patchClashConfigProvider.select(
            (state) => state.mitm.enable && state.mitm.capture,
          ),
        );
    return DetailTabs(
      tabs: [
        (appLocalizations.overview, _buildOverview),
        if (capturing)
          (
            appLocalizations.httpRequests,
            (_) => MitmExchangesView(trackerInfo: trackerInfo),
          ),
      ],
    );
  }
}
