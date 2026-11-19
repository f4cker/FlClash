import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_body.dart';
import 'package:fl_clash/common/mitm_rewrite.dart';
import 'package:fl_clash/features/connection/mitm_script_hits.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'detail_tabs.dart';
import 'mitm_body.dart';
import 'mitm_exchange_menu.dart';
import 'mitm_rewrite_hits.dart';

String _millis(int milliseconds) {
  if (milliseconds < 1000) {
    return '$milliseconds ms';
  }
  return '${(milliseconds / 1000).toStringAsFixed(1)} s';
}

String _pathOf(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasAuthority) {
    return url;
  }
  final path = uri.path.isEmpty ? '/' : uri.path;
  return uri.hasQuery ? '$path?${uri.query}' : path;
}

EdgeInsets _detailPadding(BuildContext context) => const EdgeInsets.symmetric(
  horizontal: 16,
).copyWith(bottom: 20 + context.bottomInset, top: context.sectionsTopPadding);

String _statusText(
  AppLocalizations appLocalizations, {
  required bool pending,
  required int status,
}) {
  if (status != 0) {
    return '$status';
  }
  return pending ? appLocalizations.inProgress : '';
}

String _actionLabel(AppLocalizations appLocalizations, MitmAction action) {
  return switch (action.kind) {
    'url-rewrite' => appLocalizations.urlRewrite,
    'header-rewrite' => appLocalizations.headerRewrite,
    'body-rewrite' => appLocalizations.bodyRewrite,
    'map-local' => appLocalizations.mapLocal,
    'script' => appLocalizations.script,
    _ => action.kind,
  };
}

String _phaseLabel(AppLocalizations appLocalizations, String phase) {
  return switch (phase) {
    'request' => appLocalizations.request,
    'response' => appLocalizations.response,
    _ => phase,
  };
}

Future<void> _copyError(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  dialogs.showBanner(context.appLocalizations.copySuccess);
}

/// The requests captured on a decrypted connection.
class MitmExchangesView extends ConsumerWidget {
  final TrackerInfo trackerInfo;

  const MitmExchangesView({super.key, required this.trackerInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final (list, loading, error) = ref.watch(
      mitmExchangesProvider(trackerInfo.id).select(
        (value) => (
          value.value,
          !value.hasValue && (value.isLoading || value.retrying),
          value.hasValue || value.retrying ? null : value.error,
        ),
      ),
    );
    final errorText = error == null
        ? null
        : userFacingErrorMessage(error, appLocalizations);
    final exchanges = list?.exchanges ?? const <MitmExchangeSummary>[];
    final since = list?.since;
    final missing = since != null && trackerInfo.start.isBefore(since);
    return NullStatusSwitcher(
      isLoading: loading,
      isEmpty: exchanges.isEmpty,
      nullStatus: NullStatus(
        label: errorText != null
            ? appLocalizations.httpRequestsReadFailed
            : list?.capturing == false
            ? appLocalizations.httpCaptureOff
            : missing
            ? appLocalizations.httpRequestsMissing
            : appLocalizations.nullTip(appLocalizations.httpRequests),
        description: errorText,
        action: errorText == null
            ? null
            : TonalButton(
                size: TonalButtonSize.bar,
                glyph: AppGlyphs.copy,
                label: appLocalizations.copy,
                onPressed: () => _copyError(context, errorText),
              ),
        illustration: NullStatusIllustration.requests,
      ),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: _detailPadding(context),
            sliver: generateSliverSection(
              items: exchanges,
              itemBuilder: (exchange) => _MitmExchangeItem(exchange: exchange),
              footer: missing ? appLocalizations.httpRequestsMissing : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Why the Core says a request did not complete, in words; a code this app
/// does not know reads as a plain failure.
String mitmExchangeErrorText(AppLocalizations l, String error) {
  return switch (error) {
    'noResponse' => l.mitmExchangeNoResponse,
    'responseFailed' => l.mitmExchangeResponseFailed,
    'stopped' => l.mitmExchangeStopped,
    _ => l.mitmExchangeFailed,
  };
}

/// The protocol of an exchange as a row shows it: h2 or 1.1.
String mitmProtoLabel(String proto) => switch (proto) {
  'HTTP/2.0' || 'HTTP/2' => 'h2',
  'HTTP/1.1' => '1.1',
  'HTTP/1.0' => '1.0',
  _ => '',
};

class _MitmExchangeItem extends ConsumerWidget {
  final MitmExchangeSummary exchange;

  const _MitmExchangeItem({required this.exchange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final failed = exchange.error.isNotEmpty;
    final result = failed
        ? mitmExchangeErrorText(context.appLocalizations, exchange.error)
        : exchange.status == 0
        ? ''
        : '${exchange.status}';
    final proto = mitmProtoLabel(exchange.proto);
    final outcome = [result, proto].where((s) => s.isNotEmpty).join(' · ');
    return ContextMenuRegion(
      menuItems: mitmExchangeMenuItems(
        context,
        ref,
        url: exchange.url,
        pending: exchange.pending,
        status: exchange.status,
        responseSize: exchange.responseSize,
        modules: watchLocalMitmModules(ref),
        load: () => ref.read(coreHandlerProvider).getMitmExchange(exchange.id),
      ),
      child: ListItem(
        title: Text(
          '${exchange.method} ${_pathOf(exchange.url)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: outcome.isEmpty
            ? null
            : Text(
                outcome,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: failed ? TextStyle(color: colorScheme.error) : null,
              ),
        trailing: Text(
          exchange.pending
              ? context.appLocalizations.inProgress
              : _millis(exchange.duration),
          style: AppTextStyle.subheadline
              .of(context)
              .copyWith(color: colorScheme.onSurfaceVariant),
        ),
        onTap: () => showNestedSheet<void>(
          context,
          builder: (_) => MitmExchangeView(id: exchange.id),
        ),
      ),
    );
  }
}

class MitmExchangeView extends ConsumerWidget {
  final int id;

  const MitmExchangeView({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final value = ref.watch(mitmExchangeProvider(id));
    final exchange = value.value;
    final modules = watchLocalMitmModules(ref);
    return Scaffold(
      title: appLocalizations.details(appLocalizations.request),
      menuItems: exchange == null
          ? const []
          : mitmExchangeMenuItems(
              context,
              ref,
              url: exchange.url,
              pending: exchange.pending,
              status: exchange.status,
              responseSize: exchange.responseSize,
              modules: modules,
              load: () async => exchange,
            ),
      body: NullStatusSwitcher(
        isLoading: value.isLoading && !value.hasValue,
        isEmpty: exchange == null,
        nullStatus: NullStatus(
          label: appLocalizations.httpRequestCleared,
          illustration: NullStatusIllustration.requests,
        ),
        child: exchange == null
            ? const SizedBox.shrink()
            : _MitmExchangeDetail(exchange: exchange),
      ),
    );
  }
}

class _MitmExchangeDetail extends StatelessWidget {
  final MitmExchange exchange;

  const _MitmExchangeDetail({required this.exchange});

  Widget _buildOverview(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final overview = [
      (appLocalizations.url, exchange.url),
      (appLocalizations.originalUrl, exchange.originalUrl),
      (appLocalizations.method, exchange.method),
      (appLocalizations.protocol, exchange.proto),
      (
        appLocalizations.status,
        _statusText(
          appLocalizations,
          pending: exchange.pending,
          status: exchange.status,
        ),
      ),
      (
        appLocalizations.error,
        exchange.error.isEmpty
            ? ''
            : mitmExchangeErrorText(appLocalizations, exchange.error),
      ),
      (appLocalizations.creationTime, exchange.start.showFull),
      if (exchange.status != 0)
        (appLocalizations.timeToFirstByte, _millis(exchange.ttfb)),
      if (!exchange.pending)
        (appLocalizations.duration, _millis(exchange.duration)),
      if (exchange.requestSize > 0)
        (appLocalizations.requestBody, exchange.requestSize.traffic.show),
      (appLocalizations.responseBody, exchange.responseSize.traffic.show),
    ];
    final rewrites = [
      for (final action in exchange.actions)
        if (mitmListOfKey(action.kind) != null) action,
    ];
    final others = [
      for (final action in exchange.actions)
        if (mitmListOfKey(action.kind) == null && action.kind != mitmScriptKind)
          action,
    ];
    final scripted = exchange.actions.any(
      (action) => action.kind == mitmScriptKind,
    );
    return ListView(
      padding: _detailPadding(context),
      children: [
        if (rewrites.isNotEmpty) MitmRewriteHitsSection(exchange: exchange),
        if (scripted) MitmScriptHitsSection(exchange: exchange),
        generateSection(
          title: appLocalizations.basicInfo,
          items: [
            for (final (title, value) in overview)
              if (value.isNotEmpty) DetailRow.text(title: title, value: value),
          ],
        ),
        generateSection(
          title: appLocalizations.matchedRules,
          items: [
            for (final action in others)
              DetailRow(
                title: _actionLabel(appLocalizations, action),
                value: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (action.phase.isNotEmpty)
                      MetaChip(
                        label: _phaseLabel(appLocalizations, action.phase),
                      ),
                    if (action.detail.isNotEmpty) Text(action.detail),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return DetailTabs(
      tabs: [
        (appLocalizations.overview, _buildOverview),
        (
          appLocalizations.request,
          (_) => _MitmSideView(exchange: exchange, response: false),
        ),
        (
          appLocalizations.response,
          (_) => _MitmSideView(exchange: exchange, response: true),
        ),
      ],
    );
  }
}

/// One side of a request: its headers, then its body once the request ends.
/// A side rewrite rules changed shows as it went on, or as it came.
class _MitmSideView extends ConsumerStatefulWidget {
  final MitmExchange exchange;
  final bool response;

  const _MitmSideView({required this.exchange, required this.response});

  @override
  ConsumerState<_MitmSideView> createState() => _MitmSideViewState();
}

class _MitmSideViewState extends ConsumerState<_MitmSideView> {
  bool _before = false;

  @override
  Widget build(BuildContext context) {
    final exchange = widget.exchange;
    final response = widget.response;
    final appLocalizations = context.appLocalizations;
    final originalHeader = response
        ? exchange.originalResponseHeader
        : exchange.originalRequestHeader;
    final originalBody = response
        ? exchange.originalResponseBody
        : exchange.originalRequestBody;
    final changed = originalHeader.isNotEmpty || originalBody;
    final before = changed && _before;
    final header = before && originalHeader.isNotEmpty
        ? originalHeader
        : response
        ? exchange.responseHeader
        : exchange.requestHeader;
    final size = response ? exchange.responseSize : exchange.requestSize;
    final bodyTitle = response
        ? appLocalizations.responseBody
        : appLocalizations.requestBody;
    final sending = size > 0 && exchange.pending;
    final body = (size > 0 || (before && originalBody)) && !exchange.pending
        ? ref.watch(
            mitmBodyProvider(
              exchange.id,
              response: response,
              contentType: mitmHeaderValue(header, 'Content-Type'),
              original: before && originalBody,
            ),
          )
        : null;
    final content = body?.value;
    final kept =
        content != null && (content.bytes.isNotEmpty || content.truncated);
    final bodyError = body != null && !body.hasValue && !body.retrying
        ? body.error
        : null;
    final names = header.keys.toList()..sort();
    // Small, at the end of the headers' title row, not a row of its own
    // (design review 1 §5).
    final toggle = changed
        ? SegmentedControl<bool>(
            dense: true,
            segments: [
              (true, appLocalizations.mitmRewriteBefore),
              (false, appLocalizations.mitmRewriteAfter),
            ],
            value: before,
            onChanged: (value) => setState(() => _before = value),
          )
        : null;
    return NullStatusSwitcher(
      isLoading:
          body != null && body.isLoading && !body.hasValue && bodyError == null,
      isEmpty:
          header.isEmpty &&
          !sending &&
          !kept &&
          bodyError == null &&
          toggle == null,
      nullStatus: NullStatus(
        label: exchange.pending
            ? appLocalizations.inProgress
            : appLocalizations.nullTip(
                response ? appLocalizations.response : appLocalizations.request,
              ),
        illustration: NullStatusIllustration.requests,
      ),
      child: ListView(
        padding: _detailPadding(context),
        children: [
          if (names.isNotEmpty || toggle != null)
            ListHeader(
              title: response
                  ? appLocalizations.responseHeaders
                  : appLocalizations.requestHeaders,
              trailing: toggle,
            ),
          generateGroup([
            for (final name in names)
              for (final value in header[name]!)
                DetailRow.text(title: name, value: value),
          ]),
          if (sending)
            generateSection(
              title: bodyTitle,
              items: [ListItem(title: Text(appLocalizations.inProgress))],
            ),
          if (kept) MitmBodySection(title: bodyTitle, content: content),
          if (bodyError != null)
            generateSection(
              title: bodyTitle,
              items: [
                DetailRow.text(
                  title: response
                      ? appLocalizations.responseBodyReadFailed
                      : appLocalizations.requestBodyReadFailed,
                  value: userFacingErrorMessage(bodyError, appLocalizations),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
