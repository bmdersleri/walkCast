import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:walkcast_mobile/src/data/api/items_api_client.dart';
import 'package:walkcast_mobile/src/data/dto/item_dto.dart';
import 'package:walkcast_mobile/src/data/repositories/items_repository_impl.dart';
import 'package:walkcast_mobile/src/core/config/app_config.dart';

class FakeApi extends ItemsApiClient {
  Object? error;
  @override
  Future<List<ItemDto>> listItems() async {
    if (error != null) throw error!;
    return const [
      ItemDto(
        id: 1,
        status: 'ready',
        audioQuality: 'medium',
        title: 'Saved track',
        playlistName: 'My list',
      ),
    ];
  }
}

void main() {
  late Directory dir;
  late Box cache;
  late Box prefs;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('walkcast_queue_test');
    Hive.init(dir.path);
    prefs = await Hive.openBox('walkcast_prefs');
    cache = await Hive.openBox('queue_cache');
  });
  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('queue metadata survives restart and enables offline opening', () async {
    final api = FakeApi();
    final online = ItemsRepositoryImpl(api, cache: cache);
    expect((await online.listItems()).single.title, 'Saved track');
    await cache.close();
    cache = await Hive.openBox('queue_cache');
    api.error = DioException(
      requestOptions: RequestOptions(path: '/items'),
      type: DioExceptionType.connectionError,
    );
    var offline = false;
    final restarted = ItemsRepositoryImpl(
      api,
      cache: cache,
      onOfflineChanged: (value) => offline = value,
    );
    final items = await restarted.listItems();
    expect(items.single.title, 'Saved track');
    expect(items.single.playlistName, 'My list');
    expect(offline, isTrue);
  });
  test('cache is isolated by server address', () async {
    final api = FakeApi();
    final repo = ItemsRepositoryImpl(api, cache: cache);
    await repo.listItems();
    await prefs.put('server_base_url', 'http://another-server:8000');
    api.error = DioException(
      requestOptions: RequestOptions(path: '/items'),
      type: DioExceptionType.connectionError,
    );
    await expectLater(repo.listItems(), throwsA(isA<DioException>()));
  });
  test('authorization errors are not hidden by cached data', () async {
    final api = FakeApi();
    final repo = ItemsRepositoryImpl(api, cache: cache);
    await repo.listItems();
    final options = RequestOptions(path: '/items');
    api.error = DioException(
      requestOptions: options,
      response: Response(requestOptions: options, statusCode: 403),
    );
    await expectLater(repo.listItems(), throwsA(isA<DioException>()));
  });

  test(
    'legacy host-only settings preserve the previous default port',
    () async {
      await prefs.put('server_host', '192.168.1.10');
      expect(AppConfig.apiBaseUrl, 'http://192.168.1.10:8000');
    },
  );
}
