import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/core.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/views/config/rules.dart';
import 'package:fl_clash/views/dashboard/widgets/card.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'assign_dialog.dart';
import 'device_card.dart';
import 'device_list.dart';
import 'exit_dialog.dart';
import 'settings_cards.dart' hide TailscaleTag;
import 'state.dart';
import 'widgets.dart';

/// Below this the exit and subnet cards stack, design.md §2.
const tailscaleTwoColumnWidth = 720.0;

const tailscalePollInterval = Duration(seconds: 3);

/// Opens the auth URL; swapped in tests so nothing reaches a browser.
typedef TailscaleUrlLauncher = Future<bool> Function(Uri url);

Future<bool> _launch(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

class TailscaleView extends ConsumerStatefulWidget {
  const TailscaleView({super.key, this.launcher = _launch, this.clock});

  final TailscaleUrlLauncher launcher;

  /// The time the expiry reminder is measured from; now when null.
  final DateTime Function()? clock;

  @override
  ConsumerState<TailscaleView> createState() => _TailscaleViewState();
}

class _HeldUrl {
  const _HeldUrl(this.generation, this.url);

  final int generation;
  final String url;
}

/// The last change asked of a card, so 重试 repeats exactly that one.
class _Retry {
  const _Retry({this.exitPeer, this.acceptRoutes});

  final TailscalePeer? exitPeer;
  final bool? acceptRoutes;
}

class _TailscaleViewState extends ConsumerState<TailscaleView> {
  TailscaleNodeKey? _selected;
  bool _preparingProfile = false;
  bool _adding = false;
  TailscaleNodeKey? _shownKey;

  /// Only this page's own login answers, never persisted or logged.
  final Map<TailscaleNodeKey, _HeldUrl> _urls = {};
  final Map<TailscaleNodeKey, _Retry> _exitRetries = {};
  final Map<TailscaleNodeKey, _Retry> _routesRetries = {};

  /// Instances this page read on its own once; a later read is the user's.
  final Set<(TailscaleNodeKey, int)> _autoRead = {};
  final _searchController = TextEditingController();
  String? _ownerKey;
  String _query = '';
  Timer? _poll;

  TailscaleAction get _action => ref.read(tailscaleActionProvider.notifier);

  TailscalePanelNodes get _panel =>
      ref.read(tailscalePanelNodesProvider.notifier);

  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(tailscalePollInterval, (_) => _tick());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool get _visible =>
      ref.read(currentPageLabelProvider) == PageLabel.tailscale &&
      ref.read(coreStatusProvider) == CoreStatus.connected;

  /// Read only, every few seconds while a state waits on something else.
  void _tick() {
    if (!mounted || !_visible) {
      return;
    }
    final node = _currentNode(ref.read(tailscaleNodesProvider).value);
    if (node == null) {
      return;
    }
    final panel = _panel.of(node.key);
    if (panel.reading) {
      return;
    }
    if (tailscalePolledPhases.contains(_phaseOf(node, panel))) {
      unawaited(_action.readStatus(node));
    }
  }

  TailscaleNode? _currentNode(List<TailscaleNode>? nodes) {
    if (nodes == null || nodes.isEmpty) {
      return null;
    }
    final selected = _selected;
    if (selected == null) {
      return nodes.first;
    }
    final node = nodes.firstWhereOrNull((node) => node.key == selected);
    if (node == null && nodes.length == 1) {
      return nodes.first;
    }
    return node;
  }

  TailscaleStatus? _statusOf(TailscaleNode node, TailscalePanelNode panel) {
    final status = panel.status;
    if (status == null || status.node.generation != node.generation) {
      return null;
    }
    return status;
  }

  TailscalePhase _phaseOf(TailscaleNode node, TailscalePanelNode panel) {
    return deriveTailscalePhase(
      node: node,
      status: _statusOf(node, panel),
      readFailed: panel.readFailed,
      loginInFlight: panel.loggingIn,
      startInFlight: panel.starting || panel.restarting,
      startCallFailed: panel.startFailed && panel.prewarmed == node.generation,
      holdsAuthUrl: _urls[node.key]?.generation == node.generation,
      unconfirmed: panel.unconfirmed,
      now: _now,
    );
  }

  /// A new node shows nothing of the one before: no URL, filter or search.
  void _onShown(TailscaleNode node) {
    final key = node.key;
    if (_shownKey == key) {
      return;
    }
    final previous = _shownKey;
    _shownKey = key;
    if (previous != null) {
      _urls.remove(previous);
      _ownerKey = null;
      _query = '';
      if (_searchController.text.isNotEmpty) {
        _searchController.clear();
      }
    }
  }

  /// Once per instance the page opens on: read it, and start one that holds
  /// a login of its own and was not logged out.
  void _ensureRead(TailscaleNode node) {
    final mark = (node.key, node.generation);
    if (_autoRead.contains(mark)) {
      return;
    }
    _autoRead.add(mark);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      if (!node.started &&
          node.hasIdentity &&
          !node.loggedOut &&
          node.startError == null) {
        await _action.prewarm(node);
      } else {
        await _action.readStatus(node);
      }
    });
  }

  void _select(TailscaleNodeKey key) {
    setState(() {
      _selected = key;
    });
  }

  TailscaleManagedPanels get _managedPanels =>
      ref.read(tailscaleManagedPanelsProvider.notifier);

  /// The account as the node's own identity names it; the node name before
  /// one is known, 新账号 for a panel-added draft.
  String _accountLabel(TailscaleNode node, TailscaleStatus? status) {
    final user = status?.loginUser;
    final name = user == null ? '' : tailscaleUserName(user);
    if (name.isNotEmpty) {
      return name;
    }
    final account = node.account;
    if (account != null && !node.loggedOut) {
      final label = account.loginName.takeFirstValid([account.displayName]);
      if (label.isNotEmpty) {
        return label;
      }
    }
    if (_isDraft(node)) {
      return context.appLocalizations.tsNewAccount;
    }
    return node.name;
  }

  /// A panel-added entry no account has signed in to yet.
  bool _isDraft(TailscaleNode node) =>
      node.managed &&
      !node.hasIdentity &&
      !node.loggedOut &&
      node.account == null;

  String _networkOf(TailscaleNode node, TailscaleStatus? status) {
    final tailnet = status?.tailnet?.name ?? '';
    if (tailnet.isNotEmpty) {
      return tailnet;
    }
    return node.loggedOut ? '' : node.account?.tailnet ?? '';
  }

  String _stateLabel(TailscaleNode node, TailscalePhase phase) {
    if (node.managed && node.loggedOut && phase == TailscalePhase.signedOut) {
      return context.appLocalizations.tsAccountSignedOut;
    }
    return tailscalePhaseLabel(context, phase);
  }

  /// Only a node from a file names its source; panel-added is the default.
  String? _sourceLabel(TailscaleNode node) {
    final appLocalizations = context.appLocalizations;
    if (node.managed) {
      return null;
    }
    return switch (ref.read(tailscaleSetupProvider)?.configSource) {
      TailscaleSettingSource.subscription =>
        appLocalizations.tsFromSubscription,
      TailscaleSettingSource.profile => appLocalizations.tsFromProfile,
      _ => null,
    };
  }

  /// Only the user's tap gets here: the draft, then the sign-in page.
  Future<void> _addAccount() async {
    if (_adding) {
      return;
    }
    setState(() {
      _adding = true;
    });
    TailscaleNode? node;
    try {
      node = await _action.addManaged(
        newProfileLabel: PageLabel.tailscale.label,
        onPreparingProfile: () {
          if (mounted) {
            setState(() => _preparingProfile = true);
          }
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _adding = false;
          _preparingProfile = false;
          if (node != null) {
            _selected = node.key;
          }
        });
      }
    }
    if (node == null) {
      final profileId = ref.read(currentProfileIdProvider);
      final notice = profileId == null
          ? TailscaleManagedNotice.prepareFailed
          : _managedPanels.of(tailscaleManagedNodeKey(profileId, '')).notice;
      dialogs.showBanner(
        notice == TailscaleManagedNotice.prepareUnknown
            ? currentAppLocalizations.tsPrepareUnknown
            : currentAppLocalizations.tsPrepareFailed,
        level: BannerLevel.error,
      );
      return;
    }
    if (mounted) {
      await _login(node);
    }
  }

  Future<void> _confirmSignOut(TailscaleNode node, String account) async {
    final appLocalizations = context.appLocalizations;
    final confirmed = await dialogs.showMessage(
      title: appLocalizations.tsSignOutAccountTitle,
      message: TextSpan(
        text: appLocalizations.tsSignOutAccountBody(account, node.name),
      ),
      confirmText: appLocalizations.tsSignOutAccount,
      destructive: true,
    );
    if (confirmed != true) {
      return;
    }
    if (await _action.signOutManaged(node)) {
      dialogs.showBanner(
        currentAppLocalizations.tsSignedOutReceipt,
        level: BannerLevel.success,
      );
    }
  }

  Future<void> _confirmRemove(TailscaleNode node, String? account) async {
    final appLocalizations = context.appLocalizations;
    final profile = ref.read(currentProfileProvider)?.realLabel ?? '';
    final last =
        ref
            .read(tailscaleManagedRecordsProvider.notifier)
            .ofProfile(node.profileId)
            .length ==
        1;
    final confirmed = await dialogs.showMessage(
      title: appLocalizations.tsRemoveTitle,
      body: TailscaleNamedText(
        names: [?account, node.name, profile],
        fill: (names) => account == null
            ? appLocalizations.tsRemoveBodyNode(names[0], names[1])
            : appLocalizations.tsRemoveBody(names[0], names[1], names[2]),
        trailing: [
          '',
          appLocalizations.tsRemoveExtra,
          last
              ? appLocalizations.tsRemoveLast
              : appLocalizations.tsRemoveTargetsKept,
        ].join('\n\n'),
      ),
      confirmText: appLocalizations.tsSignOutRemove,
      destructive: true,
      width: 440,
    );
    if (confirmed != true) {
      return;
    }
    final notice = await _action.removeManaged(node);
    final gone =
        ref
            .read(tailscaleManagedRecordsProvider.notifier)
            .recordOf(node.profileId, node.managedId) ==
        null;
    if (notice != null && gone) {
      if (mounted) {
        setState(() => _selected = null);
      }
      dialogs.showBanner(
        currentAppLocalizations.tsRemoveIncomplete,
        level: BannerLevel.error,
      );
    } else if (notice == null) {
      if (mounted) {
        setState(() => _selected = null);
      }
      dialogs.showBanner(
        currentAppLocalizations.tsRemoved,
        level: BannerLevel.success,
      );
    }
  }

  Future<void> _chooseAccounts(
    TailscaleRoutes routes,
    List<TailscaleNode> nodes, {
    TailscaleRouteTarget? focus,
  }) async {
    final choices = await showTailscaleAssignDialog(
      context,
      routes: routes,
      focus: focus,
      labelOf: (owner) => _ownerLabel(owner, nodes),
    );
    if (choices == null || choices.isEmpty || !mounted) {
      return;
    }
    final notice = await _action.assignRoutes(routes.profileId, choices);
    final appLocalizations = currentAppLocalizations;
    switch (notice) {
      case TailscaleAssignNotice.updated:
        dialogs.showBanner(
          appLocalizations.tsChoicesUpdated,
          level: BannerLevel.success,
        );
      case TailscaleAssignNotice.saved:
        dialogs.showBanner(appLocalizations.tsChoicesSaved);
      case TailscaleAssignNotice.failed:
        dialogs.showBanner(
          appLocalizations.tsChoicesFailed,
          level: BannerLevel.error,
        );
      case TailscaleAssignNotice.unknown:
        dialogs.showBanner(
          appLocalizations.tsChoicesUnknown,
          level: BannerLevel.error,
        );
        ref.invalidate(tailscaleRoutesReportProvider);
    }
  }

  /// An account by its real identity, a profile node by its name.
  ({String account, String network}) _ownerLabel(
    TailscaleRouteOwner owner,
    List<TailscaleNode> nodes,
  ) {
    if (owner.kind == tailscaleOwnerManaged) {
      final node = nodes.firstWhereOrNull((node) => node.managedId == owner.id);
      if (node != null) {
        final panel = ref.read(tailscalePanelNodesProvider)[node.key];
        final status = panel == null ? null : _statusOf(node, panel);
        return (
          account: _accountLabel(node, status),
          network: _networkOf(node, status).takeFirstValid(['—']),
        );
      }
    }
    return (
      account: owner.id,
      network:
          _sourceLabel(TailscaleNode(name: owner.id, generation: 0)) ?? '—',
    );
  }

  Future<void> _refresh(TailscaleNode node, {bool settings = false}) async {
    await _action.refresh(node, settings: settings);
  }

  Future<void> _openUrl(TailscaleNode node, String url) async {
    var opened = false;
    try {
      opened = await widget.launcher(Uri.parse(url));
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      _panel.change(
        node.key,
        (state) => state.copyWith(notice: TailscaleCardNotice.browserFailed),
      );
    }
  }

  Future<void> _login(TailscaleNode node, {bool reauth = false}) async {
    final key = node.key;
    _urls.remove(key);
    final url = await _action.loginFromPanel(node, reauth: reauth);
    if (url == null || !mounted) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final current = _currentNode(ref.read(tailscaleNodesProvider).value);
    if (current == null || current.key != key) {
      // The page moved on; the URL is not shown on another node.
      return;
    }
    setState(() {
      _urls[key] = _HeldUrl(current.generation, url);
    });
    await _openUrl(current, url);
  }

  Future<void> _reopen(TailscaleNode node) async {
    final held = _urls[node.key];
    if (held == null || held.generation != node.generation) {
      return _login(node);
    }
    _panel.change(node.key, (state) => state.copyWith(notice: null));
    await _openUrl(node, held.url);
  }

  Future<void> _confirmLogout(TailscaleNode node) async {
    final appLocalizations = context.appLocalizations;
    final confirmed = await dialogs.showMessage(
      title: appLocalizations.tsLogoutTitle,
      message: TextSpan(
        text: [
          appLocalizations.tsLogoutBody(node.name),
          if (node.authKey) appLocalizations.tsLogoutAuthKeyNote,
        ].join('\n'),
      ),
      confirmText: appLocalizations.tsLogout,
      destructive: true,
    );
    if (confirmed != true) {
      return;
    }
    final done = await _action.logoutFromPanel(node);
    if (done) {
      dialogs.showBanner(
        currentAppLocalizations.tsLoggedOutReceipt,
        level: BannerLevel.success,
      );
    }
  }

  Future<void> _selectExit(TailscaleNode node, TailscalePeer? peer) async {
    final report = peer == null && node.managed
        ? await _readExitGroup(node.profileId)
        : null;
    final plan =
        report?.offPlanOf(node.managedId) ?? const TailscaleExitOffPlan();
    if (!mounted) {
      return;
    }
    if (!plan.isEmpty) {
      final appLocalizations = context.appLocalizations;
      final confirmed = await dialogs.showMessage(
        title: appLocalizations.tsExitOffAffectedTitle,
        confirmText: appLocalizations.tsExitTurnOff,
        width: tailscaleExitOffDialogWidth,
        body: TailscaleExitOffRows(group: report!.group, plan: plan),
      );
      if (confirmed != true) {
        return;
      }
      final notice = await _applyExit(node, null);
      if (notice == TailscaleSettingNotice.updated ||
          notice == TailscaleSettingNotice.saved) {
        _keepFallbacks(report.group, plan);
      }
      return;
    }
    final appLocalizations = context.appLocalizations;
    final confirmed = await dialogs.showMessage(
      title: peer == null
          ? appLocalizations.tsExitOffTitle
          : appLocalizations.tsExitChangeTitle,
      message: TextSpan(
        text: peer == null
            ? appLocalizations.tsExitOffBody(node.name)
            : appLocalizations.tsExitChangeBody(
                node.name,
                tailscalePeerName(peer) ?? appLocalizations.tsNameMissing,
              ),
      ),
      confirmText: peer == null
          ? appLocalizations.tsNoExitNode
          : appLocalizations.tsExitChangeConfirm,
    );
    if (confirmed != true) {
      return;
    }
    await _applyExit(node, peer);
  }

  /// A fresh read for the dialog; the last one when the Core does not answer.
  Future<TailscaleExitReport?> _readExitGroup(int profileId) async {
    try {
      return await ref.read(coreHandlerProvider).getTailscaleExit(profileId);
    } catch (error) {
      commonPrint.log(
        'tailscale exit group unread: ${compactError(error)}',
        logLevel: coreFailureLogLevel(error),
      );
      return ref.read(tailscaleExitRuntimeProvider).value;
    }
  }

  /// Kept past the next apply; the groups are read back from the Core.
  void _keepFallbacks(String group, TailscaleExitOffPlan plan) {
    ref.read(profilesActionProvider.notifier).updateCurrentSelections({
      if (plan.groupMove case final next?) ...{
        group: next.member,
        tailscaleExitSelectionKey: next.id,
      },
      for (final move in plan.moves) move.group: move.to,
    });
    for (final name in plan.empty) {
      commonPrint.log(
        'tailscale exit off: $name has no option left',
        logLevel: LogLevel.warning,
      );
    }
    ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
  }

  Future<TailscaleSettingNotice> _applyExit(
    TailscaleNode node,
    TailscalePeer? peer,
  ) async {
    final value = peer == null ? '' : tailscaleAddressOf(peer) ?? peer.id;
    _exitRetries[node.key] = _Retry(exitPeer: peer);
    final notice = await _action.setPrefsFromPanel(
      node,
      exitNode: value,
      exitNodeName: peer == null ? null : tailscalePeerName(peer),
    );
    if (notice == TailscaleSettingNotice.updated) {
      _exitRetries.remove(node.key);
      dialogs.showBanner(
        currentAppLocalizations.tsExitUpdated,
        level: BannerLevel.success,
      );
    }
    if (mounted) {
      setState(() {});
    }
    return notice;
  }

  Future<void> _changeRoutes(TailscaleNode node, bool accept) async {
    final appLocalizations = context.appLocalizations;
    final confirmed = await dialogs.showMessage(
      title: accept
          ? appLocalizations.tsRoutesOnTitle
          : appLocalizations.tsRoutesOffTitle,
      message: TextSpan(
        text: accept
            ? appLocalizations.tsRoutesOnBody
            : appLocalizations.tsRoutesOffBody,
      ),
      confirmText: accept
          ? appLocalizations.tsAcceptRoutes
          : appLocalizations.tsRoutesOffConfirm,
    );
    if (confirmed != true) {
      return;
    }
    await _applyRoutes(node, accept);
  }

  Future<void> _applyRoutes(TailscaleNode node, bool accept) async {
    _routesRetries[node.key] = _Retry(acceptRoutes: accept);
    final notice = await _action.setPrefsFromPanel(node, acceptRoutes: accept);
    if (notice == TailscaleSettingNotice.updated) {
      _routesRetries.remove(node.key);
      dialogs.showBanner(
        currentAppLocalizations.tsRoutesUpdated,
        level: BannerLevel.success,
      );
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// The dialog shows the offer as read; the Core takes the migration only
  /// while that offer's token still describes the node.
  Future<void> _confirmMigrate(TailscaleNode node) async {
    final offer = node.legacy;
    if (offer == null || offer.offerToken == null) {
      return;
    }
    final appLocalizations = context.appLocalizations;
    final profile = ref.read(currentProfileProvider);
    final account = offer.loginName.takeFirstValid([
      offer.displayName,
      appLocalizations.tsLegacyAccountUnconfirmed,
    ]);
    final control = tailscaleControlHost(
      offer.controlUrl.takeFirstValid([node.controlUrl]),
    );
    final confirmed = await dialogs.showMessage(
      title: appLocalizations.tsLegacyConfirmTitle,
      message: TextSpan(
        text: [
          appLocalizations.tsLegacyConfirmProfile(profile?.realLabel ?? ''),
          appLocalizations.tsLegacyConfirmNode(node.name),
          appLocalizations.tsLegacyConfirmAccount(account),
          appLocalizations.tsLegacyConfirmControl(control),
          '',
          appLocalizations.tsLegacyConfirmBody,
        ].join('\n'),
      ),
      confirmText: appLocalizations.tsLegacyConfirm,
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _action.migrateLegacy(node, offer);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _recheckLegacy(TailscaleNode node) async {
    await _action.recheckLegacy(node.key);
    final current = _currentNode(ref.read(tailscaleNodesProvider).value);
    if (current != null && current.key == node.key) {
      await _action.readStatus(current);
    }
  }

  Future<void> _copy(String text, {String? message}) async {
    await Clipboard.setData(ClipboardData(text: text));
    dialogs.showBanner(
      message ?? currentAppLocalizations.tsAddressCopied,
      level: BannerLevel.success,
    );
  }

  void _goToProfiles() {
    ref.read(currentPageLabelProvider.notifier).toProfiles();
  }

  /// A managed node's rules are the rows the Core puts first, which the
  /// rules page locates; a profile node's rules are the profile's own.
  void _goToRules(TailscaleNode node) {
    if (node.managed) {
      ref
          .read(rulesLocateRequestProvider.notifier)
          .ask(RulesLocateSource.tailscaleManaged);
      return;
    }
    showInSheet<void>(context, builder: (_) => const AddedRulesView());
  }

  void _showHelp() {
    final appLocalizations = context.appLocalizations;
    dialogs.showAlert(
      title: appLocalizations.tsHelp,
      message: TextSpan(
        text: [
          appLocalizations.tsHelpBody,
          appLocalizations.tsNetworkNameTip,
        ].join('\n\n'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coreStatus = ref.watch(coreStatusProvider);
    ref.watch(currentPageLabelProvider);
    if (coreStatus != CoreStatus.connected) {
      return _page(
        context,
        body: coreStatus == CoreStatus.connecting
            ? const Center(child: ActivityIndicator())
            : _coreStopped(context),
      );
    }
    final nodesValue = ref.watch(tailscaleNodesProvider);
    final panels = ref.watch(tailscalePanelNodesProvider);
    final legacyStates = ref.watch(tailscaleLegacyStatesProvider);
    final nodes = nodesValue.value;
    if (nodes == null) {
      if (nodesValue.hasError) {
        final error = nodesValue.error;
        if (error is CoreMethodException && error.isCoreUnavailable) {
          return _page(context, body: _coreStopped(context));
        }
        return _page(context, body: _nodesFailed(context));
      }
      return _page(context, body: const Center(child: ActivityIndicator()));
    }
    if (nodes.isEmpty) {
      return _page(context, body: _noNodes(context));
    }
    final node = _currentNode(nodes);
    if (node == null) {
      return _page(context, nodes: nodes, body: _nodeGone(context, nodes));
    }
    _onShown(node);
    _ensureRead(node);
    final panel = panels[node.key] ?? const TailscalePanelNode();
    final legacyState = legacyStates[node.key] ?? const TailscaleLegacyState();
    final status = _statusOf(node, panel);
    final phase = _phaseOf(node, panel);
    final legacyView = tailscaleLegacyViewOf(
      node: node,
      state: legacyState,
      phase: phase,
    );
    if (legacyView == TailscaleLegacyView.offer && !legacyState.offered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _action.markLegacyOffered(node);
        }
      });
    }
    final now = _now;
    final managedPanels = ref.watch(tailscaleManagedPanelsProvider);
    final managedRecord = node.managed
        ? ref
              .watch(tailscaleManagedRecordsProvider.notifier)
              .recordOf(node.profileId, node.managedId)
        : null;
    ref.watch(tailscaleManagedRecordsProvider);
    var managedPanel = managedPanels[node.key] ?? const TailscaleManagedPanel();
    if (managedRecord?.removing == true && managedPanel.notice == null) {
      managedPanel = managedPanel.copyWith(
        notice: TailscaleManagedNotice.removeUnknown,
      );
    }
    final routes = ref.watch(tailscaleRoutesReportProvider).value;
    final account = _accountLabel(node, status);
    final duplicate = node.managed ? _action.duplicateOf(node, nodes) : null;
    final awaitingAttach =
        node.managed &&
        !node.attached &&
        managedPanel.attach == TailscaleAttachState.none &&
        managedRecord != null &&
        !managedRecord.removing;
    if (awaitingAttach &&
        managedPanel.signInTapped &&
        phase == TailscalePhase.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _action.attachManaged(node, nodes);
        }
      });
    } else if (awaitingAttach &&
        !managedPanel.signInTapped &&
        node.hasIdentity &&
        !node.loggedOut) {
      // Signed in before this run and never attached: only a tap attaches.
      managedPanel = managedPanel.copyWith(attach: TailscaleAttachState.failed);
    }
    final managedView = node.managed
        ? TailscaleManagedCardView(
            panel: managedPanel,
            onRetryAttach: () => _action.attachManaged(node, nodes),
            onRecheck: () => _action.recheckManaged(node),
            onViewExisting: duplicate == null ? null : () => _select(duplicate),
          )
        : null;
    final actions = TailscaleCardActions(
      onLogin: () => _login(node),
      onRelogin: () => _login(node, reauth: true),
      onReopen: () => _reopen(node),
      onRead: () => _refresh(node),
      onLogout: node.managed
          ? () => _confirmSignOut(node, account)
          : () => _confirmLogout(node),
      onRetryStart: () => _action.retryStart(node),
      onGoToProfiles: _goToProfiles,
      onCopy: _copy,
      onMigrate: () => _confirmMigrate(node),
      onRecheckLegacy: () => _recheckLegacy(node),
    );
    final exitRetry = _exitRetries[node.key];
    final routesRetry = _routesRetries[node.key];
    final record = ref
        .watch(tailscaleNodeRecordsProvider)
        .firstWhereOrNull((record) => record.key == node.key);
    final savedExitName = record?.exitNode == node.settings.exitNode.value
        ? record?.exitNodeName
        : null;
    final exitReport = node.managed
        ? ref.watch(tailscaleExitRuntimeProvider).value
        : null;
    final body = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= tailscaleTwoColumnWidth + 40;
        final exitCard = TailscaleExitCard(
          node: node,
          status: status,
          phase: phase,
          panel: panel,
          savedExitName: savedExitName,
          onSelect: (peer) => _selectExit(node, peer),
          onReadSettings: () => _refresh(node, settings: true),
          onRetry: exitRetry == null
              ? null
              : () => _applyExit(node, exitRetry.exitPeer),
          attach: managedPanel.attach,
          exitReport: exitReport,
        );
        final routesCard = TailscaleRoutesCard(
          node: node,
          status: status,
          phase: phase,
          panel: panel,
          onChanged: (accept) => _changeRoutes(node, accept),
          onReadSettings: () => _refresh(node, settings: true),
          onRetry: routesRetry?.acceptRoutes == null
              ? null
              : () => _applyRoutes(node, routesRetry!.acceptRoutes!),
          attach: managedPanel.attach,
        );
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 24,
            top: context.contentTopPadding,
            bottom: 24 + context.bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              ..._pageBanners(context, routes, nodes),
              TailscaleDeviceCard(
                managed: managedView,
                node: node,
                phase: phase,
                status: status,
                actions: actions,
                legacyView: legacyView,
                legacyState: legacyState,
                now: now,
                stale: status != null && panel.readFailed,
                notice: panel.notice,
                loggingIn: panel.loggingIn,
                loggingOut: panel.loggingOut,
                reading: panel.reading,
                restarting: panel.restarting,
                wide: constraints.maxWidth >= 560,
                source: _sourceLabel(node),
              ),
              if (wide)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 16,
                    children: [
                      Expanded(child: exitCard),
                      Expanded(child: routesCard),
                    ],
                  ),
                )
              else ...[
                exitCard,
                routesCard,
              ],
              _rulesCard(context, node, routes, nodes),
              if (phase == TailscalePhase.connected &&
                  (!node.managed || node.attached))
                TailscaleDeviceSection(
                  status: status,
                  readFailed: panel.readFailed,
                  reading: panel.reading,
                  ownerKey: _ownerKey,
                  query: _query,
                  searchController: _searchController,
                  onOwnerChanged: (key) => setState(() => _ownerKey = key),
                  onQueryChanged: (query) => setState(() => _query = query),
                  onRefresh: () => _refresh(node),
                  onCopy: _copy,
                  onCopyName: (name) =>
                      _copy(name, message: currentAppLocalizations.copySuccess),
                  conflictOf: routes == null
                      ? null
                      : (peer) => tailscaleConflictOf(context, routes, peer),
                  onAssign: routes == null
                      ? null
                      : (target) =>
                            _chooseAccounts(routes, nodes, focus: target),
                ),
            ],
          ),
        );
      },
    );
    return _page(
      context,
      nodes: nodes,
      node: node,
      panels: panels,
      phase: phase,
      reading: panel.reading,
      managedView: managedView,
      account: account,
      body: body,
    );
  }

  /// Profile-wide: the conflict count first, then a mode that bypasses the
  /// rules, then the DNS caveat, whichever account is shown.
  List<Widget> _pageBanners(
    BuildContext context,
    TailscaleRoutes? routes,
    List<TailscaleNode> nodes,
  ) {
    final appLocalizations = context.appLocalizations;
    if (!nodes.any((node) => node.managed)) {
      return const [];
    }
    final config = ref.watch(
      patchClashConfigProvider.select(
        (state) => (
          mode: state.mode,
          tun: state.tun.enable,
          dns: state.dns.enhancedMode,
        ),
      ),
    );
    final pending = routes?.pending ?? const [];
    return [
      if (pending.isNotEmpty)
        Semantics(
          liveRegion: true,
          child: TailscaleBanner(
            level: TailscaleBannerLevel.warn,
            title: appLocalizations.tsConflictTitle(pending.length),
            text: appLocalizations.tsConflictBody,
            actionLabel: appLocalizations.tsChooseAccounts,
            onAction: () => _chooseAccounts(routes!, nodes),
          ),
        ),
      if (config.mode != Mode.rule)
        TailscaleBanner(
          level: TailscaleBannerLevel.warn,
          text: config.mode == Mode.direct
              ? appLocalizations.tsDirectMode
              : appLocalizations.tsGlobalMode,
        ),
      if (config.tun && config.dns != DnsMode.fakeIp)
        TailscaleBanner(
          level: TailscaleBannerLevel.warn,
          text: appLocalizations.tsDnsUnverified,
        ),
    ];
  }

  /// The summary is only what the Core read back; a missing or stale report
  /// says so instead of showing a number or a domain.
  Widget _rulesCard(
    BuildContext context,
    TailscaleNode node,
    TailscaleRoutes? routes,
    List<TailscaleNode> nodes,
  ) {
    final appLocalizations = context.appLocalizations;
    void onGoToRules() => _goToRules(node);
    if (!node.managed) {
      return TailscaleRulesCard(
        onGoToRules: onGoToRules,
        about: [appLocalizations.tsRulesProfileNode],
      );
    }
    final about = [
      appLocalizations.tsRulesManaged,
      appLocalizations.tsUnverifiedBlocked,
    ];
    if (!node.attached || routes == null || !routes.active) {
      return TailscaleRulesCard(
        onGoToRules: onGoToRules,
        caption: appLocalizations.tsRulesPending,
        about: about,
      );
    }
    final report = routes.accountOf(node.managedId);
    final verified = report != null && report.fresh && !report.loggedOut;
    final String? caption;
    if (report?.loggedOut ?? false) {
      caption = null;
    } else if (!verified) {
      caption = appLocalizations.tsRulesUnconfirmed;
    } else if (report.domain.isNotEmpty) {
      caption = appLocalizations.tsRulesSummary(
        report.addresses,
        report.domain,
      );
    } else {
      caption = appLocalizations.tsRulesAddresses(report.addresses);
    }
    return TailscaleRulesCard(
      onGoToRules: onGoToRules,
      caption: caption,
      warning: _rulesWarning(context, node, routes),
      about: about,
    );
  }

  /// A blocked target of this account, worded as on the rules page.
  String? _rulesWarning(
    BuildContext context,
    TailscaleNode node,
    TailscaleRoutes routes,
  ) {
    final appLocalizations = context.appLocalizations;
    bool ours(TailscaleRouteTargetReport target) =>
        target.owner?.kind == tailscaleOwnerManaged &&
        target.owner?.id == node.managedId;
    if (routes.targets.any(
      (target) =>
          target.state == TailscaleRouteState.unavailable && ours(target),
    )) {
      return appLocalizations.tsAssignedUnavailable;
    }
    if (routes.targets.any(
      (target) => target.state == TailscaleRouteState.unconfirmed,
    )) {
      return appLocalizations.tsTargetUnconfirmedTip;
    }
    return null;
  }

  Widget _page(
    BuildContext context, {
    required Widget body,
    List<TailscaleNode> nodes = const [],
    TailscaleNode? node,
    Map<TailscaleNodeKey, TailscalePanelNode> panels = const {},
    TailscalePhase? phase,
    bool reading = false,
    TailscaleManagedCardView? managedView,
    String? account,
  }) {
    final appLocalizations = context.appLocalizations;
    final settled =
        managedView != null &&
        !managedView.unsettled &&
        !managedView.panel.removing;
    return Scaffold(
      title: PageLabel.tailscale.label,
      actions: [if (nodes.isNotEmpty) _switcher(context, nodes, node, panels)],
      iconActions: [
        if (node != null)
          IconButtonData(
            glyph: AppGlyphs.refresh,
            tooltip: appLocalizations.tsRefresh,
            isLoading: reading,
            onPressed: reading ? null : () => _refresh(node),
          ),
      ],
      menuItems: [
        if (node != null &&
            !node.managed &&
            tailscaleLogoutPhases.contains(phase))
          PopupMenuItem(
            label: appLocalizations.tsLogout,
            danger: true,
            onPressed: () => _confirmLogout(node),
          ),
        if (node != null &&
            node.managed &&
            settled &&
            tailscaleLogoutPhases.contains(phase))
          PopupMenuItem(
            label: appLocalizations.tsSignOutAccount,
            onPressed: () => _confirmSignOut(node, account ?? node.name),
          ),
        if (node != null && node.managed)
          PopupMenuItem(
            label: appLocalizations.tsSignOutRemoveMenu,
            section: const PopupMenuSection(),
            danger: true,
            onPressed: settled
                ? () => _confirmRemove(
                    node,
                    node.hasIdentity || node.account != null ? account : null,
                  )
                : null,
          ),
        if (node != null)
          PopupMenuItem(
            label: appLocalizations.tsHelp,
            glyph: AppGlyphs.info,
            onPressed: _showHelp,
          ),
      ],
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: body,
      ),
    );
  }

  /// The account switcher, design.md §13.1: it only changes what the page
  /// shows and manages.
  Widget _switcher(
    BuildContext context,
    List<TailscaleNode> nodes,
    TailscaleNode? current,
    Map<TailscaleNodeKey, TailscalePanelNode> panels,
  ) {
    final appLocalizations = context.appLocalizations;
    ({String account, String network, String state, TailscalePhase phase})
    describe(TailscaleNode node) {
      final panel = panels[node.key] ?? const TailscalePanelNode();
      final status = _statusOf(node, panel);
      final phase = _phaseOf(node, panel);
      return (
        account: _accountLabel(node, status),
        network: _networkOf(node, status),
        state: _stateLabel(node, phase),
        phase: phase,
      );
    }

    final managedCount = nodes.where((node) => node.managed).length;
    final shown = current == null ? null : describe(current);
    return PopupAnchor(
      placement: PopupPlacement.belowAnchorEnd,
      targetBuilder: (open) => TailscaleAccountPill(
        account: shown?.account ?? appLocalizations.tsChooseNode,
        state: shown?.state,
        tone: switch (shown?.phase) {
          TailscalePhase.connected => DashboardChipTone.ok,
          TailscalePhase.waitingBrowser ||
          TailscalePhase.needsApproval ||
          TailscalePhase.needsReauth => DashboardChipTone.warn,
          TailscalePhase.startFailed ||
          TailscalePhase.loadFailed => DashboardChipTone.error,
          _ => DashboardChipTone.idle,
        },
        newAccount: current != null && _isDraft(current),
        semanticsLabel: appLocalizations.tsSwitcherSemantics(
          shown?.account ?? '',
          shown?.state ?? '',
          nodes.length,
        ),
        onPressed: open,
      ),
      popupBuilder: (_) => PopupMenu(
        width: 380,
        leadingCheck: true,
        itemPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        items: [
          for (final (index, node) in nodes.indexed)
            () {
              final item = describe(node);
              final source = _sourceLabel(node);
              return PopupMenuItem(
                label: item.account,
                labelEmphasized: true,
                leading: _isDraft(node)
                    ? const TailscaleNewAccountAvatar()
                    : TailscaleAvatar(name: item.account),
                labelTrailing: source == null
                    ? null
                    : TailscaleTag(label: source),
                subtitle: [
                  if (item.network.isNotEmpty)
                    appLocalizations.tsNetworkOf(item.network),
                  item.state,
                ].join(' · '),
                subtitleMaxLines: 1,
                checked: node.key == current?.key,
                section: index == 0
                    ? PopupMenuSection(
                        title: appLocalizations.tsAccountsInProfile,
                      )
                    : null,
                onPressed: () => _select(node.key),
              );
            }(),
          PopupMenuItem(
            label: appLocalizations.tsAddAccount,
            glyph: AppGlyphs.add,
            subtitle: managedCount >= 2 ? appLocalizations.tsMemoryTip : null,
            subtitleMaxLines: 4,
            section: const PopupMenuSection(),
            onPressed: _adding ? null : _addAccount,
          ),
        ],
      ),
    );
  }

  Widget _coreStopped(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return NullStatus(
      illustration: NullStatusIllustration.core,
      label: appLocalizations.tsCoreStopped,
      description: appLocalizations.tsCoreStoppedTip,
      action: FilledButton(
        onPressed: () => ref.read(coreActionProvider.notifier).restartCore(),
        child: Text(appLocalizations.tsStartCore),
      ),
    );
  }

  /// No node in the profile: sign in from here, design.md §12.1.
  Widget _noNodes(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return _SignInStatus(
      about: [appLocalizations.tsSignInTip, appLocalizations.tsSignInBoundary],
      action: FilledButton.icon(
        onPressed: _adding ? null : _addAccount,
        icon: _adding
            ? tailscaleBusyIcon(context)
            : const GlyphIcon(AppGlyphs.openExternal, fill: 1),
        label: Text(
          _preparingProfile
              ? appLocalizations.tsPreparingProfile
              : _adding
              ? appLocalizations.tsPreparingSignIn
              : appLocalizations.tsSignIn,
        ),
      ),
    );
  }

  /// The node list itself could not be read: a state of its own, never the
  /// empty one.
  Widget _nodesFailed(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return NullStatus(
      illustration: NullStatusIllustration.error,
      label: appLocalizations.tsStateLoadFailed,
      description: appLocalizations.tsLoadFailedTip,
      action: FilledButton(
        onPressed: () => ref.invalidate(tailscaleNodesProvider),
        child: Text(appLocalizations.tsReadStatus),
      ),
    );
  }

  Widget _nodeGone(BuildContext context, List<TailscaleNode> nodes) {
    final appLocalizations = context.appLocalizations;
    return NullStatus(
      illustration: NullStatusIllustration.devices,
      label: appLocalizations.tsNodeGone,
      description: appLocalizations.tsNodeGoneTip,
      action: PopupAnchor(
        targetBuilder: (open) => FilledButton(
          onPressed: open,
          child: Text(appLocalizations.tsChooseNode),
        ),
        popupBuilder: (_) => PopupMenu(
          items: [
            for (final node in nodes)
              PopupMenuItem(
                label: node.name,
                onPressed: () => _select(node.key),
              ),
          ],
        ),
      ),
    );
  }
}

String tailscalePhaseLabel(BuildContext context, TailscalePhase phase) {
  final appLocalizations = context.appLocalizations;
  return switch (phase) {
    TailscalePhase.loadFailed => appLocalizations.tsStateLoadFailed,
    TailscalePhase.preparing => appLocalizations.tsStatePreparing,
    TailscalePhase.starting => appLocalizations.tsStateStarting,
    TailscalePhase.signedOut => appLocalizations.tsStateSignedOut,
    TailscalePhase.waitingBrowser => appLocalizations.tsStateWaitingBrowser,
    TailscalePhase.needsApproval => appLocalizations.tsStateNeedsApproval,
    TailscalePhase.connected => appLocalizations.tsStateConnected,
    TailscalePhase.needsReauth => appLocalizations.tsStateNeedsReauth,
    TailscalePhase.stopped => appLocalizations.tsStateStopped,
    TailscalePhase.startFailed => appLocalizations.tsStateStartFailed,
    TailscalePhase.unconfirmed => appLocalizations.tsStateUnconfirmed,
  };
}

/// The no-node screen of [NullStatus], with an info button after its title.
class _SignInStatus extends StatelessWidget {
  const _SignInStatus({required this.about, required this.action});

  final List<String> about;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final compact = MediaQuery.sizeOf(context).height < 560;
    return Align(
      alignment: const Alignment(0.0, -0.2),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyIllustration(
                type: NullStatusIllustration.devices,
                dimension: EmptyIllustration.dimensionOf(context),
              ),
              SizedBox(height: compact ? 12 : 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Flexible(
                    child: Text(
                      appLocalizations.tsSignIn,
                      textAlign: TextAlign.center,
                      style: AppTextStyle.headline
                          .of(context)
                          .copyWith(color: colorScheme.onSurface),
                    ),
                  ),
                  InfoButton(
                    label: appLocalizations.tsAboutTailscale,
                    paragraphs: about,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                appLocalizations.tsSignInShort,
                textAlign: TextAlign.center,
                style: AppTextStyle.subheadline
                    .of(context)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(visualDensity: VisualDensity.standard),
                child: action,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
