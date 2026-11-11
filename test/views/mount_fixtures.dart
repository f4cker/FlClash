import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/widgets.dart';

typedef SaveCall = ({int? version, List<int> sources, List<String> groups});

class FakeMounts extends MountAction {
  FakeMounts(this.panel);

  MountPanel? panel;
  Error? loadError;
  MountRuntimeState? runtime;
  MountSaveResult saveResult = const MountSaveResult(
    outcome: MountSaveOutcome.applied,
  );
  MountSaveOutcome recheckOutcome = MountSaveOutcome.unknown;
  MountSourceRefresh? refreshResult;
  Completer<void>? saveGate;
  final saves = <SaveCall>[];
  final refreshed = <int>[];
  var loads = 0;
  var rechecks = 0;
  List<Profile> targets = const [];
  bool pending = false;
  List<MountSourceDeletion> deletions = const [];
  final deleted = <int>[];

  @override
  Future<List<Profile>> sourceTargets(int sourceId) async => targets;

  @override
  Future<bool> hasPendingRemoval(int sourceId) async => pending;

  @override
  Future<({MountSourceDeletion result, TailscaleUnlinkOutcome? unlink})>
  deleteSource(int sourceId) async {
    deleted.add(sourceId);
    return (
      result: deletions.isEmpty
          ? MountSourceDeletion.deleted
          : deletions[(deleted.length - 1).clamp(0, deletions.length - 1)],
      unlink: null,
    );
  }

  @override
  Future<MountPanel> loadPanel(int targetId) async {
    loads++;
    if (loadError case final error?) {
      throw error;
    }
    return panel!;
  }

  @override
  Future<MountRuntimeState?> readRuntime(int targetId) async => runtime;

  @override
  Future<MountSaveResult> save(
    int targetId, {
    required int? expectedVersion,
    required List<int> sourceIds,
    required List<String> groups,
    VoidCallback? onStored,
  }) async {
    saves.add((version: expectedVersion, sources: sourceIds, groups: groups));
    onStored?.call();
    await saveGate?.future;
    return saveResult;
  }

  @override
  Future<MountSaveResult> recheck(int targetId) async {
    rechecks++;
    return MountSaveResult(outcome: recheckOutcome);
  }

  @override
  Future<MountSourceRefresh> refreshSource(
    int sourceId, {
    int? targetId,
  }) async {
    refreshed.add(sourceId);
    return refreshResult ?? const MountSourceRefresh(updated: true);
  }
}

final target = Profile.normal(label: 'Home');
final updated = DateTime.now().subtract(const Duration(minutes: 5));
Profile sub(String label) => Profile.normal(
  label: label,
  url: 'https://example.com/$label',
).copyWith(lastUpdateDate: updated);

MountSourceItem item(
  Profile profile, {
  MountSourceState state = MountSourceState.nodes,
  int count = 12,
  bool mounted = false,
  MountSourceFailure? failure,
  int tailscaleExcluded = 0,
  int relayExcluded = 0,
}) => MountSourceItem(
  profile: profile,
  state: state,
  count: count,
  mounted: mounted,
  tailscaleExcluded: tailscaleExcluded,
  relayExcluded: relayExcluded,
  record: failure == null
      ? null
      : MountSourceRecord(sourceId: profile.id, failure: failure),
);

MountGroupInfo groupInfo(
  String name, {
  MountGroupKind kind = MountGroupKind.candidate,
  String type = 'select',
  MountGroupCollects? collects,
  bool filter = false,
  String? emptyFallback,
}) => MountGroupInfo(
  name: name,
  type: type,
  kind: kind,
  collects: collects,
  filter: filter,
  emptyFallback: emptyFallback,
);

MountPanel panelOf(
  List<MountSourceItem> sources, {
  MountTarget? groups = const MountTarget(),
  MountTargetState? stored,
}) => MountPanel(
  target: target,
  sources: sources,
  groups: groups,
  stored: stored,
);
