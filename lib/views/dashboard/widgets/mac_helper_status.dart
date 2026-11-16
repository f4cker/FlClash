import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/desktop/macos_helper_client.dart';
import 'package:fl_clash/core/desktop/macos_helper_maintenance.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/config/macos_helper.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Places the single "Helper" card above the dashboard. The card switches its
/// content by state and collapses to one line once the helper is ready.
class MacHelperStatus extends ConsumerWidget {
  final Widget child;
  final MacHelperMaintenance? maintenance;

  const MacHelperStatus({super.key, required this.child, this.maintenance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow =
        maintenance ??
        (system.isMacOS && macosManagedHelperBuild
            ? macHelperMaintenance
            : null);
    if (flow == null || ref.watch(safeModeProvider)) return child;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, context.contentTopPadding, 16, 0),
            // Large text or a long failure detail scrolls inside the card
            // instead of pushing the dashboard out of the window.
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: constraints.maxHeight.isFinite
                    ? constraints.maxHeight * 0.6
                    : double.infinity,
              ),
              child: SingleChildScrollView(
                child: MacHelperCard(maintenance: flow),
              ),
            ),
          ),
          Expanded(child: TopInsetScope(inset: 12, child: child)),
        ],
      ),
    );
  }
}
