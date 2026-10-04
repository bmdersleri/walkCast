String normalizeServerAddress(String host, String port) {
  final raw = host.trim();
  final uri = Uri.tryParse(raw.contains('://') ? raw : 'http://$raw');
  if (raw.isEmpty ||
      RegExp(r'\s').hasMatch(raw) ||
      uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      RegExp(r'\s').hasMatch(uri.host)) {
    throw const FormatException('Enter a valid HTTP or HTTPS server address.');
  }
  final portText = port.trim();
  final parsedPort = portText.isEmpty ? uri.port : int.tryParse(portText);
  if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
    throw const FormatException('Port must be between 1 and 65535.');
  }
  return Uri(scheme: uri.scheme, host: uri.host, port: parsedPort).toString();
}
