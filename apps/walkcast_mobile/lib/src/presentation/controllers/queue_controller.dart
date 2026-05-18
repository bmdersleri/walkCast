import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/items_api_client.dart';
import '../../data/repositories/items_repository_impl.dart';
import '../../domain/entities/queue_item.dart';
import '../../domain/repositories/items_repository.dart';

final itemsApiClientProvider = Provider<ItemsApiClient>((ref) {
  return ItemsApiClient();
});

final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  final api = ref.watch(itemsApiClientProvider);
  return ItemsRepositoryImpl(api);
});

final queueItemsProvider = FutureProvider<List<QueueItem>>((ref) async {
  final repository = ref.watch(itemsRepositoryProvider);
  return repository.listItems();
});
