import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' show join;

class Request {
  late final Dio dio;
  late final Dio _clashDio;

  /// Refuses an untrusted certificate even with the certificate check turned
  /// off, because what it fetches is installed, on Windows as administrator.
  @visibleForTesting
  late final Dio releaseDio;
  String? userAgent;

  ProviderReader? _read;

  void attach(ProviderReader read) {
    _read = read;
  }

  Request() {
    dio = Dio(BaseOptions(headers: {'User-Agent': browserUa}));
    _clashDio = Dio();
    _clashDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (Uri uri) {
          client.userAgent = globalState.ua;
          return _findProxy(uri);
        };
        return client;
      },
    );
    releaseDio = Dio(BaseOptions(headers: {'User-Agent': browserUa}));
    releaseDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        return HttpClient()
          ..badCertificateCallback = ((_, _, _) => false)
          ..findProxy = _findProxy;
      },
    );
  }

  String _findProxy(Uri uri) {
    final read = _read;
    if (read == null) {
      return 'DIRECT';
    }
    return FlClashHttpOverrides.findProxyForReader(read, uri);
  }

  Future<Response<T>> _download<T>(String url, ResponseType responseType) {
    final target = downloadTarget(url);
    final cancelToken = CancelToken();
    return _clashDio
        .getUri<T>(
          target.uri,
          options: Options(responseType: responseType, headers: target.headers),
          cancelToken: cancelToken,
        )
        .timeout(
          downloadTimeoutDuration,
          onTimeout: () {
            cancelToken.cancel();
            throw DioException.receiveTimeout(
              timeout: downloadTimeoutDuration,
              requestOptions: RequestOptions(path: url),
            );
          },
        );
  }

  Future<Response<Uint8List>> getFileResponseForUrl(String url) async {
    try {
      return await _download<Uint8List>(url, ResponseType.bytes);
    } catch (e) {
      commonPrint.log(
        'getFileResponseForUrl error ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
      rethrow;
    }
  }

  Future<Response<String>> getTextResponseForUrl(String url) async {
    try {
      return await _download<String>(url, ResponseType.plain);
    } catch (e) {
      commonPrint.log(
        'getTextResponseForUrl error ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
      rethrow;
    }
  }

  Future<UpdateCheck> checkForUpdate({
    required String version,
    required String? assetSuffix,
  }) async {
    try {
      final release = await latestRelease();
      if (release == null) return const UpdateNoRelease();
      final tag = release['tag_name'] as String;
      if (assetSuffix != null &&
          !await _hasReleaseAsset(
            release,
            tag,
            releaseAssetName(tag, assetSuffix),
          )) {
        return const UpdateNoRelease();
      }
      return compareVersions(tag.replaceAll('v', ''), version) > 0
          ? UpdateAvailable(release)
          : const UpdateUpToDate();
    } catch (error) {
      commonPrint.log(
        'checkForUpdate failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return UpdateCheckFailed(error);
    }
  }

  /// The signed manifest at [url]; any HTTPS host, following redirects.
  Future<UpdateCheck> checkForMacUpdate({
    required int? installedBuild,
    required String? arch,
    String url = macUpdateManifestUrl,
    Iterable<String> publicKeys = macUpdatePublicKeys,
  }) async {
    try {
      if (!macUpdateKeysPinned(publicKeys)) {
        throw const MacUpdateManifestException(
          MacUpdateRejection.notConfigured,
        );
      }
      if (installedBuild == null || arch == null) {
        throw StateError('No build number or architecture to update from');
      }
      final response = await _getHttps<List<int>>(
        Uri.parse(url),
        ResponseType.bytes,
      );
      final manifest = openMacUpdateManifest(
        response.data ?? const [],
        publicKeys: publicKeys,
      );
      if (manifest.assetFor(arch) == null) return const UpdateNoRelease();
      if (!macUpdateIsNewer(manifest, installedBuild)) {
        return const UpdateUpToDate();
      }
      return UpdateAvailable({
        'tag_name': manifest.tag,
        'body': manifest.notes,
      }, manifest: manifest);
    } catch (error) {
      commonPrint.log(
        'checkForMacUpdate failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      return UpdateCheckFailed(error);
    }
  }

  /// Downloads [asset] into [directory] and keeps it only when its size and
  /// SHA-256 are the ones the signed manifest names.
  Future<String> downloadMacUpdate({
    required MacUpdateAsset asset,
    required String directory,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final path = join(directory, asset.name);
    final response = await _getHttps<ResponseBody>(
      asset.url,
      ResponseType.stream,
      cancelToken: cancelToken,
    );
    final file = File(path).openWrite();
    var received = 0;
    try {
      try {
        await for (final chunk in response.data!.stream) {
          received += chunk.length;
          if (received > asset.size) {
            throw ReleaseNotVerifiedException(asset.name);
          }
          file.add(chunk);
          onReceiveProgress?.call(received, asset.size);
        }
      } finally {
        await file.close();
      }
      if (received != asset.size || await fileSha256(path) != asset.sha256) {
        throw ReleaseNotVerifiedException(asset.name);
      }
    } catch (_) {
      await safeDeletePath(path);
      rethrow;
    }
    return path;
  }

  Future<Response<T>> _getHttps<T>(
    Uri uri,
    ResponseType responseType, {
    CancelToken? cancelToken,
  }) async {
    var target = uri;
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      if (target.scheme != 'https' || target.host.isEmpty) {
        throw const MacUpdateManifestException(MacUpdateRejection.insecureUrl);
      }
      final response = await releaseDio.getUri<T>(
        target,
        options: Options(
          responseType: responseType,
          followRedirects: false,
          validateStatus: (status) =>
              status == HttpStatus.ok || _redirect(status),
        ),
        cancelToken: cancelToken,
      );
      if (!_redirect(response.statusCode)) return response;
      if (response.data case final ResponseBody body) {
        await body.stream.drain<void>();
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null) {
        throw const FormatException('A redirect without a location');
      }
      target = target.resolve(location);
    }
    throw const FormatException('Too many redirects');
  }

  static const _maxRedirects = 10;

  static bool _redirect(int? status) => const {
    HttpStatus.movedPermanently,
    HttpStatus.found,
    HttpStatus.seeOther,
    HttpStatus.temporaryRedirect,
    HttpStatus.permanentRedirect,
  }.contains(status);

  /// Null when nothing is published; the page answers past the API quota.
  Future<Map<String, dynamic>?> latestRelease() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/$updateRepository/releases/latest',
        options: Options(responseType: ResponseType.json),
      );
      return response.data!;
    } on DioException catch (error) {
      if (error.response?.statusCode == HttpStatus.notFound) return null;
      commonPrint.log(
        'latest release API failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
    }
    final response = await dio.get<void>(
      'https://github.com/$updateRepository/releases/latest',
      options: Options(followRedirects: false, validateStatus: _answered),
    );
    if (response.statusCode == HttpStatus.notFound) return null;
    final location = response.headers.value(HttpHeaders.locationHeader);
    if (location == null) {
      throw const FormatException('The release page did not redirect');
    }
    final segments = Uri.tryParse(location)?.pathSegments ?? const [];
    final tagIndex = segments.indexOf('tag') + 1;
    // With nothing published GitHub redirects to the release list instead.
    if (tagIndex == 0 || tagIndex >= segments.length) return null;
    return {'tag_name': segments[tagIndex]};
  }

  static bool _answered(int? status) =>
      status != null && (status < 400 || status == HttpStatus.notFound);

  Future<bool> _hasReleaseAsset(
    Map<String, dynamic> release,
    String tag,
    String name,
  ) async {
    final assets = release['assets'];
    if (assets is List) {
      return assets.any((asset) => asset is Map && asset['name'] == name);
    }
    final response = await dio.head<void>(
      releaseAssetUri(tag, name).toString(),
      options: Options(followRedirects: false, validateStatus: _answered),
    );
    return response.statusCode != HttpStatus.notFound;
  }

  Future<String> downloadVerifiedRelease({
    required String tag,
    required String name,
    required String directory,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    final sums = await releaseDio.getUri<String>(
      releaseAssetUri(tag, updateChecksumsName(tag)),
      options: Options(responseType: ResponseType.plain),
      cancelToken: cancelToken,
    );
    final expected = releaseChecksum(sums.data ?? '', name);
    if (expected == null) {
      throw ReleaseNotVerifiedException(name);
    }
    final path = join(directory, name);
    final uri = releaseAssetUri(tag, name);
    if (app case final android?) {
      await android.downloadFile(
        uri,
        path,
        title: name,
        onReceiveProgress: onReceiveProgress ?? (_, _) {},
        cancelToken: cancelToken ?? CancelToken(),
      );
    } else {
      await releaseDio.downloadUri(
        uri,
        path,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
      );
    }
    if (await fileSha256(path) != expected) {
      throw ReleaseNotVerifiedException(name);
    }
    return path;
  }
}

final request = Request();

/// Some subscription servers send a gzip or zlib body without saying so in
/// Content-Encoding, which is the only signal dart:io decompresses on.
Uint8List decompressUnlabeled(Uint8List bytes) {
  final codec = switch (bytes) {
    [0x1f, 0x8b, ...] => gzip,
    [0x78, final flags, ...] when (0x78 << 8 | flags) % 31 == 0 => zlib,
    _ => null,
  };
  if (codec == null) {
    return bytes;
  }
  try {
    return Uint8List.fromList(codec.decode(bytes));
  } on FormatException {
    return bytes;
  }
}

/// dart:io turns [Uri.userInfo] into Basic credentials still percent-encoded.
@visibleForTesting
({Uri uri, Map<String, Object> headers}) downloadTarget(String url) {
  final uri = url.webUri ?? Uri.parse(url);
  if (uri.userInfo.isEmpty) {
    return (uri: uri, headers: const {});
  }
  final credentials = uri.userInfo.split(':').map(_decodeUserInfo).join(':');
  return (
    uri: uri.replace(userInfo: ''),
    headers: {
      HttpHeaders.authorizationHeader:
          'Basic ${base64.encode(utf8.encode(credentials))}',
    },
  );
}

String _decodeUserInfo(String value) {
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    return value;
  }
}

String? getFileNameForDisposition(String? disposition) {
  if (disposition == null) return null;
  final parseValue = HeaderValue.parse(disposition);
  final parameters = parseValue.parameters;
  final fileNamePointKey = parameters.keys.firstWhere(
    (key) => key == 'filename*',
    orElse: () => '',
  );
  if (fileNamePointKey.isNotEmpty) {
    final res = parameters[fileNamePointKey]?.split("''") ?? [];
    if (res.length >= 2) {
      return Uri.decodeComponent(res[1]);
    }
  }
  final fileNameKey = parameters.keys.firstWhere(
    (key) => key == 'filename',
    orElse: () => '',
  );
  if (fileNameKey.isEmpty) return null;
  return parameters[fileNameKey];
}
