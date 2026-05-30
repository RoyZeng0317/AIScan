class AIScanResult {
  final double aiProbability;
  final String verdict;
  final List<String> reasons;
  final Map<String, double> details;

  AIScanResult({
    required this.aiProbability,
    required this.verdict,
    required this.reasons,
    required this.details,
  });
}

class AIDetector {
  static const List<String> _aiPhrases = [
    'as an ai', 'as a language model', 'i cannot', "i can't",
    'i apologize', "i'm sorry", 'i am sorry', 'i am unable',
    'i do not have', 'i don\'t have', 'it is important to note',
    'it\'s worth noting', 'in conclusion', 'in summary',
    'to summarize', 'overall,', 'furthermore,', 'moreover,',
    'additionally,', 'in addition,', 'nevertheless,', 'nonetheless,',
    'on the other hand', 'as a result', 'consequently,',
    'this highlights', 'this underscores', 'it is crucial',
    'it is essential', 'please note that', 'keep in mind that',
    'let\'s delve', 'let us explore', 'delve into',
    'a tapestry', 'a nuanced', 'in the realm of',
    'landscape of', 'the intricate', 'the evolving',
    'here\'s why', 'here are', 'here is', 'let me share',
    'let me break', 'that\'s a wrap', 'that is a wrap',
    'day 1 of', 'day 2 of', 'day 3 of', 'day 4 of', 'day 5 of',
    'day 6 of', 'day 7 of', 'day 8 of', 'day 9 of',
    'things that will', 'habits that will', 'tips that will',
    'ways to improve', 'ways to boost', 'signs you\'re',
    'reasons why', 'reasons you should', 'steps to',
    'your daily routine', 'your morning routine',
    'changed my life', 'changed my perspective',
  ];

  static const List<String> _zhAiPhrases = [
    '首先，', '其次，', '最後，', '總之，', '總而言之',
    '值得注意的是', '重要的是', '不可否認', '我們可以看到',
    '從這個角度來看', '綜上所述', '由此可見', '換句話說',
    '具體來說', '一般來說', '毫無疑問', '毋庸置疑',
    '值得一提的是', '需要強調的是', '必須指出',
    '從某種意義上說', '在某種程度上', '從這個意義上說',
    '這意味著', '這表明', '這說明',
    '因此，', '然而，', '但是，', '不過，',
    '第一，', '第二，', '第三，',
    '不僅如此', '除此之外', '也就是說',
    '改變人生的', '改變你的', '讓你變得更好',
    '個習慣', '個方法', '個技巧', '個秘訣',
    '為什麼你應該', '為什麼需要',
  ];

  static const List<String> _humanMarkers = [
    ' honestly', ' honestly,', ' honestly?', 'wtf', 'wtf?',
    'damn', 'crap', ' screw', 'lol', 'lmao',
    ' tbh', ' tbh,', ' idk', ' idk,',
    ' kinda', ' sorta', ' dunno',
    'gonna', 'wanna', 'gotta',
    'ain\'t', ' y\'all', 'gimme',
    ' lemme',
    '!?!', '?!?', '...!',
  ];

  static const List<String> _zhHumanMarkers = [
    '欸', '喔', '啦', '囉', '嘛', '耶',
    '靠', '幹', '妈的', '媽的', '他媽',
    '笑死', '超好笑', '真的假的',
    '不懂', '問號', '傻眼',
    '呃', '嗯...', '嗯…',
    '哈哈哈', '哈哈', '呵呵',
    '無言', '無語', '暈倒',
    '拜託', '拜托', '好歹',
  ];

  AIScanResult analyze(String text) {
    if (text.trim().isEmpty) {
      return AIScanResult(
        aiProbability: 0,
        verdict: '請輸入文字',
        reasons: ['無內容可分析'],
        details: {},
      );
    }

    final reasons = <String>[];
    final details = <String, double>{};
    final wordCount = text.split(RegExp(r'\s+')).length;
    final isShort = wordCount < 40;

    final aiPhraseScore = _checkAIPhrases(text);
    details['AI常用語句'] = aiPhraseScore;
    if (aiPhraseScore > 0.2) {
      reasons.add('偵測到 AI 常用語句（如 "as an AI", "值得注意的是" 等）');
    }

    final humanMarkerScore = _checkHumanMarkers(text);
    details['人類口語標記'] = humanMarkerScore;
    if (humanMarkerScore > 0.15) {
      reasons.add('偵測到人類口語表達，內容傾向真人撰寫');
    }

    final repetitionScore = _checkRepetition(text);
    details['重複模式'] = repetitionScore;
    if (repetitionScore > 0.3) {
      reasons.add('文字存在高頻重複模式（AI 常見特徵）');
    }

    double burstinessScore;
    if (isShort) {
      burstinessScore = _checkShortBurstiness(text);
    } else {
      burstinessScore = _checkBurstiness(text);
    }
    details['句長變化'] = burstinessScore;
    if (burstinessScore > 0.6) {
      reasons.add('句子長度過於均勻，缺乏人類寫作的起伏變化');
    } else if (burstinessScore < 0.3) {
      reasons.add('句子長度變化大，符合人類寫作特徵');
    }

    final formalityScore = _checkFormality(text);
    details['正式程度'] = formalityScore;
    if (formalityScore > 0.4) {
      reasons.add('語言風格過於正式且結構化');
    }

    final aiStructureScore = _checkAIStructure(text);
    details['AI文章結構'] = aiStructureScore;
    if (aiStructureScore > 0.2) {
      reasons.add('文章結構過於工整（分點列舉、對稱句式等 AI 特徵）');
    }

    final perfectScore = _checkPerfectness(text);
    details['完美程度'] = perfectScore;
    if (perfectScore > 0.3) {
      reasons.add('文字太過「完美」（無口語、無錯字、標點工整）');
    }

    final socialScore = _checkSocialPatterns(text);
    details['社群AI套路'] = socialScore;
    if (socialScore > 0.2) {
      reasons.add('使用常見 AI 社群貼文套路（清單體、心靈雞湯句式等）');
    }

    double totalScore = 0;

    if (isShort) {
      totalScore += aiPhraseScore * 0.18;
      totalScore += (1 - humanMarkerScore) * 0.20;
      totalScore += repetitionScore * 0.06;
      totalScore += burstinessScore * 0.12;
      totalScore += formalityScore * 0.08;
      totalScore += aiStructureScore * 0.16;
      totalScore += perfectScore * 0.08;
      totalScore += socialScore * 0.12;
      totalScore += _checkNoErrors(text) * 0.04;
      if (totalScore > 0) totalScore = (totalScore * 1.15).clamp(0.0, 1.0);
    } else {
      totalScore += aiPhraseScore * 0.20;
      totalScore += (1 - humanMarkerScore) * 0.15;
      totalScore += repetitionScore * 0.10;
      totalScore += burstinessScore * 0.13;
      totalScore += formalityScore * 0.10;
      totalScore += aiStructureScore * 0.14;
      totalScore += perfectScore * 0.08;
      totalScore += socialScore * 0.10;
    }

    totalScore = totalScore.clamp(0.0, 1.0);

    String verdict;
    if (totalScore >= 0.55) {
      verdict = '高度可能是 AI 生成';
    } else if (totalScore >= 0.35) {
      verdict = '可能包含 AI 生成內容';
    } else if (totalScore >= 0.15) {
      verdict = '可能為人類撰寫';
    } else {
      verdict = '高度可能是人類撰寫';
    }

    if (reasons.isEmpty) {
      reasons.add('未偵測到明顯的 AI 生成特徵');
    }

    return AIScanResult(
      aiProbability: double.parse(totalScore.toStringAsFixed(2)),
      verdict: verdict,
      reasons: reasons,
      details: details,
    );
  }

  double _checkAIPhrases(String text) {
    final lower = text.toLowerCase();
    int count = 0;
    for (final phrase in _aiPhrases) {
      if (lower.contains(phrase)) count++;
    }
    for (final phrase in _zhAiPhrases) {
      if (text.contains(phrase)) count++;
    }
    final wordCount = text.split(RegExp(r'\s+')).length;
    if (wordCount == 0) return 0;
    final rate = count / ((wordCount / 30) + 1);
    return rate.clamp(0.0, 1.0);
  }

  double _checkHumanMarkers(String text) {
    final lower = text.toLowerCase();
    int count = 0;
    for (final marker in _humanMarkers) {
      if (lower.contains(marker)) count++;
    }
    for (final marker in _zhHumanMarkers) {
      if (text.contains(marker)) count++;
    }
    return (count / 4).clamp(0.0, 1.0);
  }

  double _checkRepetition(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    if (words.length < 6) return 0.3;

    final freq = <String, int>{};
    for (final w in words) {
      final clean = w.replaceAll(RegExp(r'[^\w]'), '');
      if (clean.length > 2) {
        freq[clean] = (freq[clean] ?? 0) + 1;
      }
    }

    if (freq.isEmpty) return 0.3;
    final maxFreq = freq.values.reduce((a, b) => a > b ? a : b);
    if (maxFreq <= 1) return 0.0;

    final avgFreq = freq.values.reduce((a, b) => a + b) / freq.length;
    return ((maxFreq / avgFreq) / 4).clamp(0.0, 1.0);
  }

  double _checkBurstiness(String text) {
    final sentences = text.split(RegExp(r'[.!?\n]+'))
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim().split(RegExp(r'\s+')).length)
        .toList();

    if (sentences.length < 4) return _checkShortBurstiness(text);

    final mean = sentences.reduce((a, b) => a + b) / sentences.length;
    if (mean == 0) return 0.5;

    final variance = sentences
        .map((s) => (s - mean) * (s - mean))
        .reduce((a, b) => a + b) /
        sentences.length;
    final cv = variance / mean;

    return (1 - (cv / 3).clamp(0.0, 1.0));
  }

  double _checkShortBurstiness(String text) {
    final lines = text.split(RegExp(r'[\n]+'))
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim().split(RegExp(r'\s+')).length)
        .toList();

    if (lines.length < 2) return 0.4;

    final mean = lines.reduce((a, b) => a + b) / lines.length;
    if (mean == 0) return 0.4;

    final variance = lines
        .map((s) => (s - mean) * (s - mean))
        .reduce((a, b) => a + b) /
        lines.length;
    final cv = variance / mean;

    return (1 - (cv / 2).clamp(0.0, 1.0));
  }

  double _checkFormality(String text) {
    final lower = text.toLowerCase();
    final formalWords = [
      'therefore', 'consequently', 'furthermore', 'moreover',
      'nevertheless', 'nonetheless', 'whereas', 'thus', 'hence',
      'accordingly', 'additionally', 'subsequently',
      'predominantly', 'significantly', 'substantially',
      'considerably', 'remarkably',
      'utilize', 'utilizes', 'utilized', 'implement',
      'implements', 'implemented', 'implementation',
      'demonstrate', 'demonstrates', 'demonstrated',
      'facilitate', 'facilitates', 'facilitated',
      'leverage', 'leverages', 'leveraged',
      '然而', '此外', '因此', '總之', '綜上',
      '首先', '其次', '最後', ' notably',
    ];

    int count = 0;
    for (final w in formalWords) {
      if (lower.contains(w)) count++;
    }

    final wordCount = text.split(RegExp(r'\s+')).length;
    final rate = count / ((wordCount / 20) + 1);
    return rate.clamp(0.0, 1.0);
  }

  double _checkAIStructure(String text) {
    double score = 0;
    int checks = 0;

    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (lines.length >= 2) {
      bool hasNumberedList = false;
      bool hasBulletList = false;
      int numbered = 0;
      for (final line in lines) {
        if (RegExp(r'^\d+[\.\)]').hasMatch(line.trim())) numbered++;
        if (line.trim().startsWith('-') || line.trim().startsWith('•')) hasBulletList = true;
      }
      if (numbered >= 2) hasNumberedList = true;
      if (hasNumberedList || hasBulletList) {
        score += 0.4;
        checks++;
      }
    }

    if (RegExp(r'[—–]').hasMatch(text)) {
      score += 0.3;
      checks++;
    }

    final sentences = text.split(RegExp(r'[.!?\n]+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    if (sentences.length >= 3) {
      final lengths = sentences.map((s) => s.split(RegExp(r'\s+')).length).toList();
      final maxDiff = lengths.reduce((a, b) => a > b ? a : b) - lengths.reduce((a, b) => a < b ? a : b);
      if (maxDiff <= 3) {
        score += 0.3;
        checks++;
      }
    }

    return checks > 0 ? (score / checks).clamp(0.0, 1.0) : 0.0;
  }

  double _checkPerfectness(String text) {
    double score = 0;
    int checks = 0;

    final sentences = text.split(RegExp(r'[.!?\n]+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    if (sentences.length >= 3) {
      final endWithPunct = sentences.where((s) {
        final t = s.trim();
        return t.endsWith('.') || t.endsWith('!') || t.endsWith('?') || t.endsWith('。') || t.endsWith('！') || t.endsWith('？');
      }).length;

      final punctRate = endWithPunct / sentences.length;
      if (punctRate > 0.9) {
        score += 0.5;
        checks++;
      }
    }

    if (text.length > 20) {
      final firstWordCaps = RegExp(r'(?<=[.!?\n]\s)[A-Z]');
      final capsCount = firstWordCaps.allMatches(text).length;
      if (capsCount > 0) {
        final sentenceCount = text.split(RegExp(r'[.!?]+\s')).length;
        if (capsCount >= sentenceCount - 1 && sentenceCount > 2) {
          score += 0.3;
          checks++;
        }
      }
    }

    if (RegExp(r'[，]').hasMatch(text)) {
      final zhChars = text.split('').where((c) => RegExp(r'[\u4e00-\u9fff]').hasMatch(c)).length;
      final commas = RegExp(r'[，]').allMatches(text).length;
      if (zhChars > 0 && commas > 0) {
        final commaRate = commas / zhChars;
        if (commaRate > 0.02 && commaRate < 0.08) {
          score += 0.3;
          checks++;
        }
      }
    }

    final hasTypoMarkers = RegExp(r'[，,]\s*[a-z]').hasMatch(text) == false;
    if (hasTypoMarkers && text.length > 30) {
      score += 0.2;
      checks++;
    }

    return checks > 0 ? (score / checks).clamp(0.0, 1.0) : 0.0;
  }

  double _checkSocialPatterns(String text) {
    double score = 0;
    int checks = 0;

    final lower = text.toLowerCase();

    final listPatterns = [
      'things that', 'habits that', 'ways to', 'signs you',
      'reasons why', 'lessons that', 'rules that', 'quotes that',
      'books that', 'skills that', 'tips that', 'habits of',
      'secrets of', 'benefits of', 'power of', 'art of',
      'importance of', 'beauty of', 'future of',
    ];
    for (final p in listPatterns) {
      if (lower.contains(p)) { score += 0.35; checks++; break; }
    }

    final openingPatterns = [
      'here\'s why', 'here\'s how', 'here\'s what', 'here\'s the',
      'let me tell', 'let me share', 'let me explain',
      'i\'ve been thinking', 'i wanted to share',
      'after years of', 'after months of', 'after weeks of',
      'if you\'re looking', 'if you want to',
    ];
    for (final p in openingPatterns) {
      if (lower.contains(p)) { score += 0.3; checks++; break; }
    }

    if (RegExp(r'(that will|that can|that could|that would)\s+\w+\s+(your|you)')
        .hasMatch(lower)) {
      score += 0.3;
      checks++;
    }

    if (RegExp(r'(stop|start|try|avoid|embrace|master|unlock)\s+'
        r'(doing|being|overthinking|procrastinating|settling|limiting)').hasMatch(lower)) {
      score += 0.3;
      checks++;
    }

    if (RegExp(r'\d+\s+(things|habits|ways|tips|signs|lessons|books|lessons|reasons|steps)')
        .hasMatch(lower)) {
      score += 0.4;
      checks++;
    }

    if (RegExp(r'(thread|🧵|📖|📚|💡|🔥|⚡|👑|💎)\s*[:\-—]').hasMatch(text)) {
      score += 0.25;
      checks++;
    }

    return checks > 0 ? (score / checks).clamp(0.0, 1.0) : 0.0;
  }

  double _checkNoErrors(String text) {
    if (text.length < 15) return 0.3;

    final sentences = text.split(RegExp(r'[.!?\n]+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (sentences.length < 2) return 0.2;

    int properEndings = 0;
    for (final s in sentences) {
      final t = s.trim();
      if (t.endsWith('.') || t.endsWith('!') || t.endsWith('?') ||
          t.endsWith('。') || t.endsWith('！') || t.endsWith('？')) {
        properEndings++;
      }
    }

    final rate = properEndings / sentences.length;
    if (rate > 0.85) return 0.6;
    if (rate > 0.6) return 0.3;
    return 0.0;
  }
}
