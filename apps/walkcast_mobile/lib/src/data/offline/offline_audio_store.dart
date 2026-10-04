import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';

import 'offline_files.dart';

String serverCacheKey(String server) => sha256
    .convert(utf8.encode(server.replaceFirst(RegExp(r'/+$'), '')))
    .toString();

class OfflineAudioStore {
  OfflineAudioStore(this.box, {OfflineFiles? files, Dio? dio})
    : files = files ?? OfflineFiles(),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Box box;
  final OfflineFiles files;
  final Dio _dio;
  final _tokens = <String, CancelToken>{};
  final _jobs = <String, Future<void>>{};

  String _key(String server, int id) => '${serverCacheKey(server)}-$id';
  Map? _record(String server, int id) => box.get(_key(server, id)) as Map?;

  bool contains(String server, int id) {
    final record = _record(server, id);
    if (record == null) return false;
    return files.supported
        ? record['path'] is String && files.exists(record['path'] as String)
        : record['bytes'] is Uint8List &&
              (record['bytes'] as Uint8List).isNotEmpty;
  }

  String? path(String server, int id) =>
      contains(server, id) ? (_record(server, id)?['path'] as String?) : null;
  Uint8List? bytes(String server, int id) =>
      _record(server, id)?['bytes'] as Uint8List?;

  Set<int> savedIds(String server) {
    final prefix = '${serverCacheKey(server)}-';
    return box.keys
        .whereType<String>()
        .where((key) => key.startsWith(prefix))
        .map((key) => int.tryParse(key.substring(prefix.length)))
        .whereType<int>()
        .where((id) => contains(server, id))
        .toSet();
  }

  int sizeBytes(String server) => savedIds(server).fold(
    0,
    (total, id) =>
        total + ((_record(server, id)?['size'] as num?)?.toInt() ?? 0),
  );

  Future<void> migrateLegacy(String server) async {
    if (box.get('legacy_files_migrated', defaultValue: false) == true) return;
    for (final key
        in box.keys
            .whereType<String>()
            .where((key) => key.startsWith('item_'))
            .toList()) {
      final id = int.tryParse(key.substring(5));
      final raw = box.get(key);
      if (id == null || raw is! List<int> || raw.isEmpty) continue;
      final data = Uint8List.fromList(raw);
      final filePath = files.supported
          ? await files.saveLegacy(_key(server, id), data)
          : null;
      await box.put(_key(server, id), {
        'path': ?filePath,
        if (!files.supported) 'bytes': data,
        'size': data.length,
      });
      await box.delete(key);
    }
    await box.put('legacy_files_migrated', true);
  }

  Future<void> download(
    String server,
    int id,
    List<String> urls, {
    required void Function(int received, int total) onProgress,
  }) {
    final key = _key(server, id);
    if (contains(server, id)) return Future.value();
    final existing = _jobs[key];
    if (existing != null) return existing;
    final token = CancelToken();
    _tokens[key] = token;
    final job = _download(server, id, urls, token, onProgress).whenComplete(() {
      _tokens.remove(key);
      _jobs.remove(key);
    });
    _jobs[key] = job;
    return job;
  }

  Future<void> _download(
    String server,
    int id,
    List<String> urls,
    CancelToken token,
    void Function(int, int) onProgress,
  ) async {
    Object? lastError;
    for (final url in urls) {
      if (token.isCancelled) throw token.cancelError!;
      String? filePath;
      try {
        Uint8List? data;
        if (files.supported) {
          filePath = await files.download(
            _dio,
            url,
            _key(server, id),
            token,
            onProgress,
          );
        } else {
          final response = await _dio.get<List<int>>(
            url,
            options: Options(responseType: ResponseType.bytes),
            cancelToken: token,
            onReceiveProgress: onProgress,
          );
          final contentType = response.headers.value('content-type') ?? '';
          if (contentType.contains('text/') ||
              contentType.contains('json') ||
              response.data == null ||
              response.data!.isEmpty) {
            throw const FormatException(
              'The server did not return an audio file.',
            );
          }
          data = Uint8List.fromList(response.data!);
        }
        if (token.isCancelled) throw token.cancelError!;
        await box.put(_key(server, id), {
          'path': ?filePath,
          'bytes': ?data,
          'size': filePath != null ? await files.size(filePath) : data!.length,
        });
        return;
      } catch (error) {
        if (filePath != null) await files.remove(filePath);
        if (error is DioException && CancelToken.isCancel(error)) rethrow;
        lastError = error;
      }
    }
    throw lastError ?? StateError('No audio URL is available.');
  }

  void cancel(String server, int id) => _tokens[_key(server, id)]?.cancel();
  void cancelAll(String server) {
    final prefix = '${serverCacheKey(server)}-';
    for (final entry in _tokens.entries.toList()) {
      if (entry.key.startsWith(prefix)) entry.value.cancel();
    }
  }

  Future<void> remove(String server, int id) async {
    final key = _key(server, id);
    cancel(server, id);
    try {
      await _jobs[key];
    } catch (_) {
      /* Cancellation is expected. */
    }
    final record = _record(server, id);
    if (record?['path'] is String) {
      await files.remove(record!['path'] as String);
    }
    await box.delete(key);
  }

  Future<void> clear(String server) async {
    cancelAll(server);
    final prefix = '${serverCacheKey(server)}-';
    final pending = _jobs.entries
        .where((entry) => entry.key.startsWith(prefix))
        .map((entry) => entry.value)
        .toList();
    for (final job in pending) {
      try {
        await job;
      } catch (_) {}
    }
    for (final key
        in box.keys
            .whereType<String>()
            .where((key) => key.startsWith(prefix))
            .toList()) {
      final id = int.tryParse(key.substring(prefix.length));
      if (id != null) await remove(server, id);
    }
  }
}
