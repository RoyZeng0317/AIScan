import 'package:flutter/material.dart';
import '../services/ai_detector.dart';
import '../services/article_fetcher.dart';
import '../services/url_scanner_service.dart';
import '../widgets/scan_result_card.dart';

class TextScannerScreen extends StatefulWidget {
  const TextScannerScreen({super.key});

  @override
  State<TextScannerScreen> createState() => _TextScannerScreenState();
}

class _TextScannerScreenState extends State<TextScannerScreen> {
  final _textController = TextEditingController();
  final _urlController = TextEditingController();
  final _detector = AIDetector();
  final _fetcher = ArticleFetcher();
  final _urlScanner = URLScannerService();
  AIScanResult? _result;
  URLScanResult? _urlScanResult;
  bool _isScanning = false;
  bool _isUrlMode = false;
  String? _fetchedTitle;
  String? _extractedPreview;
  String? _fetchError;

  @override
  void dispose() {
    _textController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_isUrlMode) {
      await _fetchAndScan();
    } else {
      _scanText();
    }
  }

  void _scanText() {
    final text = _textController.text;
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請貼上要掃描的文字')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _fetchedTitle = null;
      _extractedPreview = null;
      _fetchError = null;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() {
        _result = _detector.analyze(text);
        _isScanning = false;
      });
    });
  }

  Future<void> _fetchAndScan() async {
    final url = _urlController.text;
    if (url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入網址')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _result = null;
      _urlScanResult = null;
      _fetchedTitle = null;
      _extractedPreview = null;
      _fetchError = null;
    });

    final fetchResult = await _fetcher.fetch(url);
    final urlScanResult = _urlScanner.scan(url);

    if (!mounted) return;
    setState(() => _isScanning = false);

    setState(() {
      _urlScanResult = urlScanResult;
      _fetchedTitle = fetchResult.title;
      _extractedPreview = fetchResult.content;
      if (fetchResult.error != null) {
        _fetchError = fetchResult.error;
      } else {
        _result = _detector.analyze(fetchResult.content);
      }
    });
  }

  void _clear() {
    _textController.clear();
    _urlController.clear();
    setState(() {
      _result = null;
      _urlScanResult = null;
      _fetchedTitle = null;
      _extractedPreview = null;
      _fetchError = null;
    });
  }

  void _toggleMode() {
    setState(() {
      _isUrlMode = !_isUrlMode;
      _result = null;
      _urlScanResult = null;
      _fetchedTitle = null;
      _extractedPreview = null;
      _fetchError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 文章掃描'),
        actions: [
          if (_result != null)
            IconButton(icon: const Icon(Icons.clear), onPressed: _clear),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('貼上文字'), icon: Icon(Icons.edit)),
                ButtonSegment(value: true, label: Text('輸入網址'), icon: Icon(Icons.link)),
              ],
              selected: {_isUrlMode},
              onSelectionChanged: (v) => _toggleMode(),
            ),
            const SizedBox(height: 16),
            if (_isUrlMode) ...[
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: '貼上文章網址...',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ] else ...[
              TextField(
                controller: _textController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: '貼上要掃描的文章內容...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ],
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
                    label: Text(
                      _isScanning
                          ? (_isUrlMode ? '載入並分析中...' : '分析中...')
                          : '開始掃描',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: (_isUrlMode && _urlController.text.isNotEmpty) ||
                          (!_isUrlMode && _textController.text.isNotEmpty)
                      ? _clear
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('清除'),
                ),
              ],
            ),
            if (_fetchedTitle != null) ...[
              const SizedBox(height: 8),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.article, size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fetchedTitle!,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_extractedPreview != null) ...[
              const SizedBox(height: 8),
              Card(
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
                          Icon(
                            _fetchError != null ? Icons.warning_amber : Icons.text_snippet,
                            size: 16,
                            color: _fetchError != null ? Colors.orange : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _fetchError != null
                                ? _fetchError!
                                : '擷取內容 (${_extractedPreview!.length} 字元)',
                            style: TextStyle(
                              fontSize: 12,
                              color: _fetchError != null ? Colors.orange : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      if (_fetchError == null) ...[
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _extractedPreview!.length > 300
                                ? '${_extractedPreview!.substring(0, 300)}...'
                                : _extractedPreview!,
                            style: const TextStyle(fontSize: 12, height: 1.4),
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (_urlScanResult != null) ...[
              const SizedBox(height: 20),
              ScanResultCard(
                icon: Icons.security,
                title: '連結安全掃描',
                value: _urlScanResult!.verdict,
                valueColor: _urlScanResult!.riskScore >= 0.6
                    ? Colors.red
                    : _urlScanResult!.riskScore >= 0.3
                        ? Colors.orange
                        : Colors.green,
                children: [
                  Center(
                    child: RiskIndicator(score: _urlScanResult!.riskScore),
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
                  ...(_urlScanResult!.checks.entries.map(
                    (e) => DetailRow(label: e.key, value: e.value),
                  )),
                ],
              ),
              const SizedBox(height: 12),
              if (_urlScanResult!.warnings.any((w) => w != '未偵測到明顯的安全風險'))
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
                        ..._urlScanResult!.warnings.where((w) => w != '未偵測到明顯的安全風險').map(
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
              const SizedBox(height: 16),
            ],
            if (_result != null) ...[
              const SizedBox(height: 20),
              ScanResultCard(
                icon: Icons.auto_awesome,
                title: 'AI 生成機率',
                value: _result!.verdict,
                valueColor: _result!.aiProbability >= 0.55
                    ? Colors.red
                    : _result!.aiProbability >= 0.35
                        ? Colors.orange
                        : _result!.aiProbability >= 0.15
                            ? Colors.blueGrey
                            : Colors.green,
                children: [
                  Center(
                    child: RiskIndicator(score: _result!.aiProbability),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '偵測細項',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(_result!.details.entries.map(
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
                          Icon(Icons.info_outline, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            '分析說明',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._result!.reasons.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(' • ', style: TextStyle(color: Colors.grey)),
                              Expanded(
                                child: Text(
                                  r,
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
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
