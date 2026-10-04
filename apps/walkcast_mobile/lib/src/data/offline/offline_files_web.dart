import 'dart:typed_data';
import 'package:dio/dio.dart';

class OfflineFiles {
  OfflineFiles({Future<String> Function()? directoryProvider});
  bool get supported => false;
  bool exists(String path) => false;
  Future<int> size(String path) async => 0;
  Future<void> remove(String path) async {}
  Future<String> saveLegacy(String key, Uint8List bytes) =>
      throw UnsupportedError('Browser audio is stored in IndexedDB.');
  Future<String> download(
    Dio dio,
    String url,
    String key,
    CancelToken cancel,
    void Function(int received, int total) onProgress,
  ) => throw UnsupportedError('Browser audio is stored in IndexedDB.');
}
