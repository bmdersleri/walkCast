class QueueItem {
  const QueueItem({
    required this.id,
    required this.status,
    required this.audioQuality,
    this.playlistId,
    this.title,
    this.duration,
    this.filepath,
    this.fileSizeBytes,
    this.isListened = false,
  });

  final int id;
  final int? playlistId;
  final String status;
  final String audioQuality;
  final String? title;
  final String? duration;
  final bool isListened;
  final String? filepath;
  final int? fileSizeBytes;

  bool get isReady => status == 'ready';

  String get playlistLabel {
    const names = <int, String>{
      1: 'Technology',
      2: 'Economy',
      3: 'Science',
      4: 'Education',
      5: 'Other',
    };
    if (playlistId == null) return 'Unassigned';
    return names[playlistId!] ?? 'Playlist #$playlistId';
  }
}
