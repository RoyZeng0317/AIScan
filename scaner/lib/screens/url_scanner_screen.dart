import 'package:flutter/material.dart';
import '../services/url_scanner_service.dart';
import '../services/ai_scam_detector.dart';
import '../widgets/scan_result_card.dart';

class URLScannerScreen extends StatefulWidget {
  const URLScannerScreen({super.key});

  @override
  State<URLScannerScreen> createState() => _URLScannerScreenState();
}

class _URLScannerScreenState extends State<URLScannerScreen> {
  final _controller = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _scanner = URLScannerService();
  final _aiDetector = AIScamDetector();
  URLScanResult? _result;
  AIScamResult? _aiResult;
  bool _isScanning = false;
  bool _showApiSettings = false;
  bool _isAiConfigured = false;

  @override
  void dispose() {
    _controller.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _toggleApiSettings() {
    setState(() => _showApiSettings = !_showApiSettings);
  }

  void _saveApiKey() {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      _aiDetector.clear();
      setState(() => _isAiConfigured = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清除 AI API Key')),
      );
    } else {
      _aiDetector.configure(key);
      setState(() => _isAiConfigured = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI API Key 已設定')),
      );
    }
  }

  Future<void> _scan() async {
    final url = _controller.text;
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入要掃描的 URL')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _result = null;
      _aiResult = null;
    });

    final result = _scanner.scan(url);

    if (_isAiConfigured) {
      final aiResult = await _aiDetector.analyzeURL(url);
      if (!mounted) return;
      setState(() {
        _result = URLScanResult(
          riskScore: result.riskScore,
          verdict: result.verdict,
          warnings: result.warnings,
          checks: result.checks,
          aiAnalysis: aiResult.explanation,
          aiRiskScore: aiResult.scamProbability,
        );
        _aiResult = aiResult;
        _isScanning = false;
      });
    } else {
      setState(() {
        _result = result;
        _isScanning = false;
      });
    }
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _result = null;
      _aiResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('連結掃描'),
        actions: [
          IconButton(
            icon: Icon(_isAiConfigured ? Icons.auto_awesome : Icons.settings),
            onPressed: _toggleApiSettings,
            tooltip: _isAiConfigured ? 'AI 已啟用' : 'AI 設定',
          ),
          if (_result != null)
            IconButton(icon: const Icon(Icons.clear), onPressed: _clear),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showApiSettings) ...[
              Card(
                color: Colors.indigo.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 18, color: Colors.indigo),
                          const SizedBox(width: 8),
                          const Text(
                            'AI 詐騙偵測設定',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _apiKeyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: '輸入 OpenAI API Key...',
                          prefixIcon: const Icon(Icons.key, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _isAiConfigured
                                  ? '✅ AI 分析已啟用（GPT-4o-mini）'
                                  : '💡 輸入 API Key 啟用 AI 詐騙分析',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            onPressed: _saveApiKey,
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('設定', style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '貼上要掃描的網址...',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isScanning ? null : _scan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isScanning ? '掃描中...' : '開始掃描'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _controller.text.isNotEmpty ? _clear : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('清除'),
                ),
              ],
            ),
            if (_result != null) ...[
              const SizedBox(height: 24),
              ScanResultCard(
                icon: Icons.security,
                title: '風險評估（規則分析）',
                value: _result!.verdict,
                valueColor: _result!.riskScore >= 0.6
                    ? Colors.red
                    : _result!.riskScore >= 0.3
                        ? Colors.orange
                        : Colors.green,
                children: [
                  Center(
                    child: RiskIndicator(score: _result!.riskScore),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '檢查項目',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(_result!.checks.entries.map(
                    (e) => DetailRow(label: e.key, value: e.value),
                  )),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            '安全警告',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._result!.warnings.map(
                        (w) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(' ⚠ ', style: TextStyle(color: Colors.orange)),
                              Expanded(
                                child: Text(
                                  w,
                                  style: const TextStyle(fontSize: 13, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isAiConfigured && _aiResult != null) ...[
                const SizedBox(height: 16),
                ScanResultCard(
                  icon: Icons.auto_awesome,
                  title: 'AI 詐騙分析',
                  value: _aiResult!.scamProbability >= 0.5
                      ? '高度可能為詐騙'
                      : _aiResult!.scamProbability >= 0.3
                          ? '可能為詐騙'
                          : '安全',
                  valueColor: _aiResult!.scamProbability >= 0.5
                      ? Colors.red
                      : _aiResult!.scamProbability >= 0.3
                          ? Colors.orange
                          : Colors.green,
                  children: [
                    Center(
                      child: RiskIndicator(score: _aiResult!.scamProbability),
                    ),
                    const SizedBox(height: 16),
                    if (_aiResult!.error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _aiResult!.error!,
                                style: const TextStyle(fontSize: 12, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _aiResult!.explanation,
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
