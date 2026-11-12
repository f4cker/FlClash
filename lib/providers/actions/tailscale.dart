part of '../action.dart';

bool _isUnboundTailscaleError(Object error) =>
    error is CoreMethodException &&
    const {
      'tailscale_stale_generation',
      'tailscale_node_not_found',
    }.contains(error.code);

String? _codeOf(Object error) =>
    error is CoreMethodException ? error.code : null;

@Riverpod(keepAlive: true)
class TailscaleAction extends _$TailscaleAction {
  CoreController get _core => ref.read(coreHandlerProvider);

  TailscaleNodeRecords get _records =>
      ref.read(tailscaleNodeRecordsProvider.notifier);

  @override
  void build() {}

  Future<TailscaleStatus> status(TailscaleNode node) {
    return _core.getTailscaleStatus(node.ref);
  }

  Future<TailscaleNode> start(TailscaleNode node) async {
    final started = await _core.startTailscale(node.ref);
    _publish(started);
    return started;
  }

  /// The only lift of the logout guard; stored whenever the Core may have
  /// dropped it, so a restart cannot bring back one it already let go.
  Future<TailscaleLoginResult> login(
    TailscaleNode node, {
    bool reauth = false,
  }) async {
    try {
      final result = await _core.loginTailscale(node.ref, reauth: reauth);
      await _setLoggedOut(node, false);
      return result;
    } catch (error) {
      if (!_isUnboundTailscaleError(error)) {
        await _setLoggedOut(node, false);
      }
      rethrow;
    }
  }

  /// Nothing is sent until the guard is on disk.
  Future<TailscaleLogoutResult> logout(TailscaleNode node) async {
    if (!await _setLoggedOut(node, true)) {
      throw const CoreMethodException(
        code: 'tailscale_guard_not_saved',
        message: 'the logout guard could not be saved; nothing was sent',
      );
    }
    return _core.logoutTailscale(node.ref);
  }

  /// A null field is left as it is; an empty [exitNode] means none.
  Future<TailscaleSetPrefsResult> setPrefs(
    TailscaleNode node, {
    String? exitNode,
    String? exitNodeName,
    bool? acceptRoutes,
  }) async {
    if (!node.overridable) {
      return const TailscaleSetPrefsResult(
        outcome: TailscaleSetPrefsOutcome.failed,
        error: TailscaleError(code: 'tailscale_override_ambiguous'),
      );
    }
    final previous = _records.recordOf(node.key);
    final previousManaged = _managedRecordOf(node);
    final saved = node.managed
        ? await _managed.change(
            node.profileId,
            node.managedId,
            (record) => record.copyWith(
              exitNode: exitNode ?? record.exitNode,
              exitNodeName: exitNode == null
                  ? record.exitNodeName
                  : exitNode.isEmpty
                  ? null
                  : exitNodeName,
              acceptRoutes: acceptRoutes ?? record.acceptRoutes,
            ),
          )
        : await _records.modify(
            node.key,
            (record) => record.copyWith(
              exitNode: exitNode ?? record.exitNode,
              exitNodeName: exitNode == null
                  ? record.exitNodeName
                  : exitNode.isEmpty
                  ? null
                  : exitNodeName,
              acceptRoutes: acceptRoutes ?? record.acceptRoutes,
            ),
          );
    if (!saved) {
      return const TailscaleSetPrefsResult(
        outcome: TailscaleSetPrefsOutcome.failed,
        error: TailscaleError(code: 'tailscale_override_not_saved'),
      );
    }
    try {
      final result = await _core.setTailscalePrefs(
        node.ref,
        exitNode: exitNode,
        exitLabel: _managedRecordOf(node)?.exitLabelFor(
          exitNode,
          exitNodeName,
          shared: tailscaleExitShared(
            _managed.state ?? const [],
            node.profileId,
          ),
        ),
        acceptRoutes: acceptRoutes,
      );
      return TailscaleSetPrefsResult(
        outcome: switch (result.outcome) {
          TailscalePrefsOutcome.applied => TailscaleSetPrefsOutcome.applied,
          TailscalePrefsOutcome.notRunning => TailscaleSetPrefsOutcome.saved,
          TailscalePrefsOutcome.failed => TailscaleSetPrefsOutcome.applyFailed,
          TailscalePrefsOutcome.unknown => TailscaleSetPrefsOutcome.unknown,
        },
        prefs: result.prefs,
        error: result.error,
      );
    } on CoreMethodException catch (error) {
      final cause = TailscaleError(code: error.code, message: error.message);
      if (error.code == 'tailscale_override_ambiguous') {
        if (previousManaged != null) {
          await _managed.change(
            node.profileId,
            node.managedId,
            (_) => previousManaged,
          );
        } else {
          await _records.modify(node.key, (_) => previous);
        }
        return TailscaleSetPrefsResult(
          outcome: TailscaleSetPrefsOutcome.failed,
          error: cause,
        );
      }
      return TailscaleSetPrefsResult(
        outcome: _isUnboundTailscaleError(error)
            ? TailscaleSetPrefsOutcome.saved
            : TailscaleSetPrefsOutcome.unknown,
        error: cause,
      );
    } on TimeoutException {
      return const TailscaleSetPrefsResult(
        outcome: TailscaleSetPrefsOutcome.unknown,
        error: TailscaleError(code: 'no_response'),
      );
    } finally {
      if (exitNode != null && node.managed) {
        ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
      }
    }
  }

  TailscalePanelNodes get _panel =>
      ref.read(tailscalePanelNodesProvider.notifier);

  /// Read only: the node as listed now, then its status. Settles an unknown
  /// result as far as the state goes; a pending legacy outcome stays.
  Future<TailscaleNode?> refresh(
    TailscaleNode node, {
    bool settings = false,
  }) async {
    final (read, fresh) = await _readNode(node.key);
    if (read && fresh == null) {
      _refreshNodes();
      return null;
    }
    final target = fresh ?? node;
    if (settings) {
      _panel.change(
        target.key,
        (state) => state.copyWith(exitNotice: null, routesNotice: null),
      );
    }
    await readStatus(target);
    return target;
  }

  /// A failed read keeps the last status and marks it as not current.
  Future<void> readStatus(TailscaleNode node) async {
    final key = node.key;
    if (_panel.of(key).reading) {
      return;
    }
    _panel.change(key, (state) => state.copyWith(reading: true));
    try {
      final status = await _core.getTailscaleStatus(node.ref);
      _publish(status.node);
      _panel.change(
        key,
        (state) => state.copyWith(
          status: status,
          readFailed: false,
          reading: false,
          unconfirmed: false,
          notice: switch (state.notice) {
            TailscaleCardNotice.loginUnconfirmed ||
            TailscaleCardNotice.logoutUnknown ||
            TailscaleCardNotice.logoutFailed ||
            TailscaleCardNotice.nodeChanged => null,
            final notice => notice,
          },
        ),
      );
    } catch (error) {
      commonPrint.log(
        'tailscale ${node.name} status error $error',
        logLevel: LogLevel.warning,
      );
      if (_isUnboundTailscaleError(error)) {
        _refreshNodes();
        _panel.change(key, (state) => state.copyWith(reading: false));
        return;
      }
      _panel.change(
        key,
        (state) => state.copyWith(readFailed: true, reading: false),
      );
    }
  }

  /// Starts a node that has a login of its own, once per instance; never one
  /// the user logged out of, one that still needs a login, or a panel-added
  /// draft not in the routing, which only reads.
  Future<void> prewarm(TailscaleNode node) async {
    if (node.managed && !node.attached) {
      return readStatus(node);
    }
    final key = node.key;
    final panel = _panel.of(key);
    if (panel.prewarmed == node.generation ||
        panel.starting ||
        node.started ||
        node.loggedOut ||
        !node.hasIdentity ||
        node.startError != null) {
      return;
    }
    _panel.change(
      key,
      (state) => state.copyWith(
        prewarmed: node.generation,
        starting: true,
        startFailed: false,
      ),
    );
    var startFailed = false;
    var unconfirmed = false;
    TailscaleNode? started;
    try {
      started = await start(node);
    } catch (error) {
      commonPrint.log(
        'tailscale ${node.name} start error $error',
        logLevel: LogLevel.warning,
      );
      if (_isUnboundTailscaleError(error) ||
          const {
            'tailscale_logged_out',
            'tailscale_needs_login',
          }.contains(_codeOf(error))) {
        _refreshNodes();
      } else if (isUnansweredCoreError(error)) {
        unconfirmed = true;
      } else {
        startFailed = true;
      }
    } finally {
      _panel.change(
        key,
        (state) => state.copyWith(
          starting: false,
          startFailed: startFailed,
          unconfirmed: state.unconfirmed || unconfirmed,
        ),
      );
    }
    if (started != null) {
      await readStatus(started);
    }
  }

  /// A start error sticks to its instance, so a retry applies the profile
  /// again and the new instance starts.
  Future<void> retryStart(TailscaleNode node) async {
    final key = node.key;
    if (_panel.of(key).restarting) {
      return;
    }
    _panel.change(
      key,
      (state) => state.copyWith(restarting: true, startFailed: false),
    );
    try {
      await reapply();
    } finally {
      _panel.change(key, (state) => state.copyWith(restarting: false));
    }
    await _readNode(key);
  }

  /// The URL to open, only for the instance the page showed; the page drops
  /// it once the node changes.
  Future<String?> loginFromPanel(
    TailscaleNode node, {
    bool reauth = false,
  }) async {
    final key = node.key;
    if (_panel.of(key).loggingIn) {
      return null;
    }
    if (node.managed && !node.attached) {
      _managedPanel.change(key, (state) => state.copyWith(signInTapped: true));
    }
    _panel.change(
      key,
      (state) =>
          state.copyWith(loggingIn: true, notice: null, unconfirmed: false),
    );
    String? url;
    TailscaleCardNotice? notice;
    var unconfirmed = false;
    try {
      final result = await login(node, reauth: reauth);
      if (result.generation != node.generation) {
        notice = TailscaleCardNotice.nodeChanged;
      } else if (result.authUrl case final authUrl? when authUrl.isNotEmpty) {
        url = authUrl;
      } else if (result.pending) {
        notice = TailscaleCardNotice.loginUnconfirmed;
        unconfirmed = true;
      } else if (result.state == TailscaleBackendState.needsLogin) {
        notice = TailscaleCardNotice.urlMissing;
      }
    } catch (error) {
      commonPrint.log(
        'tailscale ${node.name} login error ${_codeOf(error) ?? error.runtimeType}',
        logLevel: LogLevel.warning,
      );
      if (_isUnboundTailscaleError(error)) {
        notice = TailscaleCardNotice.nodeChanged;
      } else if (_codeOf(error) == 'tailscale_auth_url_rejected') {
        notice = TailscaleCardNotice.urlRejected;
      } else if (isUnansweredCoreError(error)) {
        notice = TailscaleCardNotice.loginUnconfirmed;
        unconfirmed = true;
      } else {
        notice = TailscaleCardNotice.urlMissing;
      }
    } finally {
      _panel.change(
        key,
        (state) => state.copyWith(
          loggingIn: false,
          notice: notice,
          unconfirmed: unconfirmed,
        ),
      );
    }
    final (_, fresh) = await _readNode(key);
    if (fresh == null) {
      _refreshNodes();
      return null;
    }
    if (fresh.generation != node.generation) {
      url = null;
    }
    // A pending result stays until the user reads; this read would settle it.
    if (!unconfirmed) {
      await readStatus(fresh);
    }
    return url;
  }

  /// True only once the Core confirmed the logout and the guard was saved.
  Future<bool> logoutFromPanel(TailscaleNode node) async {
    final key = node.key;
    if (_panel.of(key).loggingOut) {
      return false;
    }
    _panel.change(
      key,
      (state) => state.copyWith(loggingOut: true, notice: null),
    );
    var confirmed = false;
    TailscaleCardNotice? notice;
    try {
      final result = await logout(node);
      confirmed = result.outcome == TailscaleLogoutOutcome.confirmed;
      if (!confirmed) {
        notice = TailscaleCardNotice.logoutUnknown;
      }
    } catch (error) {
      commonPrint.log(
        'tailscale ${node.name} logout error ${_codeOf(error) ?? error.runtimeType}',
        logLevel: LogLevel.warning,
      );
      notice = switch (_codeOf(error)) {
        'tailscale_guard_not_saved' => TailscaleCardNotice.logoutFailed,
        _ when _isUnboundTailscaleError(error) =>
          TailscaleCardNotice.nodeChanged,
        _ => TailscaleCardNotice.logoutUnknown,
      };
    } finally {
      _panel.change(
        key,
        (state) => state.copyWith(
          loggingOut: false,
          notice: notice,
          unconfirmed: notice == TailscaleCardNotice.logoutUnknown,
        ),
      );
    }
    final (_, fresh) = await _readNode(key);
    if (fresh != null &&
        fresh.generation == node.generation &&
        notice != TailscaleCardNotice.logoutUnknown) {
      await readStatus(fresh);
    }
    return confirmed;
  }

  /// Saved first, then applied; the outcome stays on the card until a read
  /// of the settings or the next change.
  Future<TailscaleSettingNotice> setPrefsFromPanel(
    TailscaleNode node, {
    String? exitNode,
    String? exitNodeName,
    bool? acceptRoutes,
  }) async {
    final key = node.key;
    final exit = exitNode != null;
    final panel = _panel.of(key);
    if (exit ? panel.applyingExit : panel.applyingRoutes) {
      return TailscaleSettingNotice.unknown;
    }
    _panel.change(
      key,
      (state) => exit
          ? state.copyWith(applyingExit: true, exitNotice: null)
          : state.copyWith(applyingRoutes: true, routesNotice: null),
    );
    var notice = TailscaleSettingNotice.unknown;
    try {
      final result = await setPrefs(
        node,
        exitNode: exitNode,
        exitNodeName: exitNodeName,
        acceptRoutes: acceptRoutes,
      );
      notice = switch (result.outcome) {
        TailscaleSetPrefsOutcome.applied => TailscaleSettingNotice.updated,
        TailscaleSetPrefsOutcome.saved => TailscaleSettingNotice.saved,
        TailscaleSetPrefsOutcome.applyFailed =>
          TailscaleSettingNotice.applyFailed,
        TailscaleSetPrefsOutcome.failed => TailscaleSettingNotice.failed,
        TailscaleSetPrefsOutcome.unknown => TailscaleSettingNotice.unknown,
      };
    } catch (error) {
      commonPrint.log(
        'tailscale ${node.name} prefs error ${_codeOf(error) ?? error.runtimeType}',
        logLevel: LogLevel.warning,
      );
    } finally {
      _panel.change(
        key,
        (state) => exit
            ? state.copyWith(applyingExit: false, exitNotice: notice)
            : state.copyWith(applyingRoutes: false, routesNotice: notice),
      );
    }
    final (_, fresh) = await _readNode(key);
    if (fresh != null) {
      await readStatus(fresh);
    }
    return notice;
  }

  TailscaleLegacyStates get _legacy =>
      ref.read(tailscaleLegacyStatesProvider.notifier);

  /// The Core refuses the token once anything the confirmation showed changed.
  Future<TailscaleLegacyNotice> migrateLegacy(
    TailscaleNode node,
    TailscaleLegacyIdentity offer,
  ) async {
    final key = node.key;
    final token = offer.offerToken;
    if (token == null || _legacy.of(key).migrating) {
      return _settleLegacy(key, TailscaleLegacyNotice.changed);
    }
    _legacy.change(
      key,
      (state) => state.copyWith(
        migrating: true,
        notice: TailscaleLegacyNotice.none,
        archiveIntact: false,
        stage: null,
      ),
    );
    var notice = TailscaleLegacyNotice.unknown;
    var archiveIntact = false;
    TailscaleMigrateStage? stage;
    try {
      final result = await _core.migrateTailscaleLegacy(
        node.ref,
        offerToken: token,
      );
      archiveIntact = result.archiveIntact;
      stage = result.stage;
      notice = switch (result.outcome) {
        TailscaleMigrateOutcome.migrated => TailscaleLegacyNotice.migrated,
        TailscaleMigrateOutcome.failed
            when result.targetUntouched && archiveIntact =>
          TailscaleLegacyNotice.failed,
        TailscaleMigrateOutcome.failed ||
        TailscaleMigrateOutcome.unknown => TailscaleLegacyNotice.unknown,
      };
      if (notice == TailscaleLegacyNotice.migrated) {
        await _keepMigration(node, result.migration);
      }
      if (result.reapplyRequired) {
        await reapply();
      } else {
        _publish(result.node);
      }
    } on CoreMethodException catch (error) {
      notice = switch (error.code) {
        'tailscale_legacy_unreadable' => TailscaleLegacyNotice.unreadable,
        'tailscale_legacy_unconfirmed' => TailscaleLegacyNotice.unconfirmed,
        final code when code.startsWith('tailscale_') =>
          TailscaleLegacyNotice.changed,
        _ => TailscaleLegacyNotice.unknown,
      };
      if (notice != TailscaleLegacyNotice.unknown) {
        _refreshNodes();
      }
    } on TimeoutException {
      notice = TailscaleLegacyNotice.unknown;
    } finally {
      _legacy.change(
        key,
        (state) => state.copyWith(
          migrating: false,
          notice: notice,
          archiveIntact: archiveIntact,
          stage: stage,
        ),
      );
    }
    return notice;
  }

  /// Read only, never migrates again; only a read proving the outcome settles
  /// it, anything else leaves it pending.
  Future<TailscaleLegacyNotice> recheckLegacy(TailscaleNodeKey key) async {
    var (read, node) = await _readNode(key);
    if (read && node == null && await reapply()) {
      (read, node) = await _readNode(key);
    }
    final notice = switch (node) {
      TailscaleNode(hasIdentity: true) => TailscaleLegacyNotice.migrated,
      TailscaleNode(:final legacy?)
          when legacy.eligibility == TailscaleLegacyEligibility.eligible =>
        TailscaleLegacyNotice.failed,
      _ => TailscaleLegacyNotice.unknown,
    };
    if (node != null && notice == TailscaleLegacyNotice.migrated) {
      final marker = node.legacy?.migratedTo;
      if (marker != null && marker.name == node.name) {
        await _keepMigration(node, marker);
      }
    }
    if (notice != TailscaleLegacyNotice.unknown) {
      _legacy.change(key, (state) => state.copyWith(notice: notice));
    }
    return _legacy.of(key).notice;
  }

  /// A later ineligible read then explains a change, not an offer never made.
  void markLegacyOffered(TailscaleNode node) {
    _legacy.change(node.key, (state) => state.copyWith(offered: true));
  }

  TailscaleLegacyNotice _settleLegacy(
    TailscaleNodeKey key,
    TailscaleLegacyNotice notice,
  ) {
    _legacy.change(key, (state) => state.copyWith(notice: notice));
    return notice;
  }

  Future<void> _keepMigration(
    TailscaleNode node,
    TailscaleLegacyMigration migration,
  ) async {
    await ref.read(tailscaleLegacyMigratedProvider.notifier).save(migration);
    await _setLoggedOut(node, false);
  }

  Future<(bool, TailscaleNode?)> _readNode(TailscaleNodeKey key) async {
    try {
      final nodes = await _core.getTailscaleNodes();
      final node = nodes.where((node) => node.key == key).firstOrNull;
      if (node != null) {
        _publish(node);
      }
      return (true, node);
    } catch (error) {
      commonPrint.log(
        'tailscale recheck error $error',
        logLevel: LogLevel.warning,
      );
      return (false, null);
    }
  }

  void _refreshNodes() {
    if (ref.exists(tailscaleNodesProvider)) {
      ref.invalidate(tailscaleNodesProvider);
    }
  }

  /// A start error sticks to its instance; only a new one starts again.
  Future<bool> reapply() {
    return ref
        .read(setupActionProvider.notifier)
        .applyProfile(force: true, silence: true);
  }

  Future<bool> _setLoggedOut(TailscaleNode node, bool loggedOut) async {
    final saved = node.managed
        ? await _managed.change(
            node.profileId,
            node.managedId,
            (record) => record.copyWith(loggedOut: loggedOut),
          )
        : await _records.modify(
            node.key,
            (record) => record.copyWith(loggedOut: loggedOut),
          );
    if (!saved) {
      commonPrint.log(
        'tailscale ${node.name}: logged-out=$loggedOut not saved',
        logLevel: LogLevel.warning,
      );
    }
    return saved;
  }

  TailscaleManagedRecords get _managed =>
      ref.read(tailscaleManagedRecordsProvider.notifier);

  TailscaleManagedPanels get _managedPanel =>
      ref.read(tailscaleManagedPanelsProvider.notifier);

  TailscaleManagedRecord? _managedRecordOf(TailscaleNode node) =>
      node.managed ? _managed.recordOf(node.profileId, node.managedId) : null;

  int? _addingTo;
  bool _adding = false;

  /// Creates a panel-added draft in the current profile, a local one first
  /// when there is none, and returns its node once the Core lists it. The
  /// sign-in itself starts only from the user's tap that called this.
  Future<TailscaleNode?> addManaged({
    required String newProfileLabel,
    void Function()? onPreparingProfile,
  }) async {
    if (_adding) {
      return null;
    }
    _adding = true;
    try {
      var profileId = ref.read(currentProfileIdProvider);
      if (profileId == null) {
        onPreparingProfile?.call();
        profileId = ref
            .read(profilesActionProvider.notifier)
            .addCustomProfile(newProfileLabel);
      }
      _addingTo = profileId;
      final id = tailscaleManagedId();
      final key = tailscaleManagedNodeKey(profileId, id);
      final saved = await _managed.modify(
        (records) => [
          ...records,
          TailscaleManagedRecord(
            id: id,
            profileId: profileId!,
            name: _freeManagedName(records, profileId),
          ),
        ],
      );
      if (!saved) {
        _managedPanel.change(
          tailscaleManagedNodeKey(profileId, ''),
          (state) =>
              state.copyWith(notice: TailscaleManagedNotice.prepareFailed),
        );
        return null;
      }
      _managedPanel.change(key, (state) => state.copyWith(preparing: true));
      final applied = await reapply();
      final (read, node) = await _readNode(key);
      final notice = node != null
          ? null
          : read && applied
          ? TailscaleManagedNotice.prepareFailed
          : TailscaleManagedNotice.prepareUnknown;
      _managedPanel.change(
        key,
        (state) => state.copyWith(preparing: false, notice: notice),
      );
      // The page has no node to show this on; it reads the profile's slot.
      _managedPanel.change(
        tailscaleManagedNodeKey(profileId, ''),
        (state) => state.copyWith(notice: notice),
      );
      _refreshNodes();
      return node;
    } finally {
      _adding = false;
      _addingTo = null;
    }
  }

  static String _freeManagedName(
    List<TailscaleManagedRecord> records,
    int profileId,
  ) {
    final taken = {
      for (final record in records)
        if (record.profileId == profileId) record.name,
    };
    for (var i = 1; ; i++) {
      final name = i == 1 ? 'Tailscale' : 'Tailscale $i';
      if (!taken.contains(name)) {
        return name;
      }
    }
  }

  /// Another panel-added entry of the profile holding the same account, by
  /// its live identity or, once signed out, the one it was attached with.
  TailscaleNodeKey? duplicateOf(TailscaleNode node, List<TailscaleNode> nodes) {
    final account = node.account;
    if (!node.managed || account == null) {
      return null;
    }
    final live = nodes
        .where(
          (other) =>
              other.managed &&
              other.managedId != node.managedId &&
              other.profileId == node.profileId &&
              other.account != null &&
              other.account!.sameAs(account),
        )
        .firstOrNull;
    if (live != null) {
      return live.key;
    }
    return _managed
        .ofProfile(node.profileId)
        .where(
          (record) =>
              record.id != node.managedId &&
              record.account != null &&
              record.account!.sameAs(account),
        )
        .firstOrNull
        ?.key;
  }

  /// Puts a signed-in account into the profile's routing; only a list read
  /// after the apply that shows it attached confirms it.
  Future<TailscaleAttachState> attachManaged(
    TailscaleNode node,
    List<TailscaleNode> nodes,
  ) async {
    final key = node.key;
    final current = _managedPanel.of(key).attach;
    if (!node.managed ||
        node.attached ||
        current == TailscaleAttachState.attaching ||
        current == TailscaleAttachState.unknown) {
      return current;
    }
    if (duplicateOf(node, nodes) != null) {
      _managedPanel.change(
        key,
        (state) => state.copyWith(attach: TailscaleAttachState.duplicate),
      );
      return TailscaleAttachState.duplicate;
    }
    _managedPanel.change(
      key,
      (state) => state.copyWith(attach: TailscaleAttachState.attaching),
    );
    var attach = TailscaleAttachState.unknown;
    try {
      final saved = await _managed.change(
        node.profileId,
        node.managedId,
        (record) => record.copyWith(attached: true, account: node.account),
      );
      if (!saved) {
        attach = TailscaleAttachState.failed;
        return attach;
      }
      final applied = await reapply();
      final (read, fresh) = await _readNode(key);
      attach = switch ((read, fresh)) {
        (_, TailscaleNode(attached: true)) => TailscaleAttachState.attached,
        (true, _) when applied => TailscaleAttachState.failed,
        _ => TailscaleAttachState.unknown,
      };
      if (attach == TailscaleAttachState.failed) {
        await _managed.change(
          node.profileId,
          node.managedId,
          (record) => record.copyWith(attached: false, account: null),
        );
      }
      return attach;
    } finally {
      _managedPanel.change(
        key,
        (state) => state.copyWith(attach: attach, signInTapped: false),
      );
      _refreshRoutes();
    }
  }

  /// Read only: settles an unknown attach or removal as far as a list read
  /// proves it, and never writes again on its own.
  Future<void> recheckManaged(TailscaleNode node) async {
    final key = node.key;
    final (read, fresh) = await _readNode(key);
    if (!read) {
      return;
    }
    final record = _managedRecordOf(node);
    final panel = _managedPanel.of(key);
    if (fresh == null) {
      if (record == null) {
        _managedPanel.change(key, (_) => const TailscaleManagedPanel());
      }
      _refreshNodes();
      return;
    }
    // Only a node whose sign-in is gone proves the logout went through.
    final signedOut = !fresh.hasIdentity && fresh.account == null;
    var removing = record != null && record.removing;
    if (removing && signedOut) {
      removing = !await _managed.change(
        node.profileId,
        node.managedId,
        (record) => record.copyWith(removing: false),
      );
    }
    _managedPanel.change(
      key,
      (state) => state.copyWith(
        attach: switch (panel.attach) {
          TailscaleAttachState.unknown when fresh.attached =>
            TailscaleAttachState.attached,
          TailscaleAttachState.unknown => TailscaleAttachState.failed,
          final attach => attach,
        },
        notice: switch (panel.notice) {
          TailscaleManagedNotice.removeLogoutUnknown ||
          TailscaleManagedNotice.removeIncomplete ||
          TailscaleManagedNotice.removeUnknown when removing => panel.notice,
          TailscaleManagedNotice.removeLogoutUnknown ||
          TailscaleManagedNotice.removeIncomplete ||
          TailscaleManagedNotice.removeUnknown ||
          TailscaleManagedNotice.prepareUnknown ||
          TailscaleManagedNotice.addUnconfirmed => null,
          final notice => notice,
        },
      ),
    );
    await readStatus(fresh);
    _refreshRoutes();
  }

  /// Plain sign-out: the record, its guard and its targets stay.
  Future<bool> signOutManaged(TailscaleNode node) async {
    final done = await logoutFromPanel(node);
    if (done) {
      _managedPanel.change(
        node.key,
        (state) => state.copyWith(notice: TailscaleManagedNotice.signedOut),
      );
      _refreshRoutes();
    }
    return done;
  }

  /// Sign-out, then the record; null once both are confirmed. The guard and
  /// the pending mark are saved before anything is sent, and only a read
  /// lifts the mark again.
  Future<TailscaleManagedNotice?> removeManaged(TailscaleNode node) async {
    final key = node.key;
    final record = _managedRecordOf(node);
    if (record == null) {
      return null;
    }
    if (record.removing || _managedPanel.of(key).removing) {
      return TailscaleManagedNotice.removeUnknown;
    }
    _managedPanel.change(
      key,
      (state) => state.copyWith(removing: true, notice: null),
    );
    TailscaleManagedNotice? notice = TailscaleManagedNotice.removeUnknown;
    try {
      final guarded = await _managed.change(
        node.profileId,
        node.managedId,
        (record) => record.copyWith(loggedOut: true, removing: true),
      );
      if (!guarded) {
        _panel.change(
          key,
          (state) => state.copyWith(notice: TailscaleCardNotice.logoutFailed),
        );
        notice = null;
        return TailscaleManagedNotice.removeIncomplete;
      }
      try {
        final result = await _core.logoutTailscale(node.ref);
        if (result.outcome != TailscaleLogoutOutcome.confirmed) {
          notice = TailscaleManagedNotice.removeLogoutUnknown;
          return notice;
        }
      } catch (error) {
        commonPrint.log(
          'tailscale ${node.name} remove logout error ${_codeOf(error) ?? error.runtimeType}',
          logLevel: LogLevel.warning,
        );
        notice = TailscaleManagedNotice.removeLogoutUnknown;
        return notice;
      }
      final last = _managed.ofProfile(node.profileId).length == 1;
      final dropped = await _managed.modify(
        (records) => [
          for (final item in records)
            if (!(item.profileId == node.profileId &&
                item.id == node.managedId))
              item,
        ],
      );
      if (!dropped) {
        notice = TailscaleManagedNotice.removeIncomplete;
        return notice;
      }
      if (last && await _forgetRoutes(node.profileId) != true) {
        await reapply();
        notice = TailscaleManagedNotice.removeIncomplete;
        return notice;
      }
      final applied = await reapply();
      final (read, fresh) = await _readNode(key);
      notice = read && fresh == null && applied
          ? null
          : TailscaleManagedNotice.removeUnknown;
      return notice;
    } finally {
      _managedPanel.change(
        key,
        (state) => state.copyWith(removing: false, notice: notice),
      );
      _refreshNodes();
      _refreshRoutes();
    }
  }

  /// Saves the user's choices; [TailscaleAssignNotice.updated] only once a
  /// read of the routes shows each one in force.
  Future<TailscaleAssignNotice> assignRoutes(
    int profileId,
    List<TailscaleRouteAssignment> assignments,
  ) async {
    try {
      final result = await _core.assignTailscaleRoutes(profileId, assignments);
      if (result.outcome != 'applied') {
        return TailscaleAssignNotice.failed;
      }
      final routes = await _core.getTailscaleRoutes(profileId);
      if (ref.exists(tailscaleRoutesReportProvider)) {
        ref.read(tailscaleRoutesReportProvider.notifier).put(routes);
      }
      final inForce = assignments.every(
        (item) =>
            routes.targetOf(item.target.kind, item.target.value)?.owner ==
            item.owner,
      );
      return inForce
          ? TailscaleAssignNotice.updated
          : TailscaleAssignNotice.saved;
    } on CoreMethodException catch (error) {
      if (error.code == 'tailscale_assign_invalid' ||
          error.code == 'tailscale_profile_not_current') {
        return TailscaleAssignNotice.failed;
      }
      return TailscaleAssignNotice.unknown;
    } catch (_) {
      return TailscaleAssignNotice.unknown;
    }
  }

  Future<bool?> _forgetRoutes(int profileId) async {
    try {
      final forgot = await _core.forgetTailscaleRoutes(profileId);
      return switch (forgot.outcome) {
        'confirmed' => true,
        'failed' => false,
        _ => null,
      };
    } catch (error) {
      commonPrint.log(
        'tailscale forget routes error ${_codeOf(error) ?? error.runtimeType}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  /// A profile cannot be deleted while its accounts are unreadable, an add
  /// runs, or any of its accounts has an operation whose outcome is open.
  bool hasPendingManaged(int profileId) {
    if (ref.read(tailscaleManagedRecordsProvider) == null ||
        (_adding && _addingTo == profileId)) {
      return true;
    }
    final slot = _managedPanel.of(tailscaleManagedNodeKey(profileId, ''));
    if (slot.notice == TailscaleManagedNotice.prepareUnknown) {
      return true;
    }
    return _managed.ofProfile(profileId).any((record) {
      final managed = _managedPanel.of(record.key);
      final panel = _panel.of(record.key);
      return record.removing ||
          record.unlinking ||
          managed.removing ||
          managed.preparing ||
          const {
            TailscaleAttachState.attaching,
            TailscaleAttachState.unknown,
            TailscaleAttachState.checking,
          }.contains(managed.attach) ||
          const {
            TailscaleManagedNotice.removeLogoutUnknown,
            TailscaleManagedNotice.removeIncomplete,
            TailscaleManagedNotice.removeUnknown,
            TailscaleManagedNotice.prepareUnknown,
            TailscaleManagedNotice.addUnconfirmed,
          }.contains(managed.notice) ||
          panel.loggingIn ||
          panel.loggingOut ||
          panel.unconfirmed;
    });
  }

  /// Records stay marked until [delete] returns, so an open outcome keeps
  /// them, their targets and the delete lock; sign-in archives stay on disk.
  Future<TailscaleUnlinkOutcome> unlinkProfile(
    int profileId,
    Future<void> Function() delete,
  ) async {
    if (hasPendingManaged(profileId)) {
      return TailscaleUnlinkOutcome.pending;
    }
    if (_managed.ofProfile(profileId).isEmpty) {
      await delete();
      return TailscaleUnlinkOutcome.done;
    }
    final before = await _readManaged(profileId);
    if (before == null) {
      return TailscaleUnlinkOutcome.failed;
    }
    final mark = TailscaleUnlinkMark(
      operation: '${snowflake.id}',
      profileId: profileId,
      before: before.fingerprint(attached: _attached(profileId)),
    );
    if (!await _markUnlinking(profileId, mark)) {
      return TailscaleUnlinkOutcome.failed;
    }
    switch (await _forgetRoutes(profileId)) {
      case null:
        return TailscaleUnlinkOutcome.unconfirmed;
      case false:
        return await _settleUnlink(profileId, mark, stored: true) ??
            TailscaleUnlinkOutcome.unconfirmed;
      case true:
    }
    try {
      await delete();
    } catch (error) {
      commonPrint.log(
        'tailscale delete profile error ${error.runtimeType}',
        logLevel: LogLevel.warning,
      );
      return TailscaleUnlinkOutcome.deleteUnconfirmed;
    }
    await _dropProfile(profileId);
    return TailscaleUnlinkOutcome.done;
  }

  /// Read only. The mark lifts only when the Core shows this profile's
  /// routing, pins and REJECT rules settled wholly before or wholly after the
  /// marked unlink: a deleted profile then drops its records, a kept one may
  /// be deleted again. Anything else, a read that fails included, stays open.
  Future<TailscaleUnlinkOutcome> recheckUnlink(
    int profileId, {
    required TailscaleUnlinkOutcome open,
  }) async {
    if (ref.read(tailscaleManagedRecordsProvider) == null) {
      return open;
    }
    final marked = [
      for (final record in _managed.ofProfile(profileId))
        if (record.unlinking) record,
    ];
    if (marked.isEmpty) {
      return hasPendingManaged(profileId)
          ? TailscaleUnlinkOutcome.pending
          : TailscaleUnlinkOutcome.failed;
    }
    final marks = {for (final record in marked) record.unlink};
    final mark = marks.length == 1 && marks.single?.profileId == profileId
        ? marks.single
        : null;
    final bool stored;
    try {
      stored = await ref.read(profilesProvider.notifier).stored(profileId);
    } catch (error) {
      commonPrint.log(
        'tailscale profile read error ${error.runtimeType}',
        logLevel: LogLevel.warning,
      );
      return open;
    }
    return await _settleUnlink(profileId, mark, stored: stored) ?? open;
  }

  /// Null leaves the mark: the read failed or the state is partial.
  Future<TailscaleUnlinkOutcome?> _settleUnlink(
    int profileId,
    TailscaleUnlinkMark? mark, {
    required bool stored,
  }) async {
    final state = await _readManaged(profileId);
    final attached = _attached(profileId);
    if (state == null || !state.settled(attached: attached)) {
      return null;
    }
    if (!stored) {
      return state.isForgotten && await _dropProfile(profileId)
          ? TailscaleUnlinkOutcome.done
          : null;
    }
    final before =
        mark?.before != null &&
        state.fingerprint(attached: attached) == mark!.before;
    if (!before && !state.isForgotten) {
      return null;
    }
    if (!await _markUnlinking(profileId, null)) {
      return null;
    }
    return hasPendingManaged(profileId)
        ? TailscaleUnlinkOutcome.pending
        : TailscaleUnlinkOutcome.failed;
  }

  Future<TailscaleManagedState?> _readManaged(int profileId) async {
    try {
      final state = await _core.getTailscaleManagedState(profileId);
      return state.profileId == profileId ? state : null;
    } catch (error) {
      commonPrint.log(
        'tailscale managed state error ${_codeOf(error) ?? error.runtimeType}',
        logLevel: LogLevel.warning,
      );
      return null;
    }
  }

  bool _attached(int profileId) =>
      _managed.ofProfile(profileId).any((record) => record.attached);

  Future<bool> _markUnlinking(int profileId, TailscaleUnlinkMark? mark) {
    return _managed.modify(
      (records) => [
        for (final record in records)
          record.profileId == profileId
              ? record.copyWith(unlinking: mark != null, unlink: mark)
              : record,
      ],
    );
  }

  Future<bool> _dropProfile(int profileId) {
    return _managed.modify(
      (records) => [
        for (final record in records)
          if (record.profileId != profileId) record,
      ],
    );
  }

  void _refreshRoutes() {
    if (ref.exists(tailscaleRoutesReportProvider)) {
      ref.invalidate(tailscaleRoutesReportProvider);
    }
  }

  void _publish(TailscaleNode node) {
    if (ref.exists(tailscaleNodesProvider)) {
      ref.read(tailscaleNodesProvider.notifier).put(node);
    }
  }
}
