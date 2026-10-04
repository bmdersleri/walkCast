import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/audio/walkcast_audio_handler.dart';
import '../../data/offline/offline_audio_store.dart';

import '../../data/api/items_api_client.dart';
import '../../data/repositories/items_repository_impl.dart';
import '../../domain/entities/queue_item.dart';
import '../../domain/repositories/items_repository.dart';

late WalkCastAudioHandler mobileAudioHandler;
late OfflineAudioStore mobileOfflineStore;
final audioHandlerProvider = Provider<WalkCastAudioHandler>(
  (ref) => mobileAudioHandler,
);
final offlineStoreProvider = Provider<OfflineAudioStore>(
  (ref) => mobileOfflineStore,
);
final queueOfflineProvider = StateProvider<bool>((ref) => false);

final itemsApiClientProvider = Provider<ItemsApiClient>((ref) {
  return ItemsApiClient();
});

final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  final api = ref.watch(itemsApiClientProvider);
  var disposed = false;
  ref.onDispose(() => disposed = true);
  return ItemsRepositoryImpl(
    api,
    cache: Hive.isBoxOpen('walkcast_queue_cache')
        ? Hive.box('walkcast_queue_cache')
        : null,
    onOfflineChanged: (offline) {
      if (!disposed) ref.read(queueOfflineProvider.notifier).state = offline;
    },
  );
});

final queueItemsProvider = FutureProvider<List<QueueItem>>((ref) async {
  final repository = ref.watch(itemsRepositoryProvider);
  return repository.listItems();
});
