// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../domain/entities/queue_item.dart';
import '../controllers/queue_controller.dart';
import '../widgets/queue_item_card.dart';
import 'settings_screen.dart';

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({
    super.key,
    required this.isDarkMode,
    required this.languageCode,
    required this.onThemeToggle,
    required this.onLanguageChanged,
  });

  final bool isDarkMode;
  final String languageCode;
  final VoidCallback onThemeToggle;
  final ValueChanged<String> onLanguageChanged;

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _BytesAudioSource extends StreamAudioSource {
  _BytesAudioSource(this.bytes, this.id);

  final Uint8List bytes;
  final int id;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final safeStart = start ?? 0;
    final safeEnd = end ?? bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: safeEnd - safeStart,
      offset: safeStart,
      stream: Stream<List<int>>.value(bytes.sublist(safeStart, safeEnd)),
      contentType: 'audio/mpeg',
    );
  }
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  static const String _playModeAll = 'all';
  static const String _playModeSingle = 'single';

  final AudioPlayer _audioPlayer = AudioPlayer();
  Box? _prefs;
  Box? _audioCache;
  final Dio _dio = Dio();
  StreamSubscription<PlayerState>? _playerStateSub;

  List<QueueItem> _items = <QueueItem>[];
  bool _seededFromApi = false;
  int? _playingItemId;
  int? _loadedItemId;
  String? _loadedAudioUrl;
  Set<int> _offlineSavedIds = <int>{};
  String _selectedPlaylist = 'All';
  double _playbackSpeed = 1.0;
  String _playMode = _playModeSingle;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  bool _isAudioRunning = false;
  bool _suppressAutoAdvance = false;
  bool _allowAutoAdvance = false;
  DateTime? _manualStopAt;
  bool _isSeeking = false;
  double? _seekDragValueMillis;
  final Set<int> _downloadingIds = <int>{};
  final Map<int, double> _downloadProgressById = <int, double>{};
  final Map<int, int> _downloadEtaSecsById = <int, int>{};
  final Map<int, DateTime> _downloadStartById = <int, DateTime>{};
  final Set<int> _completedTrackIds = <int>{};
  bool _bulkDownloading = false;
  int _bulkTotal = 0;
  int _bulkDone = 0;

  bool get _isTr => widget.languageCode == 'tr';
  String t(String en, String tr) => _isTr ? tr : en;

  @override
  void initState() {
    super.initState();
    if (Hive.isBoxOpen('walkcast_prefs')) {
      _prefs = Hive.box('walkcast_prefs');
      final saved = (_prefs!.get('offline_saved_ids', defaultValue: <dynamic>[]) as List<dynamic>)
          .map((e) => e as int)
          .toSet();
      _offlineSavedIds = saved;
      _playbackSpeed = (_prefs!.get('playback_speed', defaultValue: 1.0) as num).toDouble();
      _playMode = _prefs!.get('play_mode', defaultValue: _playModeSingle) as String;
      if (_playMode != _playModeAll && _playMode != _playModeSingle) {
        _playMode = _playModeSingle;
      }
      _audioPlayer.setSpeed(_playbackSpeed);
    }
    _audioCache = Hive.isBoxOpen('walkcast_audio_cache')
        ? Hive.box('walkcast_audio_cache')
        : null;
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isAudioRunning = state.playing;
        });
      }
      if (state.processingState == ProcessingState.completed) {
        _handleTrackCompleted();
      }
    });
    _audioPlayer.positionStream.listen((pos) {
      if (!mounted) return;
      if (_isSeeking) return;
      if (_loadedItemId == null) return;
      setState(() {
        _currentPosition = pos;
      });
    });
    _audioPlayer.durationStream.listen((dur) {
      if (!mounted) return;
      if (_loadedItemId == null) return;
      setState(() {
        _currentDuration = dur ?? Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _seededFromApi = false;
    ref.invalidate(queueItemsProvider);
    await ref.read(queueItemsProvider.future);
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t('Cancel', 'Vazgec')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _markAsListened(QueueItem item) async {
    final confirmed = await _confirmAction(
      title: t('Mark listened?', 'Dinlendi olarak isaretlensin mi?'),
      message: t(
        'This will mark the track as listened.',
        'Bu islem parcayi dinlendi olarak isaretler.',
      ),
      confirmText: t('Mark', 'Isaretle'),
    );
    if (!confirmed) return;

    try {
      await _dio.post('${AppConfig.apiBaseUrl}/api/v1/items/${item.id}/listen');
      _toast(t('Marked as listened.', 'Dinlendi olarak isaretlendi.'));
      await _refresh();
    } catch (_) {
      _toast(t('Could not mark listened.', 'Dinlendi olarak isaretlenemedi.'));
    }
  }

  Future<void> _deleteTrack(QueueItem item) async {
    final confirmed = await _confirmAction(
      title: t('Delete track?', 'Parca silinsin mi?'),
      message: t(
        'This will delete the track from server and list.',
        'Bu islem parcayi sunucudan ve listeden siler.',
      ),
      confirmText: t('Delete', 'Sil'),
    );
    if (!confirmed) return;

    try {
      await _dio.delete('${AppConfig.apiBaseUrl}/api/v1/items/${item.id}');
      _toast(t('Track deleted.', 'Parca silindi.'));
      if (_playingItemId == item.id) {
        await _audioPlayer.stop();
        _playingItemId = null;
        _loadedItemId = null;
        _loadedAudioUrl = null;
      }
      await _refresh();
    } catch (_) {
      _toast(t('Could not delete track.', 'Parca silinemedi.'));
    }
  }

  List<String> _audioUrlCandidates(QueueItem item) {
    final path = item.filepath;
    if (path == null || path.isEmpty) return const <String>[];
    final fileName = path.split('/').last;
    return <String>[
      '${AppConfig.apiBaseUrl}/api/v1/items/${item.id}/audio',
      '${AppConfig.apiBaseUrl}/backend/storage/audio/$fileName',
    ];
  }

  Future<void> _togglePlay(QueueItem item) async {
    final candidates = _audioUrlCandidates(item);
    if (candidates.isEmpty) {
      _snack(t('Audio file is not ready yet.', 'Ses dosyasi henuz hazir degil.'));
      return;
    }

    try {
      if (mounted && _playingItemId != item.id) {
        _activateItem(item.id, resetPosition: true);
        _resetSeekState();
      }

      if (_loadedItemId == item.id && _audioPlayer.playing) {
        _suppressAutoAdvance = true;
        _allowAutoAdvance = false;
        _manualStopAt = DateTime.now();
        await _audioPlayer.pause();
        return;
      }

      if (_loadedItemId == item.id && !_audioPlayer.playing) {
        _suppressAutoAdvance = false;
        _allowAutoAdvance = (_playMode == _playModeAll);
        _manualStopAt = null;
        await _audioPlayer.play();
        if (mounted) {
          _activateItem(item.id);
        }
        return;
      }

      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _loadedItemId = null;
          _loadedAudioUrl = null;
          _isAudioRunning = false;
        });
      }
      _resetSeekState();
      final hasLocal = _hasOfflineBytes(item.id);
      if (hasLocal) {
        final localBytes = _readOfflineBytes(item.id)!;
        await _audioPlayer.setAudioSource(_BytesAudioSource(localBytes, item.id));
        _loadedAudioUrl = 'local-cache:${item.id}';
        _loadedItemId = item.id;
      } else {
        _downloadAndCache(item, silentSuccess: true);
      }

      String? loadedUrl;
      Object? lastErr;
      if (!hasLocal) {
        for (final url in candidates) {
          try {
            await _audioPlayer.setUrl(url);
            loadedUrl = url;
            break;
          } catch (err) {
            lastErr = err;
          }
        }
        if (loadedUrl == null) {
          throw lastErr ?? Exception('No playable source');
        }
        _loadedAudioUrl = loadedUrl;
        _loadedItemId = item.id;
      }
      _currentDuration = _audioPlayer.duration ?? Duration.zero;
      _suppressAutoAdvance = false;
      _allowAutoAdvance = (_playMode == _playModeAll);
      _manualStopAt = null;
      await _audioPlayer.setSpeed(_playbackSpeed);
      await _audioPlayer.play();
      if (mounted) {
        _activateItem(item.id);
      }
    } catch (_) {
      _allowAutoAdvance = false;
      if (mounted) {
        setState(() {
          if (_playingItemId == item.id) {
            _playingItemId = null;
          }
        });
      }
      _snack(t('Could not play this track.', 'Bu parca oynatilamadi.'));
    }
  }

  Future<void> _download(QueueItem item) async {
    await _downloadAndCache(item);
  }

  bool _hasOfflineBytes(int itemId) => _audioCache?.containsKey('item_$itemId') ?? false;

  Uint8List? _readOfflineBytes(int itemId) {
    final raw = _audioCache?.get('item_$itemId');
    if (raw is Uint8List) return raw;
    if (raw is List<int>) return Uint8List.fromList(raw);
    return null;
  }

  Future<bool> _downloadAndCache(QueueItem item, {bool silentSuccess = false}) async {
    if (_downloadingIds.contains(item.id)) return false;
    final candidates = _audioUrlCandidates(item);
    if (candidates.isEmpty) {
      if (!silentSuccess) {
        _snack(t('Audio file is not ready for download.', 'Ses dosyasi indirilmeye hazir degil.'));
      }
      return false;
    }

    final audioUrl = candidates.first;
    setState(() {
      _downloadingIds.add(item.id);
      _downloadProgressById[item.id] = 0;
      _downloadStartById[item.id] = DateTime.now();
      _downloadEtaSecsById.remove(item.id);
    });

    try {
      final response = await _dio.get<List<int>>(
        audioUrl,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (!mounted || total <= 0) return;
          final startedAt = _downloadStartById[item.id];
          int? etaSecs;
          if (startedAt != null) {
            final elapsed = DateTime.now().difference(startedAt).inMilliseconds / 1000.0;
            if (elapsed > 0.6 && received > 0) {
              final speed = received / elapsed;
              if (speed > 0) {
                etaSecs = ((total - received) / speed).ceil().clamp(0, 36000);
              }
            }
          }
          setState(() {
            _downloadProgressById[item.id] = (received / total).clamp(0, 1);
            if (etaSecs != null) _downloadEtaSecsById[item.id] = etaSecs;
          });
        },
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('No file bytes');
      }
      await _audioCache?.put('item_${item.id}', Uint8List.fromList(bytes));

      final updatedOffline = Set<int>.from(_offlineSavedIds)..add(item.id);
      await _prefs?.put('offline_saved_ids', updatedOffline.toList());
      if (mounted) {
        setState(() {
          _offlineSavedIds = updatedOffline;
        });
      }
      if (!silentSuccess) {
        _toast(t('Downloaded for offline use.', 'Cevrimdisi icin indirildi.'));
      }
      return true;
    } catch (_) {
      if (!silentSuccess) {
        _toast(t('Download failed.', 'Indirme basarisiz oldu.'));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(item.id);
          _downloadStartById.remove(item.id);
          if ((_downloadProgressById[item.id] ?? 0) >= 1) {
            _downloadProgressById.remove(item.id);
            _downloadEtaSecsById.remove(item.id);
          }
        });
      }
    }
  }

  Future<void> _toggleOffline(QueueItem item) async {
    final next = Set<int>.from(_offlineSavedIds);
    if (next.contains(item.id)) {
      next.remove(item.id);
      await _audioCache?.delete('item_${item.id}');
      _snack(t('Removed from offline list.', 'Cevrimdisi listesinden kaldirildi.'));
    } else {
      final ok = await _downloadAndCache(item, silentSuccess: true);
      if (!ok) return;
      next.add(item.id);
      _snack(t('Marked as offline saved.', 'Cevrimdisi olarak isaretlendi.'));
    }
    await _prefs?.put('offline_saved_ids', next.toList());
    if (mounted) {
      setState(() {
        _offlineSavedIds = next;
      });
    }
  }

  Future<void> _handleTrackCompleted() async {
    final durationMs = _audioPlayer.duration?.inMilliseconds ?? _currentDuration.inMilliseconds;
    final positionMs = _audioPlayer.position.inMilliseconds;
    final reachedNaturalEnd = durationMs > 0 && positionMs >= (durationMs - 900);
    final pausedRecentlyByUser = _manualStopAt != null &&
        DateTime.now().difference(_manualStopAt!).inMilliseconds < 1800;
    final completedId = _playingItemId;

    if (_suppressAutoAdvance ||
        pausedRecentlyByUser ||
        !_allowAutoAdvance ||
        !reachedNaturalEnd ||
        _playMode != _playModeAll ||
        completedId == null) {
      _suppressAutoAdvance = false;
      _allowAutoAdvance = false;
      _manualStopAt = null;
      return;
    }

    _completedTrackIds.add(completedId);
    final sequenceItems = _sequenceItems();
    final ready = sequenceItems
        .where((i) => i.isReady && !i.isListened && !_completedTrackIds.contains(i.id))
        .toList(growable: false);
    final currentIndex = ready.indexWhere((i) => i.id == completedId);
    if (currentIndex == -1 || currentIndex + 1 >= ready.length) {
      _allowAutoAdvance = false;
      if (mounted) {
        setState(() {
          _playingItemId = null;
          _loadedItemId = null;
          _loadedAudioUrl = null;
        });
      }
      return;
    }
    await _togglePlay(ready[currentIndex + 1]);
  }

  List<QueueItem> _sequenceItems() {
    return _selectedPlaylist == 'All'
        ? List<QueueItem>.from(_items)
        : _items.where((item) => item.playlistLabel == _selectedPlaylist).toList(growable: true);
  }

  List<QueueItem> _visibleItems() {
    final base = _sequenceItems();
    if (_playingItemId == null) {
      return base;
    }
    final idx = base.indexWhere((item) => item.id == _playingItemId);
    if (idx > 0) {
      final active = base.removeAt(idx);
      base.insert(0, active);
    }
    return base;
  }

  void _activateItem(int itemId, {bool resetPosition = false}) {
    setState(() {
      _playingItemId = itemId;
      if (resetPosition) {
        _currentPosition = Duration.zero;
        _currentDuration = Duration.zero;
      }
    });
  }

  void _resetSeekState() {
    if (!mounted) return;
    setState(() {
      _isSeeking = false;
      _seekDragValueMillis = null;
      _currentPosition = Duration.zero;
      _currentDuration = Duration.zero;
    });
  }

  void _moveUp(int index) {
    if (index <= 0) return;
    setState(() {
      final tmp = _items[index - 1];
      _items[index - 1] = _items[index];
      _items[index] = tmp;
    });
  }

  void _moveDown(int index) {
    if (index >= _items.length - 1) return;
    setState(() {
      final tmp = _items[index + 1];
      _items[index + 1] = _items[index];
      _items[index] = tmp;
    });
  }

  void _onSpeedChanged(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    _audioPlayer.setSpeed(speed);
    _prefs?.put('playback_speed', speed);
  }

  void _onPlayModeChanged(String mode) {
    setState(() {
      _playMode = mode;
    });
    if (mode != _playModeAll) {
      _allowAutoAdvance = false;
      _suppressAutoAdvance = true;
      _manualStopAt = DateTime.now();
    } else {
      _suppressAutoAdvance = false;
      _allowAutoAdvance = _isAudioRunning;
      _manualStopAt = null;
    }
    _prefs?.put('play_mode', mode);
  }

  Future<void> _seekToMillis(double value) async {
    if (!_isSeeking) return;
    setState(() {
      _seekDragValueMillis = value;
    });
  }

  void _onSeekStart(double value) {
    setState(() {
      _isSeeking = true;
      _seekDragValueMillis = value;
    });
  }

  Future<void> _onSeekEnd(double value) async {
    if (_playingItemId == null || _loadedItemId != _playingItemId) return;
    try {
      final target = _seekDragValueMillis ?? value;
      final targetDuration = Duration(milliseconds: target.round());
      await _seekToTarget(targetDuration);
      if (mounted) {
        setState(() {
          _currentPosition = targetDuration;
        });
      }
    } catch (_) {
      _toast(t('Seek failed.', 'Ileri/geri sarma basarisiz.'));
    } finally {
      if (mounted) {
        setState(() {
          _isSeeking = false;
          _seekDragValueMillis = null;
        });
      }
    }
  }

  Future<void> _seekToTarget(Duration targetDuration) async {
    await _audioPlayer.seek(targetDuration);
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final reached = (_audioPlayer.position - targetDuration).inMilliseconds.abs() < 1200;
    if (!reached) {
      await _seekWithReload(targetDuration);
    }
  }

  Future<void> _seekWithReload(Duration target) async {
    if (_playingItemId == null) return;
    QueueItem? playingItem;
    for (final item in _items) {
      if (item.id == _playingItemId) {
        playingItem = item;
        break;
      }
    }
    if (playingItem == null) return;
    final fallbackUrl = _loadedAudioUrl;
    if (fallbackUrl == null) return;
    await _audioPlayer.setUrl(fallbackUrl, initialPosition: target);
    _loadedItemId = playingItem.id;
    await _audioPlayer.setSpeed(_playbackSpeed);
    await _audioPlayer.play();
  }

  Future<void> _seekBySeconds(QueueItem item, int deltaSeconds) async {
    if (_playingItemId != item.id) {
      _toast(t('Play this track first.', 'Once bu parcayi oynatin.'));
      return;
    }
    try {
      final current = _audioPlayer.position;
      final total = _audioPlayer.duration ?? _currentDuration;
      final targetMs = (current.inMilliseconds + deltaSeconds * 1000)
          .clamp(0, total.inMilliseconds > 0 ? total.inMilliseconds : current.inMilliseconds);
      await _seekToTarget(Duration(milliseconds: targetMs));
    } catch (_) {
      _toast(t('Seek failed.', 'Ileri/geri sarma basarisiz.'));
    }
  }

  Future<void> _playAdjacentTrack({required QueueItem anchorItem, required int delta}) async {
    final ready = _sequenceItems().where((i) => i.isReady).toList(growable: false);
    if (ready.isEmpty) return;
    final anchorId = _playingItemId ?? anchorItem.id;
    final currentIndex = ready.indexWhere((i) => i.id == anchorId);
    if (currentIndex == -1) return;
    final targetIndex = currentIndex + delta;
    if (targetIndex < 0 || targetIndex >= ready.length) {
      _toast(delta < 0 ? t('No previous track.', 'Onceki parca yok.') : t('No next track.', 'Sonraki parca yok.'));
      return;
    }
    await _togglePlay(ready[targetIndex]);
  }

  Future<void> _downloadAllInPlaylist() async {
    if (_bulkDownloading) return;
    final targets = _sequenceItems().where((i) => i.isReady && !_hasOfflineBytes(i.id)).toList(growable: false);
    if (targets.isEmpty) {
      _toast(t('All tracks already downloaded.', 'Tum parcalar zaten indirildi.'));
      return;
    }
    setState(() {
      _bulkDownloading = true;
      _bulkTotal = targets.length;
      _bulkDone = 0;
    });
    for (final item in targets) {
      final ok = await _downloadAndCache(item, silentSuccess: true);
      if (mounted) {
        setState(() {
          if (ok) _bulkDone += 1;
        });
      }
    }
    if (mounted) {
      setState(() {
        _bulkDownloading = false;
      });
    }
    _toast(t('Playlist download completed.', 'Playlist indirme tamamlandi.'));
  }

  void _toast(String message) {
    Fluttertoast.showToast(msg: message, toastLength: Toast.LENGTH_SHORT);
  }

  void _snack(String message) {
    _toast(message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final queueItems = ref.watch(queueItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('walkCast Queue', 'walkCast Liste')),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsScreen(languageCode: widget.languageCode),
                ),
              );
              await _refresh();
            },
            icon: const Icon(Icons.settings_rounded),
            tooltip: t('Settings', 'Ayarlar'),
          ),
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: t('Refresh', 'Yenile'),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.isDarkMode
                ? const [Color(0xFF0A1513), Color(0xFF101E1B), Color(0xFF0D1614)]
                : const [Color(0xFFF4FBF8), Color(0xFFF8F6FF), Color(0xFFFFF7F1)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: queueItems.when(
          data: (items) {
            if (!_seededFromApi) {
              _items = List<QueueItem>.from(items);
              _seededFromApi = true;
            }

            final allPlaylistNames = <String>{'All'}..addAll(_items.map((e) => e.playlistLabel));
            final visibleItems = _visibleItems();

            if (visibleItems.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _topControls(allPlaylistNames.toList()..sort()),
                  const SizedBox(height: 180),
                  Center(child: Text(t('No items in selected playlist.', 'Secili oynatma listesinde parca yok.'))),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
              itemCount: visibleItems.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _topControls(allPlaylistNames.toList()..sort());
                }

                final item = visibleItems[index - 1];
                final globalIndex = _items.indexOf(item);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: QueueItemCard(
                    key: ValueKey(item.id),
                    item: item,
                    isTopCard: index == 1,
                    isActiveItem: _playingItemId == item.id,
                    isAudioRunning: _playingItemId == item.id && _isAudioRunning,
                    isOfflineSaved: _offlineSavedIds.contains(item.id),
                    isZebraOdd: (index - 1).isOdd,
                    languageCode: widget.languageCode,
                    progress: item.id == _playingItemId && _currentDuration.inMilliseconds > 0
                        ? (_currentPosition.inMilliseconds / _currentDuration.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0,
                    isDownloading: _downloadingIds.contains(item.id),
                    downloadProgress: _downloadProgressById[item.id] ?? 0,
                    downloadEtaSeconds: _downloadEtaSecsById[item.id],
                    currentPosition: item.id == _playingItemId
                        ? Duration(milliseconds: (_isSeeking ? (_seekDragValueMillis ?? _currentPosition.inMilliseconds.toDouble()) : _currentPosition.inMilliseconds.toDouble()).round())
                        : Duration.zero,
                    totalDuration: item.id == _playingItemId ? _currentDuration : Duration.zero,
                    onSeek: _seekToMillis,
                    onSeekStart: _onSeekStart,
                    onSeekEnd: _onSeekEnd,
                    onPlay: () => _togglePlay(item),
                    onMoveUp: () => _moveUp(globalIndex),
                    onMoveDown: () => _moveDown(globalIndex),
                    onDownload: () => _download(item),
                    onToggleOffline: () => _toggleOffline(item),
                    onFastRewind: () => _seekBySeconds(item, -10),
                    onFastForward: () => _seekBySeconds(item, 10),
                    onPreviousTrack: () => _playAdjacentTrack(anchorItem: item, delta: -1),
                    onNextTrack: () => _playAdjacentTrack(anchorItem: item, delta: 1),
                    onMarkListened: () => _markAsListened(item),
                    onDeleteTrack: () => _deleteTrack(item),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 140),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Could not load queue.\n$error',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _topControls(List<String> playlists) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panel = isDark ? const Color(0xFF1A2623) : const Color(0xFFFFFFFF);
    final border = isDark ? const Color(0xFF3A5550) : const Color(0xFFD8E1DD);
    final titleColor = isDark ? const Color(0xFFEAF4F1) : const Color(0xFF1D2A26);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x22000000) : const Color(0x140B8F7A),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(t('Playlist', 'Oynatma Listesi'), style: TextStyle(fontWeight: FontWeight.w700, color: titleColor)),
              const Spacer(),
              IconButton(
                icon: Icon(widget.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
                onPressed: widget.onThemeToggle,
                tooltip: t('Theme', 'Tema'),
              ),
              const SizedBox(width: 4),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(value: 'en', label: Text('EN')),
                  ButtonSegment<String>(value: 'tr', label: Text('TR')),
                ],
                selected: {widget.languageCode},
                onSelectionChanged: (values) => widget.onLanguageChanged(values.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: playlists.map((name) {
                final selected = name == _selectedPlaylist;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    label: Text(name),
                    labelStyle: TextStyle(color: selected ? Colors.white : titleColor),
                    selectedColor: const Color(0xFF355E56),
                    backgroundColor: isDark ? const Color(0xFF12201D) : const Color(0xFFF1F5F3),
                    onSelected: (_) => setState(() => _selectedPlaylist = name),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _bulkDownloading ? null : _downloadAllInPlaylist,
                icon: const Icon(Icons.download_for_offline_rounded),
                label: Text(t('Download playlist', 'Playlist indir')),
              ),
              if (_bulkDownloading) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: _bulkTotal == 0 ? null : (_bulkDone / _bulkTotal).clamp(0, 1)),
                      const SizedBox(height: 4),
                      Text(
                        t('Downloading: $_bulkDone/$_bulkTotal', 'Indiriliyor: $_bulkDone/$_bulkTotal'),
                        style: TextStyle(color: titleColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(t('Play mode', 'Calma modu'), style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(value: 'all', label: Text(t('Play all', 'Tumunu cal'))),
                  ButtonSegment<String>(value: 'single', label: Text(t('Track by track', 'Tane tane'))),
                ],
                selected: {_playMode},
                onSelectionChanged: (values) => _onPlayModeChanged(values.first),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 18, color: titleColor),
              const SizedBox(width: 6),
              Text('${_playbackSpeed.toStringAsFixed(2)}x', style: TextStyle(color: titleColor)),
            ],
          ),
          Slider(
            min: 1.0,
            max: 2.0,
            divisions: 8,
            value: _playbackSpeed,
            onChanged: _onSpeedChanged,
          ),
        ],
      ),
    );
  }
}
