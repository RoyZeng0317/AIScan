import 'package:flutter/material.dart';
import '../services/ai_detector.dart';
import '../services/fake_news_detector.dart';
import '../services/article_fetcher.dart';
import '../services/url_scanner_service.dart';
import '../widgets/scan_result_card.dart';
import '../widgets/floating_evidence_panel.dart';

class TextScannerScreen extends StatefulWidget {
  const TextScannerScreen({super.key});

  @override
  State<TextScannerScreen> createState() => _TextScannerScreenState();
}

class _TextScannerScreenState extends State<TextScannerScreen> {
  final _textController = TextEditingController();
  final _urlController = TextEditingController();
  final _detector = AIDetector();
  final _fakeNewsDetector = FakeNewsDetector();
  final _fetcher = ArticleFetcher();
  final _urlScanner = URLScannerService();

  AIScanResult? _result;
  FakeNewsResult? _fakeNewsResult;
  URLScanResult? _urlScanResult;
  bool _isScanning = false;
  bool _isUrlMode = false;
  String? _fetchedTitle;
  String? _extractedPreview;
  String? _fetchError;
  List<EvidenceItem> _evidenceItems = [];

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

    Future.delayed(const Duration(milliseconds: 400), () {
      final aiResult = _detector.analyze(text);
      final fakeNewsResult = _fakeNewsDetector.analyze(text);
      setState(() {
        _result = aiResult;
        _fakeNewsResult = fakeNewsResult;
        _evidenceItems = _buildTextEvidenceItems(aiResult, fakeNewsResult);
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
      _fakeNewsResult = null;
      _urlScanResult = null;
      _fetchedTitle = null;
      _extractedPreview = null;
      _fetchError = null;
      _evidenceItems = [];
    });

    final fetchResult = await _fetcher.fetch(url);
    final urlScanResult = _urlScanner.scan(url);

    if (!mounted) return;

    AIScanResult? aiResult;
    FakeNewsResult? fakeNewsResult;
    if (fetchResult.error == null) {
      aiResult = _detector.analyze(fetchResult.content);
      fakeNewsResult = _fakeNewsDetector.analyze(fetchResult.content);
    }

    setState(() {
      _urlScanResult = urlScanResult;
      _fetchedTitle = fetchResult.title;
      _extractedPreview = fetchResult.content;
      _fetchError = fetchResult.error;
      _result = aiResult;
      _fakeNewsResult = fakeNewsResult;
      _evidenceItems = _buildUrlModeEvidenceItems(urlScanResult, aiResult, fakeNewsResult);
      _isScanning = false;
    });
  }

  List<EvidenceItem> _buildTextEvidenceItems(
    AIScanResult aiResult,
    FakeNewsResult fakeNewsResult,
  ) {
    final items = <EvidenceItem>[];

    // Fake news red flags
    for (final entry in fakeNewsResult.categoryBreakdown.entries) {
      final keywords = entry.value.take(2).join('、');
      items.add(EvidenceItem(
        category: '假訊息：${entry.key}',
        detail: '偵測到：$keywords',
        contribution: 0.20,
        isRisk: true,
      ));
    }

    // Credibility markers
    for (final marker in fakeNewsResult.credibilityMarkers.take(3)) {
      items.add(EvidenceItem(
        category: '可信度標記',
        detail: '包含：「$marker」',
        contribution: 0,
        isRisk: false,
      ));
    }

    // AI detection signals
    const aiRiskKeys = {
      'AI常用語句': 'AI 常用語句偵測',
      '重複模式': '高頻重複詞語',
      '正式程度': '語言過度正式',
      'AI文章結構': 'AI 工整結構',
      '社群AI套路': '社群 AI 套路',
    };
    for (final entry in aiResult.details.entries) {
      if (aiRiskKeys.containsKey(entry.key) && entry.value > 0.3) {
        items.add(EvidenceItem(
          category: 'AI特徵：${entry.key}',
          detail: aiRiskKeys[entry.key]!,
          contribution: entry.value * 0.12,
          isRisk: true,
        ));
      }
    }

    // Human marker (credibility)
    final humanScore = aiResult.details['人類口語標記'] ?? 0;
    if (humanScore > 0.2) {
      items.add(EvidenceItem(
        category: '人類撰寫特徵',
        detail: '偵測到口語、非正式表達',
        contribution: 0,
        isRisk: false,
      ));
    }

    return items;
  }

  List<EvidenceItem> _buildUrlModeEvidenceItems(
    URLScanResult urlResult,
    AIScanResult? aiResult,
    FakeNewsResult? fakeNewsResult,
  ) {
    final items = <EvidenceItem>[];

    if (urlResult.isTrustedDomain && urlResult.trustedDomainLabel != null) {
      items.add(EvidenceItem(
        category: '可信任來源網站',
        detail: urlResult.trustedDomainLabel!,
        contribution: 0,
        isRisk: false,
      ));
    }

    for (final entry in urlResult.checks.entries) {
      if (entry.value > 0) {
        items.add(EvidenceItem(
          category: '連結風險：${entry.key}',
          detail: '風險值 ${(entry.value * 100).toStringAsFixed(0)}%',
          contribution: entry.value * 0.15,
          isRisk: true,
        ));
      }
    }

    if (fakeNewsResult != null) {
      for (final entry in fakeNewsResult.categoryBreakdown.entries) {
        items.add(EvidenceItem(
          category: '假訊息：${entry.key}',
          detail: entry.value.take(2).join('、'),
          contribution: 0.18,
          isRisk: true,
        ));
      }
    }

    return items;
  }

  double get _combinedRiskScore {
    double score = 0;
    int count = 0;
    if (_result != null) { score += _result!.aiProbability; count++; }
    if (_fakeNewsResult != null) { score += _fakeNewsResult!.riskScore; count++; }
    if (_urlScanResult != null) { score += _urlScanResult!.riskScore; count++; }
    return count > 0 ? (score / count) : 0;
  }

  void _clear() {
    _textController.clear();
    _urlController.clear();
    setState(() {
      _result = null;
      _fakeNewsResult = null;
      _urlScanResult = null;
      _fetchedTitle = null;
      _extractedPreview = null;
      _fetchError = null;
      _evidenceItems = [];
    });
  }

  void _toggleMode() {
    setState(() {
      _isUrlMode = !_isUrlMode;
      _result = null;
      _fakeNewsResult = null;
      _urlScanResult = null;
      _fetchedTitle = null;
      _extractedPreview = null;
      _fetchError = null;
      _evidenceItems = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 文章掃描'),
        actions: [
          if (_result != null || _fakeNewsResult != null)
            IconButton(icon: const Icon(Icons.clear), onPressed: _clear),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('貼上文字'),
                      icon: Icon(Icons.edit),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('輸入網址'),
                      icon: Icon(Icons.link),
                    ),
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
                      Center(child: RiskIndicator(score: _urlScanResult!.riskScore)),
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
                            ..._urlScanResult!.warnings
                                .where((w) => w != '未偵測到明顯的安全風險')
                                .map(
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
                // Fake news detection results
                if (_fakeNewsResult != null) ...[
                  const SizedBox(height: 8),
                  ScanResultCard(
                    icon: Icons.fact_check,
                    title: '假訊息偵測',
                    value: _fakeNewsResult!.verdict,
                    valueColor: _fakeNewsResult!.riskScore >= 0.55
                        ? Colors.red
                        : _fakeNewsResult!.riskScore >= 0.30
                        ? Colors.orange
                        : _fakeNewsResult!.riskScore >= 0.10
                        ? Colors.blueGrey
                        : Colors.green,
                    children: [
                      Center(child: RiskIndicator(score: _fakeNewsResult!.riskScore)),
                      const SizedBox(height: 16),
                      if (_fakeNewsResult!.foundRedFlags.isNotEmpty) ...[
                        const Text(
                          '偵測到的紅旗詞語',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _fakeNewsResult!.foundRedFlags.take(8).map((kw) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                kw,
                                style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_fakeNewsResult!.credibilityMarkers.isNotEmpty) ...[
                        const Text(
                          '可信度標記',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _fakeNewsResult!.credibilityMarkers.take(5).map((m) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                m,
                                style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Text(
                        '分析說明',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ..._fakeNewsResult!.reasons.map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(' • ', style: TextStyle(color: Colors.grey)),
                              Expanded(
                                child: Text(r, style: const TextStyle(fontSize: 13, height: 1.4)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // AI generation detection results
                if (_result != null) ...[
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
                      Center(child: RiskIndicator(score: _result!.aiProbability)),
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
                  const SizedBox(height: 80),
                ],
              ],
            ),
          ),
          if (_evidenceItems.isNotEmpty)
            FloatingEvidencePanel(
              key: ValueKey(Object.hashAll([
                _result?.aiProbability,
                _fakeNewsResult?.riskScore,
                _urlScanResult?.riskScore,
              ])),
              items: _evidenceItems,
              overallScore: _combinedRiskScore,
              title: '判斷依據（拖曳可移動）',
            ),
        ],
      ),
    );
  }
}
