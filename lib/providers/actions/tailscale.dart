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
    final saved = await _records.modify(
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
        await _records.modify(node.key, (_) => previous);
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
  /// the user logged out of or one that still needs a login.
  Future<void> prewarm(TailscaleNode node) async {
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
    final saved = await _records.modify(
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

  void _publish(TailscaleNode node) {
    if (ref.exists(tailscaleNodesProvider)) {
      ref.read(tailscaleNodesProvider.notifier).put(node);
    }
  }
}
