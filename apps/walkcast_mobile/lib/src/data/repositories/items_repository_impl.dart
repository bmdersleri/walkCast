import '../../domain/entities/queue_item.dart';
import '../../domain/repositories/items_repository.dart';
import '../api/items_api_client.dart';

class ItemsRepositoryImpl implements ItemsRepository {
  ItemsRepositoryImpl(this._apiClient);

  final ItemsApiClient _apiClient;

  @override
  Future<List<QueueItem>> listItems() async {
    final dtos = await _apiClient.listItems();
    return dtos.map((dto) => dto.toEntity()).toList(growable: false);
  }
}
