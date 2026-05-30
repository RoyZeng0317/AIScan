import 'dart:convert';
import 'package:http/http.dart' as http;

class AIScamResult {
  final double scamProbability;
  final String explanation;
  final String? error;

  AIScamResult({
    required this.scamProbability,
    required this.explanation,
    this.error,
  });
}

class AIScamDetector {
  String? _apiKey;
  String _model = 'gpt-4o-mini';

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  void configure(String apiKey, {String model = 'gpt-4o-mini'}) {
    _apiKey = apiKey;
    _model = model;
  }

  void clear() {
    _apiKey = null;
  }

  Future<AIScamResult> analyzeURL(String url) async {
    if (!isConfigured) {
      return AIScamResult(
        scamProbability: 0,
        explanation: '未設定 AI API Key，無法使用 AI 分析',
        error: 'API key not configured',
      );
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': '''你是一個專業的網路詐騙偵測專家。請分析給定的 URL 是否為詐騙/釣魚連結。

請從以下面向分析：
1. 域名是否冒充知名品牌或平台（如 threads.net → threads.com 的 typo-squatting）
2. 是否包含可疑的追蹤參數
3. 路徑中是否有可疑模式（隨機數字、@username.number 等）
4. URL 整體的可疑程度

請以 JSON 格式回覆，格式如下：
{
  "isScam": true/false,
  "scamProbability": 0.0-1.0,
  "reasons": ["原因1", "原因2"],
  "explanation": "詳細分析說明"
}''',
            },
            {
              'role': 'user',
              'content': '請分析這個 URL 是否為詐騙連結：$url',
            },
          ],
          'temperature': 0.1,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final errorMsg = body['error']?['message'] ?? 'API 請求失敗 (${response.statusCode})';
        return AIScamResult(
          scamProbability: 0,
          explanation: 'AI 分析失敗',
          error: errorMsg,
        );
      }

      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'] ?? '';

      final jsonMatch = RegExp(r'\{[^{}]*\}').firstMatch(content);
      if (jsonMatch != null) {
        final result = jsonDecode(jsonMatch.group(0)!);
        return AIScamResult(
          scamProbability: (result['scamProbability'] as num?)?.toDouble() ?? 0.5,
          explanation: result['explanation'] as String? ??
              result['reasons']?.join('\n') ?? '分析完成',
        );
      }

      return AIScamResult(
        scamProbability: 0.5,
        explanation: content,
      );
    } catch (e) {
      return AIScamResult(
        scamProbability: 0,
        explanation: 'AI 分析連線失敗',
        error: e.toString(),
      );
    }
  }

  Future<AIScamResult> analyzeText(String text) async {
    if (!isConfigured) {
      return AIScamResult(
        scamProbability: 0,
        explanation: '未設定 AI API Key',
        error: 'API key not configured',
      );
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': '''你是一個專業的詐騙訊息偵測專家。請分析給定的文字內容是否為詐騙訊息。

請從以下面向分析：
1. 是否包含緊急/威脅性語言（要求立即行動）
2. 是否要求提供個資、帳密、金融資訊
3. 是否承諾不實獎勵（中獎、贈品、投資報酬）
4. 語言風格是否像典型的詐騙/釣魚訊息
5. 是否包含可疑的連結或聯絡方式

請以 JSON 格式回覆：
{
  "isScam": true/false,
  "scamProbability": 0.0-1.0,
  "reasons": ["原因1", "原因2"],
  "explanation": "詳細分析說明"
}''',
            },
            {
              'role': 'user',
              'content': '請分析以下內容是否為詐騙訊息：\n\n$text',
            },
          ],
          'temperature': 0.1,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final errorMsg = body['error']?['message'] ?? 'API 請求失敗 (${response.statusCode})';
        return AIScamResult(
          scamProbability: 0,
          explanation: 'AI 分析失敗',
          error: errorMsg,
        );
      }

      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'] ?? '';

      final jsonMatch = RegExp(r'\{[^{}]*\}').firstMatch(content);
      if (jsonMatch != null) {
        final result = jsonDecode(jsonMatch.group(0)!);
        return AIScamResult(
          scamProbability: (result['scamProbability'] as num?)?.toDouble() ?? 0.5,
          explanation: result['explanation'] as String? ??
              result['reasons']?.join('\n') ?? '分析完成',
        );
      }

      return AIScamResult(
        scamProbability: 0.5,
        explanation: content,
      );
    } catch (e) {
      return AIScamResult(
        scamProbability: 0,
        explanation: 'AI 分析連線失敗',
        error: e.toString(),
      );
    }
  }
}
