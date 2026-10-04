import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/config/server_address.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.languageCode, this.dio});
  final String languageCode;
  final Dio? dio;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final Dio _dio;
  final _cancel = CancelToken();
  bool _busy = false;
  String? _message;
  bool _error = false;

  String t(String en, String tr) => widget.languageCode == 'tr' ? tr : en;

  @override
  void initState() {
    super.initState();
    final uri = Uri.parse(AppConfig.apiBaseUrl);
    final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    _host = TextEditingController(text: '${uri.scheme}://$host');
    _port = TextEditingController(text: uri.port.toString());
    _dio =
        widget.dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
  }

  @override
  void dispose() {
    _cancel.cancel();
    _host.dispose();
    _port.dispose();
    if (widget.dio == null) _dio.close(force: true);
    super.dispose();
  }

  String? _validated() {
    try {
      return normalizeServerAddress(_host.text, _port.text);
    } on FormatException catch (error) {
      setState(() {
        _error = true;
        _message = error.message.contains('Port')
            ? t(
                'Port must be between 1 and 65535.',
                'Port 1 ile 65535 arasinda olmali.',
              )
            : t(
                'Enter a valid HTTP or HTTPS server address.',
                'Gecerli bir HTTP veya HTTPS sunucu adresi girin.',
              );
      });
      return null;
    }
  }

  Future<void> _testConnection() async {
    final server = _validated();
    if (server == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final response = await _dio.get<dynamic>(
        '$server/api/v1/items',
        cancelToken: _cancel,
      );
      if (response.data is! List) {
        throw const FormatException('Invalid queue response');
      }
      if (mounted) {
        setState(() {
          _error = false;
          _message = t(
            'Connection successful. Save to use this server.',
            'Baglanti basarili. Bu sunucuyu kullanmak icin kaydedin.',
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = t(
            'Could not connect. Check the server address and port.',
            'Baglanilamadi. Sunucu adresini ve portunu kontrol edin.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final server = _validated();
    if (server == null) return;
    setState(() => _busy = true);
    try {
      if (!Hive.isBoxOpen('walkcast_prefs')) {
        throw StateError('Preferences unavailable');
      }
      await Hive.box('walkcast_prefs').put('server_base_url', server);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = t(
            'Could not save server settings.',
            'Sunucu ayarlari kaydedilemedi.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(t('Settings', 'Ayarlar'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _host,
          enabled: !_busy,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: t('Server address', 'Sunucu adresi'),
            hintText: 'http://192.168.1.10',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _port,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: t('Port', 'Port'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        Text('${t('Active server', 'Aktif sunucu')}: ${AppConfig.apiBaseUrl}'),
        const SizedBox(height: 8),
        Text(
          t(
            'Use your computer’s LAN address on a phone. Changes take effect only after saving.',
            'Telefonda bilgisayarinizin yerel ag adresini kullanin. Degisiklikler kaydettikten sonra uygulanir.',
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _message!,
              style: TextStyle(
                color: _error
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _busy ? null : _testConnection,
          icon: const Icon(Icons.wifi),
          label: Text(t('Test connection', 'Baglantiyi test et')),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(t('Save', 'Kaydet')),
        ),
        if (_busy) const LinearProgressIndicator(),
      ],
    ),
  );
}
