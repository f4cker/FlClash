import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ipx_report.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'ip_quality_text.dart';
import 'labels.dart';

/// The exit address as ipx.al reports it. What the card already knows (the
/// address, its country, the organization a quality source named) shows at
/// once; the location and network fill in from `/api/me` within a second,
/// the score, type and breakdown when the report lands.
class IpxReportSections extends StatelessWidget {
  const IpxReportSections({
    super.key,
    required this.ip,
    required this.lookup,
    this.countryCode,
    this.quality,
    this.onOpenReport,
  });

  final String ip;
  final IpxLookupState lookup;
  final String? countryCode;
  final IpQuality? quality;
  final VoidCallback? onOpenReport;

  /// Rows a report will fill, laid out while it is on its way so the page
  /// keeps its height.
  static const _pendingDeductions = 3;

  @override
  Widget build(BuildContext context) {
    final localizations = context.appLocalizations;
    final report = lookup.report;
    final brief = lookup.brief;
    final pending = report == null;
    final country = report?.countryCode ?? brief?.countryCode ?? countryCode;
    final city = report?.city ?? brief?.city;
    final organization =
        report?.organization ?? brief?.organization ?? quality?.organization;
    final asn = report?.asn ?? brief?.asn ?? quality?.asn;
    final secondary = context.colorScheme.onSurfaceVariant;

    Widget valueOf(String? text, {required double width}) =>
        switch ((text, pending)) {
          (final text?, _) => Text(text),
          (null, true) => SkeletonText(width: width),
          (null, false) => const Text('—'),
        };

    final location = [?country, ?city].join(' · ');
    final nativity = report?.nativity.label(context);
    final registered = report?.registeredCountry;
    final used = report?.usedCountry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        generateSection(
          title: localizations.ipxScore,
          items: [_ScoreItem(report: report)],
        ),
        generateSection(
          title: localizations.basicInfo,
          items: [
            DetailRow(
              title: localizations.ipAddress,
              copyText: ip,
              value: IpQualityText(ip: ip),
            ),
            DetailRow(
              title: localizations.ipxLocation,
              copyText: location.isEmpty ? null : location,
              value: switch ((country, city)) {
                _ when location.isNotEmpty && (city != null || !pending) =>
                  Text(location),
                (final country?, null) when pending => Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [Text(country), const SkeletonText(width: 64)],
                ),
                _ => valueOf(null, width: 96),
              },
            ),
            DetailRow(
              title: localizations.ipType,
              value: valueOf(report?.type.label(context), width: 64),
            ),
            DetailRow(
              title: localizations.ipxNativity,
              value: switch (report) {
                null => const SkeletonText(width: 72),
                _ when nativity == null => const Text('—'),
                _ => Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(nativity),
                    if (registered != null && used != null)
                      Text(
                        localizations.ipxNativeDetail(registered, used),
                        style: AppTextStyle.footnote
                            .of(context)
                            .copyWith(color: secondary),
                      ),
                  ],
                ),
              },
            ),
          ],
        ),
        generateSection(
          title: localizations.network,
          items: [
            DetailRow(
              title: localizations.ipxIsp,
              copyText: organization,
              value: valueOf(organization, width: 120),
            ),
            DetailRow(
              title: localizations.ipAsn,
              copyText: asn == null ? null : 'AS$asn',
              value: valueOf(asn == null ? null : 'AS$asn', width: 56),
            ),
          ],
        ),
        generateSection(
          title: localizations.ipxDeductions,
          items: switch (report) {
            null => [
              for (var i = 0; i < _pendingDeductions; i++)
                const DecorationListItem(
                  title: SkeletonText(width: 160),
                  trailing: SkeletonText(width: 24),
                ),
            ],
            final report => [
              for (final deduction in report.deductions)
                _DeductionItem(deduction: deduction),
            ],
          },
        ),
        generateSection(
          items: [
            ListItem(
              title: Text(localizations.ipxFullReport),
              trailing: const GlyphIcon(AppGlyphs.openExternal),
              onTap: onOpenReport,
            ),
          ],
          footer: localizations.ipxAttribution,
        ),
      ],
    );
  }
}

class _ScoreItem extends StatelessWidget {
  const _ScoreItem({required this.report});

  final IpxReport? report;

  @override
  Widget build(BuildContext context) {
    final localizations = context.appLocalizations;
    final report = this.report;
    final scoreStyle = AppTextStyle.largeTitle.of(context, emphasized: true);
    final secondary = AppTextStyle.footnote
        .of(context)
        .copyWith(color: context.colorScheme.onSurfaceVariant);
    if (report == null) {
      return DecorationListItem(
        title: Row(
          spacing: 12,
          children: [
            SkeletonText(width: 56, style: scoreStyle),
            const SkeletonText(width: 72),
          ],
        ),
      );
    }
    final grade = report.grade;
    final color = grade.color(context);
    final ceiling = report.ceiling;
    return DecorationListItem(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        spacing: 6,
        children: [
          Text('${report.score}', style: scoreStyle.copyWith(color: color)),
          Text(localizations.ipxScoreOutOf, style: secondary),
          const Spacer(),
          Text(
            '${grade.letter} · ${grade.label(context)}',
            style: AppTextStyle.headline.of(context).copyWith(color: color),
          ),
        ],
      ),
      subtitle: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          MetaChip(label: report.type.label(context)),
          if (report.nativity.label(context) case final nativity?)
            MetaChip(label: nativity),
          if (ceiling != null)
            Text(localizations.ipxScoreCeiling(ceiling), style: secondary),
        ],
      ),
    );
  }
}

class _DeductionItem extends StatelessWidget {
  const _DeductionItem({required this.deduction});

  final IpxDeduction deduction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final points = deduction.points;
    final source = deduction.source;
    final note = deduction.note;
    // "pass" marks a check that found nothing; it is no note to read.
    final detail = [
      ?source,
      if (note != null && note != 'pass') note,
    ].join(' · ');
    return DecorationListItem(
      title: Text(deduction.label),
      subtitle: detail.isEmpty
          ? null
          : Text(
              detail,
              style: AppTextStyle.footnote
                  .of(context)
                  .copyWith(color: colorScheme.onSurfaceVariant),
            ),
      trailing: Text(
        points < 0 ? '−${-points}' : '0',
        style: AppTextStyle.subheadline
            .of(context, emphasized: points < 0)
            .copyWith(
              color: points < 0
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            )
            .toJetBrainsMono,
      ),
    );
  }
}

/// Where the detail offers ipx.al again after it did not answer: no error,
/// just the way back.
class IpxRetryItem extends StatelessWidget {
  const IpxRetryItem({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      title: Text(
        context.appLocalizations.ipxLoadReport,
        style: TextStyle(color: context.colorScheme.onSurfaceVariant),
      ),
      trailing: const GlyphIcon(AppGlyphs.refresh),
      onTap: onPressed,
    );
  }
}
