import 'package:flutter/material.dart';

import 'screens/parse_screen.dart';
import 'services/parser_service.dart';

class PinDouApp extends StatelessWidget {
  const PinDouApp({required this.parserService, super.key});

  final ParserService parserService;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF476C5E);
    return MaterialApp(
      title: '品豆',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          alignLabelWithHint: true,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: ParseScreen(parserService: parserService),
    );
  }
}
