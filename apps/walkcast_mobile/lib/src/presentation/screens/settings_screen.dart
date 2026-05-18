import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/config/app_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.languageCode,
  });

  final String languageCode;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  Box? _prefs;

  bool get _isTr => widget.languageCode == 'tr';
  String t(String en, String tr) => _isTr ? tr : en;

  @override
  void initState() {
    super.initState();
    _prefs = Hive.isBoxOpen('walkcast_prefs') ? Hive.box('walkcast_prefs') : null;
    _hostController = TextEditingController(text: (_prefs?.get('server_host', defaultValue: '127.0.0.1') as String));
    _portController = TextEditingController(text: _prefs?.get('server_port', defaultValue: '8000').toString() ?? '8000');
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _saveHost(String value) async {
    await _prefs?.put('server_host', value.trim());
    if (mounted) setState(() {});
  }

  Future<void> _savePort(String value) async {
    await _prefs?.put('server_port', value.trim());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Settings', 'Ayarlar')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _hostController,
            decoration: InputDecoration(
              labelText: t('Server host / address', 'Sunucu host / adres'),
              hintText: '127.0.0.1 or localhost',
              border: const OutlineInputBorder(),
            ),
            onChanged: _saveHost,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: t('Port', 'Port'),
              hintText: '8000',
              border: const OutlineInputBorder(),
            ),
            onChanged: _savePort,
          ),
          const SizedBox(height: 14),
          Text(
            '${t('Active API base URL', 'Aktif API temel adresi')}: ${AppConfig.apiBaseUrl}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            t(
              'Changes are saved automatically while typing.',
              'Degisiklikler yazarken otomatik kaydedilir.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
