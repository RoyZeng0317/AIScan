import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const ScanerApp());
}

class ScanerApp extends StatelessWidget {
  const ScanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '詐騙連結文章掃描',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const HomeScreen(),
    );
  }
}
