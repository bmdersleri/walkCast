import 'package:hive_flutter/hive_flutter.dart';
import 'server_address.dart';

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
    final saved = box.get('server_base_url') as String?;
    if (saved != null) {
      try {
        return normalizeServerAddress(saved, '');
      } on FormatException {
        return _defaultApiBaseUrl;
      }
    }
    final hostRaw = (box.get('server_host', defaultValue: '') as String).trim();
    final portRaw = box.get('server_port', defaultValue: '').toString().trim();

    if (hostRaw.isEmpty) {
      return _defaultApiBaseUrl;
    }

    try {
      final parsed = Uri.tryParse(
        hostRaw.contains('://') ? hostRaw : 'http://$hostRaw',
      );
      final legacyPort = portRaw.isEmpty && parsed != null && !parsed.hasPort
          ? Uri.parse(_defaultApiBaseUrl).port.toString()
          : portRaw;
      return normalizeServerAddress(hostRaw, legacyPort);
    } on FormatException {
      return _defaultApiBaseUrl;
    }
  }
}
