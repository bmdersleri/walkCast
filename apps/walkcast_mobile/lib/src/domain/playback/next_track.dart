import '../entities/queue_item.dart';

QueueItem? nextTrack(
  List<QueueItem> items,
  int currentId, {
  int direction = 1,
  bool skipListened = false,
  Set<int> completedIds = const {},
}) {
  final current = items.indexWhere((item) => item.id == currentId);
  if (current < 0) return null;
  final step = direction < 0 ? -1 : 1;
  for (
    var index = current + step;
    index >= 0 && index < items.length;
    index += step
  ) {
    final item = items[index];
    if (item.isReady &&
        (!skipListened || !item.isListened) &&
        !completedIds.contains(item.id)) {
      return item;
    }
  }
  return null;
}
