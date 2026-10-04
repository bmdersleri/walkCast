import 'package:flutter_test/flutter_test.dart';
import 'package:walkcast_mobile/src/domain/entities/queue_item.dart';
import 'package:walkcast_mobile/src/domain/playback/next_track.dart';

QueueItem item(int id, {String status = 'ready', bool listened = false}) =>
    QueueItem(
      id: id,
      status: status,
      audioQuality: 'medium',
      isListened: listened,
    );

void main() {
  test('completed current track remains an anchor in canonical order', () {
    expect(nextTrack([item(6), item(7), item(8)], 6, completedIds: {6})?.id, 7);
  });
  test(
    'automatic continuation skips listened, unfinished and completed tracks',
    () {
      expect(
        nextTrack(
          [
            item(1),
            item(2, listened: true),
            item(3, status: 'queued'),
            item(4),
            item(5),
          ],
          1,
          skipListened: true,
          completedIds: {1, 4},
        )?.id,
        5,
      );
    },
  );
  test('manual previous and next can replay listened tracks', () {
    final queue = [item(1, listened: true), item(2), item(3, listened: true)];
    expect(nextTrack(queue, 2, direction: -1)?.id, 1);
    expect(nextTrack(queue, 2)?.id, 3);
  });
  test('missing anchor and queue boundaries do not wrap', () {
    expect(nextTrack([item(1)], 1), isNull);
    expect(nextTrack([item(1)], 1, direction: -1), isNull);
    expect(nextTrack([item(1)], 99), isNull);
  });
}
