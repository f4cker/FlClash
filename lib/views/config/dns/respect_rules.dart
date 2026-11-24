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

/// mihomo refuses the switch without a Proxy Server Nameserver, so on the
/// app page it asks for one rather than turning on.
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
    final write = model.modelWriter(update);
    return ConfigToggleItem(
      leading: leading,
      title: title,
      selector: model.selectModel(select),
      onChanged: (ref, value) {
        final prompt = ref.read(_respectRulesPromptProvider.notifier);
        final servers = ref.read(
          model.selectModel((dns) => dns.proxyServerNameserver),
        );
        final held = value && servers.isEmpty;
        prompt.shown = held;
        if (!held) {
          write(ref, value);
        }
      },
    );
  }
}

class _RespectRulesNotice extends ConsumerWidget {
  const _RespectRulesNotice(this.target);

  final OverrideTarget<DnsOverrideKey, Dns> target;

  void _write(WidgetRef ref, Dns Function(Dns dns) update) {
    ref.read(_respectRulesPromptProvider.notifier).shown = false;
    target.update(
      ref,
      (state) => (model: update(state.model), keys: state.keys),
    );
  }

  Future<void> _fill(
    BuildContext context,
    WidgetRef ref, {
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
        titleBuilder: (item) => Text(item),
      ),
    );
    if (result is! List || !context.mounted) {
      return;
    }
    final servers = List<String>.from(result);
    _write(
      ref,
      (dns) => dns.copyWith(
        proxyServerNameserver: servers,
        respectRules: dns.respectRules || turnOn && servers.isNotEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final (:unmet, :held, :nameserver) = ref.watch(
      target.selectModel(
        (dns) => (
          unmet: dns.respectRulesUnmet,
          held: !dns.respectRules && dns.proxyServerNameserver.isEmpty,
          nameserver: dns.nameserver,
        ),
      ),
    );
    final prompted = held && ref.watch(_respectRulesPromptProvider);
    final fill = TonalButton(
      size: TonalButtonSize.compact,
      label: appLocalizations.dnsFillProxyServerNameserver,
      onPressed: () => _fill(context, ref, turnOn: prompted),
    );
    final notice = unmet
        ? _Notice(
            glyph: AppGlyphs.error,
            color: colorScheme.errorContainer,
            foregroundColor: colorScheme.onErrorContainer,
            message: appLocalizations.dnsRespectRulesUnmetWarning,
            actions: [
              fill,
              TonalButton(
                size: TonalButtonSize.compact,
                label: appLocalizations.dnsTurnOffRespectRules,
                onPressed: () =>
                    _write(ref, (dns) => dns.copyWith(respectRules: false)),
              ),
            ],
          )
        : prompted
        ? _Notice(
            glyph: AppGlyphs.info,
            color: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            message: appLocalizations.dnsRespectRulesNeedsProxyServer,
            actions: [
              fill,
              if (nameserver.isNotEmpty)
                TonalButton(
                  size: TonalButtonSize.compact,
                  label: appLocalizations.dnsUseNameserverForProxyServer,
                  onPressed: () => _write(
                    ref,
                    (dns) => dns.copyWith(
                      proxyServerNameserver: dns.nameserver,
                      respectRules: true,
                    ),
                  ),
                ),
              TonalButton(
                size: TonalButtonSize.compact,
                label: appLocalizations.cancel,
                onPressed: () =>
                    ref.read(_respectRulesPromptProvider.notifier).shown =
                        false,
              ),
            ],
          )
        : null;
    return AnimatedSize(
      duration: commonDuration,
      alignment: Alignment.topCenter,
      child: notice ?? const SizedBox(width: double.infinity),
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
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(
        top: listHeaderPaddingOf(context).top,
        bottom: 16,
      ),
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
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}
