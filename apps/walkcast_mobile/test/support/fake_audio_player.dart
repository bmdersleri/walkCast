import 'dart:async';
import 'package:just_audio/just_audio.dart';

class FakeAudioPlayer implements AudioPlayer {
  final _events = StreamController<PlaybackEvent>.broadcast();
  final _states = StreamController<PlayerState>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration?>.broadcast();
  final urls = <String>[];
  final filePaths = <String>[];
  @override
  bool playing = false;
  @override
  ProcessingState processingState = ProcessingState.idle;
  @override
  Duration position = Duration.zero;
  @override
  Duration? duration = const Duration(seconds: 10);
  @override
  Duration get bufferedPosition => duration ?? Duration.zero;
  @override
  double speed = 1;
  @override
  Stream<PlaybackEvent> get playbackEventStream => _events.stream;
  @override
  Stream<PlayerState> get playerStateStream => _states.stream;
  @override
  Stream<Duration> get positionStream => _positions.stream;
  @override
  Stream<Duration?> get durationStream => _durations.stream;

  void _emit() {
    _events.add(
      PlaybackEvent(processingState: processingState, updatePosition: position),
    );
    _states.add(PlayerState(playing, processingState));
    _positions.add(position);
    _durations.add(duration);
  }

  void complete() {
    position = duration!;
    processingState = ProcessingState.completed;
    _emit();
  }

  void fail(Object error) => _events.addError(error);

  @override
  Future<void> play() async {
    playing = true;
    _emit();
  }

  @override
  Future<void> pause() async {
    playing = false;
    _emit();
  }

  @override
  Future<void> stop() async {
    playing = false;
    processingState = ProcessingState.idle;
    _emit();
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    this.position = position ?? Duration.zero;
    if (processingState == ProcessingState.completed) {
      processingState = ProcessingState.ready;
    }
    _emit();
  }

  @override
  Future<void> setSpeed(double speed) async {
    this.speed = speed;
    _emit();
  }

  Future<Duration?> _load(Duration? initialPosition) async {
    position = initialPosition ?? Duration.zero;
    processingState = ProcessingState.ready;
    _emit();
    return duration;
  }

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) {
    urls.add(url);
    return _load(initialPosition);
  }

  @override
  Future<Duration?> setFilePath(
    String path, {
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) {
    filePaths.add(path);
    return _load(initialPosition);
  }

  @override
  Future<Duration?> setAudioSource(
    AudioSource audioSource, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) => _load(initialPosition);
  @override
  Future<void> dispose() async {
    await _events.close();
    await _states.close();
    await _positions.close();
    await _durations.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
