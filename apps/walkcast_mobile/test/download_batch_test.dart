import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:walkcast_mobile/src/core/audio/walkcast_audio_handler.dart';
import 'package:walkcast_mobile/src/data/offline/offline_audio_store.dart';
import 'package:walkcast_mobile/src/domain/entities/queue_item.dart';
import 'package:walkcast_mobile/src/domain/repositories/items_repository.dart';
import 'package:walkcast_mobile/src/presentation/controllers/queue_controller.dart';
import 'package:walkcast_mobile/src/presentation/screens/queue_screen.dart';
import 'support/fake_audio_player.dart';

class QueueRepository implements ItemsRepository {
  @override
  Future<List<QueueItem>> listItems() async => const [
    QueueItem(id: 1, title: 'One', status: 'ready', audioQuality: 'medium'),
    QueueItem(id: 2, title: 'Two', status: 'ready', audioQuality: 'medium'),
  ];
}

class BatchStore extends OfflineAudioStore {
  BatchStore(super.box);
  final attempts = <int, int>{};
  final saved = <int>{};
  bool failSecond = true;
  Completer<void>? waiting;
  @override
  bool contains(String server, int id) => saved.contains(id);
  @override
  Set<int> savedIds(String server) => Set.of(saved);
  @override
  int sizeBytes(String server) => saved.length * 1024;
  @override
  Future<void> download(
    String server,
    int id,
    List<String> urls, {
    required void Function(int, int) onProgress,
  }) async {
    attempts[id] = (attempts[id] ?? 0) + 1;
    if (waiting != null) await waiting!.future;
    if (id == 2 && failSecond) {
      throw StateError('Simulated download failure');
    }
    saved.add(id);
  }

  @override
  void cancel(String server, int id) {
    if (waiting != null && !waiting!.isCompleted) {
      waiting!.completeError(
        DioException(
          requestOptions: RequestOptions(path: '/audio'),
          type: DioExceptionType.cancel,
        ),
      );
    }
  }

  @override
  void cancelAll(String server) {
    cancel(server, 1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late BatchStore store;
  late WalkCastAudioHandler handler;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('walkcast_batch_test');
    Hive.init(dir.path);
    store = BatchStore(await Hive.openBox('audio'));
    handler = WalkCastAudioHandler(
      offlineStore: store,
      player: FakeAudioPlayer(),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('PonnamKarthik/fluttertoast'),
          (_) async => true,
        );
  });
  tearDown(() async {
    await handler.close();
    await Hive.close();
    await dir.delete(recursive: true);
  });
  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemsRepositoryProvider.overrideWithValue(QueueRepository()),
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
  }

  testWidgets(
    'bulk failure offers retry and retry only repeats failed tracks',
    (tester) async {
      await show(tester);
      await tester.tap(find.text('Download playlist'));
      await tester.pumpAndSettle();
      expect(store.saved, {1});
      expect(store.attempts, {1: 1, 2: 1});
      expect(find.text('Retry 1 failed downloads'), findsOneWidget);
      store.failSecond = false;
      await tester.tap(find.text('Retry 1 failed downloads'));
      await tester.pumpAndSettle();
      expect(store.saved, {1, 2});
      expect(store.attempts, {1: 1, 2: 2});
      expect(find.text('Retry 1 failed downloads'), findsNothing);
    },
  );
  testWidgets(
    'bulk cancellation stops the pending track and never starts the next one',
    (tester) async {
      store.waiting = Completer<void>();
      await show(tester);
      await tester.tap(find.text('Download playlist'));
      await tester.pump();
      await tester.tap(find.text('Cancel download'));
      await tester.pumpAndSettle();
      expect(store.attempts, {1: 1});
      expect(store.saved, isEmpty);
      expect(find.text('Retry 1 failed downloads'), findsNothing);
    },
  );
}
