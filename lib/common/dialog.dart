import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class Dialogs {
  Dialogs._();

  // Focus sits in the route the user acts in, so an alert raised from a form
  // sheet, or a page pushed inside one, opens over it, beside the navigation
  // as the sheet sits.
  BuildContext get _context {
    var context = FocusManager.instance.primaryFocus?.context;
    while (context != null) {
      final route = ModalRoute.of(context);
      if (route is AlertHostRoute) {
        final host = route.navigator;
        if (host != null && host.mounted) {
          return host.context;
        }
        break;
      }
      context = route?.navigator?.context;
    }
    return rootNavigatorKey.currentContext!;
  }

  Future<T?> showCommonDialog<T>({
    required Widget child,
    BuildContext? context,
    bool? dismissible,
  }) async {
    return showFloatingDialog<T>(
      context: context ?? _context,
      child: child,
      dismissible: dismissible ?? true,
    );
  }

  /// [body] stands in for [message] when the text needs widgets of its own.
  Future<bool?> showMessage({
    InlineSpan? message,
    Widget? body,
    BuildContext? context,
    String? title,
    String? confirmText,
    String? cancelText,
    bool? dismissible,
    bool destructive = false,
    double? width,
  }) {
    assert(message != null || body != null);
    return _showMessage(
      message: message,
      body: body,
      context: context,
      title: title,
      confirmText: confirmText,
      cancelText: cancelText,
      dismissible: dismissible,
      destructive: destructive,
      cancelable: true,
      width: width,
    );
  }

  /// Asked on leaving with unsaved changes: true saves, false leaves without
  /// saving, and null, the alert dismissed, stays.
  Future<bool?> showSaveChanges({String? title}) {
    return showMessage(
      title: title,
      message: TextSpan(text: currentAppLocalizations.saveChanges),
    );
  }

  /// A message with nothing to decide, acknowledged with a single button.
  Future<void> showAlert({
    required InlineSpan message,
    String? title,
    bool? dismissible,
    String? confirmText,
  }) {
    return _showMessage(
      message: message,
      title: title,
      dismissible: dismissible,
      cancelable: false,
      confirmText: confirmText,
    );
  }

  Future<bool?> _showMessage({
    required InlineSpan? message,
    required bool cancelable,
    Widget? body,
    BuildContext? context,
    String? title,
    String? confirmText,
    String? cancelText,
    bool? dismissible,
    bool destructive = false,
    double? width,
  }) async {
    return showCommonDialog<bool>(
      context: context,
      dismissible: dismissible,
      child: Builder(
        builder: (context) {
          final appLocalizations = context.appLocalizations;
          return AlertDialog(
            title: title ?? appLocalizations.tip,
            destructive: destructive,
            width: width,
            actions: [
              if (cancelable)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(cancelText ?? appLocalizations.cancel),
                ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: Text(confirmText ?? appLocalizations.confirm),
              ),
            ],
            child:
                body ??
                SelectableText.rich(
                  TextSpan(children: [?message]),
                  style: const TextStyle(overflow: TextOverflow.visible),
                ),
          );
        },
      ),
    );
  }

  Future<void> showFailureDetails(List<UpdatingMessage> failures) {
    return showNestedSheet(
      _context,
      builder: (_) => _FailureDetailsSheet(failures: failures),
    );
  }

  Future<void> showQrCode({
    required String title,
    required String data,
    String? message,
  }) {
    return showCommonDialog<void>(
      child: Builder(
        builder: (context) => AlertDialog(
          title: title,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.appLocalizations.close),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              if (QrCodeView.fits(data)) ...[
                QrCodeView(data: data),
                if (message != null) Text(message, textAlign: TextAlign.center),
              ] else
                Text(
                  context.appLocalizations.qrcodeTooLongTip,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> showUrlInput({
    required String title,
    String value = '',
    bool Function(String value)? accepts,
  }) {
    final appLocalizations = currentAppLocalizations;
    return showCommonDialog<String>(
      child: InputDialog(
        title: title,
        value: value,
        labelText: appLocalizations.url,
        inputFormatters: TextInputLimits.limit(TextInputLimits.url),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return appLocalizations.emptyTip(appLocalizations.value);
          }
          if (!(accepts?.call(value) ?? value.isUrl)) {
            return appLocalizations.urlTip(appLocalizations.value);
          }
          return null;
        },
      ),
    );
  }

  Future<String?> showPasswordInput({required String title}) {
    return showCommonDialog<String>(
      child: InputDialog(
        title: title,
        value: '',
        labelText: currentAppLocalizations.password,
        obscureText: true,
      ),
    );
  }

  Future<String?> showAgeSecretKeyInput() {
    final appLocalizations = currentAppLocalizations;
    return showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.ageEncryptedProfile,
        value: '',
        labelText: appLocalizations.ageSecretKey,
        obscureText: true,
        validator: (value) => value == null || value.trim().isEmpty
            ? appLocalizations.emptyTip(appLocalizations.ageSecretKey)
            : null,
      ),
    );
  }

  void showBanner(
    String text, {
    BannerLevel level = BannerLevel.info,
    VoidCallback? onTap,
  }) {
    if (text.isEmpty) {
      return;
    }
    commonPrint.log('banner: $text');
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      return;
    }
    BannerHost.maybeOf(context)?.show(text, level: level, onTap: onTap);
  }

  /// A config the Core refused opens its raw words on a tap.
  void showErrorBanner(Object error) {
    final message = userFacingErrorMessage(error, currentAppLocalizations);
    final raw = rawConfigErrorOf(error);
    showBanner(
      message,
      level: BannerLevel.error,
      onTap: raw == null || raw == message
          ? null
          : () => unawaited(showErrorDetails(message: message, raw: raw)),
    );
  }

  Future<void> showErrorDetails({
    required String message,
    required String raw,
    String? title,
  }) {
    return _showMessage(
      message: null,
      title: title,
      cancelable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          SelectableText(message),
          RawErrorDetails(key: ValueKey(raw), raw: raw),
        ],
      ),
    );
  }

  Future<void> copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    showBanner(currentAppLocalizations.copySuccess);
  }

  void showFailures(List<UpdatingMessage> failures) {
    final appLocalizations = currentAppLocalizations;
    switch (failures) {
      case []:
        return;
      case [final failure]:
        showBanner(
          appLocalizations.failedItem(failure.label, failure.message),
          level: BannerLevel.error,
        );
      default:
        showBanner(
          appLocalizations.failedCount(failures.length),
          level: BannerLevel.error,
          onTap: () {
            unawaited(showFailureDetails(failures));
          },
        );
    }
  }

  void showMixedPortReset(Object value, int port) {
    commonPrint.log(
      'mixed-port $value reset to $port',
      logLevel: LogLevel.warning,
    );
    showBanner(
      currentAppLocalizations.mixedPortReset(value, port),
      level: BannerLevel.warning,
    );
  }

  Future<void> openUrl(String url) async {
    final res = await showMessage(
      message: TextSpan(text: url),
      title: currentAppLocalizations.externalLink,
      confirmText: currentAppLocalizations.go,
    );
    if (res != true) {
      return;
    }
    unawaited(launchUrl(Uri.parse(url)));
  }
}

class _FailureDetailsSheet extends StatelessWidget {
  final List<UpdatingMessage> failures;

  const _FailureDetailsSheet({required this.failures});

  @override
  Widget build(BuildContext context) {
    final labelsByMessage = <String, List<String>>{};
    for (final failure in failures) {
      (labelsByMessage[failure.message] ??= []).add(failure.label);
    }
    final groups = labelsByMessage.entries.toList();
    return Scaffold(
      title: context.appLocalizations.errorDetails,
      body: SelectionArea(
        child: PrismListView(
          padding: context.listInsets.page().copyWith(
            top: context.sectionsTopPadding,
            bottom: 20 + context.bottomInset,
          ),
          itemCount: groups.length,
          itemBuilder: (_, index) {
            final MapEntry(key: message, value: labels) = groups[index];
            return generateSection(
              items: [
                for (final label in labels)
                  DecorationListItem(
                    title: TooltipText(
                      text: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
              footer: message,
              last: index == groups.length - 1,
            );
          },
        ),
      ),
    );
  }
}

final dialogs = Dialogs._();
