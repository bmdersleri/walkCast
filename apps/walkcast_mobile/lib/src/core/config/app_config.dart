import 'package:hive_flutter/hive_flutter.dart';

class AppConfig {
  const AppConfig._();

  static const String _defaultApiBaseUrl = String.fromEnvironment(
    'WALKCAST_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static String get apiBaseUrl {
    if (!Hive.isBoxOpen('walkcast_prefs')) {
      return _defaultApiBaseUrl;
    }

    final box = Hive.box('walkcast_prefs');
    final hostRaw = (box.get('server_host', defaultValue: '') as String).trim();
    final portRaw = box.get('server_port', defaultValue: '').toString().trim();

    if (hostRaw.isEmpty) {
      return _defaultApiBaseUrl;
    }

    final withScheme = hostRaw.contains('://') ? hostRaw : 'http://$hostRaw';
    final parsed = Uri.tryParse(withScheme);
    if (parsed == null || parsed.host.isEmpty) {
      return _defaultApiBaseUrl;
    }

    final defaultUri = Uri.parse(_defaultApiBaseUrl);
    final scheme = parsed.scheme.isEmpty ? defaultUri.scheme : parsed.scheme;
    final port = int.tryParse(portRaw) ?? (parsed.hasPort ? parsed.port : defaultUri.port);

    return Uri(
      scheme: scheme,
      host: parsed.host,
      port: port,
    ).toString();
  }
}
