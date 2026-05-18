// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:dio/dio.dart';

Future<void> downloadWithProgress({
  required String url,
  required String fileName,
  required void Function(double progress) onProgress,
}) async {
  final dio = Dio();
  final response = await dio.get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
    onReceiveProgress: (received, total) {
      if (total <= 0) return;
      onProgress((received / total).clamp(0, 1));
    },
  );

  final bytes = response.data;
  if (bytes == null || bytes.isEmpty) {
    throw Exception('No file bytes received');
  }

  onProgress(1);

  final blob = html.Blob([bytes]);
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: objectUrl)
    ..setAttribute('download', fileName)
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(objectUrl);
}
