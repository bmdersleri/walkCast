import 'package:flutter/material.dart';

import '../screens/queue_screen.dart';

class WalkCastApp extends StatefulWidget {
  const WalkCastApp({super.key});

  @override
  State<WalkCastApp> createState() => _WalkCastAppState();
}

class _WalkCastAppState extends State<WalkCastApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  String _languageCode = 'en';

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _setLanguage(String code) {
    setState(() {
      _languageCode = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'walkCast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B8F7A)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFE6F1ED),
          foregroundColor: Color(0xFF1A2C27),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B8F7A), brightness: Brightness.dark),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0B1412),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F1F1B),
          foregroundColor: Color(0xFFEAF4F1),
        ),
      ),
      themeMode: _themeMode,
      home: QueueScreen(
        isDarkMode: _themeMode == ThemeMode.dark,
        languageCode: _languageCode,
        onThemeToggle: _toggleTheme,
        onLanguageChanged: _setLanguage,
      ),
    );
  }
}
