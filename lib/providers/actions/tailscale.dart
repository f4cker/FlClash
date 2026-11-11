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
