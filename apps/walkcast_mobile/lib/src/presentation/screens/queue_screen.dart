// ignore_for_file: experimental_member_use

import 'dart:async';
import 'package:audio_service/audio_service.dart';
import '../../core/audio/walkcast_audio_handler.dart';
import '../../data/offline/offline_audio_store.dart';

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
import 'about_screen.dart';
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

class _QueueScreenState extends ConsumerState<QueueScreen> {
  static const String _playModeAll = 'all';
  static const String _playModeSingle = 'single';

  late final WalkCastAudioHandler _handler;
  late final AudioPlayer _audioPlayer;
  late final OfflineAudioStore _offlineStore;
  String _serverBase = AppConfig.apiBaseUrl;
  Box? _prefs;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );
  StreamSubscription<PlaybackState>? _playerStateSub;
  StreamSubscription<MediaItem?>? _mediaSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<dynamic>? _errorSub;

  List<QueueItem> _items = <QueueItem>[];
  bool _seededFromApi = false;
  int? _playingItemId;
  int? _loadedItemId;
  Set<int> _offlineSavedIds = <int>{};
  String _selectedPlaylist = 'All';
  double _playbackSpeed = 1.0;
  String _playMode = _playModeSingle;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  bool _isAudioRunning = false;
  bool _isSeeking = false;
  double? _seekDragValueMillis;
  final Set<int> _downloadingIds = <int>{};
  final Map<int, double> _downloadProgressById = <int, double>{};
  final Map<int, int> _downloadEtaSecsById = <int, int>{};
  final Map<int, DateTime> _downloadStartById = <int, DateTime>{};
  bool _bulkDownloading = false;
  int _bulkTotal = 0;
  int _bulkDone = 0;
  int _bulkProcessed = 0;
  bool _bulkCancelled = false;
  int? _bulkCurrentId;
  Set<int> _bulkFailedIds = {};
  final Map<int, Future<bool>> _downloadJobs = {};
  int _storageBytes = 0;
  bool _usingOfflineQueue = false;

  bool get _isTr => widget.languageCode == 'tr';
  String t(String en, String tr) => _isTr ? tr : en;

  @override
  void initState() {
    super.initState();
    _handler = ref.read(audioHandlerProvider);
    _audioPlayer = _handler.player;
    _offlineStore = ref.read(offlineStoreProvider);
    if (Hive.isBoxOpen('walkcast_prefs')) {
      _prefs = Hive.box('walkcast_prefs');
      _playbackSpeed =
          ((_prefs!.get('playback_speed', defaultValue: 1.0) as num).toDouble())
              .clamp(1.0, 2.0);
      _playMode =
          _prefs!.get('play_mode', defaultValue: _playModeSingle) as String;
      if (_playMode != _playModeAll) _playMode = _playModeSingle;
    }
    _syncOffline();
    unawaited(_audioPlayer.setSpeed(_playbackSpeed));
    _handler.onNeedsDownload = (item) {
      unawaited(_downloadAndCache(item, silentSuccess: true));
    };
    _playerStateSub = _handler.playbackState.listen((state) {
      if (!mounted) return;
      setState(() {
        _loadedItemId = _handler.loadedItemId;
        _isAudioRunning = state.playing && _loadedItemId != null;
        _currentDuration = _loadedItemId == null
            ? Duration.zero
            : (_audioPlayer.duration ?? Duration.zero);
      });
    });
    _mediaSub = _handler.mediaItem.listen((media) {
      if (!mounted) return;
      final id = media?.extras?['itemId'] as int?;
      setState(() {
        if (_playingItemId != id) {
          _currentPosition = Duration.zero;
          _currentDuration = Duration.zero;
          _isSeeking = false;
          _seekDragValueMillis = null;
        }
        _playingItemId = id;
      });
    });
    _positionSub = _audioPlayer.positionStream.listen((position) {
      if (!mounted || _isSeeking || _loadedItemId == null) return;
      setState(() => _currentPosition = position);
    });
    _durationSub = _audioPlayer.durationStream.listen((duration) {
      if (!mounted || _loadedItemId == null) return;
      setState(() => _currentDuration = duration ?? Duration.zero);
    });
    _errorSub = _handler.customEvent.listen((event) {
      if (mounted && event is Map && event.containsKey('error')) {
        _toast(
          t(
            'Playback failed. Please try again.',
            'Oynatma basarisiz. Tekrar deneyin.',
          ),
        );
      }
    });
  }

  void _syncOffline() {
    _offlineSavedIds = _offlineStore.savedIds(_serverBase);
    _storageBytes = _offlineStore.sizeBytes(_serverBase);
  }

  void _syncPlaybackQueue() {
    _handler.configureQueue(
      _sequenceItems(),
      _serverBase,
      autoAdvance: _playMode == _playModeAll,
    );
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _mediaSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _errorSub?.cancel();
    _handler.onNeedsDownload = null;
    _offlineStore.cancelAll(_serverBase);
    _bulkCancelled = true;
    _dio.close(force: true);
    // AudioService owns the player so lock-screen playback survives navigation.
    super.dispose();
  }

  Future<void> _refresh() async {
    final server = AppConfig.apiBaseUrl;
    if (_serverBase != server) {
      _bulkCancelled = true;
      _offlineStore.cancelAll(_serverBase);
      await Future.wait(_downloadJobs.values.toList());
      await _handler.stop();
      if (!mounted) return;
      setState(() {
        _serverBase = server;
        _items = [];
        _selectedPlaylist = 'All';
        _bulkFailedIds.clear();
        _syncOffline();
      });
    }
    _seededFromApi = false;
    ref.invalidate(queueItemsProvider);
    try {
      await ref.read(queueItemsProvider.future);
    } catch (_) {
      if (mounted) _toast(t('Could not refresh queue.', 'Liste yenilenemedi.'));
    }
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
        'This removes the track from the server and this device.',
        'Parca sunucudan ve bu cihazdan silinecek.',
      ),
      confirmText: t('Delete', 'Sil'),
    );
    if (!confirmed || !mounted) return;
    try {
      await _dio.delete('$_serverBase/api/v1/items/${item.id}');
      if (_handler.loadedItemId == item.id) await _handler.stop();
      await _offlineStore.remove(_serverBase, item.id);
      final cache = Hive.isBoxOpen('walkcast_queue_cache')
          ? Hive.box('walkcast_queue_cache')
          : null;
      final key = serverCacheKey(_serverBase);
      final stored = cache?.get(key);
      if (stored is List) {
        await cache!.put(
          key,
          stored.where((row) => (row as Map)['id'] != item.id).toList(),
        );
      }
      if (!mounted) return;
      setState(() {
        _items.removeWhere((row) => row.id == item.id);
        _syncOffline();
      });
      _syncPlaybackQueue();
      _toast(t('Track deleted.', 'Parca silindi.'));
      await _refresh();
    } catch (_) {
      if (mounted) _toast(t('Could not delete track.', 'Parca silinemedi.'));
    }
  }

  Future<void> _togglePlay(QueueItem item) async {
    if (!item.isReady && !_hasOfflineBytes(item.id)) {
      _snack(t('Audio file not ready yet.', 'Ses dosyasi henuz hazir degil.'));
      return;
    }
    _syncPlaybackQueue();
    try {
      if (_handler.loadedItemId == item.id &&
          _handler.loadedServer == _serverBase) {
        if (_audioPlayer.playing) {
          await _handler.pause();
        } else {
          await _handler.play();
        }
      } else {
        _resetSeekState();
        await _handler.loadItem(item);
      }
    } catch (_) {
      if (mounted) _snack(t('Could not play track.', 'Bu parca oynatilamadi.'));
    }
  }

  Future<void> _download(QueueItem item) async {
    if (_downloadingIds.contains(item.id)) {
      _offlineStore.cancel(_serverBase, item.id);
      return;
    }
    if (_hasOfflineBytes(item.id)) {
      _toast(t('Already saved offline.', 'Zaten cevrimdisi kayitli.'));
      return;
    }
    await _downloadAndCache(item);
  }

  bool _hasOfflineBytes(int id) => _offlineStore.contains(_serverBase, id);

  Future<bool> _downloadAndCache(QueueItem item, {bool silentSuccess = false}) {
    final existing = _downloadJobs[item.id];
    if (existing != null) return existing;
    final job = _performDownload(item, silentSuccess: silentSuccess)
        .whenComplete(() {
          _downloadJobs.remove(item.id);
        });
    _downloadJobs[item.id] = job;
    return job;
  }

  Future<bool> _performDownload(
    QueueItem item, {
    required bool silentSuccess,
  }) async {
    if (!mounted || !item.isReady) return false;
    final server = _serverBase;
    setState(() {
      _downloadingIds.add(item.id);
      _downloadProgressById[item.id] = 0;
      _downloadStartById[item.id] = DateTime.now();
    });
    try {
      await _offlineStore.download(
        server,
        item.id,
        audioUrls(server, item),
        onProgress: (received, total) {
          if (!mounted || server != _serverBase || total <= 0) return;
          final elapsed =
              DateTime.now()
                  .difference(_downloadStartById[item.id]!)
                  .inMilliseconds /
              1000;
          setState(() {
            _downloadProgressById[item.id] = (received / total).clamp(0, 1);
            if (elapsed > 0.6 && received > 0) {
              _downloadEtaSecsById[item.id] =
                  ((total - received) / (received / elapsed)).ceil().clamp(
                    0,
                    36000,
                  );
            }
          });
        },
      );
      if (mounted && !silentSuccess) {
        _toast(
          t(
            'Downloaded for offline use.',
            'Cevrimdisi kullanim icin indirildi.',
          ),
        );
      }
      return true;
    } catch (error) {
      if (mounted && !silentSuccess) {
        _toast(
          error is DioException && CancelToken.isCancel(error)
              ? t('Download cancelled.', 'Indirme iptal edildi.')
              : t(
                  'Download failed. Tap download to retry.',
                  'Indirme basarisiz. Tekrar denemek icin indir dugmesine basin.',
                ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(item.id);
          _downloadStartById.remove(item.id);
          _downloadProgressById.remove(item.id);
          _downloadEtaSecsById.remove(item.id);
          _syncOffline();
        });
      }
    }
  }

  Future<void> _toggleOffline(QueueItem item) async {
    if (!_hasOfflineBytes(item.id)) {
      await _downloadAndCache(item);
      return;
    }
    if (!await _confirmAction(
      title: t('Remove offline copy?', 'Cevrimdisi kopya silinsin mi?'),
      message: t(
        'The server copy will be kept.',
        'Sunucudaki kopya korunacak.',
      ),
      confirmText: t('Remove', 'Kaldir'),
    )) {
      return;
    }
    try {
      if (_handler.loadedItemId == item.id) await _handler.stop();
      await _offlineStore.remove(_serverBase, item.id);
      if (mounted) setState(_syncOffline);
    } catch (_) {
      if (mounted) {
        _toast(
          t('Could not remove offline copy.', 'Cevrimdisi kopya silinemedi.'),
        );
      }
    }
  }

  Future<void> _clearOffline() async {
    if (!await _confirmAction(
      title: t('Clear offline files?', 'Cevrimdisi dosyalar silinsin mi?'),
      message: t(
        'Downloaded audio on this device will be removed. Server files will be kept.',
        'Bu cihazdaki indirilen sesler silinecek. Sunucudaki dosyalar korunacak.',
      ),
      confirmText: t('Clear', 'Temizle'),
    )) {
      return;
    }
    try {
      _bulkCancelled = true;
      if (_handler.loadedItemId != null &&
          _hasOfflineBytes(_handler.loadedItemId!)) {
        await _handler.stop();
      }
      await _offlineStore.clear(_serverBase);
      if (mounted) setState(_syncOffline);
    } catch (_) {
      if (mounted) {
        _toast(
          t(
            'Could not clear offline files.',
            'Cevrimdisi dosyalar temizlenemedi.',
          ),
        );
      }
    }
  }

  List<QueueItem> _sequenceItems() {
    return _selectedPlaylist == 'All'
        ? List<QueueItem>.from(_items)
        : _items
              .where((item) => item.playlistLabel == _selectedPlaylist)
              .toList(growable: true);
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
    _syncPlaybackQueue();
  }

  void _moveDown(int index) {
    if (index >= _items.length - 1) return;
    setState(() {
      final tmp = _items[index + 1];
      _items[index + 1] = _items[index];
      _items[index] = tmp;
    });
    _syncPlaybackQueue();
  }

  void _onSpeedChanged(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    _audioPlayer.setSpeed(speed);
    _prefs?.put('playback_speed', speed);
  }

  void _onPlayModeChanged(String mode) {
    setState(() => _playMode = mode);
    _syncPlaybackQueue();
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
    final reached =
        (_audioPlayer.position - targetDuration).inMilliseconds.abs() < 1200;
    if (!reached) {
      await _seekWithReload(targetDuration);
    }
  }

  Future<void> _seekWithReload(Duration target) async {
    final id = _handler.loadedItemId;
    if (id == null) return;
    final items = _items.where((item) => item.id == id);
    if (items.isEmpty) return;
    await _handler.loadItem(
      items.first,
      position: target,
      startPlaying: _audioPlayer.playing,
    );
  }

  Future<void> _seekBySeconds(QueueItem item, int deltaSeconds) async {
    if (_playingItemId != item.id) {
      _toast(t('Play this track first.', 'Once bu parcayi oynatin.'));
      return;
    }
    try {
      final current = _audioPlayer.position;
      final total = _audioPlayer.duration ?? _currentDuration;
      final targetMs = (current.inMilliseconds + deltaSeconds * 1000).clamp(
        0,
        total.inMilliseconds > 0
            ? total.inMilliseconds
            : current.inMilliseconds,
      );
      await _seekToTarget(Duration(milliseconds: targetMs));
    } catch (_) {
      _toast(t('Seek failed.', 'Ileri/geri sarma basarisiz.'));
    }
  }

  Future<void> _playAdjacentTrack({
    required QueueItem anchorItem,
    required int delta,
  }) async {
    _syncPlaybackQueue();
    if (_handler.loadedItemId == null) {
      await _togglePlay(anchorItem);
      return;
    }
    try {
      if (delta < 0) {
        await _handler.skipToPrevious();
      } else {
        await _handler.skipToNext();
      }
    } catch (_) {
      if (mounted) _toast(t('Could not play track.', 'Bu parca oynatilamadi.'));
    }
  }

  void _cancelBulkDownload() {
    _bulkCancelled = true;
    final current = _bulkCurrentId;
    if (current != null) _offlineStore.cancel(_serverBase, current);
  }

  Future<void> _downloadAllInPlaylist({bool retryOnly = false}) async {
    if (_bulkDownloading) return;
    final targets = _sequenceItems()
        .where(
          (item) =>
              item.isReady &&
              !_hasOfflineBytes(item.id) &&
              (!retryOnly || _bulkFailedIds.contains(item.id)),
        )
        .toList();
    if (targets.isEmpty) {
      _toast(
        t('All tracks already downloaded.', 'Tum parcalar zaten indirildi.'),
      );
      return;
    }
    setState(() {
      _bulkDownloading = true;
      _bulkCancelled = false;
      _bulkTotal = targets.length;
      _bulkDone = 0;
      _bulkProcessed = 0;
      _bulkFailedIds = {};
    });
    for (final item in targets) {
      if (_bulkCancelled || !mounted) break;
      _bulkCurrentId = item.id;
      final ok = await _downloadAndCache(item, silentSuccess: true);
      if (!mounted) break;
      setState(() {
        _bulkProcessed++;
        if (ok) {
          _bulkDone++;
        } else if (!_bulkCancelled) {
          _bulkFailedIds.add(item.id);
        }
      });
    }
    _bulkCurrentId = null;
    if (!mounted) return;
    setState(() => _bulkDownloading = false);
    final failed = _bulkFailedIds.length;
    _toast(
      _bulkCancelled
          ? t(
              'Download cancelled. $_bulkDone files saved.',
              'Indirme iptal edildi. $_bulkDone dosya kaydedildi.',
            )
          : t(
              '$_bulkDone/$_bulkTotal downloaded; $failed failed.',
              '$_bulkDone/$_bulkTotal indirildi; $failed basarisiz.',
            ),
    );
  }

  void _toast(String message) {
    Fluttertoast.showToast(msg: message, toastLength: Toast.LENGTH_SHORT);
  }

  void _snack(String message) {
    _toast(message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final queueItems = ref.watch(queueItemsProvider);
    _usingOfflineQueue = ref.watch(queueOfflineProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('walkCast Queue', 'walkCast Liste')),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      AboutScreen(languageCode: widget.languageCode),
                ),
              );
            },
            icon: const Icon(Icons.info_outline),
            tooltip: t('About', 'Hakkinda'),
          ),
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      SettingsScreen(languageCode: widget.languageCode),
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
                ? const [
                    Color(0xFF0A1513),
                    Color(0xFF101E1B),
                    Color(0xFF0D1614),
                  ]
                : const [
                    Color(0xFFF4FBF8),
                    Color(0xFFF8F6FF),
                    Color(0xFFFFF7F1),
                  ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: queueItems.when(
            data: (items) {
              if (!_seededFromApi) {
                _items = List<QueueItem>.from(items);
                _seededFromApi = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _syncPlaybackQueue();
                });
              }

              final allPlaylistNames = <String>{'All'}
                ..addAll(_items.map((e) => e.playlistLabel));
              final visibleItems = _visibleItems();

              if (visibleItems.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _topControls(allPlaylistNames.toList()..sort()),
                    const SizedBox(height: 180),
                    Center(
                      child: Text(
                        t(
                          'No items in selected playlist.',
                          'Secili oynatma listesinde parca yok.',
                        ),
                      ),
                    ),
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
                      isAudioRunning:
                          _playingItemId == item.id && _isAudioRunning,
                      isOfflineSaved: _offlineSavedIds.contains(item.id),
                      isZebraOdd: (index - 1).isOdd,
                      languageCode: widget.languageCode,
                      progress:
                          item.id == _playingItemId &&
                              _currentDuration.inMilliseconds > 0
                          ? (_currentPosition.inMilliseconds /
                                    _currentDuration.inMilliseconds)
                                .clamp(0.0, 1.0)
                          : 0.0,
                      isDownloading: _downloadingIds.contains(item.id),
                      downloadProgress: _downloadProgressById[item.id] ?? 0,
                      downloadEtaSeconds: _downloadEtaSecsById[item.id],
                      currentPosition: item.id == _playingItemId
                          ? Duration(
                              milliseconds:
                                  (_isSeeking
                                          ? (_seekDragValueMillis ??
                                                _currentPosition.inMilliseconds
                                                    .toDouble())
                                          : _currentPosition.inMilliseconds
                                                .toDouble())
                                      .round(),
                            )
                          : Duration.zero,
                      totalDuration: item.id == _playingItemId
                          ? _currentDuration
                          : Duration.zero,
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
                      onPreviousTrack: () =>
                          _playAdjacentTrack(anchorItem: item, delta: -1),
                      onNextTrack: () =>
                          _playAdjacentTrack(anchorItem: item, delta: 1),
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
    final titleColor = isDark
        ? const Color(0xFFEAF4F1)
        : const Color(0xFF1D2A26);

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
              Text(
                t('Playlist', 'Oynatma Listesi'),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(
                  widget.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                ),
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
                onSelectionChanged: (values) =>
                    widget.onLanguageChanged(values.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: playlists
                  .map((name) {
                    final selected = name == _selectedPlaylist;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: selected,
                        label: Text(name),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : titleColor,
                        ),
                        selectedColor: const Color(0xFF355E56),
                        backgroundColor: isDark
                            ? const Color(0xFF12201D)
                            : const Color(0xFFF1F5F3),
                        onSelected: (_) {
                          setState(() => _selectedPlaylist = name);
                          _syncPlaybackQueue();
                        },
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 10),
          if (_usingOfflineQueue)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                t(
                  'Server unavailable — showing saved queue. Downloaded tracks are playable.',
                  'Sunucuya ulasilamiyor — kayitli liste gosteriliyor. Indirilen parcalar oynatilabilir.',
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  t(
                    'Offline storage: ${(_storageBytes / 1048576).toStringAsFixed(1)} MB',
                    'Cevrimdisi depolama: ${(_storageBytes / 1048576).toStringAsFixed(1)} MB',
                  ),
                ),
              ),
              IconButton(
                onPressed: _offlineSavedIds.isEmpty ? null : _clearOffline,
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: t(
                  'Clear offline files',
                  'Cevrimdisi dosyalari temizle',
                ),
              ),
            ],
          ),
          if (_bulkDownloading)
            TextButton.icon(
              onPressed: _cancelBulkDownload,
              icon: const Icon(Icons.cancel_outlined),
              label: Text(t('Cancel download', 'Indirmeyi iptal et')),
            ),
          if (!_bulkDownloading && _bulkFailedIds.isNotEmpty)
            TextButton.icon(
              onPressed: () => _downloadAllInPlaylist(retryOnly: true),
              icon: const Icon(Icons.refresh),
              label: Text(
                t(
                  'Retry ${_bulkFailedIds.length} failed downloads',
                  '${_bulkFailedIds.length} basarisiz indirmeyi tekrar dene',
                ),
              ),
            ),
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
                      LinearProgressIndicator(
                        value: _bulkTotal == 0
                            ? null
                            : (_bulkProcessed / _bulkTotal).clamp(0, 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t(
                          'Processed: $_bulkProcessed/$_bulkTotal',
                          'Islenen: $_bulkProcessed/$_bulkTotal',
                        ),
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
              Text(
                t('Play mode', 'Calma modu'),
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment<String>(
                    value: 'all',
                    label: Text(t('Play all', 'Tumunu cal')),
                  ),
                  ButtonSegment<String>(
                    value: 'single',
                    label: Text(t('Track by track', 'Tane tane')),
                  ),
                ],
                selected: {_playMode},
                onSelectionChanged: (values) =>
                    _onPlayModeChanged(values.first),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 18, color: titleColor),
              const SizedBox(width: 6),
              Text(
                '${_playbackSpeed.toStringAsFixed(2)}x',
                style: TextStyle(color: titleColor),
              ),
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
