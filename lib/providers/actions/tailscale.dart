part of '../action.dart';

bool _isUnboundTailscaleError(Object error) =>
    error is CoreMethodException &&
    const {
      'tailscale_stale_generation',
      'tailscale_node_not_found',
    }.contains(error.code);

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
    bool? acceptRoutes,
  }) async {
    if (!node.overridable) {
      return const TailscaleSetPrefsResult(
        outcome: TailscaleSetPrefsOutcome.failed,
        error: TailscaleError(code: 'tailscale_not_overridable'),
      );
    }
    final previous = _records.recordOf(node.key);
    final saved = await _records.modify(
      node.key,
      (record) => record.copyWith(
        exitNode: exitNode ?? record.exitNode,
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
      if (error.code == 'tailscale_not_overridable') {
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
        archiveIntact: true,
      ),
    );
    var notice = TailscaleLegacyNotice.unknown;
    var archiveIntact = true;
    try {
      final result = await _core.migrateTailscaleLegacy(
        node.ref,
        offerToken: token,
      );
      archiveIntact = result.archiveIntact;
      notice = switch (result.outcome) {
        TailscaleMigrateOutcome.migrated => TailscaleLegacyNotice.migrated,
        TailscaleMigrateOutcome.failed when !result.targetUntouched =>
          TailscaleLegacyNotice.unknown,
        TailscaleMigrateOutcome.failed =>
          archiveIntact
              ? TailscaleLegacyNotice.failed
              : TailscaleLegacyNotice.archiveError,
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
