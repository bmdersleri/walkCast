import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'src/core/audio/walkcast_audio_handler.dart';
import 'src/core/config/app_config.dart';
import 'src/data/offline/offline_audio_store.dart';
import 'src/presentation/controllers/queue_controller.dart';

import 'src/presentation/app/walkcast_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('walkcast_prefs');
  await Hive.openBox('walkcast_audio_cache');
  await Hive.openBox('walkcast_queue_cache');
  mobileOfflineStore = OfflineAudioStore(Hive.box('walkcast_audio_cache'));
  await mobileOfflineStore.migrateLegacy(AppConfig.apiBaseUrl);
  mobileAudioHandler = kIsWeb
      ? WalkCastAudioHandler(offlineStore: mobileOfflineStore)
      : await AudioService.init<WalkCastAudioHandler>(
          builder: () => WalkCastAudioHandler(offlineStore: mobileOfflineStore),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'com.bmdersleri.walkcast.playback',
            androidNotificationChannelName: 'walkCast playback',
            androidNotificationOngoing: true,
          ),
        );
  runApp(const ProviderScope(child: WalkCastApp()));
}
