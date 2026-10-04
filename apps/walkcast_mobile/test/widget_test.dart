import 'package:flutter/material.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:walkcast_mobile/src/core/audio/walkcast_audio_handler.dart';
import 'package:walkcast_mobile/src/data/offline/offline_audio_store.dart';
import 'support/fake_audio_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:walkcast_mobile/src/domain/entities/queue_item.dart';
import 'package:walkcast_mobile/src/domain/repositories/items_repository.dart';
import 'package:walkcast_mobile/src/presentation/controllers/queue_controller.dart';
import 'package:walkcast_mobile/src/presentation/screens/queue_screen.dart';

class _FakeItemsRepository implements ItemsRepository {
  @override
  Future<List<QueueItem>> listItems() async {
    return const <QueueItem>[];
  }
}

void main() {
  late Directory directory;
  late OfflineAudioStore store;
  late WalkCastAudioHandler handler;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('walkcast_widget_test');
    Hive.init(directory.path);
    store = OfflineAudioStore(await Hive.openBox('audio'));
    handler = WalkCastAudioHandler(
      offlineStore: store,
      player: FakeAudioPlayer(),
    );
  });
  tearDown(() async {
    await handler.close();
    await Hive.close();
    await directory.delete(recursive: true);
  });
  testWidgets('Queue title is visible', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemsRepositoryProvider.overrideWithValue(_FakeItemsRepository()),
          audioHandlerProvider.overrideWithValue(handler),
          offlineStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp(
          home: QueueScreen(
            isDarkMode: false,
            languageCode: 'en',
            onThemeToggle: () {},
            onLanguageChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('walkCast Queue'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('No items in selected playlist.'), findsOneWidget);
  });
}
