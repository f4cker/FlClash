import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

import 'mount.dart';

typedef MountDeletion = ({
  MountSourceDeletion result,
  TailscaleUnlinkOutcome? unlink,
});

/// The names of [targets] as the delete dialog lists them: a name two
/// profiles share gets the kind of profile and, if that still matches, its
/// place among them.
List<String> mountTargetNames(
  List<Profile> targets,
  AppLocalizations appLocalizations,
) {
  String kind(Profile profile) => switch (profile.type) {
    ProfileType.url => appLocalizations.remote,
    ProfileType.file => appLocalizations.local,
    ProfileType.custom => appLocalizations.custom,
  };
  final byName = <String, int>{};
  final byKind = <String, int>{};
  for (final profile in targets) {
    byName.update(profile.realLabel, (n) => n + 1, ifAbsent: () => 1);
    byKind.update(
      '${profile.realLabel}\u0000${kind(profile)}',
      (n) => n + 1,
      ifAbsent: () => 1,
    );
  }
  final seen = <String, int>{};
  return [
    for (final profile in targets)
      if (byName[profile.realLabel] == 1)
        profile.realLabel
      else if (byKind['${profile.realLabel}\u0000${kind(profile)}'] == 1)
        '${profile.realLabel} · ${kind(profile)}'
      else
        '${profile.realLabel} · ${kind(profile)} · ${seen.update('${profile.realLabel}\u0000${kind(profile)}', (n) => n + 1, ifAbsent: () => 1)}',
  ];
}

/// The delete dialog of a source mounted somewhere, design §10.4 with §11:
/// it confirms, unmounts and deletes, and holds while an outcome is
/// unknown. Null when the user leaves before anything is deleted.
Future<MountDeletion?> showMountDeleteDialog(
  BuildContext context, {
  required Profile source,
  required List<Profile> targets,
  required int managed,
  required MountAction mounts,
}) {
  return dialogs.showCommonDialog<MountDeletion>(
    context: context,
    dismissible: false,
    child: _MountDeleteDialog(
      source: source,
      targets: targets,
      managed: managed,
      mounts: mounts,
    ),
  );
}

enum _Phase { checking, confirm, pending, deleting, unknown }

class _MountDeleteDialog extends StatefulWidget {
  const _MountDeleteDialog({
    required this.source,
    required this.targets,
    required this.managed,
    required this.mounts,
  });

  final Profile source;
  final List<Profile> targets;
  final int managed;
  final MountAction mounts;

  @override
  State<_MountDeleteDialog> createState() => _MountDeleteDialogState();
}

class _MountDeleteDialogState extends State<_MountDeleteDialog> {
  var _phase = _Phase.checking;
  var _rechecking = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final pending = await widget.mounts.hasPendingRemoval(widget.source.id);
    if (mounted) {
      setState(() => _phase = pending ? _Phase.pending : _Phase.confirm);
    }
  }

  Future<void> _delete() async {
    setState(() => _phase = _Phase.deleting);
    final deletion = await widget.mounts.deleteSource(widget.source.id);
    if (!mounted) {
      return;
    }
    switch (deletion.result) {
      case MountSourceDeletion.unknown:
        setState(() => _phase = _Phase.unknown);
      case MountSourceDeletion.blocked || MountSourceDeletion.unchanged:
        setState(() => _phase = _Phase.pending);
      case MountSourceDeletion.deleted || MountSourceDeletion.keptProfile:
        Navigator.of(context).pop(deletion);
    }
  }

  /// Reads every affected target back; only a resolved readback unlocks.
  Future<void> _recheck() async {
    setState(() => _rechecking = true);
    var resolved = true;
    for (final target in widget.targets) {
      final result = await widget.mounts.recheck(target.id);
      resolved &= result.outcome != MountSaveOutcome.unknown;
    }
    if (!mounted) {
      return;
    }
    if (!resolved) {
      setState(() => _rechecking = false);
      return;
    }
    final pending = await widget.mounts.hasPendingRemoval(widget.source.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _rechecking = false;
      _phase = pending ? _Phase.pending : _Phase.confirm;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final busy = _phase == _Phase.deleting || _rechecking;
    final locked = _phase == _Phase.unknown;
    final captionStyle = AppTextStyle.caption1
        .of(context, emphasized: true)
        .copyWith(color: colorScheme.error);
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: appLocalizations.mountDeleteSourceTitle,
        destructive: !locked,
        width: 420,
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(),
            child: Text(
              locked ? appLocalizations.close : appLocalizations.cancel,
            ),
          ),
          // Keyed by phase: a pressed button is replaced, never disabled in
          // place.
          if (locked)
            TextButton(
              key: ValueKey((_phase, _rechecking)),
              onPressed: busy ? null : _recheck,
              child: Text(appLocalizations.mountReadStatus),
            )
          else
            TextButton(
              key: ValueKey(_phase),
              onPressed: _phase == _Phase.confirm ? _delete : null,
              child: Text(appLocalizations.mountDeleteSourceConfirm),
            ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            if (_phase == _Phase.deleting)
              MountBanner(
                level: MountBannerLevel.info,
                lines: [appLocalizations.mountDeleteSourceProgress],
              ),
            if (locked)
              MountBanner(
                level: MountBannerLevel.error,
                lines: [appLocalizations.mountDeleteSourceUnknown],
              ),
            Text(
              appLocalizations.mountDeleteSourceBody(
                widget.source.realLabel,
                widget.targets.length,
              ),
            ),
            MountNameList(
              names: mountTargetNames(widget.targets, appLocalizations),
            ),
            if (widget.managed > 0)
              Text(appLocalizations.tsDeleteProfileManaged(widget.managed)),
            if (_phase == _Phase.pending) ...[
              Text(
                appLocalizations.mountDeleteSourceBlocked,
                style: captionStyle,
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TonalButton(
                  key: ValueKey(_rechecking),
                  size: TonalButtonSize.compact,
                  glyph: AppGlyphs.sync,
                  label: appLocalizations.mountReadStatus,
                  onPressed: busy ? null : _recheck,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
