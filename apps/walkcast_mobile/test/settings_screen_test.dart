import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:walkcast_mobile/src/presentation/screens/settings_screen.dart';

class TestAdapter implements HttpClientAdapter {
  final requests = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri.toString());
    return ResponseBody.fromString(
      '[]',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory dir;
  late Box prefs;
  late TestAdapter adapter;
  late Dio dio;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('walkcast_settings_test');
    Hive.init(dir.path);
    prefs = await Hive.openBox('walkcast_prefs');
    adapter = TestAdapter();
    dio = Dio()..httpClientAdapter = adapter;
  });
  tearDown(() async {
    dio.close();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> show(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: SettingsScreen(languageCode: 'en', dio: dio),
    ),
  );

  testWidgets(
    'typing settings and testing connection never change active configuration',
    (tester) async {
      await show(tester);
      await tester.enterText(
        find.byType(TextField).at(0),
        'https://example.com',
      );
      await tester.enterText(find.byType(TextField).at(1), '8443');
      expect(prefs.get('server_base_url'), isNull);
      await tester.tap(find.text('Test connection'));
      await tester.pumpAndSettle();
      expect(adapter.requests, ['https://example.com:8443/api/v1/items']);
      expect(
        find.text('Connection successful. Save to use this server.'),
        findsOneWidget,
      );
      expect(prefs.get('server_base_url'), isNull);
    },
  );
  testWidgets('invalid settings show validation errors and cannot be saved', (
    tester,
  ) async {
    await show(tester);
    await tester.enterText(find.byType(TextField).at(1), '70000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Port must be between 1 and 65535.'), findsOneWidget);
    expect(prefs.get('server_base_url'), isNull);
    expect(adapter.requests, isEmpty);
  });
  testWidgets('save persists one complete validated address', (tester) async {
    await show(tester);
    await tester.enterText(find.byType(TextField).at(0), 'http://192.168.1.8');
    await tester.enterText(find.byType(TextField).at(1), '8000');
    await tester.runAsync(() async {
      final saved = prefs.watch(key: 'server_base_url').first;
      await tester.tap(find.text('Save'));
      await saved;
      await prefs.flush();
    });
    await tester.pumpAndSettle();
    expect(prefs.get('server_base_url'), 'http://192.168.1.8:8000');
  });
}
