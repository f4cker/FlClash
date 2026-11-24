part of '../dns.dart';

/// Set by a turn-on the page held back, since the list was empty.
final _respectRulesPromptProvider =
    NotifierProvider.autoDispose<_RespectRulesPrompt, bool>(
      _RespectRulesPrompt.new,
    );

class _RespectRulesPrompt extends Notifier<bool> {
  @override
  bool build() => false;

  set shown(bool value) => state = value;
}

bool _respectRules(Dns dns) => dns.respectRules;

Dns _setRespectRules(Dns dns, bool value) => dns.copyWith(respectRules: value);

/// A `#` entry goes through a proxy, so could not find the proxy servers.
List<String> _copyableNameservers(Dns dns) => [
  for (final server in dns.nameserver)
    if (!server.contains('#')) server,
];

String? _proxyServerSaveError(Dns dns, List<String> servers) =>
    dns.respectRules && servers.isEmpty
    ? currentAppLocalizations.dnsRespectRulesUnmetWarning
    : null;

/// The width under which, as with large text, the prompt stacks its buttons.
const _stackedWidth = 600.0;

typedef _DnsTarget = OverrideTarget<DnsOverrideKey, Dns>;

void _writeDns(WidgetRef ref, _DnsTarget target, Dns Function(Dns) update) {
  ref.read(_respectRulesPromptProvider.notifier).shown = false;
  target.update(ref, (state) => (model: update(state.model), keys: state.keys));
}

/// Opens the Proxy Server Nameserver list; with [turnOn], saving servers in
/// it also turns the switch on, and nothing else does.
Future<void> _fillProxyServerNameserver(
  BuildContext context,
  WidgetRef ref,
  _DnsTarget target, {
  required bool turnOn,
}) async {
  final appLocalizations = context.appLocalizations;
  final result = await showNestedExtend<dynamic>(
    context,
    props: const ExtendProps(forceFull: true),
    builder: (_) => ListEditView(
      title: DnsOverrideKey.proxyServerNameserver.label(appLocalizations),
      description: appLocalizations.proxyServerNameserverDesc,
      items: target.read(ref).model.proxyServerNameserver,
      itemMaxLength: TextInputLimits.dnsServer,
      itemValidator: (item) => validateDnsServer(item, appLocalizations),
      titleBuilder: (item) => Text(item),
      saveError: (servers) =>
          _proxyServerSaveError(target.read(ref).model, servers),
    ),
  );
  if (result is! List || !context.mounted) {
    return;
  }
  final servers = List<String>.from(result);
  if (turnOn && servers.isEmpty) {
    return;
  }
  _writeDns(
    ref,
    target,
    (dns) => dns.copyWith(
      proxyServerNameserver: servers,
      respectRules: dns.respectRules || turnOn,
    ),
  );
}

/// mihomo refuses the switch without a Proxy Server Nameserver, so on the
/// app page it asks for one, under the switch, rather than turning on.
class _RespectRulesField extends ToggleOverrideField<Dns> {
  const _RespectRulesField() : super(_respectRules, _setRespectRules);

  @override
  Widget build(
    OverrideModel<Dns> model, {
    required ConfigLabel title,
    required Widget? leading,
  }) {
    if (model is! PatchOverrideTarget<DnsOverrideKey, Dns>) {
      return super.build(model, title: title, leading: leading);
    }
    return _RespectRulesRow(
      field: this,
      target: model,
      title: title,
      leading: leading,
    );
  }
}

class _ProxyServerNameserverField extends ListOverrideField<Dns> {
  const _ProxyServerNameserverField()
    : super(
        _proxyServerNameserver,
        _setProxyServerNameserver,
        itemMaxLength: TextInputLimits.dnsServer,
        itemValidator: validateDnsServer,
        description: _proxyServerNameserverDesc,
      );

  @override
  Widget build(
    OverrideModel<Dns> model, {
    required ConfigLabel title,
    required Widget? leading,
  }) {
    if (model is! PatchOverrideTarget<DnsOverrideKey, Dns>) {
      return super.build(model, title: title, leading: leading);
    }
    return ConfigListEditItem(
      leading: leading,
      title: title,
      selector: model.selectModel(select),
      onChanged: model.modelWriter(update),
      itemMaxLength: itemMaxLength,
      itemValidator: itemValidator,
      description: description,
      saveError: (ref, servers) =>
          _proxyServerSaveError(model.read(ref).model, servers),
    );
  }
}

List<String> _proxyServerNameserver(Dns dns) => dns.proxyServerNameserver;

Dns _setProxyServerNameserver(Dns dns, List<String> value) =>
    dns.copyWith(proxyServerNameserver: value);

String _proxyServerNameserverDesc(AppLocalizations l) =>
    l.proxyServerNameserverDesc;

class _RespectRulesRow extends ConsumerWidget {
  const _RespectRulesRow({
    required this.field,
    required this.target,
    required this.title,
    required this.leading,
  });

  final _RespectRulesField field;
  final PatchOverrideTarget<DnsOverrideKey, Dns> target;
  final ConfigLabel title;
  final Widget? leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final write = target.modelWriter(field.update);
    final held = ref.watch(
      target.selectModel(
        (dns) => !dns.respectRules && dns.proxyServerNameserver.isEmpty,
      ),
    );
    final prompted = held && ref.watch(_respectRulesPromptProvider);
    final position = ItemPositionProvider.of(context)?.position;
    final bottomOpen = prompted && position != null;
    Widget toggle = ConfigToggleItem(
      leading: leading,
      title: title,
      selector: target.selectModel(field.select),
      onChanged: (ref, value) {
        final servers = ref.read(
          target.selectModel((dns) => dns.proxyServerNameserver),
        );
        final hold = value && servers.isEmpty;
        ref.read(_respectRulesPromptProvider.notifier).shown = hold;
        if (!hold) {
          write(ref, value);
        }
      },
    );
    if (bottomOpen) {
      // The prompt carries on the row, so the row leaves its end to it.
      toggle = ItemPositionProvider(
        position: switch (position) {
          ItemPosition.startAndEnd || ItemPosition.start => ItemPosition.start,
          _ => ItemPosition.middle,
        },
        child: toggle,
      );
    }
    final end =
        position == ItemPosition.end || position == ItemPosition.startAndEnd;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        toggle,
        AnimatedSize(
          duration: commonDuration,
          alignment: Alignment.topCenter,
          child: prompted
              ? DecoratedBox(
                  decoration: ShapeDecoration(
                    color: position == null
                        ? const Color(0x00000000)
                        : context.raisedSurfaceLevel.colorOf(
                            context.colorScheme,
                          ),
                    shape: AppShape.of(
                      AppRadius.vertical(
                        top: AppCorner.none,
                        bottom: end ? AppCorner.listGroup : AppCorner.none,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.listInsets.leading,
                      vertical: 12,
                    ),
                    child: _RespectRulesPromptCard(target),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _RespectRulesPromptCard extends ConsumerWidget {
  const _RespectRulesPromptCard(this.target);

  final _DnsTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final copyable = ref.watch(
      target.selectModel((dns) => _copyableNameservers(dns).isNotEmpty),
    );
    final foreground = colorScheme.onSecondaryContainer;
    final stacked =
        MediaQuery.sizeOf(context).width <= _stackedWidth ||
        MediaQuery.textScalerOf(context).scale(16) > 24;
    Widget button(String label, VoidCallback onPressed) => stacked
        ? _StackedButton(label: label, onPressed: onPressed)
        : TonalButton(
            size: TonalButtonSize.compact,
            label: label,
            onPressed: onPressed,
          );
    final fill = button(
      appLocalizations.dnsFillProxyServerNameserver,
      () => _fillProxyServerNameserver(context, ref, target, turnOn: true),
    );
    final copy = !copyable
        ? null
        : button(
            appLocalizations.dnsUseNameserverForProxyServer,
            () => _writeDns(
              ref,
              target,
              (dns) => dns.copyWith(
                proxyServerNameserver: _copyableNameservers(dns),
                respectRules: true,
              ),
            ),
          );
    final note = copy == null
        ? null
        : Text(
            appLocalizations.dnsUseNameserverForProxyServerDesc,
            style: AppTextStyle.footnote
                .of(context)
                .copyWith(color: foreground),
          );
    final cancel = button(
      appLocalizations.cancel,
      () => ref.read(_respectRulesPromptProvider.notifier).shown = false,
    );
    return _Notice(
      glyph: AppGlyphs.info,
      color: colorScheme.secondaryContainer,
      foregroundColor: foreground,
      message: appLocalizations.dnsRespectRulesNeedsProxyServer,
      // Stacked, the buttons that change a setting each take a row of their
      // own, apart from the one that cancels.
      actions: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [fill, ?copy, ?note, cancel],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [fill, ?copy, cancel],
                ),
                ?note,
              ],
            ),
    );
  }
}

/// A [TonalButton] a row wide, whose label wraps inside its corners when the
/// text is large.
class _StackedButton extends StatelessWidget {
  const _StackedButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElasticPress(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: context.raisedSurfaceLevel.colorOf(context.colorScheme),
          shape: AppShape.lg,
        ),
        child: TonalButtonTheme(
          grouped: true,
          size: TonalButtonSize.compact,
          child: FilledButton(
            style: const ButtonStyle(
              shape: AppShape.lg,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            onPressed: onPressed,
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

/// At the top of the app page, for a saved pair mihomo would refuse.
class _RespectRulesNotice extends ConsumerWidget {
  const _RespectRulesNotice(this.target);

  final _DnsTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final unmet = ref.watch(target.selectModel((dns) => dns.respectRulesUnmet));
    return AnimatedSize(
      duration: commonDuration,
      alignment: Alignment.topCenter,
      child: unmet
          ? Padding(
              padding: EdgeInsets.only(
                top: listHeaderPaddingOf(context).top,
                bottom: 16,
              ),
              child: _Notice(
                glyph: AppGlyphs.error,
                color: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
                message: appLocalizations.dnsRespectRulesUnmetWarning,
                actions: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TonalButton(
                      size: TonalButtonSize.compact,
                      label: appLocalizations.dnsFillProxyServerNameserver,
                      onPressed: () => _fillProxyServerNameserver(
                        context,
                        ref,
                        target,
                        turnOn: false,
                      ),
                    ),
                    TonalButton(
                      size: TonalButtonSize.compact,
                      label: appLocalizations.dnsTurnOffRespectRules,
                      onPressed: () => _writeDns(
                        ref,
                        target,
                        (dns) => dns.copyWith(respectRules: false),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

/// The current profile's own policy is kept over the app's empty list,
/// which mihomo refuses.
class _ProxyServerPolicyNotice extends ConsumerWidget {
  const _ProxyServerPolicyNotice(this.target);

  final _DnsTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final hasPolicy = ref.watch(
      profileSettingsProvider.select(
        (settings) => switch (settings?['dns']) {
          final Map dns =>
            dns['proxy-server-nameserver-policy'] is Map &&
                (dns['proxy-server-nameserver-policy'] as Map).isNotEmpty,
          _ => false,
        },
      ),
    );
    final empty = ref.watch(
      target.selectModel((dns) => dns.proxyServerNameserver.isEmpty),
    );
    final profile = ref.watch(
      currentProfileProvider.select((profile) => profile?.realLabel),
    );
    final unmet = hasPolicy && empty && profile != null;
    return AnimatedSize(
      duration: commonDuration,
      alignment: Alignment.topCenter,
      child: unmet
          ? Padding(
              padding: EdgeInsets.only(
                top: listHeaderPaddingOf(context).top,
                bottom: 16,
              ),
              child: _Notice(
                glyph: AppGlyphs.error,
                color: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
                message: appLocalizations.dnsProxyServerPolicyUnmetWarning(
                  profile,
                ),
                actions: TonalButton(
                  size: TonalButtonSize.compact,
                  label: appLocalizations.dnsFillProxyServerNameserver,
                  onPressed: () => _fillProxyServerNameserver(
                    context,
                    ref,
                    target,
                    turnOn: false,
                  ),
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.glyph,
    required this.color,
    required this.foregroundColor,
    required this.message,
    required this.actions,
  });

  final Glyph glyph;
  final Color color;
  final Color foregroundColor;
  final String message;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(color: color, shape: AppShape.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              GlyphIcon(glyph, size: 20.ap(context), color: foregroundColor),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyle.subheadline
                      .of(context)
                      .copyWith(color: foregroundColor),
                ),
              ),
            ],
          ),
          actions,
        ],
      ),
    );
  }
}
