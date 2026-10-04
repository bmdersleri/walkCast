import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:walkcast_mobile/src/data/offline/offline_audio_store.dart';
import 'package:walkcast_mobile/src/data/offline/offline_files.dart';

void main() {
  late Directory dir;
  late Box box;
  late OfflineAudioStore store;
  late HttpServer server;
  late String base;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('walkcast_store_test');
    Hive.init(dir.path);
    box = await Hive.openBox('audio');
    store = OfflineAudioStore(
      box,
      files: OfflineFiles(directoryProvider: () async => '${dir.path}/files'),
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      if (request.uri.path == '/missing') {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }
      if (request.uri.path == '/bad') {
        request.response.headers.contentType = ContentType.html;
        request.response.write('<html>Error</html>');
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.contentLength = 4096;
      for (var i = 0; i < 4; i++) {
        try {
          request.response.add(List.filled(1024, i + 1));
          await request.response.flush();
          if (request.uri.path == '/slow') {
            await Future<void>.delayed(const Duration(milliseconds: 80));
          }
        } catch (_) {
          break;
        }
      }
      await request.response.close();
    });
  });
  tearDown(() async {
    await server.close(force: true);
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test(
    'native audio goes to a file; metadata survives reopening and stays server scoped',
    () async {
      await store.download(base, 1, ['$base/audio'], onProgress: (_, _) {});
      expect(store.contains(base, 1), isTrue);
      expect(store.contains('http://another-server', 1), isFalse);
      expect(store.bytes(base, 1), isNull);
      expect(store.sizeBytes(base), 4096);
      final path = store.path(base, 1)!;
      expect(await File(path).length(), 4096);
      await box.close();
      box = await Hive.openBox('audio');
      store = OfflineAudioStore(
        box,
        files: OfflineFiles(directoryProvider: () async => '${dir.path}/files'),
      );
      expect(store.savedIds(base), {1});
      await store.remove(base, 1);
      expect(File(path).existsSync(), isFalse);
      expect(store.savedIds(base), isEmpty);
    },
  );
  test('legacy Hive bytes migrate without losing audio', () async {
    await box.put('item_7', Uint8List.fromList([1, 2, 3, 4]));
    await store.migrateLegacy(base);
    expect(store.contains(base, 7), isTrue);
    expect(await File(store.path(base, 7)!).readAsBytes(), [1, 2, 3, 4]);
    expect(box.containsKey('item_7'), isFalse);
    await store.migrateLegacy('http://another-server');
    expect(store.contains('http://another-server', 7), isFalse);
  });
  test('missing files are never shown as downloaded', () async {
    await store.download(base, 1, ['$base/audio'], onProgress: (_, _) {});
    await File(store.path(base, 1)!).delete();
    expect(store.contains(base, 1), isFalse);
    expect(store.savedIds(base), isEmpty);
  });
  test(
    'download falls back to static URL when item endpoint is unavailable',
    () async {
      await store.download(base, 1, [
        '$base/missing',
        '$base/audio',
      ], onProgress: (_, _) {});
      expect(store.contains(base, 1), isTrue);
    },
  );
  test('non-audio responses never become offline files', () async {
    await expectLater(
      store.download(base, 1, ['$base/bad'], onProgress: (_, _) {}),
      throwsFormatException,
    );
    expect(store.contains(base, 1), isFalse);
    final files = await Directory('${dir.path}/files').list().toList();
    expect(files, isEmpty);
  });
  test(
    'cancellation removes partial files and allows a subsequent retry',
    () async {
      final download = store.download(
        base,
        1,
        ['$base/slow'],
        onProgress: (received, _) {
          if (received > 0) store.cancel(base, 1);
        },
      );
      await expectLater(
        download,
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      expect(store.savedIds(base), isEmpty);
      expect(await Directory('${dir.path}/files').list().toList(), isEmpty);
      await store.download(base, 1, ['$base/audio'], onProgress: (_, _) {});
      expect(store.contains(base, 1), isTrue);
    },
  );
  test('clear offline removes only the selected server files', () async {
    await store.download(base, 1, ['$base/audio'], onProgress: (_, _) {});
    await store.download('http://another-server', 1, [
      '$base/audio',
    ], onProgress: (_, _) {});
    await store.clear(base);
    expect(store.contains(base, 1), isFalse);
    expect(store.contains('http://another-server', 1), isTrue);
  });
}
