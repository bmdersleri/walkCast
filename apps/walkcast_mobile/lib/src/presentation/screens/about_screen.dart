import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, required this.languageCode});

  final String languageCode;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  static const String _repoUrl = 'https://github.com/bmdersleri/walkCast';
  static const String _buildDate =
      String.fromEnvironment('WALKCAST_BUILD_DATE', defaultValue: 'Unknown');

  String _versionText = '...';

  bool get _isTr => widget.languageCode == 'tr';
  String t(String en, String tr) => _isTr ? tr : en;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _versionText = '${info.version}+${info.buildNumber}';
    });
  }

  Future<void> _openRepo() async {
    final uri = Uri.parse(_repoUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('About', 'Hakkinda')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'walkCast',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(t('Prepared by', 'Hazirlayan')),
              subtitle: const Text('Ismail Kirbas'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tag_outlined),
              title: Text(t('Version', 'Surum')),
              subtitle: Text(_versionText),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(t('Build date', 'Derleme tarihi')),
              subtitle: Text(_buildDate),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.code_outlined),
              title: const Text('GitHub'),
              subtitle: const Text(_repoUrl),
              trailing: IconButton(
                onPressed: _openRepo,
                icon: const Icon(Icons.open_in_new),
                tooltip: t('Open repository', 'Depoyu ac'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
