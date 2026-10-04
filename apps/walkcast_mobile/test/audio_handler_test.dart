import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:walkcast_mobile/src/core/audio/walkcast_audio_handler.dart';
import 'package:walkcast_mobile/src/data/offline/offline_audio_store.dart';
import 'package:walkcast_mobile/src/domain/entities/queue_item.dart';
import 'support/fake_audio_player.dart';

QueueItem track(int id, {bool listened = false, String status = 'ready'}) =>
    QueueItem(
      id: id,
      status: status,
      audioQuality: 'medium',
      title: 'Track $id',
      isListened: listened,
    );

void main() {
  late Directory dir;
  late WalkCastAudioHandler handler;
  late FakeAudioPlayer player;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('walkcast_player_test');
    Hive.init(dir.path);
    final box = await Hive.openBox('audio');
    player = FakeAudioPlayer();
    handler = WalkCastAudioHandler(
      offlineStore: OfflineAudioStore(box),
      player: player,
    );
  });
  tearDown(() async {
    await handler.close();
    await Hive.close();
    await dir.delete(recursive: true);
  });
  Future<void> flush() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test(
    'natural completion advances in canonical order and updates notification metadata',
    () async {
      handler.configureQueue(
        [
          track(1),
          track(2, listened: true),
          track(3, status: 'queued'),
          track(4),
        ],
        'http://server',
        autoAdvance: true,
      );
      await handler.loadItem(track(1));
      await flush();
      player.complete();
      await flush();
      expect(handler.loadedItemId, 4);
      expect(handler.mediaItem.value?.title, 'Track 4');
      expect(handler.mediaItem.value?.duration, const Duration(seconds: 10));
      expect(player.urls.last, 'http://server/api/v1/items/4/audio');
    },
  );
  test('manual pause blocks a late completion callback', () async {
    handler.configureQueue(
      [track(1), track(2)],
      'http://server',
      autoAdvance: true,
    );
    await handler.loadItem(track(1));
    await handler.pause();
    player.complete();
    await flush();
    expect(handler.loadedItemId, 1);
    expect(player.playing, isFalse);
    expect(player.urls.length, 1);
  });
  test(
    'single mode finishes without advancing and can replay from the start',
    () async {
      handler.configureQueue(
        [track(1), track(2)],
        'http://server',
        autoAdvance: false,
      );
      await handler.loadItem(track(1));
      player.complete();
      await flush();
      expect(handler.loadedItemId, 1);
      expect(player.playing, isFalse);
      await handler.play();
      await flush();
      expect(player.position, Duration.zero);
      expect(player.playing, isTrue);
    },
  );
  test(
    'lock-screen previous, next, seek and stop control the same player',
    () async {
      handler.configureQueue(
        [track(1), track(2), track(3)],
        'http://server',
        autoAdvance: true,
      );
      await handler.loadItem(track(2));
      await handler.skipToNext();
      expect(handler.loadedItemId, 3);
      await handler.skipToPrevious();
      expect(handler.loadedItemId, 2);
      await handler.seek(const Duration(seconds: 5));
      expect(player.position.inSeconds, 5);
      await handler.stop();
      expect(handler.loadedItemId, isNull);
      expect(player.playing, isFalse);
    },
  );
  test(
    'last track stops without looping and completed events are idempotent',
    () async {
      handler.configureQueue([track(1)], 'http://server', autoAdvance: true);
      await handler.loadItem(track(1));
      player.complete();
      await flush();
      player.complete();
      await flush();
      expect(player.urls.length, 1);
      expect(player.playing, isFalse);
    },
  );

  test(
    'downloaded audio plays locally without filepath metadata or server access',
    () async {
      final file = File('${dir.path}/track.mp3');
      await file.writeAsBytes([1, 2, 3]);
      await handler.offlineStore.box.put(
        '${serverCacheKey('http://server')}-1',
        {'path': file.path, 'size': 3},
      );
      handler.configureQueue([track(1)], 'http://server', autoAdvance: false);
      await handler.loadItem(track(1));
      expect(player.filePaths, [file.path]);
      expect(player.urls, isEmpty);
      await handler.loadItem(
        track(1),
        position: const Duration(seconds: 4),
        startPlaying: false,
      );
      expect(player.position.inSeconds, 4);
      expect(player.playing, isFalse);
      expect(player.urls, isEmpty);
    },
  );

  test(
    'asynchronous player errors are reported to the UI instead of escaping the stream',
    () async {
      final event = handler.customEvent.first;
      player.fail(StateError('Simulated decoder failure'));
      expect((await event as Map)['error'], contains('decoder failure'));
    },
  );
}
