import 'package:fl_clash/common/app_ports.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records whether the sidebar was asked to show the rules item.
class _Navigation implements NavigationPort {
  bool? showRules;

  @override
  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
    bool showRules = false,
  }) {
    this.showRules = showRules;
    return const [];
  }
}

void main() {
  late _Navigation navigation;
  late ProviderContainer container;

  setUp(() {
    navigation = _Navigation();
    navigationPort = navigation;
    const profile = Profile(id: 1, autoUpdateDuration: Duration.zero);
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWithValue([profile]),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    navigationPort = null;
  });

  bool? shown() {
    container.read(navigationItemsStateProvider);
    return navigation.showRules;
  }

  test('the rules item stays while open after the Core stops, and goes once '
      'the page is left', () {
    container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
    expect(shown(), isTrue);

    container.read(currentPageLabelProvider.notifier).toPage(PageLabel.rules);
    container.read(coreStatusProvider.notifier).value = CoreStatus.disconnected;
    expect(shown(), isTrue);

    container
        .read(currentPageLabelProvider.notifier)
        .toPage(PageLabel.dashboard);
    expect(shown(), isFalse);
  });
}
