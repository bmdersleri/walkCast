String formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '--';

  const units = ['B', 'KB', 'MB', 'GB'];
  double size = bytes.toDouble();
  int unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  final value = size >= 10 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
  return '$value ${units[unitIndex]}';
}
