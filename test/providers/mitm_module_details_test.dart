import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/mitm.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockCoreHandlerInterface extends Mock implements CoreHandlerInterface {}

void main() {
  setUpAll(() {
    loadAppLocalizations(const Locale('en'));
    registerFallbackValue(const MitmRules());
  });

  test('the details name the hostnames the Core would skip', () async {
    final core = _MockCoreHandlerInterface();
    // The Core is not running: only the app's own check speaks.
    when(() => core.validateMitm(any())).thenAnswer((_) async => {});
    final container = ProviderContainer(
      overrides: [
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        mitmModuleContentProvider(1).overrideWith(
          (ref) async => parseMitmModule('''
[MITM]
hostname = %APPEND% a.com:443, b.com:8443, api*.c.com, d.com
'''),
        ),
      ],
    );
    addTearDown(container.dispose);

    final details = await container.read(mitmModuleDetailsProvider(1).future);

    expect(details!.issues[MitmList.hostname], {
      'b.com:8443': currentAppLocalizations.mitmHostIgnored,
      'api*.c.com': currentAppLocalizations.mitmHostIgnored,
    });
    // What the Core is asked to check is what it is sent.
    final rules =
        verify(() => core.validateMitm(captureAny())).captured.single
            as MitmRules;
    expect(rules.hostname, ['a.com', 'b.com:8443', 'api*.c.com', 'd.com']);
  });
}
