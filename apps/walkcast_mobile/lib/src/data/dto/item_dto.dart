import '../../domain/entities/queue_item.dart';

class ItemDto {
  const ItemDto({
    required this.id,
    required this.status,
    required this.audioQuality,
    this.playlistId,
    this.playlistName,
    this.title,
    this.duration,
    this.isListened = false,
    this.filepath,
    this.fileSizeBytes,
  });

  final int id;
  final int? playlistId;
  final String? playlistName;
  final String status;
  final String audioQuality;
  final String? title;
  final String? duration;
  final bool isListened;
  final String? filepath;
  final int? fileSizeBytes;

  factory ItemDto.fromJson(Map<String, dynamic> json) {
    return ItemDto(
      id: json['id'] as int,
      playlistId: json['playlist_id'] as int?,
      playlistName: json['playlist_name'] as String?,
      status: json['status'] as String? ?? 'queued',
      audioQuality: json['audio_quality'] as String? ?? 'medium',
      title: json['title'] as String?,
      duration: json['duration'] as String?,
      isListened: json['is_listened'] as bool? ?? false,
      filepath: json['filepath'] as String?,
      fileSizeBytes: json['file_size_bytes'] as int?,
    );
  }

  QueueItem toEntity() {
    return QueueItem(
      id: id,
      playlistId: playlistId,
      playlistName: playlistName,
      status: status,
      audioQuality: audioQuality,
      title: title,
      duration: duration,
      isListened: isListened,
      filepath: filepath,
      fileSizeBytes: fileSizeBytes,
    );
  }
}
