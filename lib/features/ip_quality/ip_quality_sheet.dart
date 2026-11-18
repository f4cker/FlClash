import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/ip_quality.dart';
import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/ipx_report.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import 'ipx_report_view.dart';
import 'labels.dart';

/// Opening the detail is what asks ipx.al about [ip]; its answer is kept
/// for the session, and one that failed is asked again on the next opening.
Future<void> showIpQualitySheet(
  BuildContext context, {
  required String ip,
  String? countryCode,
}) {
  return showNestedSheet<void>(
    context,
    builder: (_) => _IpQualitySheet(ip: ip, countryCode: countryCode),
  );
}

class _IpQualitySheet extends ConsumerStatefulWidget {
  const _IpQualitySheet({required this.ip, this.countryCode});

  final String ip;
  final String? countryCode;

  @override
  ConsumerState<_IpQualitySheet> createState() => _IpQualitySheetState();
}

class _IpQualitySheetState extends ConsumerState<_IpQualitySheet> {
  @override
  void initState() {
    super.initState();
    ref.read(ipxLookupProvider(widget.ip).notifier).reload();
  }

  @override
  Widget build(BuildContext context) {
    final ip = widget.ip;
    final localizations = context.appLocalizations;
    final isLoading =
        ref.watch(ipQualityProvider(ip).select((result) => result.isLoading)) ||
        ref.watch(ipxLookupProvider(ip).select((state) => state.isLoading));
    return Scaffold(
      title: localizations.outboundIp,
      actions: [
        AppBarActionButton(
          data: IconButtonData(
            glyph: AppGlyphs.refresh,
            tooltip: localizations.ipQualityRetry,
            isLoading: isLoading,
            onPressed: () {
              ref.invalidate(ipQualityProvider(ip));
              ref.read(ipxLookupProvider(ip).notifier).retry();
            },
          ),
        ),
      ],
      body: _IpQualityDetail(ip: ip, countryCode: widget.countryCode),
    );
  }
}

class _HideIpItem extends ConsumerWidget {
  const _HideIpItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideIp = ref.watch(
      appSettingProvider.select((state) => state.hideIp),
    );
    void update(bool value) => ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(hideIp: value));
    return DecorationListItem(
      title: Text(context.appLocalizations.hideIp),
      onPressed: () => update(!hideIp),
      trailing: Switch(value: hideIp, onChanged: update),
    );
  }
}

class _IpQualityDetail extends ConsumerWidget {
  const _IpQualityDetail({required this.ip, this.countryCode});

  final String ip;
  final String? countryCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = context.appLocalizations;
    final result = ref.watch(ipQualityProvider(ip));
    final quality = result.value;
    final error = result.error;
    final failed = quality == null && !result.isLoading;
    final ipx = ref.watch(ipxLookupProvider(ip));
    final padding = const EdgeInsets.symmetric(horizontal: 16).copyWith(
      bottom: 20 + context.bottomInset,
      top: context.contentTopPadding,
    );
    if (ipx.phase != IpxPhase.failed) {
      return ListView(
        shrinkWrap: true,
        padding: padding,
        children: [
          IpxReportSections(
            ip: ip,
            lookup: ipx,
            countryCode: countryCode,
            quality: quality,
            onOpenReport: () => dialogs.openUrl(ipxAlPageUrl(ip)),
          ),
          generateSection(
            title: localizations.other,
            items: const [_HideIpItem()],
          ),
        ],
      );
    }
    // ipx.al did not answer: the detail is what it was before, with a quiet
    // way to ask again where the score would be.
    return ListView(
      shrinkWrap: true,
      padding: padding,
      children: [
        generateSection(
          title: localizations.ipxScore,
          items: [
            IpxFailedItem(
              retrying: ipx.retrying,
              onRetry: () => ref.read(ipxLookupProvider(ip).notifier).retry(),
            ),
          ],
        ),
        generateSection(
          title: localizations.basicInfo,
          items: [
            IpxAddressRow(ip: ip),
            if (failed)
              DetailRow(
                title: localizations.ipType,
                value: Text(
                  localizations.ipQualityFailed,
                  style: TextStyle(color: context.colorScheme.error),
                ),
              )
            else
              ..._qualityRows(context, quality),
          ],
        ),
        if (!failed)
          generateSection(
            title: localizations.network,
            items: _networkRows(context, quality),
          ),
        if (failed && error is IpQualityLookupException)
          generateSection(
            title: localizations.ipQualitySources,
            items: [
              for (final failure in error.failures)
                DetailRow(
                  title: failure.source.label,
                  value: Text(failure.status.label(context)),
                ),
            ],
          ),
        generateSection(
          title: localizations.other,
          items: const [_HideIpItem()],
        ),
      ],
    );
  }

  /// A lookup still running lays out every row it will fill, so the page
  /// keeps its height when the values arrive.
  List<Widget> _qualityRows(BuildContext context, IpQuality? quality) {
    final localizations = context.appLocalizations;
    if (quality == null) {
      return [
        DetailRow(
          title: localizations.ipQualityLevel,
          value: const SkeletonText(width: 40),
        ),
        DetailRow(
          title: localizations.ipType,
          value: const SkeletonText(width: 64),
        ),
        DetailRow(
          title: localizations.ipFlags,
          value: const SkeletonText(width: 40),
        ),
      ];
    }
    final flags = [
      if (quality.isTor) localizations.ipFlagTor,
      if (quality.isAbuser) localizations.ipFlagAbuser,
      if (quality.isVpn) localizations.ipFlagVpn,
      if (quality.isProxy) localizations.ipFlagProxy,
    ];
    return [
      DetailRow(
        title: localizations.ipQualityLevel,
        value: Text(
          quality.level.label(context),
          style: TextStyle(color: quality.level.color(context)),
        ),
      ),
      DetailRow(
        title: localizations.ipType,
        value: Text(quality.type.label(context)),
      ),
      DetailRow(
        title: localizations.ipFlags,
        value: flags.isEmpty
            ? Text(localizations.none)
            : Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: [for (final flag in flags) MetaChip(label: flag)],
              ),
      ),
    ];
  }

  List<Widget> _networkRows(BuildContext context, IpQuality? quality) {
    final localizations = context.appLocalizations;
    Widget valueOf(String? text, {required double width}) =>
        switch ((quality, text)) {
          (null, _) => SkeletonText(width: width),
          (_, final text?) => Text(text),
          _ => Text(localizations.ipxUnknown),
        };
    final organization = quality?.organization;
    final asn = switch (quality?.asn) {
      final asn? => 'AS$asn',
      null => null,
    };
    return [
      DetailRow(
        title: localizations.ipxIsp,
        copyText: organization,
        value: valueOf(organization, width: 120),
      ),
      DetailRow(
        title: localizations.ipAsn,
        copyText: asn,
        value: valueOf(asn, width: 56),
      ),
      DetailRow(
        title: localizations.ipQualitySource,
        value: valueOf(quality?.source.label, width: 72),
      ),
    ];
  }
}
