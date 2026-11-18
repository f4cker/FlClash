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
/// the score, type and breakdown when the report lands. Whatever the report
/// leaves out reads as unknown: its estimates are never filled in.
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
    final unknown = localizations.ipxUnknown;
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
          (null, false) => Text(unknown),
        };

    final location = [?country, ?city].join(' · ');
    final registered = report?.registeredCountry;
    final used = report?.usedCountry;
    final asnText = asn == null ? null : 'AS$asn';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        generateSection(
          title: localizations.ipxScore,
          items: [IpxScoreItem(report: report)],
        ),
        generateSection(
          title: localizations.basicInfo,
          items: [
            IpxAddressRow(ip: ip),
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
                final report => Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(report.nativity.label(context)),
                    if (report.nativity != IpxNativity.unknown &&
                        registered != null &&
                        used != null)
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
              copyText: asnText,
              value: valueOf(asnText, width: 56),
            ),
          ],
        ),
        // A scored report that lists nothing took nothing off.
        if (report == null ||
            report.deductions.isNotEmpty ||
            report.score == null)
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
              IpxReport(deductions: []) => [
                DecorationListItem(title: Text(unknown)),
              ],
              final report => [
                for (final deduction in report.sortedDeductions)
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
        ),
        IpxFootnote(
          lines: [
            localizations.ipxAttribution,
            // Only what the Core says the report took, never the setting.
            if (lookup.viaProxy) localizations.ipxViaExit,
          ],
        ),
      ],
    );
  }
}

/// The address, plain and monospaced: the grade beside it carries the
/// colour.
class IpxAddressRow extends StatelessWidget {
  const IpxAddressRow({super.key, required this.ip});

  final String ip;

  @override
  Widget build(BuildContext context) {
    return DetailRow(
      title: context.appLocalizations.ipAddress,
      copyText: ip,
      value: IpQualityText(
        ip: ip,
        tinted: false,
        style: const TextStyle().toJetBrainsMono,
      ),
    );
  }
}

/// A section footer set in from the edge as far as the section titles.
class IpxFootnote extends StatelessWidget {
  const IpxFootnote({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final inset = listHeaderPaddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(inset.left, 8, inset.right, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          for (final line in lines) Text(line, style: context.listCaptionStyle),
        ],
      ),
    );
  }
}

class IpxScoreItem extends StatelessWidget {
  const IpxScoreItem({super.key, required this.report});

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
    final score = report.score;
    final grade = report.grade;
    final color = grade?.color(context);
    final ceiling = report.ceiling;
    return DecorationListItem(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        spacing: 6,
        children: [
          if (score != null) ...[
            Text('$score', style: scoreStyle.copyWith(color: color)),
            Text(localizations.ipxScoreOutOf, style: secondary),
          ] else
            Text(
              localizations.ipxUnknown,
              style: AppTextStyle.headline.of(context),
            ),
          const Spacer(),
          if (grade != null)
            Text(
              '${grade.letter} · ${grade.label(context)}',
              style: AppTextStyle.headline.of(context).copyWith(color: color),
            ),
        ],
      ),
      subtitle: Text(
        localizations.ipxScoreCeiling(
          ceiling == null ? localizations.ipxUnknown : '$ceiling',
        ),
        style: secondary,
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
    final deducted = points != null && points < 0;
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
        switch (points) {
          null => context.appLocalizations.ipxUnknown,
          < 0 => '−${-points}',
          _ => '$points',
        },
        style: AppTextStyle.subheadline
            .of(context, emphasized: deducted)
            .copyWith(
              color: deducted
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
            )
            .toJetBrainsMono,
      ),
    );
  }
}

/// Where the score would be when ipx.al did not answer: no error colour,
/// just the way to ask again, which spins and holds still until it answers.
class IpxFailedItem extends StatelessWidget {
  const IpxFailedItem({
    super.key,
    required this.retrying,
    required this.onRetry,
  });

  final bool retrying;
  final VoidCallback onRetry;

  static const _spinnerSize = 18.0;

  @override
  Widget build(BuildContext context) {
    final localizations = context.appLocalizations;
    return DecorationListItem(
      title: Text(
        localizations.ipxReportFailed,
        style: TextStyle(color: context.colorScheme.onSurfaceVariant),
      ),
      trailing: retrying
          ? Semantics(
              label: localizations.ipxRetry,
              enabled: false,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: ActivityIndicator(size: _spinnerSize),
              ),
            )
          : TextButton(onPressed: onRetry, child: Text(localizations.ipxRetry)),
    );
  }
}
