import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/ipx_al.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/widgets.dart';

extension IpTypeLabel on IpType {
  String label(BuildContext context) {
    final localizations = context.appLocalizations;
    return switch (this) {
      IpType.residential => localizations.ipTypeResidential,
      IpType.mobile => localizations.ipTypeMobile,
      IpType.business => localizations.ipTypeBusiness,
      IpType.hosting => localizations.ipTypeHosting,
    };
  }
}

extension IpQualityLevelView on IpQualityLevel {
  String label(BuildContext context) {
    final localizations = context.appLocalizations;
    return switch (this) {
      IpQualityLevel.good => localizations.ipQualityGood,
      IpQualityLevel.normal => localizations.ipQualityNormal,
      IpQualityLevel.risky => localizations.ipQualityRisky,
    };
  }

  Color? color(BuildContext context) {
    return switch (this) {
      IpQualityLevel.good => context.colorScheme.success,
      IpQualityLevel.normal => null,
      IpQualityLevel.risky => context.colorScheme.error,
    };
  }
}

extension IpQualitySourceStatusLabel on IpQualitySourceStatus {
  String label(BuildContext context) {
    final localizations = context.appLocalizations;
    return switch (this) {
      IpQualitySourceStatus.noType => localizations.ipSourceNoType,
      IpQualitySourceStatus.timeout => localizations.timeout,
      IpQualitySourceStatus.rateLimited => localizations.ipSourceRateLimited,
      IpQualitySourceStatus.failed => localizations.serviceFailed,
      IpQualitySourceStatus.ipMismatch => localizations.ipSourceIpMismatch,
    };
  }
}

extension IpxIpTypeLabel on IpxIpType {
  String label(BuildContext context) {
    final localizations = context.appLocalizations;
    return switch (this) {
      IpxIpType.residential => localizations.ipTypeResidential,
      IpxIpType.mobile => localizations.ipTypeMobile,
      IpxIpType.education => localizations.ipxTypeEducation,
      IpxIpType.business => localizations.ipTypeBusiness,
      IpxIpType.hosting => localizations.ipTypeHosting,
      IpxIpType.pseudo => localizations.ipxTypePseudo,
      IpxIpType.unknown => localizations.ipxUnknown,
    };
  }
}

extension IpxGradeView on IpxGrade {
  String label(BuildContext context) {
    final localizations = context.appLocalizations;
    return switch (this) {
      IpxGrade.aPlus => localizations.ipxGradeExcellent,
      IpxGrade.a => localizations.ipxGradeGood,
      IpxGrade.b => localizations.ipxGradeFair,
      IpxGrade.c => localizations.ipxGradePoor,
      IpxGrade.d => localizations.ipxGradeRisky,
    };
  }

  Color? color(BuildContext context) {
    return switch (this) {
      IpxGrade.aPlus || IpxGrade.a => context.colorScheme.success,
      IpxGrade.b => null,
      IpxGrade.c => context.colorScheme.warning,
      IpxGrade.d => context.colorScheme.error,
    };
  }
}

extension IpxNativityLabel on IpxNativity {
  String label(BuildContext context) {
    final localizations = context.appLocalizations;
    return switch (this) {
      IpxNativity.native => localizations.ipxNative,
      IpxNativity.broadcast => localizations.ipxBroadcast,
      IpxNativity.unknown => localizations.ipxUnknown,
    };
  }
}
