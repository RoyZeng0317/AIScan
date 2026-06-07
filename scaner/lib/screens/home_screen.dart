import 'package:flutter/material.dart';
import '../services/system_overlay_service.dart';
import 'text_scanner_screen.dart';
import 'url_scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _switchTo(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _ScanHomePage(onNavigate: _switchTo),
      const TextScannerScreen(),
      const URLScannerScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _switchTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首頁',
          ),
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: '文章掃描',
          ),
          NavigationDestination(
            icon: Icon(Icons.link_outlined),
            selectedIcon: Icon(Icons.link),
            label: '連結掃描',
          ),
        ],
      ),
    );
  }
}

// ─── Home page ──────────────────────────────────────────────────────────────

class _ScanHomePage extends StatefulWidget {
  final void Function(int index) onNavigate;

  const _ScanHomePage({required this.onNavigate});

  @override
  State<_ScanHomePage> createState() => _ScanHomePageState();
}

class _ScanHomePageState extends State<_ScanHomePage>
    with WidgetsBindingObserver {
  bool _isMonitoring = false;
  bool _hasOverlayPerm = false;
  bool _hasAccessibility = false;
  bool _loading = false;
  // Set to true when we open the overlay-permission settings page,
  // so that on resume we automatically start the overlay if granted.
  bool _pendingOverlayStart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    await _checkStatus();
    // Auto-start overlay if the user just granted the overlay permission
    if (_pendingOverlayStart && _hasOverlayPerm && !_isMonitoring) {
      _pendingOverlayStart = false;
      await _startOverlay();
    }
  }

  Future<void> _checkStatus() async {
    final perm = await SystemOverlayService.isOverlayPermissionGranted();
    final accessibility = await SystemOverlayService.isAccessibilityEnabled();
    if (mounted) {
      setState(() {
        _hasOverlayPerm = perm;
        _hasAccessibility = accessibility;
        // Don't read isActive() — it returns false during overlay engine warm-up
        // and would incorrectly clear _isMonitoring right after startOverlay().
        // _isMonitoring is managed solely by _startOverlay() and stopOverlay().
        if (!perm) _isMonitoring = false; // permission revoked → force off
      });
    }
  }

  Future<void> _toggleMonitor() async {
    if (_loading) return;

    if (_isMonitoring) {
      // Stop overlay
      setState(() => _loading = true);
      try {
        await SystemOverlayService.stopOverlay();
        setState(() => _isMonitoring = false);
        _snack('懸浮泡泡已關閉');
      } finally {
        setState(() => _loading = false);
      }
      return;
    }

    // Need to start overlay — first ensure permission
    if (!_hasOverlayPerm) {
      _pendingOverlayStart = true;
      await SystemOverlayService.requestOverlayPermission();
      // Don't block here — user is now on the Android settings page.
      // _onAppResumed() will auto-start once they return with permission granted.
      _snack('請在設定中允許「顯示在其他應用程式上層」，允許後自動返回啟動');
      return;
    }

    await _startOverlay();
  }

  Future<void> _startOverlay() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await SystemOverlayService.startOverlay();
      // showOverlay() not throwing means the overlay service accepted the request.
      // isActive() can return false during the engine warm-up phase, so we
      // trust showOverlay() and set the flag immediately.
      if (mounted) setState(() => _isMonitoring = true);
      _snack('懸浮泡泡啟動成功！畫面中央會出現橘色圓形，可拖曳移動');
    } catch (e) {
      _snack('啟動失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAccessibilitySettings() async {
    await SystemOverlayService.openAccessibilitySettings();
    // didChangeAppLifecycleState → _onAppResumed → _checkStatus handles the rest
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Scanner'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Icon(Icons.radar, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 10),
            Text(
              'AI 智能掃描器',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '偵測 AI 生成文章 · 掃描詐騙連結 · 假訊息預警',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ── Overlay monitoring card ──────────────────────────────────
            _MonitorCard(
              isMonitoring: _isMonitoring,
              hasOverlayPerm: _hasOverlayPerm,
              hasAccessibility: _hasAccessibility,
              loading: _loading,
              onToggleOverlay: _toggleMonitor,
              onOpenAccessibility: _openAccessibilitySettings,
            ),
            const SizedBox(height: 16),

            // ── Feature cards ────────────────────────────────────────────
            _FeatureCard(
              icon: Icons.fact_check,
              title: 'AI 文章 + 假訊息偵測',
              subtitle: '分析句長變化、用詞模式\n並偵測假訊息關鍵字與操控語言',
              onTap: () => widget.onNavigate(1),
            ),
            const SizedBox(height: 12),
            _FeatureCard(
              icon: Icons.security,
              title: '詐騙連結掃描',
              subtitle: '釣魚特徵、品牌冒充、惡意網域\n台灣銀行/政府可信任白名單',
              onTap: () => widget.onNavigate(2),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Monitor card ────────────────────────────────────────────────────────────

class _MonitorCard extends StatelessWidget {
  final bool isMonitoring;
  final bool hasOverlayPerm;
  final bool hasAccessibility;
  final bool loading;
  final VoidCallback onToggleOverlay;
  final VoidCallback onOpenAccessibility;

  const _MonitorCard({
    required this.isMonitoring,
    required this.hasOverlayPerm,
    required this.hasAccessibility,
    required this.loading,
    required this.onToggleOverlay,
    required this.onOpenAccessibility,
  });

  static const _platforms = [
    'Instagram', 'Facebook', 'LINE', 'Threads',
    'X / Twitter', 'Telegram', 'YouTube', 'TikTok',
    'Discord', 'Reddit', 'WhatsApp',
  ];

  bool get _fullyReady => isMonitoring && hasAccessibility;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: _fullyReady ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _fullyReady ? Colors.green.shade200 : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Icon(
                  _fullyReady ? Icons.shield : Icons.shield_outlined,
                  size: 22,
                  color: _fullyReady ? Colors.green.shade600 : Colors.grey.shade500,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('社群媒體背景監控',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          if (_fullyReady) ...[
                            const SizedBox(width: 8),
                            _PulseDot(color: Colors.green.shade500),
                          ],
                        ],
                      ),
                      Text(
                        _fullyReady
                            ? '已啟用，懸浮視窗自動偵測畫面連結'
                            : '需完成以下兩個設定才能背景監控',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Step 1: Overlay permission
            _StepRow(
              step: '1',
              title: '懸浮視窗權限',
              subtitle: hasOverlayPerm
                  ? (isMonitoring ? '懸浮泡泡已啟動' : '已授權，點右側開啟泡泡')
                  : '需要「顯示在其他應用程式上層」',
              isDone: isMonitoring,
              trailing: loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Switch(
                      value: isMonitoring,
                      onChanged: (_) => onToggleOverlay(),
                      activeThumbColor: Colors.green.shade600,
                    ),
            ),
            const SizedBox(height: 10),

            // Step 2: Accessibility service
            _StepRow(
              step: '2',
              title: '無障礙服務權限',
              subtitle: hasAccessibility
                  ? '已啟用，可自動偵測畫面連結'
                  : '開啟後，退出 App 仍可自動監控',
              isDone: hasAccessibility,
              trailing: hasAccessibility
                  ? Icon(Icons.check_circle, color: Colors.green.shade600, size: 24)
                  : TextButton(
                      onPressed: onOpenAccessibility,
                      style: TextButton.styleFrom(
                        foregroundColor: primary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('前往開啟', style: TextStyle(fontSize: 13)),
                    ),
            ),

            if (_fullyReady) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text('監控平台', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _platforms.map((p) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(p, style: TextStyle(fontSize: 11, color: Colors.green.shade800)),
                )).toList(),
              ),
              const SizedBox(height: 8),
              Text(
                '瀏覽社群媒體時，懸浮泡泡自動分析畫面上的連結',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final bool isDone;
  final Widget trailing;

  const _StepRow({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? Colors.green.shade100 : Colors.grey.shade200,
          ),
          child: Center(
            child: isDone
                ? Icon(Icons.check, size: 14, color: Colors.green.shade700)
                : Text(step, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

// ── Pulsing dot indicator ─────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final Color color;

  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}

// ─── Feature card ─────────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
