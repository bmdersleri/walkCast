// StreamAudioSource is used only for the browser's existing IndexedDB cache.
// ignore_for_file: experimental_member_use
import 'dart:async';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/offline/offline_audio_store.dart';
import '../../domain/entities/queue_item.dart';
import '../../domain/playback/next_track.dart';

List<String> audioUrls(String server, QueueItem item) {
  final name = item.filepath?.replaceAll('\\', '/').split('/').last;
  return [
    '$server/api/v1/items/${item.id}/audio',
    if (name != null && name.isNotEmpty)
      '$server/backend/storage/audio/${Uri.encodeComponent(name)}',
  ];
}

class BytesAudioSource extends StreamAudioSource {
  BytesAudioSource(this.bytes);
  final Uint8List bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = (start ?? 0).clamp(0, bytes.length);
    final to = (end ?? bytes.length).clamp(from, bytes.length);
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: to - from,
      offset: from,
      stream: Stream.value(bytes.sublist(from, to)),
      contentType: 'audio/mpeg',
    );
  }
}

class WalkCastAudioHandler extends BaseAudioHandler with SeekHandler {
  WalkCastAudioHandler({required this.offlineStore, AudioPlayer? player})
    : player = player ?? AudioPlayer() {
    _events = this.player.playbackEventStream.listen(
      (_) => _broadcast(),
      onError: (Object error) {
        customEvent.add({'error': error.toString()});
      },
    );
    _states = this.player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        unawaited(
          _complete().catchError((Object error) {
            customEvent.add({'error': error.toString()});
          }),
        );
      }
    });
  }

  final OfflineAudioStore offlineStore;
  final AudioPlayer player;
  late final StreamSubscription<PlaybackEvent> _events;
  late final StreamSubscription<PlayerState> _states;
  List<QueueItem> _items = [];
  final Set<int> _completed = {};
  String _server = '';
  int? loadedItemId;
  String? loadedServer;
  bool playAll = false;
  bool _allowAdvance = false;
  bool _transitioning = false;
  int _generation = 0;
  int? _handledCompletion;
  void Function(QueueItem)? onNeedsDownload;

  void configureQueue(
    List<QueueItem> items,
    String server, {
    required bool autoAdvance,
  }) {
    if (_server != server) _completed.clear();
    _server = server;
    _items = List.of(items);
    playAll = autoAdvance;
    _allowAdvance = autoAdvance && player.playing && !_transitioning;
    queue.add(items.where((item) => item.isReady).map(_mediaItem).toList());
    _broadcast();
  }

  MediaItem _mediaItem(QueueItem item) => MediaItem(
    id: '$_server#${item.id}',
    title: item.title ?? 'walkCast',
    album: item.playlistLabel,
    extras: {'itemId': item.id, 'server': _server},
  );

  void _broadcast() {
    final current = mediaItem.value;
    if (current != null &&
        loadedItemId != null &&
        current.duration != player.duration) {
      mediaItem.add(current.copyWith(duration: player.duration));
    }
    final queueIndex = queue.value.indexWhere(
      (item) => item.extras?['itemId'] == loadedItemId,
    );
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 3],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[player.processingState]!,
        playing: player.playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: queueIndex < 0 ? null : queueIndex,
      ),
    );
  }

  Future<void> loadItem(
    QueueItem item, {
    Duration position = Duration.zero,
    bool startPlaying = true,
  }) async {
    final generation = ++_generation;
    final server = _server;
    _transitioning = true;
    _allowAdvance = false;
    loadedItemId = null;
    _handledCompletion = null;
    mediaItem.add(_mediaItem(item));
    try {
      await player.stop();
      if (generation != _generation) return;
      final path = offlineStore.path(server, item.id);
      final bytes = path == null ? offlineStore.bytes(server, item.id) : null;
      if (path != null) {
        await player.setFilePath(path, initialPosition: position);
      } else if (bytes != null) {
        await player.setAudioSource(
          BytesAudioSource(bytes),
          initialPosition: position,
        );
      } else {
        Object? lastError;
        var loaded = false;
        for (final url in audioUrls(server, item)) {
          try {
            await player.setUrl(url, initialPosition: position);
            loaded = true;
            break;
          } catch (error) {
            lastError = error;
          }
          if (generation != _generation) return;
        }
        if (!loaded) throw lastError ?? StateError('No playable audio source.');
      }
      if (generation != _generation) return;
      loadedItemId = item.id;
      loadedServer = server;
      _transitioning = false;
      if (startPlaying) await play();
      if (!offlineStore.contains(server, item.id)) onNeedsDownload?.call(item);
      _broadcast();
    } catch (error) {
      if (generation != _generation) return;
      loadedItemId = null;
      mediaItem.add(null);
      rethrow;
    } finally {
      if (generation == _generation) _transitioning = false;
    }
  }

  Future<void> _complete() async {
    final id = loadedItemId;
    if (_transitioning || player.processingState != ProcessingState.completed || id == null || _handledCompletion == id) {
      return;
    }
    _handledCompletion = id;
    if (!_allowAdvance || !playAll) {
      await pause();
      return;
    }
    _completed.add(id);
    final next = nextTrack(
      _items,
      id,
      skipListened: true,
      completedIds: _completed,
    );
    if (next == null) {
      _allowAdvance = false;
      await pause();
      return;
    }
    await loadItem(next);
  }

  @override
  Future<void> play() async {
    if (loadedItemId == null) return;
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
      _handledCompletion = null;
      _completed.remove(loadedItemId);
    }
    _allowAdvance = playAll;
    unawaited(
      player.play().catchError((Object error) {
        _allowAdvance = false;
        customEvent.add({'error': error.toString()});
      }),
    );
  }

  @override
  Future<void> pause() async {
    _allowAdvance = false;
    await player.pause();
  }

  @override
  Future<void> stop() async {
    ++_generation;
    _allowAdvance = false;
    _transitioning = false;
    loadedItemId = null;
    loadedServer = null;
    mediaItem.add(null);
    await player.stop();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async => _skip(1);
  @override
  Future<void> skipToPrevious() async => _skip(-1);

  Future<void> _skip(int direction) async {
    final id = loadedItemId;
    if (id == null) return;
    final next = nextTrack(_items, id, direction: direction);
    if (next != null) await loadItem(next);
  }

  Future<void> close() async {
    await _events.cancel();
    await _states.cancel();
    await player.dispose();
  }
}
