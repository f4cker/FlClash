import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/mitm_module.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/app.dart';
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

  group('a :443 line the Core flags', () {
    const module = '''
[MITM]
hostname = %APPEND% icloud.com:443, *.com:443, bad_host.com:443, ok.example.com:443, b.com:8443
''';
    // The Core's answer by index into what it is sent, as mitm_host.go names
    // the issues.
    Future<Map<MitmList, Map<int, String>>> coreAnswer(
      Invocation invocation,
    ) async {
      final rules = invocation.positionalArguments.single as MitmRules;
      expect(rules.hostname, [
        'icloud.com',
        '*.com',
        'bad_host.com',
        'ok.example.com',
        'b.com:8443',
      ]);
      return {
        MitmList.hostname: {
          0: 'apple-service',
          1: 'over-broad',
          2: 'invalid',
          4: 'address',
        },
      };
    }

    test('is marked on the line as written in the details', () async {
      final core = _MockCoreHandlerInterface();
      when(() => core.validateMitm(any())).thenAnswer(coreAnswer);
      final container = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          mitmModuleContentProvider(
            1,
          ).overrideWith((ref) async => parseMitmModule(module)),
        ],
      );
      addTearDown(container.dispose);

      final details = await container.read(mitmModuleDetailsProvider(1).future);
      final issues = details!.issues[MitmList.hostname]!;
      expect(issues, {
        'icloud.com:443': 'apple-service',
        '*.com:443': 'over-broad',
        'bad_host.com:443': 'invalid',
        'b.com:8443': currentAppLocalizations.mitmHostIgnored,
      });
      // What the module view counts as invalid of the lines it shows.
      final lines = details.content.mitm.linesOf(MitmList.hostname);
      expect(lines.where(issues.containsKey), hasLength(4));
      expect(lines, hasLength(5));
    });

    test('is named on the import sheet as well', () async {
      final core = _MockCoreHandlerInterface();
      when(() => core.validateMitm(any())).thenAnswer(coreAnswer);
      final container = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        ],
      );
      addTearDown(container.dispose);
      final lines = parseMitmModule(module).mitm.linesOf(MitmList.hostname);

      final issues = await container.read(
        mitmModuleHostIssuesProvider(lines.join('\n')).future,
      );
      expect(issues.keys, [
        'icloud.com:443',
        '*.com:443',
        'bad_host.com:443',
        'b.com:8443',
      ]);
      expect(issues['b.com:8443'], currentAppLocalizations.mitmHostIgnored);
    });

    test('the sheet keeps the app\'s word while the Core is down', () async {
      final core = _MockCoreHandlerInterface();
      when(
        () => core.validateMitm(any()),
      ).thenAnswer((_) async => throw StateError('not running'));
      final container = ProviderContainer(
        overrides: [
          coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
          coreStatusProvider.overrideWithBuild((_, _) => CoreStatus.connected),
        ],
      );
      addTearDown(container.dispose);
      final lines = parseMitmModule(module).mitm.linesOf(MitmList.hostname);

      final issues = await container.read(
        mitmModuleHostIssuesProvider(lines.join('\n')).future,
      );
      expect(issues.keys, ['b.com:8443']);
    });
  });
}
