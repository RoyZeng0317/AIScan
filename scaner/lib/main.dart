import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'screens/home_screen.dart';
import 'overlay/overlay_bubble.dart';
import 'services/system_overlay_service.dart';

void main() {
  runApp(const ScanerApp());
}

// Entry point for the system overlay engine (separate from the main app).
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayBubble(),
    ),
  );
}

class ScanerApp extends StatefulWidget {
  const ScanerApp({super.key});

  @override
  State<ScanerApp> createState() => _ScanerAppState();
}

class _ScanerAppState extends State<ScanerApp> {
  @override
  void initState() {
    super.initState();
    // Listen for messages sent from the overlay bubble to the main app.
    FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map && data['action'] == 'openAccessibility') {
        SystemOverlayService.openAccessibilitySettings();
      }
    });
  }

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
