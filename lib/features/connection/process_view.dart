import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rebuilds as the Mac answers which app [metadata]'s process belongs to.
class ConnectionProcessBuilder extends StatelessWidget {
  final Metadata metadata;
  final Widget Function(BuildContext context, ConnectionProcess process)
  builder;

  const ConnectionProcessBuilder({
    super.key,
    required this.metadata,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: processApps,
      builder: (context, _) =>
          builder(context, processApps.processOf(metadata)),
    );
  }
}

/// A source's own icon, else a glyph, else the Mac's generic app icon.
class ProcessIcon extends StatelessWidget {
  final ConnectionProcess process;
  final double size;

  /// Whether an unrecognized process keeps the icon's room, empty, so rows
  /// stay aligned; otherwise it takes none. It never shows a placeholder.
  final bool keepsRoom;

  const ProcessIcon({
    super.key,
    required this.process,
    required this.size,
    this.keepsRoom = true,
  });

  @override
  Widget build(BuildContext context) {
    if (process.kind == ProcessKind.unknown) {
      return keepsRoom
          ? SizedBox.square(dimension: size)
          : const SizedBox.shrink();
    }
    if (process.kind == ProcessKind.otherDevice) {
      return _well(context, AppGlyphs.devices);
    }
    final app = process.app;
    final service = process.service;
    final icon = app != null
        ? processApps.iconOf(app)
        : service != null
        ? processApps.serviceIconOf(service)
        : null;
    Widget child;
    if (icon != null) {
      child = _image(icon);
    } else if (app?.isCore ?? false) {
      child = Image.asset('assets/images/icon.png', width: size, height: size);
    } else if (service != null && !process.pending) {
      final glyph = serviceGlyphOf(service.service);
      child = size < 20
          ? GlyphIcon(
              glyph,
              size: size,
              color: context.colorScheme.onSurfaceVariant,
            )
          : _well(context, glyph);
    } else if (app == null && !process.pending) {
      child = _well(context, AppGlyphs.terminal);
    } else {
      final generic = processApps.genericIcon;
      if (generic == null) {
        return keepsRoom
            ? SizedBox.square(dimension: size)
            : const SizedBox.shrink();
      }
      child = _image(generic);
    }
    if (size < 20 || app == null || (!app.isHelper && !app.isCore)) {
      return child;
    }
    final badgeSize = size >= 32 ? 14.0 : 12.0;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              key: const ValueKey('process-kind-badge'),
              width: badgeSize,
              height: badgeSize,
              decoration: const ShapeDecoration(
                color: Color(0xFF8E8C94),
                shape: AppShape.circle,
              ),
              child: GlyphIcon(
                app.isCore ? AppGlyphs.helperDaemonSmall : AppGlyphs.settings,
                size: badgeSize - 2,
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _image(ImageProvider icon) => Image(
    image: icon,
    width: size,
    height: size,
    gaplessPlayback: true,
    filterQuality: FilterQuality.medium,
    excludeFromSemantics: true,
  );

  Widget _well(BuildContext context, Glyph glyph) =>
      ProcessGlyphWell(glyph: glyph, size: size);
}

/// A glyph in an inset well, where a source has no icon of its own.
class ProcessGlyphWell extends StatelessWidget {
  final Glyph glyph;
  final double size;

  const ProcessGlyphWell({super.key, required this.glyph, required this.size});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: SurfaceLevel.inset.colorOf(colorScheme),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(size / 4),
        ),
      ),
      child: GlyphIcon(
        glyph,
        size: size * 2 / 3,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A shared service by what it does, a feature without an icon by settings.
Glyph serviceGlyphOf(SystemService service) => switch (service) {
  SystemService.backgroundDownloads ||
  SystemService.systemAssets => AppGlyphs.cloudDownload,
  SystemService.nameResolution => AppGlyphs.dns,
  SystemService.certificateChecks ||
  SystemService.appSecurity => AppGlyphs.lock,
  SystemService.webContent => AppGlyphs.language,
  SystemService.networkProxy => AppGlyphs.vpn,
  SystemService.location => AppGlyphs.locate,
  SystemService.continuity => AppGlyphs.devices,
  SystemService.captivePortal => AppGlyphs.wifi,
  _ => AppGlyphs.settings,
};

/// What a row names a connection's source by.
String processLabelOf(ConnectionProcess process) => switch (process.kind) {
  ProcessKind.app =>
    process.app!.isCore
        ? currentAppLocalizations.processCoreLabel(process.app!.name)
        : process.app!.isHelper
        ? currentAppLocalizations.processHelperLabel(process.app!.name)
        : process.label,
  ProcessKind.process => process.service?.service.label ?? process.label,
  ProcessKind.unknown => currentAppLocalizations.unknownProcess,
  ProcessKind.otherDevice => currentAppLocalizations.otherDevice,
};

/// The leading icon of a row, which filters the list by the process.
class ProcessFilterIcon extends StatelessWidget {
  final ConnectionProcess process;
  final double size;

  final double? targetHeight;

  const ProcessFilterIcon({
    super.key,
    required this.process,
    required this.size,
    this.targetHeight,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final tooltip = process.kind == ProcessKind.app
        ? appLocalizations.filterByThisApp
        : appLocalizations.filterByThisProcess;
    final named =
        process.service != null ||
        (process.app?.launchdLabel.isNotEmpty ?? false);
    return Tooltip(
      message: named ? '$tooltip\n${process.name}' : tooltip,
      child: Semantics(
        button: true,
        label: '$tooltip ${processLabelOf(process)}',
        // The room an unrecognized process leaves empty still filters.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => RecordFilterScope.add(
            context,
            RecordFilter(RecordFacetKind.app, process.key),
          ),
          child: SizedBox(
            height: targetHeight,
            child: Center(
              widthFactor: 1,
              heightFactor: targetHeight == null ? 1 : null,
              child: ProcessIcon(process: process, size: size),
            ),
          ),
        ),
      ),
    );
  }
}

/// The table's process cell: a small icon and the app or process name, the
/// full process and path on hover.
class ProcessCell extends StatelessWidget {
  final Metadata metadata;

  const ProcessCell({super.key, required this.metadata});

  @override
  Widget build(BuildContext context) {
    return ConnectionProcessBuilder(
      metadata: metadata,
      builder: (context, process) {
        final text = Text(
          processLabelOf(process),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: process.hasProcess
              ? null
              : TextStyle(color: context.colorScheme.onSurfaceVariant),
        );
        if (!process.hasProcess) {
          return Row(
            spacing: 6,
            children: [
              ProcessIcon(process: process, size: 16),
              Flexible(child: text),
            ],
          );
        }
        return Tooltip(
          message: [
            process.name,
            if (process.path.isNotEmpty) process.path,
          ].join('\n'),
          child: Row(
            spacing: 6,
            children: [
              ProcessIcon(process: process, size: 16),
              Flexible(child: text),
            ],
          ),
        );
      },
    );
  }
}

/// The 应用 / 进程 / 进程路径 rows of a connection's detail.
List<Widget> processDetailRows(
  BuildContext context,
  ConnectionProcess process,
) {
  final appLocalizations = context.appLocalizations;
  final app = process.app;
  switch (process.kind) {
    case ProcessKind.unknown:
      return [
        _ReasonRow(
          title: appLocalizations.process,
          value: appLocalizations.unknown,
          reason: appLocalizations.processInfoUnavailable,
        ),
      ];
    case ProcessKind.otherDevice:
      return [
        _ReasonRow(
          title: appLocalizations.process,
          value: appLocalizations.processUnavailable,
          reason: appLocalizations.processFromOtherDevice,
        ),
      ];
    case ProcessKind.app || ProcessKind.process:
      return [
        if (app != null)
          _SourceRow(
            title: appLocalizations.app,
            process: process,
            value: app.name,
            reason: app.launchdLabel.isEmpty
                ? null
                : appLocalizations.appViaLaunchd(app.launchdLabel),
          ),
        if (process.service case final match?)
          _SourceRow(
            title: appLocalizations.systemService,
            process: process,
            value: match.service.label,
            reason: match.service.shared
                ? appLocalizations.systemServiceSharedHint
                : appLocalizations.systemServiceFeatureHint,
          ),
        if (process.appUnreadable)
          _ReasonRow(
            title: appLocalizations.process,
            value: process.name,
            reason: appLocalizations.appInfoUnreadable,
          )
        else
          DetailRow.text(title: appLocalizations.process, value: process.name),
        if (process.path.isNotEmpty) _PathRow(path: process.path),
      ];
  }
}

/// The app or service a process works for, and why when the path hides it.
class _SourceRow extends StatelessWidget {
  final String title;
  final ConnectionProcess process;
  final String value;
  final String? reason;

  const _SourceRow({
    required this.title,
    required this.process,
    required this.value,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final reason = this.reason;
    final app = process.app;
    final tag = app?.isCore == true
        ? context.appLocalizations.processCoreTag
        : app?.isHelper == true
        ? context.appLocalizations.processHelperTag
        : null;
    final name = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Flexible(child: Text(value)),
        if (tag != null)
          TonalChip(
            label: tag,
            color: SurfaceLevel.inset.colorOf(context.colorScheme),
            foregroundColor: context.colorScheme.onSurfaceVariant,
          ),
      ],
    );
    final label = reason == null
        ? name
        : Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 2,
            children: [
              name,
              Text(
                reason,
                textAlign: TextAlign.end,
                style: AppTextStyle.caption1
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            ],
          );
    return DetailRow(
      title: title,
      copyText: value,
      value: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          ProcessIcon(process: process, size: 32, keepsRoom: false),
          Flexible(child: label),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  final String title;
  final String value;
  final String reason;

  const _ReasonRow({
    required this.title,
    required this.value,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return DetailRow(
      title: title,
      value: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 2,
        children: [
          Text(value),
          Text(
            reason,
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

const _pathMaxLines = 3;
const _copyButtonSize = 20.0;
const _copyButtonGap = 6.0;

/// [path] with its middle cut to an ellipsis until it and a trailing
/// [trailing] box fit in [maxLines] lines of [maxWidth].
String middleEllipsisPath(
  String path, {
  required TextStyle style,
  required double maxWidth,
  int maxLines = _pathMaxLines,
  Size trailing = Size.zero,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final painter = TextPainter(
    maxLines: maxLines,
    textScaler: textScaler,
    textDirection: TextDirection.ltr,
  );
  bool fits(String text) {
    painter
      ..text = TextSpan(
        style: style,
        children: [
          TextSpan(text: text),
          const WidgetSpan(child: SizedBox.shrink()),
        ],
      )
      ..setPlaceholderDimensions([
        PlaceholderDimensions(
          size: trailing,
          alignment: PlaceholderAlignment.middle,
        ),
      ])
      ..layout(maxWidth: maxWidth);
    return !painter.didExceedMaxLines;
  }

  String keeping(int count) =>
      '${path.substring(0, (count + 1) ~/ 2)}…'
      '${path.substring(path.length - count ~/ 2)}';

  try {
    if (fits(path)) {
      return path;
    }
    var low = 0;
    var high = path.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (fits(keeping(mid))) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return keeping(low);
  } finally {
    painter.dispose();
  }
}

class _PathRow extends StatelessWidget {
  final String path;

  const _PathRow({required this.path});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!context.mounted) return;
    dialogs.showBanner(context.appLocalizations.copySuccess);
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final style = AppTextStyle.caption1
        .of(context)
        .copyWith(color: colorScheme.onSurfaceVariant);
    const trailing = Size(_copyButtonSize + _copyButtonGap, _copyButtonSize);
    final copy = Padding(
      padding: const EdgeInsets.only(left: _copyButtonGap),
      child: SizedBox.square(
        dimension: _copyButtonSize,
        child: IconButton(
          tooltip: appLocalizations.copyPath,
          padding: EdgeInsets.zero,
          style: ButtonStyle.from(
            minimumSize: const Size.square(_copyButtonSize),
            fixedSize: const Size.square(_copyButtonSize),
            tapTargetSize: TapTargetSize.shrinkWrap,
          ),
          onPressed: () => _copy(context),
          icon: const GlyphIcon(AppGlyphs.copy, size: 14),
        ),
      ),
    );
    return DetailRow(
      title: appLocalizations.processPath,
      value: LayoutBuilder(
        builder: (context, constraints) {
          final shown = middleEllipsisPath(
            path,
            style: style,
            maxWidth: constraints.maxWidth,
            trailing: trailing,
            textScaler: MediaQuery.textScalerOf(context),
          );
          return Tooltip(
            message: path,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: shown),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: copy,
                  ),
                ],
              ),
              style: style,
              textAlign: TextAlign.start,
              maxLines: _pathMaxLines,
            ),
          );
        },
      ),
    );
  }
}

/// One quiet line over the requests when the running Core has process
/// lookup off and none of [visible] carries process info.
class ProcessLookupOffNotice extends ConsumerWidget {
  final List<TrackerInfo> visible;
  final Widget child;

  const ProcessLookupOffNotice({
    super.key,
    required this.visible,
    required this.child,
  });

  static bool showsFor(String? runningMode, List<TrackerInfo> visible) =>
      runningMode == 'off' &&
      visible.isNotEmpty &&
      visible.every(
        (info) =>
            info.metadata.process.trim().isEmpty &&
            info.metadata.processPath.trim().isEmpty,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = system.isAndroid
        ? null
        : ref.watch(runningFindProcessModeProvider);
    if (!showsFor(mode, visible)) {
      return child;
    }
    return Padding(
      padding: EdgeInsets.only(top: context.contentTopPadding),
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: FloatingBarScope(
          inset: 0,
          child: TopInsetScope(
            inset: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    context.appLocalizations.processLookupDisabled,
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
