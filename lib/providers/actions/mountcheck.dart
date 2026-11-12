part of '../action.dart';

// Acceptance only (branch acceptance/mount-runtime): with MOUNTCHECK_SCRIPT=1
// a loopback test build runs the mount check through the calls the mount
// sheet and the runtime config viewer make, step by step, each step waiting
// for /tmp/mountcheck/go-<n> so the controller can be read in between.
const _mcA = 379076814552698880;
const _mcB = 379077068593303552;
const _mcC = 379079108367224832;

void _mc(String line) => commonPrint.log('MOUNTCHECK $line');

Future<void> _mcWait(int step) async {
  final file = File('/tmp/mountcheck/go-$step');
  _mc('wait go-$step');
  while (!await file.exists()) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
}

Future<void> _mcDump(Ref ref, String tag) async {
  final mounts = ref.read(mountActionProvider.notifier);
  final panel = await mounts.loadPanel(_mcA);
  _mc('$tag stored=${panel.stored?.sourceIds} v=${panel.stored?.version} '
      'pending=${panel.stored?.pending != null} revision=${panel.revision}');
  for (final group in panel.groups?.groups ?? const <MountGroupInfo>[]) {
    _mc('$tag group ${group.name} kind=${group.kind.name} hidden=${group.hidden} '
        'excluded=${group.excluded?.name} reason=${group.reason?.name}');
  }
  final runtime = await mounts.readRuntime(_mcA);
  final revision = panel.revision;
  _mc('$tag runtime blocked=${runtime?.blocked} '
      'report.revision=${runtime?.report?.revision} renamed=${runtime?.report?.renamed} '
      'confirm=${runtime == null || revision == null ? null : confirmMounts(runtime, revision)?.name}');
  for (final source in runtime?.sources ?? const <MountRuntimeSource>[]) {
    _mc('$tag runtime source ${source.id} present=${source.present} matches=${source.matches}');
  }
  for (final group in runtime?.groups ?? const <MountRuntimeGroup>[]) {
    _mc('$tag runtime group ${group.name} present=${group.present} '
        'members=${group.members} mounted=${group.mounted} empty=${group.empty}');
  }
  final text = await ref
      .read(setupActionProvider.notifier)
      .getProfileWithId(_mcA);
  await File('/tmp/mountcheck/viewer-$tag.yaml').writeAsString(text);
  _mc('$tag viewer bytes=${text.length} file=/tmp/mountcheck/viewer-$tag.yaml');
}

Future<void> runMountCheck(Ref ref) async {
  try {
    final mounts = ref.read(mountActionProvider.notifier);
    await _mcWait(1);
    await _mcDump(ref, 's1-legacy');

    await _mcWait(2);
    var panel = await mounts.loadPanel(_mcA);
    var result = await mounts.save(
      _mcA,
      expectedVersion: panel.stored?.version,
      sourceIds: [_mcB, _mcC],
    );
    _mc('s2 save B+C outcome=${result.outcome.name}');
    await _mcDump(ref, 's2-bc');

    await _mcWait(3);
    panel = await mounts.loadPanel(_mcA);
    result = await mounts.save(
      _mcA,
      expectedVersion: panel.stored?.version,
      sourceIds: [_mcC],
    );
    _mc('s3 unmount B outcome=${result.outcome.name}');
    await _mcDump(ref, 's3-c');

    await _mcWait(4);
    final none = await mounts.loadPanel(_mcC);
    _mc('s4 target C groups=${none.groups?.groups.map((g) => g.name).toList()}');
    result = await mounts.save(_mcC, expectedVersion: null, sourceIds: [_mcB]);
    _mc('s4 C takes B outcome=${result.outcome.name} '
        'stored=${(await mounts.loadPanel(_mcC)).stored?.sourceIds}');

    await _mcWait(5);
    panel = await mounts.loadPanel(_mcA);
    result = await mounts.save(
      _mcA,
      expectedVersion: panel.stored?.version,
      sourceIds: [_mcB, _mcC],
    );
    _mc('s5 back to B+C outcome=${result.outcome.name}');
    await _mcDump(ref, 's5-bc');
    _mc('done');
  } catch (error, stack) {
    _mc('failed $error $stack');
  }
}
