import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_clash/common/tray_icon.dart';
import 'package:fl_clash/widgets/icon.dart';
import 'package:flutter_cache_manager/file.dart' as cache_file;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _CacheManager extends Mock implements BaseCacheManager {}

class _CacheFile extends Mock implements cache_file.File {}

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">'
    '<rect width="16" height="16" fill="#12ab34"/></svg>';

String _inlineSvg(String source) =>
    'data:image/svg+xml;base64,${base64Encode(utf8.encode(source))}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _CacheManager manager;

  setUp(() {
    manager = _CacheManager();
    cacheOnlyIconManager = manager;
    readRemoteIcon = (_) =>
        throw StateError('remote icon loading is forbidden');
  });

  tearDown(() {
    cacheOnlyIconManager = null;
    readRemoteIcon = null;
  });

  test('empty, malformed and non-cache file sources return null', () async {
    for (final src in [
      '',
      ' ',
      '/tmp/icon.png',
      'file:///tmp/icon.png',
      'not a source',
      'data:image/png;base64,',
      'data:image/png;base64,%%%bad',
      'data:image/png;base64,AQID',
      'data:text/plain;base64,SGVsbG8=',
    ]) {
      expect(await readTrayIconPng(src), isNull, reason: src);
    }
    verifyZeroInteractions(manager);
  });

  test(
    'an exact-key cache miss neither downloads nor becomes permanent',
    () async {
      const src = 'https://example.com/tray-later.svg?configured=1';
      when(() => manager.getFileFromCache(src)).thenAnswer((_) async => null);
      expect(await readTrayIconPng(src), isNull);
      verify(() => manager.getFileFromCache(src)).called(1);
      verifyNoMoreInteractions(manager);

      var remoteReads = 0;
      readRemoteIcon = (_) {
        remoteReads++;
        return Stream.value(Uint8List.fromList(utf8.encode(_svg)));
      };
      await precacheTargetIcons([src]);
      final revision = targetIconCacheRevision.value;
      final first = await readTrayIconPng(src);
      final second = await readTrayIconPng(src);
      expect(first, isNotNull);
      expect(identical(first, second), isTrue);
      expect(remoteReads, 1);
      expect(targetIconCacheRevision.value, revision);
      verifyNoMoreInteractions(manager);
    },
  );

  test(
    'a stale cache file is read without refresh and keeps original colors',
    () async {
      const src = 'https://example.com/stale-exact.svg?configured=2';
      final file = _CacheFile();
      final bytes = Uint8List.fromList(utf8.encode(_svg));
      when(() => manager.getFileFromCache(src)).thenAnswer(
        (_) async => FileInfo(file, FileSource.Cache, DateTime(2000), src),
      );
      when(() => file.length()).thenAnswer((_) async => bytes.length);
      when(
        () => file.openRead(0, maxTrayIconSourceBytes + 1),
      ).thenAnswer((_) => Stream.value(bytes));

      final png = await readTrayIconPng(src);
      expect(png, isNotNull);
      await _expectColor(png!, 0x12, 0xab, 0x34);
      verify(() => manager.getFileFromCache(src)).called(1);
      verifyNoMoreInteractions(manager);
      verify(() => file.length()).called(1);
      verify(() => file.openRead(0, maxTrayIconSourceBytes + 1)).called(1);
      verifyNoMoreInteractions(file);
    },
  );

  test(
    'an oversized cache file is rejected before opening its bytes',
    () async {
      const src = 'https://example.com/too-large.png';
      final file = _CacheFile();
      when(() => manager.getFileFromCache(src)).thenAnswer(
        (_) async => FileInfo(file, FileSource.Cache, DateTime(2000), src),
      );
      when(
        () => file.length(),
      ).thenAnswer((_) async => maxTrayIconSourceBytes + 1);

      expect(await readTrayIconPng(src), isNull);
      verify(() => file.length()).called(1);
      verifyNoMoreInteractions(file);
      verify(() => manager.getFileFromCache(src)).called(1);
      verifyNoMoreInteractions(manager);
    },
  );

  test('empty, missing and growing cached files fail closed', () async {
    for (final (suffix, length, chunks) in [
      ('empty', 0, <Uint8List>[]),
      ('growing', 1, [Uint8List(maxTrayIconSourceBytes + 1)]),
    ]) {
      final src = 'https://example.com/$suffix.png';
      final file = _CacheFile();
      when(() => manager.getFileFromCache(src)).thenAnswer(
        (_) async => FileInfo(file, FileSource.Cache, DateTime(2000), src),
      );
      when(() => file.length()).thenAnswer((_) async => length);
      when(
        () => file.openRead(0, maxTrayIconSourceBytes + 1),
      ).thenAnswer((_) => Stream.fromIterable(chunks));
      expect(await readTrayIconPng(src), isNull);
    }
    const missing = 'https://example.com/unreadable.png';
    when(
      () => manager.getFileFromCache(missing),
    ).thenThrow(const FileSystemException('missing'));
    expect(await readTrayIconPng(missing), isNull);
  });

  test(
    'cache lookup admission is bounded with no waiting source queue',
    () async {
      final lookups = <Completer<FileInfo?>>[];
      when(() => manager.getFileFromCache(any())).thenAnswer((_) {
        final lookup = Completer<FileInfo?>();
        lookups.add(lookup);
        return lookup.future;
      });
      final requests = [
        for (var i = 0; i < 100; i++)
          readTrayIconPng('https://example.com/bounded-lookup-$i.svg'),
      ];
      try {
        expect(lookups, hasLength(4));
        expect(await Future.wait(requests.skip(4)), everyElement(isNull));
        for (var i = 0; i < 4; i++) {
          expect(
            identical(
              requests[i],
              readTrayIconPng('https://example.com/bounded-lookup-$i.svg'),
            ),
            isTrue,
          );
        }
        expect(lookups, hasLength(4));
      } finally {
        for (final lookup in lookups) {
          lookup.complete(null);
        }
        await Future.wait(requests);
      }
      expect(lookups, hasLength(4));
      verify(() => manager.getFileFromCache(any())).called(4);
      verifyNoMoreInteractions(manager);
    },
  );

  test(
    'slow disk reads stay bounded across repeated timed-out callers',
    () async {
      final opened = Completer<void>();
      final streams = <StreamController<List<int>>>[];
      var lookups = 0;
      var reads = 0;
      when(() => manager.getFileFromCache(any())).thenAnswer((
        invocation,
      ) async {
        lookups++;
        final src = invocation.positionalArguments.single as String;
        final stream = StreamController<List<int>>();
        streams.add(stream);
        final file = _CacheFile();
        when(() => file.length()).thenAnswer((_) async => 1);
        when(() => file.openRead(0, maxTrayIconSourceBytes + 1)).thenAnswer((
          _,
        ) {
          reads++;
          if (reads == 4) {
            opened.complete();
          }
          return stream.stream;
        });
        return FileInfo(file, FileSource.Cache, DateTime(2000), src);
      });
      final requests = [
        for (var i = 0; i < 40; i++)
          readTrayIconPng('https://example.com/bounded-disk-$i.svg'),
      ];
      try {
        await opened.future;
        expect(await Future.wait(requests.skip(4)), everyElement(isNull));
        for (var batch = 0; batch < 3; batch++) {
          final repeated = [
            for (var i = 0; i < 4; i++)
              readTrayIconPng('https://example.com/bounded-disk-$i.svg'),
          ];
          for (var i = 0; i < 4; i++) {
            expect(identical(repeated[i], requests[i]), isTrue);
          }
          expect(
            await Future.wait([
              for (final request in repeated)
                request.timeout(Duration.zero, onTimeout: () => null),
              for (var i = 0; i < 40; i++)
                readTrayIconPng(
                  'https://example.com/overlap-$batch-$i.svg',
                ).timeout(Duration.zero, onTimeout: () => null),
            ]),
            everyElement(isNull),
          );
          expect(lookups, 4);
          expect(reads, 4);
        }
      } finally {
        await Future.wait([for (final stream in streams) stream.close()]);
        await Future.wait(requests);
      }
      expect(lookups, 4);
      expect(reads, 4);
      const retry = 'https://example.com/bounded-disk-39.svg';
      when(() => manager.getFileFromCache(retry)).thenAnswer((_) async => null);
      expect(await readTrayIconPng(retry), isNull);
      verify(() => manager.getFileFromCache(any())).called(5);
      verifyNoMoreInteractions(manager);
    },
  );

  test('base64 PNG becomes a reusable bounded original-color PNG', () async {
    final input = await _coloredPng();
    final src = 'data:image/png;base64,${base64Encode(input)}';
    final png = await readTrayIconPng(src);
    expect(png, isNotNull);
    expect(png!.length, lessThanOrEqualTo(32 << 10));
    expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    await _expectColor(png, 0xef, 0x38, 0x72);
    expect(identical(png, await readTrayIconPng(src)), isTrue);
    verifyZeroInteractions(manager);
  });

  test(
    'base64 and percent-encoded SVG use existing bytes without HTTP',
    () async {
      var httpCalls = 0;
      await HttpOverrides.runZoned(
        () async {
          for (final src in [
            _inlineSvg(_svg),
            'data:image/svg+xml,${Uri.encodeComponent(_svg)}',
          ]) {
            final png = await readTrayIconPng(src);
            expect(png, isNotNull);
            await _expectColor(png!, 0x12, 0xab, 0x34);
          }
        },
        createHttpClient: (_) {
          httpCalls++;
          throw StateError('HTTP is forbidden');
        },
      );
      expect(httpCalls, 0);
      verifyZeroInteractions(manager);
    },
  );

  test('safe comments and local gradient paints remain usable', () async {
    const svg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16">'
        '<!-- local artwork -->'
        '<defs><linearGradient id="paint">'
        '<stop stop-color="#12ab34"/>'
        '<stop offset="1" stop-color="#12ab34"/>'
        '</linearGradient></defs>'
        '<rect width="16" height="16" fill="url(#paint)"/></svg>';
    final png = await readTrayIconPng(_inlineSvg(svg));
    expect(png, isNotNull);
    await _expectColor(png!, 0x12, 0xab, 0x34);
    verifyZeroInteractions(manager);
  });

  test('unsafe or malformed SVG never attempts to resolve resources', () async {
    var httpCalls = 0;
    await HttpOverrides.runZoned(
      () async {
        for (final svg in [
          '<!DOCTYPE svg [<!ENTITY x SYSTEM "https://example.com/x">]>$_svg',
          '<svg><image href="https://example.com/icon.png"/></svg>',
          '<svg><image href="data:image/png;base64,AAAA"/></svg>',
          '<svg><use href="https://example.com/icon.svg#x"/></svg>',
          '<svg><rect fill="url(https://example.com/a)"/></svg>',
          '<svg><style>@import "https://example.com/a";</style></svg>',
          '<svg><use href="&#104;ttps://example.com/a"/></svg>',
          '<svg><rect>',
          '<svg width="999999999" height="999999999"/>',
        ]) {
          expect(await readTrayIconPng(_inlineSvg(svg)), isNull);
        }
      },
      createHttpClient: (_) {
        httpCalls++;
        throw StateError('HTTP is forbidden');
      },
    );
    expect(httpCalls, 0);
    verifyZeroInteractions(manager);
  });

  test('oversized inputs and raster dimensions are rejected', () async {
    final input = Uint8List(maxTrayIconSourceBytes + 1);
    expect(
      await readTrayIconPng('data:image/png;base64,${base64Encode(input)}'),
      isNull,
    );
    expect(
      await readTrayIconPng(_inlineSvg('$_svg${' ' * (128 << 10)}')),
      isNull,
    );
    final png = await _coloredPng(width: 4097, height: 1);
    expect(
      await readTrayIconPng('data:image/png;base64,${base64Encode(png)}'),
      isNull,
    );
    verifyZeroInteractions(manager);
  });
}

Future<Uint8List> _coloredPng({int width = 2, int height = 2}) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawPaint(ui.Paint()..color = const ui.Color(0xffef3872));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<void> _expectColor(Uint8List png, int red, int green, int blue) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  try {
    expect(frame.image.width, 48);
    expect(frame.image.height, 48);
    final rgba = (await frame.image.toByteData())!;
    final center = (24 * 48 + 24) * 4;
    expect(
      [
        rgba.getUint8(center),
        rgba.getUint8(center + 1),
        rgba.getUint8(center + 2),
        rgba.getUint8(center + 3),
      ],
      [red, green, blue, 255],
    );
  } finally {
    frame.image.dispose();
    codec.dispose();
  }
}
