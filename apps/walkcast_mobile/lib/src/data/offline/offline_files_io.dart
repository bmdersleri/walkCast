import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class OfflineFiles {
  OfflineFiles({Future<String> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? _defaultDirectory;

  final Future<String> Function() _directoryProvider;
  bool get supported => true;

  static Future<String> _defaultDirectory() async =>
      '${(await getApplicationSupportDirectory()).path}/walkcast_audio';

  Future<String> _path(String key) async {
    final dir = Directory(await _directoryProvider());
    await dir.create(recursive: true);
    return '${dir.path}/$key.mp3';
  }

  bool exists(String path) => File(path).existsSync();
  Future<int> size(String path) => File(path).length();
  Future<void> remove(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<String> saveLegacy(String key, Uint8List bytes) async {
    final path = await _path(key);
    await File(path).writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<String> download(
    Dio dio,
    String url,
    String key,
    CancelToken cancel,
    void Function(int received, int total) onProgress,
  ) async {
    final path = await _path(key);
    final partial = '$path.part';
    try {
      final response = await dio.download(
        url,
        partial,
        cancelToken: cancel,
        onReceiveProgress: onProgress,
        deleteOnError: true,
      );
      if (cancel.isCancelled) throw cancel.cancelError!;
      final contentType = response.headers.value('content-type') ?? '';
      if (contentType.contains('text/') || contentType.contains('json')) {
        throw const FormatException('The server did not return an audio file.');
      }
      if (await File(partial).length() == 0) {
        throw const FormatException('The server returned an empty audio file.');
      }
      await File(partial).rename(path);
      return path;
    } finally {
      await remove(partial);
    }
  }
}
