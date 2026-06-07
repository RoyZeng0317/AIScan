import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class SystemOverlayService {
  SystemOverlayService._();

  static const _accessibilityChannel = MethodChannel('com.example.scaner/accessibility');

  // ── Overlay window ────────────────────────────────────────────────────────

  static Future<bool> isOverlayPermissionGranted() async {
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  static Future<void> requestOverlayPermission() async {
    await FlutterOverlayWindow.requestPermission();
  }

  static Future<void> startOverlay() async {
    await FlutterOverlayWindow.showOverlay(
      height: 80,
      width: 80,
      alignment: OverlayAlignment.centerRight,
      enableDrag: true,
      overlayTitle: 'AI Scanner 監控',
      overlayContent: '正在監控社群媒體可疑內容',
      visibility: NotificationVisibility.visibilityPublic,
      flag: OverlayFlag.focusPointer,
    );
  }

  static Future<void> stopOverlay() async {
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  static Future<void> analyzeInOverlay(String text) async {
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.shareData({'action': 'analyze', 'text': text});
    }
  }

  // ── Accessibility Service ─────────────────────────────────────────────────

  static Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _accessibilityChannel.invokeMethod<bool>('isEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _accessibilityChannel.invokeMethod('openSettings');
    } catch (_) {}
  }
}
