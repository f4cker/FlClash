import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/mac_release.dart';

class HeldRelease implements HttpClientAdapter {
  final started = Completer<void>();
  final done = Completer<void>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (o.uri.path.contains('/latest/')) {
      return ResponseBody.fromString(
        jsonEncode(releasePayload(build: 2026111901)),
        200,
      );
    }
    if (o.uri.host == 'api.github.com') {
      return ResponseBody.fromString(
        jsonEncode([
          {'tag_name': 'v1.1.0-beta.1', 'draft': false, 'prerelease': true},
        ]),
        200,
      );
    }
    started.complete();
    await done.future;
    return ResponseBody.fromString(
      jsonEncode(
        releasePayload(
          channel: 'beta',
          build: 2026111903,
          version: '1.1.0-beta.1',
        ),
      ),
      200,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'late opted-in response cannot restore beta after switch closes',
    () async {
      final adapter = HeldRelease();
      final request = Request(openMacManifest: fakeAuthenticatedManifest)
        ..releaseDio.httpClientAdapter = adapter;
      globalState.packageInfo = PackageInfo(
        appName: 'Flash',
        packageName: packageName,
        version: '0.9.15-mitm.12',
        buildNumber: '2026111901',
      );
      final container = ProviderContainer(
        overrides: [
          appUpdateRequestProvider.overrideWithValue(request),
          installedMacReleaseProvider.overrideWith(
            (ref) async => const MacInstalledIdentity(
              version: '0.9.15-mitm.12',
              build: 2026111901,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(availableUpdateStateProvider, (_, _) {});
      container.listen(lastUpdateCheckStateProvider, (_, _) {});
      final action = container.read(commonActionProvider.notifier);
      container
          .read(appSettingProvider.notifier)
          .update((s) => s.copyWith(receiveBetaUpdates: true));
      final pending = action.checkForAppUpdate();
      await adapter.started.future;
      container
          .read(appSettingProvider.notifier)
          .update((s) => s.copyWith(receiveBetaUpdates: false));
      adapter.done.complete();
      expect(await pending, isA<UpdateCheckSuperseded>());
      expect(container.read(availableUpdateStateProvider), isNull);
      expect(container.read(lastUpdateCheckStateProvider), isNull);
    },
  );
  test(
    'policy revokes beta but preserves confirmed stable and installed identity',
    () async {
      const installed = MacInstalledIdentity(
        version: '1.1.0-beta.1',
        build: 2026111903,
        channel: ReleaseChannel.beta,
      );
      final container = ProviderContainer(
        overrides: [
          installedMacReleaseProvider.overrideWith((ref) async => installed),
        ],
      );
      addTearDown(container.dispose);
      container.listen(availableUpdateStateProvider, (_, _) {});
      container.read(commonActionProvider.notifier);
      await container.read(installedMacReleaseProvider.future);
      for (final channel in ['stable', 'beta']) {
        container
            .read(appSettingProvider.notifier)
            .update((s) => s.copyWith(receiveBetaUpdates: true));
        final manifest = releaseManifest(
          channel: channel,
          build: 2026111904,
          version: '1.2.0',
        );
        final candidate = UpdateAvailable({
          'tag_name': manifest.tag,
        }, manifest: manifest);
        container.read(availableUpdateStateProvider.notifier).value = candidate;
        container
            .read(appSettingProvider.notifier)
            .update((s) => s.copyWith(receiveBetaUpdates: false));
        expect(
          container.read(availableUpdateStateProvider),
          channel == 'beta' ? null : same(candidate),
        );
        expect(
          container.read(installedMacReleaseProvider).value?.channel,
          ReleaseChannel.beta,
        );
      }
    },
  );
}
