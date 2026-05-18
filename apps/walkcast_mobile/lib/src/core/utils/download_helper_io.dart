import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

Future<void> downloadWithProgress({
  required String url,
  required String fileName,
  required void Function(double progress) onProgress,
}) async {
  final dio = Dio();
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$fileName';

  await dio.download(
    url,
    path,
    onReceiveProgress: (received, total) {
      if (total <= 0) return;
      onProgress((received / total).clamp(0, 1));
    },
  );

  if (!File(path).existsSync()) {
    throw Exception('File could not be saved');
  }
}
