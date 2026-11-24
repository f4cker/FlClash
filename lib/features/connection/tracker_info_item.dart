import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_indicator.dart';
import 'package:fl_clash/common/mitm_rewrite.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/mitm/script_dialogs.dart' show mitmAmberColor;
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/mitm.dart' show mitmCorePauseReason;
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'detail_tabs.dart';
import 'mitm_exchanges.dart';
import 'process_view.dart';
import 'route_reason.dart';

String mitmOutcomeText(BuildContext context, String outcome) {
  final l = context.appLocalizations;
  return switch (outcome) {
    'refused' => l.mitmOutcomeRefused,
    'upstreamCertificate' => l.mitmOutcomeUpstreamCertificate,
    'http2Only' => l.mitmOutcomeHTTP1Unsupported,
    'unsupportedHello' || 'missingSNI' => l.mitmOutcomeHelloPassthrough,
    'paused' => l.mitmOutcomePaused,
    'upstreamFailed' ||
    'clientFailed' ||
    'http1Failed' ||
    'http2Failed' => l.mitmOutcomeFailed,
    _ => '',
  };
}

/// The mark a row in the request list carries for a decryption host: a
/// small glyph beside the host, its words in the tooltip and the detail.
/// Only connections the Core reported on have one; unlisted traffic has
/// none. The glyph and color of each are set here and nowhere else.
enum MitmBadge {
  decrypted(AppGlyphs.lockOpen),
  passedThrough(AppGlyphs.arrowForward),
  // The client sent an alert in its handshake; why is unknown.
  handshakeFailed(AppGlyphs.warning),
  failed(AppGlyphs.lockError);

  const MitmBadge(this.glyph);

  final Glyph glyph;

  /// The glyph's side in a row, and its gap after the host.
  static const iconSize = 14.0;
  static const gap = 6.0;
  static const tooltipDelay = Duration(milliseconds: 300);

  // Amber #B25E00 is under 3:1 on the dark surfaces, so dark mode takes
  // iOS's dark orange; grey #8E8C94 reads on both.
  static const _grey = Color(0xFF8E8C94);
  static const _amber = Color(0xFFB25E00);
  static const _amberDark = Color(0xFFFF9F0A);

  Color color(BuildContext context) {
    final colorScheme = context.colorScheme;
    return switch (this) {
      MitmBadge.decrypted => colorScheme.primary,
      MitmBadge.passedThrough => _grey,
      MitmBadge.handshakeFailed =>
        colorScheme.brightness == Brightness.dark ? _amberDark : _amber,
      MitmBadge.failed => colorScheme.error,
    };
  }

  /// "Passed through" is claimed only on the Core's word: each of those
  /// outcomes is sent by the Core as it hands the connection, untouched, to
  /// its relay. A reason alone (an unsupported protocol) or a protocol
  /// label never implies it, and a connection the Core decrypted is never
  /// called passed through.
  static MitmBadge? of(TrackerInfo trackerInfo) {
    return switch (trackerInfo.mitmOutcome) {
      // A later HTTP failure leaves the connection decrypted all the same.
      _ when trackerInfo.metadata.mitm => MitmBadge.decrypted,
      'refused' => MitmBadge.handshakeFailed,
      'unsupportedHello' ||
      'missingSNI' ||
      'http2Only' ||
      'paused' => MitmBadge.passedThrough,
      'upstreamCertificate' ||
      'upstreamFailed' ||
      'clientFailed' ||
      'http1Failed' ||
      'http2Failed' => MitmBadge.failed,
      _ => null,
    };
  }

  String label(BuildContext context) {
    final l = context.appLocalizations;
    return switch (this) {
      MitmBadge.decrypted => l.mitmBadgeDecrypted,
      MitmBadge.passedThrough => l.mitmBadgePassedThrough,
      MitmBadge.handshakeFailed => l.mitmBadgeHandshakeFailed,
      MitmBadge.failed => l.mitmBadgeFailed,
    };
  }

  /// [label] as a screen reader says it.
  String semanticsLabel(BuildContext context) => switch (this) {
    MitmBadge.passedThrough =>
      context.appLocalizations.mitmBadgePassedThroughSpoken,
    _ => label(context),
  };
}

/// The mark a row carries once rewrite rules acted on its connection: a
/// wand when one applied, a wand with an exclamation mark when one matched
/// but let a message pass as it was. A failure outranks an applied rule on
/// the same connection, so it is not hidden behind it.
enum MitmRewriteBadge {
  applied(AppGlyphs.wand),
  failed(AppGlyphs.wandError);

  const MitmRewriteBadge(this.glyph);

  final Glyph glyph;

  static const _purple = Color(0xFF7A4FD6);
  static const _purpleDark = Color(0xFFB69CF5);

  Color color(BuildContext context) {
    final dark = context.colorScheme.brightness == Brightness.dark;
    return switch (this) {
      MitmRewriteBadge.applied => dark ? _purpleDark : _purple,
      MitmRewriteBadge.failed => dark ? MitmBadge._amberDark : MitmBadge._amber,
    };
  }

  static MitmRewriteBadge? of(TrackerInfo trackerInfo) {
    final rewrite = trackerInfo.mitmRewrite;
    return switch (rewrite) {
      MitmConnectionRewrite(failed: true) => MitmRewriteBadge.failed,
      MitmConnectionRewrite(applied: true) => MitmRewriteBadge.applied,
      _ => null,
    };
  }

  /// Names the latest hit's kind, or the reason it failed.
  String label(BuildContext context, MitmConnectionRewrite rewrite) {
    final l = context.appLocalizations;
    final hit = rewrite.hit;
    return switch (this) {
      MitmRewriteBadge.applied when hit != null && hit.skipped.isEmpty =>
        l.mitmRewriteBadgeApplied(mitmRewriteHitType(l, hit)),
      MitmRewriteBadge.applied => l.mitmRewriteRewritten,
      MitmRewriteBadge.failed when hit != null && hit.skipped.isNotEmpty =>
        l.mitmRewriteBadgeFailed(mitmRewriteSkipText(l, hit.skipped)),
      MitmRewriteBadge.failed => l.mitmRewriteFailedShort,
    };
  }

  String semanticsLabel(BuildContext context) => switch (this) {
    MitmRewriteBadge.applied => context.appLocalizations.mitmRewriteRewritten,
    MitmRewriteBadge.failed => context.appLocalizations.mitmRewriteFailedShort,
  };
}

/// [MitmBadge.of] as a glyph that names itself on hover and to a screen
/// reader, or nothing for unlisted traffic.
class MitmBadgeIcon extends StatelessWidget {
  final TrackerInfo trackerInfo;

  const MitmBadgeIcon(this.trackerInfo, {super.key});

  @override
  Widget build(BuildContext context) {
    final badge = MitmBadge.of(trackerInfo);
    if (badge == null) {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: badge.label(context),
      hoverDelay: MitmBadge.tooltipDelay,
      excludeFromSemantics: true,
      child: Semantics(
        label: badge.semanticsLabel(context),
        excludeSemantics: true,
        child: GlyphIcon(
          badge.glyph,
          size: MitmBadge.iconSize,
          color: badge.color(context),
        ),
      ),
    );
  }
}

/// [MitmRewriteBadge.of] as a glyph, after the host; independent of the
/// decryption mark before it.
class MitmRewriteIcon extends StatelessWidget {
  final TrackerInfo trackerInfo;

  const MitmRewriteIcon(this.trackerInfo, {super.key});

  @override
  Widget build(BuildContext context) {
    final badge = MitmRewriteBadge.of(trackerInfo);
    if (badge == null) {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: badge.label(context, trackerInfo.mitmRewrite!),
      hoverDelay: MitmBadge.tooltipDelay,
      excludeFromSemantics: true,
      child: Semantics(
        label: badge.semanticsLabel(context),
        excludeSemantics: true,
        child: GlyphIcon(
          badge.glyph,
          size: MitmBadge.iconSize,
          color: badge.color(context),
        ),
      ),
    );
  }
}

/// The decryption mark's place before a host, of a fixed width: kept on
/// every row while decryption is on, so hosts line up and a mark that
/// arrives later does not push its host aside. Only the host after it
/// gives way to a narrow row.
class MitmBadgeSlot extends StatelessWidget {
  final TrackerInfo trackerInfo;

  const MitmBadgeSlot(this.trackerInfo, {super.key});

  static const width = MitmBadge.iconSize + MitmBadge.gap;

  Widget _slot(Widget? mark) => SizedBox(
    width: width,
    child: Align(alignment: AlignmentDirectional.centerStart, child: mark),
  );

  @override
  Widget build(BuildContext context) {
    if (MitmBadge.of(trackerInfo) != null) {
      return _slot(MitmBadgeIcon(trackerInfo));
    }
    if (!mitmFeature) {
      return const SizedBox.shrink();
    }
    return Consumer(
      builder: (context, ref, _) =>
          ref.watch(
            patchClashConfigProvider.select((state) => state.mitm.enable),
          )
          ? _slot(null)
          : const SizedBox.shrink(),
    );
  }
}

/// A row's host line: the decryption mark first, then [host], the only part
/// that truncates, then the rewrite mark.
class MitmHostLine extends StatelessWidget {
  final TrackerInfo trackerInfo;
  final Widget host;

  const MitmHostLine({
    super.key,
    required this.trackerInfo,
    required this.host,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MitmBadgeSlot(trackerInfo),
        Flexible(child: host),
        if (MitmRewriteBadge.of(trackerInfo) != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: MitmBadge.gap),
            child: MitmRewriteIcon(trackerInfo),
          ),
      ],
    );
  }
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

/// Lays what the Core reported of each connection ([Requests.mitmStatusIndex])
/// over a connections snapshot, which carries none of it: a row is marked
/// decrypted only on the Core's own report. Built again only when the
/// snapshot or the reports change.
class MitmStatusOverlay {
  List<TrackerInfo>? _raw;
  (int, int)? _key;
  List<TrackerInfo> _shown = const [];

  /// What [apply] last returned.
  List<TrackerInfo> get shown => _shown;

  List<TrackerInfo> apply(List<TrackerInfo> raw, WidgetRef ref) {
    final requests = ref.read(requestsProvider.notifier);
    final list = ref.read(requestsProvider);
    final key = requests.mitmStatusKey(list);
    if (identical(raw, _raw) && key == _key) {
      return _shown;
    }
    _raw = raw;
    _key = key;
    final index = requests.mitmStatusIndex(list);
    if (index.isEmpty) {
      return _shown = raw;
    }
    var changed = false;
    final shown = <TrackerInfo>[];
    for (final info in raw) {
      final overlaid = info.withMitmStatus(index[info.id]);
      changed |= !identical(overlaid, info);
      shown.add(overlaid);
    }
    return _shown = changed ? shown : raw;
  }
}

/// [trackerInfo] with what the Core has reported of it since.
TrackerInfo watchTrackerMitmStatus(WidgetRef ref, TrackerInfo trackerInfo) {
  final requests = ref.watch(requestsProvider.notifier);
  final status = ref.watch(
    requestsProvider.select(
      (list) => requests.mitmStatusIndex(list)[trackerInfo.id],
    ),
  );
  return trackerInfo.withMitmStatus(status);
}

void showTrackerInfoDetail(
  BuildContext context,
  TrackerInfo trackerInfo,
  String title,
) {
  showNestedSheet<void>(
    context,
    builder: (_) => Consumer(
      builder: (context, ref, _) => Scaffold(
        body: TrackerInfoDetailView(
          trackerInfo: watchTrackerMitmStatus(ref, trackerInfo),
        ),
        title: title,
      ),
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
        metadata: trackerInfo.metadata,
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

class TrackerInfoItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ContextMenuRegion(
      menuItems: trackerInfoMenuItems(context, trackerInfo, onClose: onClose),
      child: RecordListItem(
        onTap: () => showTrackerInfoDetail(
          context,
          latest?.call() ?? trackerInfo,
          detailTitle,
        ),
        header: _buildHeader(context),
        body: _TrackerInfoBody(trackerInfo: trackerInfo),
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
    if (!isLive) {
      return RecordHeader(
        children: [RecordTimestamp(trackerInfo.start.showFull), network],
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
      ],
    );
  }
}

class _TrackerInfoBody extends StatelessWidget {
  final TrackerInfo trackerInfo;

  const _TrackerInfoBody({required this.trackerInfo});

  Widget _buildTitle(BuildContext context, RecordTextStyles styles) {
    final metadata = trackerInfo.metadata;
    final title = MitmHostLine(
      trackerInfo: trackerInfo,
      host: Text.rich(
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
    if (process.isEmpty) {
      return title;
    }
    return OwnPackageIcon(
      packageName: process,
      size: 24,
      builder: (context, icon) => icon == null
          ? title
          : Row(
              spacing: 8,
              children: [
                GestureDetector(
                  onTap: () => RecordFilterScope.add(
                    context,
                    RecordFilter(RecordFacetKind.app, process),
                  ),
                  child: icon,
                ),
                Flexible(child: title),
              ],
            ),
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

  /// The rule that decided, else the exit; a skipped rule is never shown.
  List<Widget> _buildRule(BuildContext context) {
    final l = context.appLocalizations;
    final reason = RouteReason(trackerInfo);
    final exit = reason.exit(l);
    final notes = reason.notes(l);
    return [
      if (exit != null)
        DetailRow.text(title: l.routeExitTitle, value: exit)
      else
        ?_buildRuleRow(context),
      if (notes.isNotEmpty)
        DetailRow(
          title: reason.notesTitle(l),
          copyText: notes.join('\n'),
          stacked: true,
          value: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [for (final note in notes) Text(note)],
          ),
        ),
    ];
  }

  Widget? _buildRuleRow(BuildContext context) {
    final ruleText = trackerInfo.ruleText;
    if (!canLookUpTrackerRule(context, trackerInfo)) {
      return ruleText.isEmpty
          ? null
          : DetailRow.text(
              title: context.appLocalizations.rule,
              value: ruleText,
            );
    }
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
                    .copyWith(color: context.colorScheme.primary),
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

  /// A paused connection says why, and what to do, as the Core told it.
  Widget _buildMitmRow(BuildContext context, MitmBadge badge) {
    final l = context.appLocalizations;
    final reason = trackerInfo.mitmOutcome == 'paused'
        ? mitmCorePauseReason(trackerInfo.mitmPauseReason)
        : null;
    if (reason == null) {
      return DetailRow.text(
        title: l.mitm,
        value: switch (mitmOutcomeText(context, trackerInfo.mitmOutcome)) {
          '' => badge.label(context),
          final outcome => outcome,
        },
      );
    }
    final sentence = l.mitmIndicatorPausedBecause(
      mitmPauseReasonText(l, reason),
    );
    final hint = mitmPauseReasonHint(l, reason);
    return DetailRow(
      title: l.mitm,
      copyText: sentence,
      value: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 2,
        children: [
          Text(sentence, style: TextStyle(color: mitmAmberColor(context))),
          if (hint != null)
            Text(
              hint,
              style: AppTextStyle.caption1
                  .of(context)
                  .copyWith(color: context.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
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
            ]),
            if (MitmBadge.of(trackerInfo) case final badge?)
              _buildMitmRow(context, badge),
            ..._buildRows([
              if (MitmRewriteBadge.of(trackerInfo) case final badge?)
                (
                  appLocalizations.mitmRewrite,
                  badge.label(context, trackerInfo.mitmRewrite!),
                ),
              (appLocalizations.networkType, metadata.network),
              if (process == null)
                (appLocalizations.process, trackerInfo.progressText),
            ]),
            ..._buildRule(context),
            ..._buildRows([
              (appLocalizations.upload, trackerInfo.upload.traffic.show),
              (appLocalizations.download, trackerInfo.download.traffic.show),
            ]),
          ],
        ),
        if (process != null)
          generateSection(
            title: appLocalizations.source,
            items: processDetailRows(context, process),
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
    // A connection the Core decrypted always has the tab: what it holds, or
    // why it holds nothing, is read from the Core, not from the settings.
    return DetailTabs(
      tabs: [
        (appLocalizations.overview, _buildOverview),
        if (trackerInfo.metadata.mitm)
          (
            appLocalizations.httpRequests,
            (_) => MitmExchangesView(trackerInfo: trackerInfo),
          ),
      ],
    );
  }
}
