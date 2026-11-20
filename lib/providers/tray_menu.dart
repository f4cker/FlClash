import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';

enum TraySwitchFailure { failed, unconfirmed }

@immutable
class TrayGroupMenuState {
  const TrayGroupMenuState({
    this.confirmedName,
    this.pendingName,
    this.switchFailure,
  });

  final String? confirmedName;
  final String? pendingName;
  final TraySwitchFailure? switchFailure;
}

final rawGroupsProvider = Provider<List<Group>>(
  (ref) => ref.watch(groupsProvider),
);

void _listenForTrayReset(Ref ref, void Function() reset) {
  ref.listen(currentProfileIdProvider, (_, _) => reset());
  ref.listen(coreStatusProvider, (_, _) => reset());
  ref.listen(coreHandlerProvider, (_, _) => reset());
  ref.listen(runTimeProvider, (previous, next) {
    if ((previous == null) != (next == null)) reset();
  });
}

final trayGroupMenuStatesProvider =
    NotifierProvider<TrayGroupMenuStates, Map<String, TrayGroupMenuState>>(
      TrayGroupMenuStates.new,
    );

class TrayGroupMenuStates extends Notifier<Map<String, TrayGroupMenuState>> {
  @override
  Map<String, TrayGroupMenuState> build() {
    _listenForTrayReset(ref, clear);
    return const {};
  }

  void set(String groupName, TrayGroupMenuState value) {
    state = Map.unmodifiable({...state, groupName: value});
  }

  void remove(String groupName) {
    if (!state.containsKey(groupName)) return;
    state = Map.unmodifiable({...state}..remove(groupName));
  }

  void clear() => state = const {};
}

final trayGroupsReadFailedProvider =
    NotifierProvider<TrayGroupsReadFailed, bool>(TrayGroupsReadFailed.new);

class TrayGroupsReadFailed extends Notifier<bool> {
  @override
  bool build() {
    _listenForTrayReset(ref, () => set(false));
    return false;
  }

  void set(bool value) => state = value;
}

/// Which of the tray's decryption switches is being acted on, if one is:
/// both ignore clicks until it settles.
enum TrayMitmToggle { mitm, capture }

final trayMitmPendingProvider =
    NotifierProvider<TrayMitmPending, TrayMitmToggle?>(TrayMitmPending.new);

class TrayMitmPending extends Notifier<TrayMitmToggle?> {
  @override
  TrayMitmToggle? build() => null;

  TrayMitmToggle? get value => state;

  set value(TrayMitmToggle? value) => state = value;
}

@immutable
class TrayModeMenuState {
  const TrayModeMenuState({this.pendingMode, this.error});

  final Mode? pendingMode;
  final String? error;
}

final trayModeMenuStateProvider =
    NotifierProvider<TrayModeMenuStateNotifier, TrayModeMenuState>(
      TrayModeMenuStateNotifier.new,
    );

class TrayModeMenuStateNotifier extends Notifier<TrayModeMenuState> {
  @override
  TrayModeMenuState build() => const TrayModeMenuState();

  void set(TrayModeMenuState value) => state = value;
}

final trayDelayTestAllPendingProvider =
    NotifierProvider<TrayDelayTestAllPending, bool>(
      TrayDelayTestAllPending.new,
    );

class TrayDelayTestAllPending extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> run(Future<void> Function() test) async {
    if (state) return;
    state = true;
    try {
      await test();
    } finally {
      state = false;
    }
  }
}
