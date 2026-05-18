import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../dto/item_dto.dart';

class ItemsApiClient {
  ItemsApiClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 12),
              ),
            );

  final Dio _dio;

  Future<List<ItemDto>> listItems() async {
    final response = await _dio.get<List<dynamic>>('${AppConfig.apiBaseUrl}/api/v1/items');
    final rows = response.data ?? <dynamic>[];

    return rows
        .whereType<Map<String, dynamic>>()
        .map(ItemDto.fromJson)
        .toList(growable: false);
  }
}
