import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:path_provider/path_provider.dart';
import '../services/url_scanner_service.dart';
import '../services/fake_news_detector.dart';

// ─── Social platform metadata ─────────────────────────────────────────────────

class _Platform {
  final String name;
  final Color color;
  final IconData icon;

  const _Platform(this.name, this.color, this.icon);

  static const _byPackage = <String, _Platform>{
    'com.instagram.android':      _Platform('Instagram',   Color(0xFFE1306C), Icons.camera_alt),
    'com.instagram.barcelona':    _Platform('Threads',     Colors.black87,    Icons.alternate_email),
    'com.facebook.katana':        _Platform('Facebook',    Color(0xFF1877F2), Icons.facebook),
    'com.facebook.lite':          _Platform('Facebook',    Color(0xFF1877F2), Icons.facebook),
    'com.zhiliaoapp.musically':   _Platform('TikTok',      Colors.black87,    Icons.music_note),
    'com.ss.android.ugc.trill':   _Platform('TikTok',      Colors.black87,    Icons.music_note),
    'jp.naver.line.android':      _Platform('LINE',        Color(0xFF06C755), Icons.chat_bubble),
    'org.telegram.messenger':     _Platform('Telegram',    Color(0xFF0088CC), Icons.send),
    'com.discord':                _Platform('Discord',     Color(0xFF5865F2), Icons.headset_mic),
    'com.google.android.youtube': _Platform('YouTube',     Color(0xFFFF0000), Icons.play_circle),
    'com.twitter.android':        _Platform('X / Twitter', Colors.black87,    Icons.close),
    'com.X.android':              _Platform('X / Twitter', Colors.black87,    Icons.close),
    'com.reddit.frontpage':       _Platform('Reddit',      Color(0xFFFF4500), Icons.forum),
    'com.whatsapp':               _Platform('WhatsApp',    Color(0xFF25D366), Icons.chat),
    'com.whatsapp.w4b':           _Platform('WhatsApp',    Color(0xFF25D366), Icons.chat),
    'com.pinterest':              _Platform('Pinterest',   Color(0xFFE60023), Icons.push_pin),
    'com.linkedin.android':       _Platform('LinkedIn',    Color(0xFF0A66C2), Icons.work),
  };

  // Detect from package name (written by Accessibility Service)
  static _Platform? fromPackage(String? pkg) =>
      pkg == null ? null : _byPackage[pkg];

  // Detect from URL text (fallback for clipboard source)
  static _Platform? fromUrl(String text) {
    final t = text.toLowerCase();
    if (t.contains('instagram.com') || t.contains('instagr.am')) return _byPackage['com.instagram.android'];
    if (t.contains('facebook.com') || t.contains('fb.com'))      return _byPackage['com.facebook.katana'];
    if (t.contains('threads.net'))      return _byPackage['com.instagram.barcelona'];
    if (t.contains('twitter.com') || t.contains('x.com') || t.contains('t.co')) return _byPackage['com.twitter.android'];
    if (t.contains('youtube.com') || t.contains('youtu.be'))     return _byPackage['com.google.android.youtube'];
    if (t.contains('tiktok.com'))       return _byPackage['com.zhiliaoapp.musically'];
    if (t.contains('line.me') || t.contains('lin.ee'))           return _byPackage['jp.naver.line.android'];
    if (t.contains('telegram.me') || t.contains('t.me'))         return _byPackage['org.telegram.messenger'];
    if (t.contains('discord.com') || t.contains('discord.gg'))   return _byPackage['com.discord'];
    if (t.contains('reddit.com'))       return _byPackage['com.reddit.frontpage'];
    if (t.contains('whatsapp.com'))     return _byPackage['com.whatsapp'];
    return null;
  }
}

// ─── Overlay state ────────────────────────────────────────────────────────────

enum _BubbleState { idle, analyzing, safe, warning, danger }

// ─── Overlay root widget ──────────────────────────────────────────────────────

class OverlayBubble extends StatefulWidget {
  const OverlayBubble({super.key});

  @override
  State<OverlayBubble> createState() => _OverlayBubbleState();
}

class _OverlayBubbleState extends State<OverlayBubble>
    with SingleTickerProviderStateMixin {
  final _urlScanner = URLScannerService();
  final _fakeNewsDetector = FakeNewsDetector();

  String? _lastContent;
  int _lastTimestamp = 0;
  _BubbleState _state = _BubbleState.idle;
  _Platform? _platform;
  double _riskScore = 0;
  String _verdict = '';
  List<String> _details = [];
  bool _isExpanded = false;
  bool _accessibilityReady = false;
  Timer? _pollTimer;
  String? _filesDir;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Receive direct trigger from main app (may fail in overlay engine – safe to ignore)
    try {
      FlutterOverlayWindow.overlayListener.listen((data) {
        if (data is Map && data['action'] == 'analyze') {
          final text = data['text'] as String?;
          if (text != null) _processContent(text, platform: null);
        }
      });
    } catch (_) {}

    _initDir();
  }

  Future<void> _initDir() async {
    try {
      final dir = await getApplicationSupportDirectory();
      _filesDir = dir.path;
    } catch (_) {
      // path_provider unavailable in overlay engine — use Android's fixed filesDir path
      _filesDir = '/data/data/com.example.scaner/files';
    }
    // Check if file already exists → accessibility service is running
    final file = File('$_filesDir/scanner_content.json');
    if (mounted) setState(() => _accessibilityReady = file.existsSync());
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _pollFile());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Primary: read file written by Accessibility Service ──────────────────

  Future<void> _pollFile() async {
    if (_filesDir == null) {
      await _pollClipboard();
      return;
    }
    try {
      final file = File('$_filesDir/scanner_content.json');
      if (!file.existsSync()) {
        await _pollClipboard(); // fallback
        return;
      }

      final raw = file.readAsStringSync();
      if (raw.isEmpty) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;

      final content = json['content'] as String?;
      final timestamp = (json['timestamp'] as num?)?.toInt() ?? 0;
      final pkg = json['app'] as String?;

      if (content == null || content == _lastContent || timestamp <= _lastTimestamp) return;

      _lastContent = content;
      _lastTimestamp = timestamp;
      if (!_accessibilityReady && mounted) setState(() => _accessibilityReady = true);
      await _processContent(content, platform: _Platform.fromPackage(pkg));
    } catch (_) {
      await _pollClipboard();
    }
  }

  // ── Fallback: clipboard monitoring ───────────────────────────────────────

  Future<void> _pollClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty || text == _lastContent) return;
      _lastContent = text;
      _lastTimestamp = DateTime.now().millisecondsSinceEpoch;
      await _processContent(text, platform: _Platform.fromUrl(text));
    } catch (_) {}
  }

  // ── Analysis ──────────────────────────────────────────────────────────────

  Future<void> _processContent(String text, {_Platform? platform}) async {
    setState(() => _state = _BubbleState.analyzing);

    final effectivePlatform = platform ?? _Platform.fromUrl(text);
    final isUrl = text.startsWith('http') || text.startsWith('www.');

    double risk = 0;
    String verdict = '';
    List<String> details = [];

    if (isUrl) {
      final r = _urlScanner.scan(text);
      risk = r.riskScore;
      verdict = r.verdict;
      details = r.warnings;
    } else if (text.length >= 15) {
      final r = _fakeNewsDetector.analyze(text);
      risk = r.riskScore;
      verdict = r.verdict;
      details = r.reasons;
    } else {
      setState(() => _state = _BubbleState.idle);
      return;
    }

    _BubbleState newState;
    bool autoExpand = false;
    if (risk >= 0.6) {
      newState = _BubbleState.danger;
      autoExpand = true;
    } else if (risk >= 0.3) {
      newState = _BubbleState.warning;
    } else {
      newState = _BubbleState.safe;
    }

    setState(() {
      _platform = effectivePlatform;
      _riskScore = risk;
      _verdict = verdict;
      _details = details;
      _state = newState;
      if (autoExpand) _isExpanded = true;
    });

    if (_isExpanded) {
      await FlutterOverlayWindow.resizeOverlay(280, 380, true);
    } else {
      await FlutterOverlayWindow.resizeOverlay(80, 80, true);
    }
  }

  Color get _stateColor {
    switch (_state) {
      case _BubbleState.danger:    return Colors.red.shade600;
      case _BubbleState.warning:   return Colors.orange.shade700;
      case _BubbleState.safe:      return Colors.green.shade600;
      case _BubbleState.analyzing: return Colors.blue.shade500;
      case _BubbleState.idle:      return Colors.orange.shade600;
    }
  }

  IconData get _stateIcon {
    switch (_state) {
      case _BubbleState.danger:    return Icons.dangerous;
      case _BubbleState.warning:   return Icons.warning_amber_rounded;
      case _BubbleState.safe:      return Icons.verified_user;
      case _BubbleState.analyzing: return Icons.radar;
      case _BubbleState.idle:      return Icons.settings_suggest;
    }
  }

  Future<void> _openAccessibilityFromOverlay() async {
    try {
      await FlutterOverlayWindow.shareData({'action': 'openAccessibility'});
    } catch (_) {}
  }

  Future<void> _toggleExpand() async {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      await FlutterOverlayWindow.resizeOverlay(280, 380, true);
    } else {
      await FlutterOverlayWindow.resizeOverlay(80, 80, true);
    }
  }

  Future<void> _close() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // SizedBox.expand fills the overlay window so Center can properly position
    // the bubble. Without this, GestureDetector expands to fill the window and
    // the circle ends up at the top-left corner instead of the center.
    return Material(
      color: Colors.transparent,
      child: SizedBox.expand(
        child: Center(
          child: _isExpanded && _state != _BubbleState.idle && _state != _BubbleState.analyzing
              ? _buildExpanded()
              : _buildBubble(),
        ),
      ),
    );
  }

  Widget _buildBubble() {
    final isAnalyzing = _state == _BubbleState.analyzing;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_state == _BubbleState.idle) {
          _openAccessibilityFromOverlay();
        } else if (_state != _BubbleState.analyzing) {
          _toggleExpand();
        }
      },
      child: ScaleTransition(
        scale: isAnalyzing ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _stateColor,
            boxShadow: [
              BoxShadow(
                color: _stateColor.withValues(alpha: 0.5),
                blurRadius: 16,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_stateIcon, color: Colors.white, size: 22),
                  const SizedBox(height: 1),
                  Text(
                    _state == _BubbleState.idle
                        ? (_accessibilityReady ? '監控' : '授權')
                        : '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (_state == _BubbleState.danger || _state == _BubbleState.warning)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Center(
                      child: Text(
                        '!',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: _stateColor,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _stateColor.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: _stateColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          _buildRiskBar(),
          const Divider(height: 1),
          _buildDetailList(),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: _stateColor.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          if (_platform != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _platform!.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_platform!.icon, size: 16, color: _platform!.color),
            ),
            const SizedBox(width: 8),
            Text(
              _platform!.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            const Text('·', style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 6),
          ] else ...[
            Icon(Icons.radar, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            const Text('AI Scanner', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              _state == _BubbleState.danger ? '高風險' :
              _state == _BubbleState.warning ? '需注意' : '安全',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _stateColor),
            ),
          ),
          GestureDetector(
            onTap: _toggleExpand,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.expand_more, size: 18, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: _close,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 18, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBar() {
    final pct = (_riskScore * 100).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_stateIcon, size: 16, color: _stateColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _verdict,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _stateColor),
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _stateColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _riskScore,
              minHeight: 7,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(_stateColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailList() {
    final shown = _details.take(4).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Column(
        children: shown.map((msg) {
          final isGood = msg.contains('可信') || msg.contains('降低') || msg.contains('安全');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isGood ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                  size: 14,
                  color: isGood ? Colors.green.shade600 : Colors.red.shade500,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    msg,
                    style: const TextStyle(fontSize: 12, height: 1.35),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          Icon(Icons.radar, size: 12, color: Colors.grey.shade400),
          const SizedBox(width: 4),
          Text(
            _platform != null ? '正在監控 ${_platform!.name}' : 'AI Scanner 監控中',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _close,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _stateColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '關閉',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _stateColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
