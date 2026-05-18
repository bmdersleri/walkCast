import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/download_helper.dart';
import '../../domain/entities/queue_item.dart';
import '../controllers/queue_controller.dart';
import '../widgets/queue_item_card.dart';

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
  final AudioPlayer _audioPlayer = AudioPlayer();
  Box? _prefs;
  final Dio _dio = Dio();
  StreamSubscription<PlayerState>? _playerStateSub;

  List<QueueItem> _items = <QueueItem>[];
  bool _seededFromApi = false;
  int? _playingItemId;
  int? _loadedItemId;
  Set<int> _offlineSavedIds = <int>{};
  String _selectedPlaylist = 'All';
  double _playbackSpeed = 1.0;
  String _playMode = 'all';
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  bool _isCurrentlyPlaying = false;
  bool _isSeeking = false;
  double? _seekDragValueMillis;
  final Set<int> _downloadingIds = <int>{};
  final Map<int, double> _downloadProgressById = <int, double>{};

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
      _playMode = _prefs!.get('play_mode', defaultValue: 'all') as String;
      _audioPlayer.setSpeed(_playbackSpeed);
    }
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isCurrentlyPlaying = state.playing;
        });
      }
      if (state.processingState == ProcessingState.completed) {
        _handleTrackCompleted();
      }
    });
    _audioPlayer.positionStream.listen((pos) {
      if (!mounted) return;
      if (_isSeeking) return;
      setState(() {
        _currentPosition = pos;
      });
    });
    _audioPlayer.durationStream.listen((dur) {
      if (!mounted || dur == null) return;
      setState(() {
        _currentDuration = dur;
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
      }
      await _refresh();
    } catch (_) {
      _toast(t('Could not delete track.', 'Parca silinemedi.'));
    }
  }

  String? _audioUrlFor(QueueItem item) {
    final path = item.filepath;
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    final fileName = path.split('/').last;
    return '${AppConfig.apiBaseUrl}/backend/storage/audio/$fileName';
  }

  Future<void> _togglePlay(QueueItem item) async {
    final audioUrl = _audioUrlFor(item);
    if (audioUrl == null) {
      _snack(t('Audio file is not ready yet.', 'Ses dosyasi henuz hazir degil.'));
      return;
    }

    try {
      if (_playingItemId == item.id && _audioPlayer.playing) {
        await _audioPlayer.pause();
        return;
      }

      if (_playingItemId == item.id && _loadedItemId == item.id && !_audioPlayer.playing) {
        await _audioPlayer.play();
        return;
      }

      if (mounted) {
        setState(() {
          _playingItemId = item.id;
        });
      }

      await _audioPlayer.setUrl(audioUrl);
      _loadedItemId = item.id;
      await _audioPlayer.setSpeed(_playbackSpeed);
      await _audioPlayer.play();
    } catch (_) {
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
    final audioUrl = _audioUrlFor(item);
    if (audioUrl == null) {
      _snack(t('Audio file is not ready for download.', 'Ses dosyasi indirilmeye hazir degil.'));
      return;
    }
    final safeTitle = (item.title ?? 'track_${item.id}')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp('_+'), '_');
    final fileName = '${safeTitle.isEmpty ? 'track_${item.id}' : safeTitle}.mp3';

    setState(() {
      _downloadingIds.add(item.id);
      _downloadProgressById[item.id] = 0;
    });

    try {
      await downloadWithProgress(
        url: audioUrl,
        fileName: fileName,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _downloadProgressById[item.id] = progress;
          });
        },
      );
      _toast(t('Download completed.', 'Indirme tamamlandi.'));
    } catch (_) {
      _toast(t('Download failed.', 'Indirme basarisiz oldu.'));
    } finally {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _toggleOffline(QueueItem item) async {
    final next = Set<int>.from(_offlineSavedIds);
    if (next.contains(item.id)) {
      next.remove(item.id);
      _snack(t('Removed from offline list.', 'Cevrimdisi listesinden kaldirildi.'));
    } else {
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

  Future<void> _playOffline(QueueItem item) async {
    if (!_offlineSavedIds.contains(item.id)) {
      _snack(t('Save offline first.', 'Once cevrimdisi kaydet.'));
      return;
    }
    await _togglePlay(item);
  }

  Future<void> _handleTrackCompleted() async {
    if (_playMode != 'all' || _playingItemId == null) {
      if (mounted) {
        setState(() {
          _playingItemId = null;
          _loadedItemId = null;
        });
      }
      return;
    }

    final visibleItems = _visibleItems();
    final ready = visibleItems.where((i) => i.isReady).toList(growable: false);
    final currentIndex = ready.indexWhere((i) => i.id == _playingItemId);
    if (currentIndex == -1 || currentIndex + 1 >= ready.length) {
      if (mounted) {
        setState(() {
          _playingItemId = null;
          _loadedItemId = null;
        });
      }
      return;
    }
    await _togglePlay(ready[currentIndex + 1]);
  }

  List<QueueItem> _visibleItems() {
    final base = _selectedPlaylist == 'All'
        ? List<QueueItem>.from(_items)
        : _items.where((item) => item.playlistLabel == _selectedPlaylist).toList(growable: true);
    if (_playingItemId == null) return base;
    final idx = base.indexWhere((item) => item.id == _playingItemId);
    if (idx <= 0) return base;
    final playing = base.removeAt(idx);
    base.insert(0, playing);
    return base;
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
    if (_playingItemId == null) return;
    try {
      final target = _seekDragValueMillis ?? value;
      await _audioPlayer.seek(Duration(milliseconds: target.round()));
      if (mounted) {
        setState(() {
          _currentPosition = Duration(milliseconds: target.round());
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
      await _audioPlayer.seek(Duration(milliseconds: targetMs));
    } catch (_) {
      _toast(t('Seek failed.', 'Ileri/geri sarma basarisiz.'));
    }
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
                    item: item,
                    isPlaying: _playingItemId == item.id && _isCurrentlyPlaying,
                    isOfflineSaved: _offlineSavedIds.contains(item.id),
                    isZebraOdd: (index - 1).isOdd,
                    languageCode: widget.languageCode,
                    progress: item.id == _playingItemId && _currentDuration.inMilliseconds > 0
                        ? (_currentPosition.inMilliseconds / _currentDuration.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0,
                    isDownloading: _downloadingIds.contains(item.id),
                    downloadProgress: _downloadProgressById[item.id] ?? 0,
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
                    onPlayOffline: () => _playOffline(item),
                    onFastRewind: () => _seekBySeconds(item, -10),
                    onFastForward: () => _seekBySeconds(item, 10),
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
