import '../../domain/entities/queue_item.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../../core/config/app_config.dart';
import '../dto/item_dto.dart';
import '../offline/offline_audio_store.dart';
import '../../domain/repositories/items_repository.dart';
import '../api/items_api_client.dart';

class ItemsRepositoryImpl implements ItemsRepository {
  ItemsRepositoryImpl(this._apiClient, {this.cache, this.onOfflineChanged});

  final ItemsApiClient _apiClient;
  final Box? cache;
  final void Function(bool)? onOfflineChanged;

  @override
  Future<List<QueueItem>> listItems() async {
    final key = serverCacheKey(AppConfig.apiBaseUrl);
    try {
      final dtos = await _apiClient.listItems();
      await cache?.put(key, dtos.map((dto) => dto.toJson()).toList());
      onOfflineChanged?.call(false);
      return dtos.map((dto) => dto.toEntity()).toList(growable: false);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final stored = cache?.get(key);
      // Authentication and validation errors must remain visible.
      if (stored is! List || (status != null && status < 500)) rethrow;
      onOfflineChanged?.call(true);
      return stored
          .map(
            (json) => ItemDto.fromJson(
              Map<String, dynamic>.from(json as Map),
            ).toEntity(),
          )
          .toList();
    }
  }
}
