import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'config.dart';
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

/// Panel-added accounts of every profile, seeded from preferences; null when
/// the stored list could not be read, which refuses every write.
@Riverpod(keepAlive: true)
class TailscaleManagedRecords extends _$TailscaleManagedRecords
    with AutoDisposeNotifierMixin {
  final _writes = SerialTaskScheduler();

  @override
  List<TailscaleManagedRecord>? build() => const [];

  List<TailscaleManagedRecord> ofProfile(int profileId) => [
    for (final record in state ?? const <TailscaleManagedRecord>[])
      if (record.profileId == profileId) record,
  ];

  TailscaleManagedRecord? recordOf(int profileId, String id) =>
      state?.firstWhereOrNull(
        (record) => record.profileId == profileId && record.id == id,
      );

  /// [update] returns null to drop the record; the state follows the write.
  Future<bool> modify(
    List<TailscaleManagedRecord>? Function(List<TailscaleManagedRecord> records)
    update,
  ) {
    return _writes.run(() async {
      final current = state;
      if (current == null) {
        return false;
      }
      final next = update(current);
      if (next == null) {
        return false;
      }
      final bool saved;
      try {
        saved = await preferences.saveTailscaleManagedRecords(next);
      } catch (error) {
        commonPrint.log(
          'saveTailscaleManagedRecords error $error',
          logLevel: LogLevel.warning,
        );
        return false;
      }
      if (saved && ref.mounted) {
        state = next;
      }
      return saved;
    });
  }

  Future<bool> change(
    int profileId,
    String id,
    TailscaleManagedRecord Function(TailscaleManagedRecord record) update,
  ) {
    return modify((records) {
      if (!records.any((r) => r.profileId == profileId && r.id == id)) {
        return null;
      }
      return [
        for (final record in records)
          record.profileId == profileId && record.id == id
              ? update(record)
              : record,
      ];
    });
  }
}

/// The panel's view of each panel-added account, by its node key.
@Riverpod(keepAlive: true)
class TailscaleManagedPanels extends _$TailscaleManagedPanels
    with AutoDisposeNotifierMixin {
  @override
  Map<TailscaleNodeKey, TailscaleManagedPanel> build() => const {};

  TailscaleManagedPanel of(TailscaleNodeKey key) =>
      state[key] ?? const TailscaleManagedPanel();

  void change(
    TailscaleNodeKey key,
    TailscaleManagedPanel Function(TailscaleManagedPanel state) update,
  ) {
    final next = update(of(key));
    if (next != of(key)) {
      value = {...state, key: next};
    }
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
  final managed = ref.watch(tailscaleManagedRecordsProvider);
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
    managed: [
      for (final record in managed ?? const <TailscaleManagedRecord>[])
        if (record.profileId == profile.id) record.setup,
    ],
    managedUnknown: managed == null,
  );
}

/// The Core's routing for the current profile's panel-added accounts; null
/// while it has none.
@riverpod
class TailscaleRoutesReport extends _$TailscaleRoutesReport {
  @override
  Future<TailscaleRoutes?> build() async {
    final profileId = ref.watch(currentProfileIdProvider);
    if (profileId == null) {
      return null;
    }
    final managed = ref.watch(
      tailscaleManagedRecordsProvider.select(
        (records) =>
            records?.where((record) => record.profileId == profileId).length ??
            0,
      ),
    );
    if (managed == 0) {
      return null;
    }
    return ref.read(coreHandlerProvider).getTailscaleRoutes(profileId);
  }

  void put(TailscaleRoutes routes) {
    if (routes.profileId == ref.read(currentProfileIdProvider)) {
      state = AsyncData(routes);
    }
  }
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
