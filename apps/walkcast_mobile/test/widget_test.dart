import 'package:flutter/material.dart';
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
  testWidgets('Queue title is visible', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemsRepositoryProvider.overrideWithValue(_FakeItemsRepository()),
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
    expect(find.text('No items in selected playlist.'), findsOneWidget);
  });
}
