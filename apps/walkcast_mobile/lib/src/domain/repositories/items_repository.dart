import '../entities/queue_item.dart';

abstract class ItemsRepository {
  Future<List<QueueItem>> listItems();
}
