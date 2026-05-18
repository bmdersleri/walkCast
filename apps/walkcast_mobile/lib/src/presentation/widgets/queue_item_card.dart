import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../domain/entities/queue_item.dart';

class QueueItemCard extends StatelessWidget {
  const QueueItemCard({
    super.key,
    required this.item,
    required this.onPlay,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDownload,
    required this.onToggleOffline,
    required this.onFastRewind,
    required this.onFastForward,
    required this.onPreviousTrack,
    required this.onNextTrack,
    required this.onMarkListened,
    required this.onDeleteTrack,
    required this.isTopCard,
    required this.isActiveItem,
    required this.isAudioRunning,
    required this.isOfflineSaved,
    required this.isZebraOdd,
    required this.languageCode,
    required this.progress,
    required this.isDownloading,
    required this.downloadProgress,
    required this.downloadEtaSeconds,
    required this.currentPosition,
    required this.totalDuration,
    required this.onSeek,
    required this.onSeekStart,
    required this.onSeekEnd,
  });

  final QueueItem item;
  final VoidCallback onPlay;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDownload;
  final VoidCallback onToggleOffline;
  final VoidCallback onFastRewind;
  final VoidCallback onFastForward;
  final VoidCallback onPreviousTrack;
  final VoidCallback onNextTrack;
  final VoidCallback onMarkListened;
  final VoidCallback onDeleteTrack;
  final bool isTopCard;
  final bool isActiveItem;
  final bool isAudioRunning;
  final bool isOfflineSaved;
  final bool isZebraOdd;
  final String languageCode;
  final double progress;
  final bool isDownloading;
  final double downloadProgress;
  final int? downloadEtaSeconds;
  final Duration currentPosition;
  final Duration totalDuration;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekEnd;

  bool get _isTr => languageCode == 'tr';

  Color _statusColor(String status, BuildContext context) {
    switch (status) {
      case 'ready':
        return Colors.green.shade700;
      case 'error':
        return Colors.red.shade700;
      case 'downloading':
      case 'converting_mp3':
        return Colors.orange.shade700;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _statusColor(item.status, context);
    final listened = item.isListened;
    final active = isActiveItem;
    final zebraA = isDark ? const Color(0xFF23353B) : const Color(0xFFFFF1F4);
    final zebraB = isDark ? const Color(0xFF233C33) : const Color(0xFFEFFAF4);
    final cardBorder = isDark ? const Color(0xFF3A5550) : const Color(0xFFD8E1DD);
    final baseText = isDark ? const Color(0xFFEAF4F1) : const Color(0xFF1D2A26);
    final activeBg = isDark ? const Color(0xFF1E4038) : const Color(0xFFE5F8F1);
    final activeBorder = isDark ? const Color(0xFF74D3B5) : const Color(0xFF4CB99D);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: listened ? 0.58 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: active ? activeBg : (isZebraOdd ? zebraA : zebraB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? activeBorder : cardBorder, width: active ? 1.6 : 1),
          boxShadow: [
            BoxShadow(
              color: active
                  ? (isDark ? const Color(0x5539B693) : const Color(0x4439B693))
                  : (isDark ? const Color(0x22000000) : const Color(0x14000000)),
              blurRadius: active ? 16 : 10,
              offset: Offset(0, active ? 7 : 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _coverTile(isDark, item.playlistLabel, isAudioRunning, progress),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title ?? 'Untitled item #${item.id}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: baseText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              WaveformProgressBar(progress: progress, isDark: isDark),
              if (isActiveItem) ...[
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    min: 0,
                    max: max(1, totalDuration.inMilliseconds).toDouble(),
                    value: currentPosition.inMilliseconds.clamp(0, max(1, totalDuration.inMilliseconds)).toDouble(),
                    onChangeStart: onSeekStart,
                    onChanged: totalDuration.inMilliseconds > 0 ? onSeek : null,
                    onChangeEnd: totalDuration.inMilliseconds > 0 ? onSeekEnd : null,
                  ),
                ),
                Row(
                  children: [
                    Text(_fmtDuration(currentPosition), style: TextStyle(fontSize: 11, color: baseText.withValues(alpha: 0.8))),
                    const Spacer(),
                    Text(
                      '-${_fmtDuration(Duration(milliseconds: max(0, (totalDuration - currentPosition).inMilliseconds)))}',
                      style: TextStyle(fontSize: 11, color: baseText.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ],
              if (isDownloading) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: downloadProgress <= 0 ? null : downloadProgress,
                    backgroundColor: isDark ? const Color(0xFF2C3E39) : const Color(0xFFDCEAE4),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2CB597)),
                  ),
                ),
                if (downloadEtaSeconds != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _isTr
                        ? 'Kalan: ${_fmtDuration(Duration(seconds: downloadEtaSeconds!))}'
                        : 'ETA: ${_fmtDuration(Duration(seconds: downloadEtaSeconds!))}',
                    style: TextStyle(fontSize: 11, color: baseText.withValues(alpha: 0.82)),
                  ),
                ],
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(context, item.duration ?? '--:--'),
                  _chip(context, formatFileSize(item.fileSizeBytes)),
                  _chip(context, item.audioQuality.toUpperCase()),
                  _chip(context, item.status, color: statusColor.withValues(alpha: 0.15), textColor: statusColor),
                  if (listened)
                    _chip(context, _isTr ? 'dinlendi' : 'listened', color: Colors.blue.shade50, textColor: Colors.blue.shade700),
                  if (isOfflineSaved)
                    _chip(context, _isTr ? 'cevrimdisi' : 'offline', color: Colors.teal.shade50, textColor: Colors.teal.shade700),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _iconAction(
                        context,
                        icon: isAudioRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        onPressed: onPlay,
                        tooltip: isAudioRunning ? (_isTr ? 'Duraklat' : 'Pause') : (_isTr ? 'Oynat' : 'Play'),
                        tint: const Color(0xFF0B8F7A),
                        led: _buildLed(isAudioRunning: isAudioRunning, isActiveItem: isActiveItem),
                      ),
                      _iconAction(
                        context,
                        icon: Icons.download_rounded,
                        onPressed: onDownload,
                        tooltip: _isTr ? 'Indir' : 'Download',
                        tint: isOfflineSaved ? Colors.teal : null,
                      ),
                      _iconAction(
                        context,
                        icon: isOfflineSaved ? Icons.cloud_done_rounded : Icons.cloud_download_rounded,
                        onPressed: onToggleOffline,
                        tooltip: isOfflineSaved
                            ? (_isTr ? 'Cevrimdisi kayitli' : 'Offline saved')
                            : (_isTr ? 'Cevrimdisi kaydet' : 'Save offline'),
                        tint: isOfflineSaved ? Colors.teal : null,
                      ),
                      if (isTopCard)
                        _iconAction(
                          context,
                          icon: Icons.skip_previous_rounded,
                          onPressed: onPreviousTrack,
                          tooltip: _isTr ? 'Onceki parca' : 'Previous track',
                        ),
                      if (isTopCard)
                        _iconAction(
                          context,
                          icon: Icons.skip_next_rounded,
                          onPressed: onNextTrack,
                          tooltip: _isTr ? 'Sonraki parca' : 'Next track',
                        ),
                      if (isTopCard)
                        _iconAction(
                          context,
                          icon: Icons.fast_rewind_rounded,
                          onPressed: onFastRewind,
                          tooltip: _isTr ? 'Hizli geri sar' : 'Fast rewind',
                        ),
                      if (isTopCard)
                        _iconAction(
                          context,
                          icon: Icons.fast_forward_rounded,
                          onPressed: onFastForward,
                          tooltip: _isTr ? 'Hizli ileri sar' : 'Fast forward',
                        ),
                      _iconAction(
                        context,
                        icon: Icons.check_circle_rounded,
                        onPressed: onMarkListened,
                        tooltip: _isTr ? 'Dinlendi olarak isaretle' : 'Mark as listened',
                        tint: const Color(0xFF2E7D32),
                      ),
                      _iconAction(
                        context,
                        icon: Icons.delete_outline_rounded,
                        onPressed: onDeleteTrack,
                        tooltip: _isTr ? 'Parcayi sil' : 'Delete track',
                        tint: const Color(0xFFB03A2E),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A2623) : const Color(0xFFF8FBFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF3A5550) : const Color(0xFFD8E1DD)),
                    ),
                    child: Row(
                      children: [
                        _iconAction(
                          context,
                          icon: Icons.keyboard_arrow_up_rounded,
                          onPressed: onMoveUp,
                          tooltip: _isTr ? 'Yukari tasi' : 'Move up',
                        ),
                        const SizedBox(width: 4),
                        _iconAction(
                          context,
                          icon: Icons.keyboard_arrow_down_rounded,
                          onPressed: onMoveDown,
                          tooltip: _isTr ? 'Asagi tasi' : 'Move down',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coverTile(bool isDark, String playlist, bool isPlaying, double progress) {
    final (icon, pair) = _playlistVisual(playlist);

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(colors: [pair[0], pair[1]], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: isDark ? const Color(0xFF506863) : const Color(0xFFD8E1DD)),
      ),
      child: AnimatedRotation(
        turns: isPlaying ? progress * 6 : 0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.linear,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 24, color: const Color(0xFF1B3A34)),
            const Positioned(top: 8, child: Icon(Icons.music_note_rounded, size: 12, color: Color(0xFF1B3A34))),
          ],
        ),
      ),
    );
  }

  (IconData, List<Color>) _playlistVisual(String playlist) {
    final key = playlist.toLowerCase();
    if (key.contains('technology')) {
      return (Icons.memory_rounded, const [Color(0xFFBEE3F8), Color(0xFFD0F4DE)]);
    }
    if (key.contains('economy')) {
      return (Icons.trending_up_rounded, const [Color(0xFFFFD6A5), Color(0xFFFFF1C1)]);
    }
    if (key.contains('science')) {
      return (Icons.science_rounded, const [Color(0xFFE9D5FF), Color(0xFFFBCFE8)]);
    }
    if (key.contains('education')) {
      return (Icons.school_rounded, const [Color(0xFFCFFAFE), Color(0xFFDCFCE7)]);
    }
    if (key.contains('unassigned')) {
      return (Icons.library_music_rounded, const [Color(0xFFE2E8F0), Color(0xFFF1F5F9)]);
    }
    return (Icons.headphones_rounded, const [Color(0xFFFDE68A), Color(0xFFFECACA)]);
  }

  Widget _chip(BuildContext context, String label, {Color? color, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF263734) : const Color(0xFFF2F4F7)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor ??
              (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD8E8E3) : const Color(0xFF2C3640)),
        ),
      ),
    );
  }

  Widget _iconAction(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color? tint,
    Widget? led,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF3A5550) : const Color(0xFFD8E1DD)),
                color: isDark ? const Color(0xFF1A2623) : const Color(0xFFF8FBFA),
              ),
              child: Icon(
                icon,
                size: 20,
                color: tint ?? (isDark ? const Color(0xFFD7E8E2) : const Color(0xFF3C4A45)),
              ),
            ),
          ),
          if (led != null) Positioned(right: -3, top: -3, child: led),
        ],
      ),
    );
  }

  Widget? _buildLed({required bool isAudioRunning, required bool isActiveItem}) {
    if (!isActiveItem) return null;
    if (isAudioRunning) {
      return StreamBuilder<int>(
        stream: Stream<int>.periodic(const Duration(milliseconds: 420), (i) => i),
        builder: (context, snapshot) {
          final on = (snapshot.data ?? 0).isEven;
          return Opacity(
            opacity: on ? 1 : 0.25,
            child: _ledDot(const Color(0xFF2D7EFF), glow: const Color(0xAA2D7EFF)),
          );
        },
      );
    }
    return _ledDot(const Color(0xFFFFCC4D), glow: const Color(0x99FFCC4D));
  }

  Widget _ledDot(Color color, {required Color glow}) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: glow, blurRadius: 6, spreadRadius: 1)],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:$m:$s';
    return '$m:$s';
  }
}

class WaveformProgressBar extends StatelessWidget {
  const WaveformProgressBar({super.key, required this.progress, required this.isDark});

  final double progress;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: CustomPaint(
        painter: _WavePainter(progress: progress, isDark: isDark),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.progress, required this.isDark});

  final double progress;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = isDark ? const Color(0xFF5F7771) : const Color(0xFFC8D7D2)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    final active = Paint()
      ..color = isDark ? const Color(0xFF8DE1C7) : const Color(0xFF2CB597)
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;

    const bars = 34;
    final gap = size.width / bars;
    final activeBars = (bars * progress).round();

    for (int i = 0; i < bars; i++) {
      final x = (i + 0.5) * gap;
      final amp = 4 + (sin(i * 0.6) + 1) * 4;
      canvas.drawLine(
        Offset(x, size.height / 2 - amp),
        Offset(x, size.height / 2 + amp),
        i <= activeBars ? active : base,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
