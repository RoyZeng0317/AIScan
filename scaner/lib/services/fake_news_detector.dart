class FakeNewsResult {
  final double riskScore;
  final String verdict;
  final List<String> foundRedFlags;
  final List<String> credibilityMarkers;
  final List<String> reasons;
  final Map<String, List<String>> categoryBreakdown;

  const FakeNewsResult({
    required this.riskScore,
    required this.verdict,
    required this.foundRedFlags,
    required this.credibilityMarkers,
    required this.reasons,
    required this.categoryBreakdown,
  });
}

class FakeNewsDetector {
  static const Map<String, List<String>> _redFlagCategories = {
    '聳動標題': [
      '震驚', '重磅', '驚天大秘密', '緊急必看', '曝光', '內幕', '瞞不住了',
      '全網刪除', '你不知道的', '驚人真相', '驚呆', '驚爆',
      '刪帖前趕快看', '瘋傳', '看完我哭了',
    ],
    '陰謀論語言': [
      '政府隱瞞', '媒體封鎖', '被刪帖', '官方不敢說', '醫生不告訴你',
      '被封鎖了', '主流媒體不報', '暗黑真相', '深層政府', '洗腦媒體',
      '控制媒體', '背後黑手', '不為人知的秘密', '黑幕曝光',
    ],
    '健康謠言': [
      '包治百病', '百分百有效', '奇蹟療效', '秘方偏方', '神奇療法',
      '癌症剋星', '立即見效', '不需要吃藥', '自然療法根治',
      '一週見效', '永久治癒', '醫界不敢公布',
    ],
    '緊迫轉發': [
      '趕快轉發', '快點分享', '不轉不是', '轉給所有人',
      '刪帖前趕快', '讓更多人知道', '不分享對不起', '請大家轉傳',
      '馬上分享出去', '趕緊傳給家人',
    ],
    '詐騙誘惑': [
      '中獎了', '恭喜獲得', '免費領取', '限時免費', '點擊領獎',
      '您已被選中', '獨家優惠', '投資穩賺', '月入百萬',
      '保證獲利', '零風險投資',
    ],
    '銀行詐騙訊息': [
      '銀行帳戶凍結', '帳戶異常', '請重新付款', '信用卡遭盜刷',
      '立即解凍', '點擊驗證', '輸入OTP', '緊急聯繫客服',
      '逾期未處理將停權', '系統偵測到異常',
    ],
  };

  static const Map<String, double> _categoryWeights = {
    '聳動標題': 0.18,
    '陰謀論語言': 0.28,
    '健康謠言': 0.22,
    '緊迫轉發': 0.22,
    '詐騙誘惑': 0.25,
    '銀行詐騙訊息': 0.30,
  };

  static const List<String> _credibilityMarkers = [
    '根據研究', '研究指出', '調查顯示', '統計數據',
    '資料來源', '來源：', '引用自', '參考資料',
    '事實查核', '查核報告', '根據查核', '台灣事實查核中心',
    '衛生福利部', '疾病管制署', '教育部公告', '政府公告',
    '根據報導', '記者報導', '新聞稿', '官方聲明',
    'WHO表示', 'CDC指出',
    '另一方面', '存在爭議', '尚待確認', '需更多研究',
    'OTP驗證失敗', '餘額不足', '逾時',
  ];

  // URL links that suggest credibility when found in text
  static const List<String> _credibleUrlPatterns = [
    'gov.tw', 'edu.tw', 'who.int', 'cdc.gov',
    'factcheck.tw', 'cofacts.tw', 'mygopen.com',
    'reuters.com', 'bbc.com', 'ap.org',
  ];

  FakeNewsResult analyze(String text) {
    if (text.trim().isEmpty) {
      return const FakeNewsResult(
        riskScore: 0,
        verdict: '請輸入文字',
        foundRedFlags: [],
        credibilityMarkers: [],
        reasons: ['無內容可分析'],
        categoryBreakdown: {},
      );
    }

    final foundRedFlags = <String>[];
    final foundCategories = <String, List<String>>{};
    final foundCredibilityMarkers = <String>[];
    final reasons = <String>[];
    double riskScore = 0;

    for (final entry in _redFlagCategories.entries) {
      final found = <String>[];
      for (final kw in entry.value) {
        if (text.contains(kw)) {
          found.add(kw);
          foundRedFlags.add(kw);
        }
      }
      if (found.isNotEmpty) {
        foundCategories[entry.key] = found;
      }
    }

    for (final marker in _credibilityMarkers) {
      if (text.contains(marker)) {
        foundCredibilityMarkers.add(marker);
      }
    }

    for (final pattern in _credibleUrlPatterns) {
      if (text.contains(pattern) && !foundCredibilityMarkers.contains(pattern)) {
        foundCredibilityMarkers.add('可信網址：$pattern');
      }
    }

    for (final entry in foundCategories.entries) {
      final weight = _categoryWeights[entry.key] ?? 0.15;
      final intensity = (entry.value.length / 3).clamp(0.5, 1.0);
      riskScore += weight * intensity;
      final shown = entry.value.take(2).join('、');
      final more = entry.value.length > 2 ? '...' : '';
      reasons.add('偵測到「${entry.key}」：$shown$more');
    }

    if (foundCredibilityMarkers.isNotEmpty) {
      final bonus = (foundCredibilityMarkers.length * 0.07).clamp(0.0, 0.25);
      riskScore -= bonus;
      final shown = foundCredibilityMarkers.take(2).join('、');
      reasons.add('找到可信度標記：$shown（降低風險分數）');
    }

    riskScore = riskScore.clamp(0.0, 1.0);
    riskScore = double.parse(riskScore.toStringAsFixed(2));

    String verdict;
    if (riskScore >= 0.55) {
      verdict = '高風險 - 疑似假訊息/詐騙';
    } else if (riskScore >= 0.30) {
      verdict = '中風險 - 內容請查核';
    } else if (riskScore >= 0.10) {
      verdict = '低風險 - 建議留意';
    } else {
      verdict = '可信度較高';
    }

    if (reasons.isEmpty) {
      reasons.add('未偵測到明顯的假訊息特徵');
    }

    return FakeNewsResult(
      riskScore: riskScore,
      verdict: verdict,
      foundRedFlags: foundRedFlags,
      credibilityMarkers: foundCredibilityMarkers,
      reasons: reasons,
      categoryBreakdown: foundCategories,
    );
  }
}
