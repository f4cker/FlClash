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
      titleBuilder: (item) => Text(item),
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
    final nameserver = ref.watch(target.selectModel((dns) => dns.nameserver));
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
    final copy = nameserver.isEmpty
        ? null
        : button(
            appLocalizations.dnsUseNameserverForProxyServer,
            () => _writeDns(
              ref,
              target,
              (dns) => dns.copyWith(
                proxyServerNameserver: dns.nameserver,
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
