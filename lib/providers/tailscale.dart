import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'core.dart';
import 'state.dart';

part 'generated/tailscale.g.dart';

/// Seeded from preferences before the first setup.
@Riverpod(keepAlive: true)
class TailscaleNodeRecords extends _$TailscaleNodeRecords
    with AutoDisposeNotifierMixin {
  final _writes = SerialTaskScheduler();

  @override
  List<TailscaleNodeRecord> build() => const [];

  TailscaleNodeRecord recordOf(TailscaleNodeKey key) =>
      state.firstWhereOrNull((record) => record.key == key) ??
      TailscaleNodeRecord(
        profileId: key.profileId,
        name: key.name,
        controlUrl: key.controlUrl,
      );

  /// The state follows the write, so nothing reads a guard not on disk yet.
  Future<bool> modify(
    TailscaleNodeKey key,
    TailscaleNodeRecord Function(TailscaleNodeRecord record) update,
  ) {
    return _writes.run(() async {
      final next = update(recordOf(key));
      final records = [
        for (final record in state)
          if (record.key != key) record,
        if (!next.isEmpty) next,
      ];
      final bool saved;
      try {
        saved = await preferences.saveTailscaleNodeRecords(records);
      } catch (error) {
        commonPrint.log(
          'saveTailscaleNodeRecords error $error',
          logLevel: LogLevel.warning,
        );
        return false;
      }
      if (saved && ref.mounted) {
        state = records;
      }
      return saved;
    });
  }
}

/// The node the legacy shared login went to; seeded with the node records.
@Riverpod(keepAlive: true)
class TailscaleLegacyMigrated extends _$TailscaleLegacyMigrated
    with AutoDisposeNotifierMixin {
  @override
  TailscaleLegacyMigration? build() => null;

  Future<bool> save(TailscaleLegacyMigration migration) async {
    final bool saved;
    try {
      saved = await preferences.saveTailscaleLegacyMigration(migration);
    } catch (error) {
      commonPrint.log(
        'saveTailscaleLegacyMigration error $error',
        logLevel: LogLevel.warning,
      );
      return false;
    }
    if (saved && ref.mounted) {
      state = migration;
    }
    return saved;
  }
}

@Riverpod(keepAlive: true)
class TailscaleLegacyStates extends _$TailscaleLegacyStates
    with AutoDisposeNotifierMixin {
  @override
  Map<TailscaleNodeKey, TailscaleLegacyState> build() => const {};

  TailscaleLegacyState of(TailscaleNodeKey key) =>
      state[key] ?? const TailscaleLegacyState();

  void change(
    TailscaleNodeKey key,
    TailscaleLegacyState Function(TailscaleLegacyState state) update,
  ) {
    final next = update(of(key));
    if (next != of(key)) {
      value = {...state, key: next};
    }
  }
}

/// The panel's view of each node, by node key, so a result lands on the node
/// that asked for it whichever one the page shows by then.
@Riverpod(keepAlive: true)
class TailscalePanelNodes extends _$TailscalePanelNodes
    with AutoDisposeNotifierMixin {
  @override
  Map<TailscaleNodeKey, TailscalePanelNode> build() => const {};

  TailscalePanelNode of(TailscaleNodeKey key) =>
      state[key] ?? const TailscalePanelNode();

  void change(
    TailscaleNodeKey key,
    TailscalePanelNode Function(TailscalePanelNode state) update,
  ) {
    final next = update(of(key));
    if (next != of(key)) {
      value = {...state, key: next};
    }
  }
}

@riverpod
TailscaleSetup? tailscaleSetup(Ref ref) {
  final profile = ref.watch(
    currentProfileProvider.select(
      (profile) =>
          profile == null ? null : (id: profile.id, type: profile.type),
    ),
  );
  if (profile == null) {
    return null;
  }
  final records = ref.watch(tailscaleNodeRecordsProvider);
  final legacyMigration = ref.watch(tailscaleLegacyMigratedProvider);
  return TailscaleSetup(
    legacyMigration: legacyMigration,
    profileId: profile.id,
    configSource: profile.type == ProfileType.url
        ? TailscaleSettingSource.subscription
        : TailscaleSettingSource.profile,
    nodes: [
      for (final record in records)
        if (record.profileId == profile.id) record.setup,
    ],
  );
}

@riverpod
class TailscaleNodes extends _$TailscaleNodes {
  @override
  Future<List<TailscaleNode>> build() {
    return ref.read(coreHandlerProvider).getTailscaleNodes();
  }

  /// A node of another instance means the config was applied again.
  void applyEvent(TailscaleStateEvent event) {
    final nodes = state.value;
    if (nodes == null) {
      return;
    }
    final node = nodes.firstWhereOrNull((node) => node.name == event.name);
    if (node == null || node.generation != event.generation) {
      ref.invalidateSelf();
      return;
    }
    put(node.copyWith(backendState: event.state));
  }

  void put(TailscaleNode node) {
    final nodes = state.value;
    if (nodes == null) {
      return;
    }
    state = AsyncData([
      for (final item in nodes) item.name == node.name ? node : item,
    ]);
  }
}

/// By node name; an event of another generation is not about the node read.
@Riverpod(keepAlive: true)
class TailscaleStateEvents extends _$TailscaleStateEvents
    with AutoDisposeNotifierMixin {
  @override
  Map<String, TailscaleStateEvent> build() => const {};

  void add(TailscaleStateEvent event) {
    value = {...state, event.name: event};
  }
}
