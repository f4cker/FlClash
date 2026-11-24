import 'dart:async';

import 'package:fl_clash/common/config_rejection.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/exception.dart';
import 'package:fl_clash/common/network_error.dart';
import 'package:fl_clash/core/desktop/launch_policy.dart';
import 'package:fl_clash/core/method.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:prism_ui/l10n.dart';

var _currentLocale = const Locale('en');

AppLocalizations get currentAppLocalizations =>
    lookupAppLocalizations(_currentLocale);

/// The locale [currentAppLocalizations] reads, for caches of localized text.
Locale get currentAppLocale => _currentLocale;

AppLocalizations loadAppLocalizations(Locale locale) {
  _currentLocale = AppLocalizations.delegate.isSupported(locale)
      ? locale
      : const Locale('en');
  Intl.defaultLocale = Intl.canonicalizedLocale(_currentLocale.toString());
  return lookupAppLocalizations(_currentLocale);
}

// AppLocalizations.delegate would not move currentAppLocalizations along.
const LocalizationsDelegate<AppLocalizations> appLocalizationsDelegate =
    _AppLocalizationsDelegate();

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.delegate.isSupported(locale);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(loadAppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

class AppUiLocalizations implements UiLocalizations {
  const AppUiLocalizations(this._localizations);

  static const LocalizationsDelegate<UiLocalizations> delegate =
      _AppUiLocalizationsDelegate();

  final AppLocalizations _localizations;

  @override
  String get back => _localizations.back;

  @override
  String get cancel => _localizations.cancel;

  @override
  String get clearSearch => _localizations.clearSearch;

  @override
  String get close => _localizations.close;

  @override
  String get copy => _localizations.copy;

  @override
  String get cut => _localizations.cut;

  @override
  String get details => _localizations.bannerDetails;

  @override
  String get hidePassword => _localizations.hidePassword;

  @override
  String get dialog => _localizations.dialog;

  @override
  String get more => _localizations.more;

  @override
  String get noSearchResults => _localizations.noSearchResults;

  @override
  String get paste => _localizations.paste;

  @override
  String get reset => _localizations.reset;

  @override
  String get search => _localizations.search;

  @override
  String get select => _localizations.select;

  @override
  String get selectAll => _localizations.selectAll;

  @override
  String get showLess => _localizations.showLess;

  @override
  String get showMore => _localizations.showMore;

  @override
  String get showPassword => _localizations.showPassword;

  @override
  String get sort => _localizations.sort;

  @override
  String get submit => _localizations.submit;
}

class _AppUiLocalizationsDelegate
    extends LocalizationsDelegate<UiLocalizations> {
  const _AppUiLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.delegate.isSupported(locale);

  @override
  Future<UiLocalizations> load(Locale locale) =>
      SynchronousFuture(AppUiLocalizations(lookupAppLocalizations(locale)));

  @override
  bool shouldReload(_AppUiLocalizationsDelegate old) => false;
}

String? coreLaunchBlockedMessage(
  Object error,
  AppLocalizations appLocalizations,
) {
  if (!isPolicyBlockedLaunch(error)) {
    return null;
  }
  return switch (smartAppControlStateReader()) {
    SmartAppControlState.on || SmartAppControlState.evaluation =>
      appLocalizations.coreBlockedBySmartAppControlTip,
    _ => appLocalizations.coreBlockedByPolicyTip(launchOsError(error)!),
  };
}

String? loginItemErrorMessage(Object error, AppLocalizations appLocalizations) {
  return switch (error) {
    PlatformException(code: 'login_item_requires_approval') =>
      appLocalizations.loginItemRequiresApproval,
    PlatformException(code: 'login_item_not_found') =>
      appLocalizations.loginItemNotFound,
    PlatformException(code: 'login_item_unexpected_status') =>
      appLocalizations.loginItemUnexpectedStatus,
    PlatformException(code: 'login_item_missing_status') =>
      appLocalizations.loginItemMissingStatus,
    PlatformException(:final code) when code.startsWith('login_item_') =>
      appLocalizations.loginItemOperationFailed,
    _ => null,
  };
}

String userFacingErrorMessage(Object error, AppLocalizations appLocalizations) {
  // A setup that also starts the Core waits on both, so its error is inside.
  if (error case ParallelWaitError(
    errors: (final AsyncError? first, final AsyncError? second),
  ) when first != null || second != null) {
    return userFacingErrorMessage((first ?? second)!.error, appLocalizations);
  }
  return loginItemErrorMessage(error, appLocalizations) ??
      networkErrorMessage(error, appLocalizations) ??
      coreLaunchBlockedMessage(error, appLocalizations) ??
      switch (error) {
        AgeSecretKeyRequiredException() =>
          appLocalizations.ageSecretKeyRequiredTip,
        DnsRespectRulesUnmetException() =>
          appLocalizations.dnsRespectRulesUnmetError,
        ConfigBuildException() => configBuildMessage(error, appLocalizations),
        CoreMethodException(:final message)
            when configRejectionMessage(message, appLocalizations) != null =>
          configRejectionMessage(message, appLocalizations)!,
        ReleaseNotVerifiedException() => appLocalizations.updateNotVerified,
        SystemDownloadException() => appLocalizations.updateDownloadFailed,
        CoreMethodException(code: 'rule_set_empty') =>
          appLocalizations.ruleSetEmptyTip,
        CoreMethodException(code: 'rule_set_mixed') =>
          appLocalizations.ruleSetMixedTip,
        CoreMethodException(code: 'rule_set_invalid') =>
          appLocalizations.ruleSetInvalidTip,
        CoreMethodException(
          code: 'provider_update_refused_mount',
          details: {'providerName': final String name, 'kept': true},
        ) =>
          appLocalizations.mountProviderUpdateRefused(name),
        CoreMethodException(
          code: 'provider_update_refused_mount',
          details: {'providerName': final String name},
        ) =>
          appLocalizations.mountProviderUpdateRefusedUnconfirmed(name),
        CoreMethodException(:final message) => message,
        _ => error.toString(),
      };
}

String coreSessionLostMessage(
  Object? cause,
  AppLocalizations appLocalizations,
) {
  final reason = cause == null
      ? ''
      : userFacingErrorMessage(cause, appLocalizations);
  return reason.isEmpty
      ? appLocalizations.coreStoppedDesc
      : appLocalizations.coreStoppedWithReason(reason);
}

String delayFailureText(int delay, AppLocalizations appLocalizations) {
  return delay == delayTimedOutValue
      ? appLocalizations.timeout
      : appLocalizations.delayFailed;
}

Locale? getLocaleForString(String? localString) {
  if (localString == null) return null;
  final localSplit = localString.split('_');
  if (localSplit.length == 1) {
    return Locale(localSplit[0]);
  }
  if (localSplit.length == 2) {
    return Locale(localSplit[0], localSplit[1]);
  }
  if (localSplit.length == 3) {
    return Locale.fromSubtags(
      languageCode: localSplit[0],
      scriptCode: localSplit[1],
      countryCode: localSplit[2],
    );
  }
  return null;
}
