class URLScanResult {
  final double riskScore;
  final String verdict;
  final List<String> warnings;
  final Map<String, double> checks;
  final String? aiAnalysis;
  final double? aiRiskScore;
  final bool isTrustedDomain;
  final String? trustedDomainLabel;

  URLScanResult({
    required this.riskScore,
    required this.verdict,
    required this.warnings,
    required this.checks,
    this.aiAnalysis,
    this.aiRiskScore,
    this.isTrustedDomain = false,
    this.trustedDomainLabel,
  });
}

class URLScannerService {
  static const Map<String, String> _knownSocialMedia = {
    'threads.net': 'Threads',
    'instagram.com': 'Instagram',
    'facebook.com': 'Facebook',
    'twitter.com': 'Twitter / X',
    'x.com': 'Twitter / X',
    'linkedin.com': 'LinkedIn',
    'tiktok.com': 'TikTok',
    'youtube.com': 'YouTube',
    'pinterest.com': 'Pinterest',
    'snapchat.com': 'Snapchat',
    'reddit.com': 'Reddit',
    'discord.com': 'Discord',
    'telegram.org': 'Telegram',
    'whatsapp.com': 'WhatsApp',
    'wechat.com': 'WeChat',
    'line.me': 'LINE',
    'medium.com': 'Medium',
    'mastodon.social': 'Mastodon',
    'bluesky.social': 'Bluesky',
  };

  static const List<String> _suspiciousTLDs = [
    '.tk', '.ml', '.ga', '.cf', '.gq',
    '.xyz', '.top', '.loan', '.work', '.click',
    '.download', '.review', '.date', '.men',
    '.win', '.bid', '.trade', '.webcam',
    '.science', '.party', '.racing', '.accountant',
    '.mom', '.lol', '.kim', '.surf', '.space',
    '.site', '.online', '.press', '.rest',
  ];

  static const List<String> _shorteners = [
    'bit.ly', 'tinyurl.com', 'tiny.cc', 'goo.gl',
    'ow.ly', 'is.gd', 'buff.ly', 'shorturl.at',
    't.co', 'rb.gy', 'cutt.ly', 'shorte.st',
    'adf.ly', 'bc.vc', 'u.to', 'cli.gs',
    'dfen.in', 'gg.gg', 'v.gd', 'soo.gd',
  ];

  // Trusted domains — exact match or subdomain only
  static const Map<String, String> _trustedDomainMap = {
    // Taiwan government
    'president.gov.tw': '總統府',
    'moj.gov.tw': '法務部',
    'police.gov.tw': '警政署',
    'cdc.gov.tw': '疾病管制署',
    'mohw.gov.tw': '衛生福利部',
    'moe.edu.tw': '教育部',
    'fia.gov.tw': '金融監督管理委員會',
    // Taiwan banks
    'ctbcbank.com': '中信銀行',
    'esunbank.com': '玉山銀行',
    'bot.com.tw': '臺灣銀行',
    'megabank.com.tw': '兆豐銀行',
    'landbank.com.tw': '土地銀行',
    'firstbank.com.tw': '第一銀行',
    'taishinbank.com.tw': '台新銀行',
    'sinopac.com': '永豐銀行',
    'bok.com.tw': '高雄銀行',
    'hncb.com.tw': '華南銀行',
    'tcb-bank.com.tw': '合作金庫',
    'cathaybank.com.tw': '國泰世華銀行',
    'yuantabank.com.tw': '元大銀行',
    'ubot.com.tw': '聯邦銀行',
    'entiebank.com.tw': '安泰銀行',
    // Taiwan major media
    'udn.com': '聯合新聞網',
    'chinatimes.com': '中時媒體',
    'ltn.com.tw': '自由時報',
    'ettoday.net': 'ETtoday',
    'setn.com': '三立新聞',
    'tvbs.com.tw': 'TVBS',
    'cts.com.tw': '中視',
    'pts.org.tw': '公視',
    'storm.mg': '風傳媒',
    'ithome.com.tw': 'iThome',
    'technews.tw': 'TechNews',
    // International credible
    'bbc.com': 'BBC',
    'reuters.com': 'Reuters',
    'ap.org': 'AP通訊',
    'nytimes.com': 'NYT',
    'who.int': 'WHO',
    'cdc.gov': 'US CDC',
    // Fact-checking
    'factcheck.tw': '台灣事實查核中心',
    'cofacts.tw': 'Cofacts真的假的',
    'mygopen.com': 'MyGoPen',
  };

  static const List<String> _sensationalUrlKeywords = [
    'shocking', 'secret', 'truth', 'revealed', 'exposed', 'hidden',
    'suppressed', 'forbidden', 'leaked', 'scandal', 'bombshell',
    'banned', 'censored', 'conspiracy',
    '震驚', '曝光', '內幕', '秘密', '真相', '驚天', '黑幕', '封鎖',
  ];

  static const List<String> _phishingKeywords = [
    'login', 'signin', 'verify', 'account', 'secure',
    'update', 'confirm', 'banking', 'password', 'credential',
    'authenticate', 'security', 'paypal', 'amazon', 'apple',
    'google', 'facebook', 'instagram', 'microsoft', 'netflix',
    'free', 'prize', 'winner', 'congratulations', 'claim',
    'bonus', 'refund', 'invoice', 'payment', 'wallet',
    'cryptocurrency', 'bitcoin', 'eth', 'airdrop', 'giveaway',
    'otp', '2fa', 'authenticator', 'recovery', 'unlock',
    'claim', 'withdraw', 'deposit', 'transfer', 'verify now',
    'identity', 'ssn', 'social security', 'credit card',
    'debit', 'routing', 'account number', 'cvv',
  ];

  static const List<String> _brands = [
    'paypal', 'amazon', 'google', 'facebook', 'instagram',
    'microsoft', 'netflix', 'apple', 'twitter', 'whatsapp',
    'linkedin', 'dropbox', 'adobe', 'spotify', 'steam',
    'ebay', 'ali', 'taobao', 'wechat', 'alipay',
    'line', 'yahoo', 'outlook', 'hotmail', 'gmail',
    'threads', 'tiktok', 'discord', 'telegram',
  ];

  URLScanResult scan(String urlString) {
    if (urlString.trim().isEmpty) {
      return URLScanResult(
        riskScore: 0,
        verdict: '請輸入 URL',
        warnings: ['無內容可分析'],
        checks: {},
      );
    }

    final warnings = <String>[];
    final checks = <String, double>{};
    double riskScore = 0;

    String url = urlString.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return URLScanResult(
        riskScore: 0.9,
        verdict: '無效 URL 格式',
        warnings: ['URL 格式無法解析，可能包含惡意編碼'],
        checks: {'格式檢查': 0.9},
      );
    }

    final host = uri.host.toLowerCase();
    final fullUrl = url.toLowerCase();

    // 1. Check TLD
    final tldScore = _checkTLD(host);
    checks['可疑頂級域名'] = tldScore;
    if (tldScore > 0) {
      warnings.add('使用可疑頂級域名（${host.split('.').last}）');
      riskScore += 0.15;
    }

    // 2. Check URL shortener
    final shortScore = _checkShortener(host);
    checks['短網址服務'] = shortScore;
    if (shortScore > 0) {
      warnings.add('使用 URL 短網址服務，無法預覽真實目標');
      riskScore += 0.15;
    }

    // 3. Check phishing keywords
    final keywordScore = _checkPhishingKeywords(fullUrl);
    checks['釣魚關鍵字'] = keywordScore;
    if (keywordScore > 0) {
      final found = <String>[];
      for (final kw in _phishingKeywords) {
        if (fullUrl.contains(kw)) found.add(kw);
      }
      warnings.add('URL 包含釣魚常用詞：${found.take(3).join(', ')}${found.length > 3 ? '...' : ''}');
      riskScore += 0.2;
    }

    // 4. Check brand impersonation
    final brandScore = _checkBrandImpersonation(host, fullUrl);
    checks['品牌冒充'] = brandScore;
    if (brandScore > 0) {
      warnings.add('URL 疑似冒充知名品牌');
      riskScore += 0.25;
    }

    // 5. Check excessive subdomains
    final subdomainScore = _checkSubdomains(host);
    checks['過多子網域'] = subdomainScore;
    if (subdomainScore > 0) {
      warnings.add('URL 包含過多子網域層級，可能為混淆手法');
      riskScore += 0.1;
    }

    // 6. Check IP address instead of domain
    final ipScore = _checkIPAddress(host);
    checks['IP 直連'] = ipScore;
    if (ipScore > 0) {
      warnings.add('URL 使用 IP 位址而非網域名稱');
      riskScore += 0.15;
    }

    // 7. Check HTTPS
    final httpsScore = _checkHTTPS(uri);
    checks['HTTPS 加密'] = httpsScore;
    if (httpsScore > 0) {
      warnings.add('網站未使用 HTTPS 加密連線');
      riskScore += 0.1;
    }

    // 8. Special characters in domain
    final specialCharScore = _checkSpecialChars(host);
    checks['特殊字元'] = specialCharScore;
    if (specialCharScore > 0) {
      warnings.add('網域名稱包含特殊字元或數字混淆');
      riskScore += 0.1;
    }

    // 9. Social media typo-squatting / impersonation
    final socialMediaScore = _checkSocialMediaImpersonation(host);
    checks['社群媒體冒充'] = socialMediaScore;
    if (socialMediaScore > 0) {
      if (socialMediaScore >= 0.9) {
        warnings.add('冒充知名社群平台（疑似 typo-squatting 域名）');
      } else {
        warnings.add('域名疑似冒充社群媒體平台');
      }
      riskScore += 0.3;
    }

    // 10. Suspicious path pattern (@username.randomNumbers)
    final pathScore = _checkSuspiciousPath(uri.path, host);
    checks['可疑路徑模式'] = pathScore;
    if (pathScore > 0) {
      warnings.add('URL 路徑包含可疑的用戶名稱模式（隨機數字尾綴）');
      riskScore += 0.15;
    }

    // 11. Long tracking / suspicious query parameters
    final trackingScore = _checkTrackingParams(uri.query);
    checks['可疑追蹤參數'] = trackingScore;
    if (trackingScore > 0) {
      warnings.add('URL 包含異常長的追蹤參數（可能是釣魚追蹤碼）');
      riskScore += 0.1;
    }

    // 12. Homograph / internationalized domain confusion
    final homographScore = _checkHomograph(host);
    checks['同形字攻擊'] = homographScore;
    if (homographScore > 0) {
      warnings.add('網域名稱包含混淆字元（同形字攻擊）');
      riskScore += 0.25;
    }

    // 13. Sensational / fake-news keywords in URL path & query
    final sensationalScore = _checkSensationalKeywords(uri.path + uri.query);
    checks['聳動關鍵字'] = sensationalScore;
    if (sensationalScore > 0) {
      warnings.add('URL 包含假新聞常見聳動詞彙');
      riskScore += 0.15;
    }

    // 14. Trusted domain check — applied last to reduce false positives
    bool isTrustedDomain = false;
    String? trustedLabel;
    final trustedResult = _checkTrustedDomain(host);
    if (trustedResult != null) {
      isTrustedDomain = true;
      trustedLabel = trustedResult;
      warnings.removeWhere((w) => w.contains('釣魚常用詞') || w.contains('品牌冒充'));
      warnings.add('此網域為已知可信任網站（$trustedLabel）');
      riskScore = (riskScore - 0.45).clamp(0.0, 1.0);
    }

    riskScore = riskScore.clamp(0.0, 1.0);
    riskScore = double.parse(riskScore.toStringAsFixed(2));

    String verdict;
    if (riskScore >= 0.6) {
      verdict = '高風險 - 可能是詐騙/釣魚連結';
    } else if (riskScore >= 0.3) {
      verdict = '中風險 - 需要謹慎檢查';
    } else if (riskScore >= 0.1) {
      verdict = '低風險 - 可能有可疑特徵';
    } else {
      verdict = '安全 - 未偵測到明顯風險';
    }

    if (warnings.isEmpty) {
      warnings.add('未偵測到明顯的安全風險');
    }

    return URLScanResult(
      riskScore: riskScore,
      verdict: verdict,
      warnings: warnings,
      checks: checks,
      isTrustedDomain: isTrustedDomain,
      trustedDomainLabel: trustedLabel,
    );
  }

  double _checkTLD(String host) {
    for (final tld in _suspiciousTLDs) {
      if (host.endsWith(tld)) return 1.0;
    }
    return 0.0;
  }

  double _checkShortener(String host) {
    if (_shorteners.any((s) => host.contains(s))) return 1.0;
    return 0.0;
  }

  double _checkPhishingKeywords(String url) {
    int count = 0;
    for (final kw in _phishingKeywords) {
      if (url.contains(kw)) count++;
    }
    return (count / 4).clamp(0.0, 1.0);
  }

  double _checkBrandImpersonation(String host, String url) {
    for (final brand in _brands) {
      if (url.contains(brand) && !host.contains(brand)) {
        return 1.0;
      }
      if (host.contains(brand)) {
        final parts = host.split('.');
        if (parts.length > 2) {
          final mainDomain = parts.length >= 2
              ? parts[parts.length - 2]
              : parts[0];
          final brandWords = brand.split(RegExp(r'[\s-]+'));
          bool hasMisspelling = false;
          for (final bw in brandWords) {
            if (bw.length > 3 && mainDomain.length > 3) {
              final distance = _levenshtein(bw, mainDomain);
              if (distance <= 2 && distance > 0) {
                hasMisspelling = true;
              }
            }
          }
          if (hasMisspelling) return 1.0;
        }
      }
      if (url.contains(brand)) {
        final regex = RegExp(
          '$brand[\\.\\-][a-z]',
          caseSensitive: false,
        );
        if (regex.hasMatch(url)) return 1.0;
      }
    }
    return 0.0;
  }

  double _checkSubdomains(String host) {
    final parts = host.split('.');
    if (parts.length > 3) {
      return ((parts.length - 3) * 0.3).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  double _checkIPAddress(String host) {
    final ipRegex = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$');
    if (ipRegex.hasMatch(host)) return 1.0;
    return 0.0;
  }

  double _checkHTTPS(Uri uri) {
    if (uri.scheme != 'https') return 1.0;
    return 0.0;
  }

  double _checkSpecialChars(String host) {
    final mainPart = host.split('.').first;
    int specialCount = 0;
    for (final c in mainPart.codeUnits) {
      if ((c >= 48 && c <= 57) || (c >= 97 && c <= 122) || c == 45) {
        continue;
      }
      specialCount++;
    }
    final digitCount = mainPart.split('').where((c) => RegExp(r'[0-9]').hasMatch(c)).length;
    return ((specialCount * 0.3) + (digitCount > mainPart.length ~/ 2 ? 0.3 : 0)).clamp(0.0, 1.0);
  }

  int _levenshtein(String a, String b) {
    final matrix = List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) { matrix[i][0] = i; }
    for (var j = 0; j <= b.length; j++) { matrix[0][j] = j; }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((min, v) => v < min ? v : min);
      }
    }
    return matrix[a.length][b.length];
  }

  double _checkSocialMediaImpersonation(String host) {
    for (final entry in _knownSocialMedia.entries) {
      final legitDomain = entry.key;
      final legitMain = legitDomain.split('.').first;
      final hostMain = host.split('.').first;
      final hostWithoutTld = host.split('.').take(host.split('.').length - 1).join('.');

      if (host == legitDomain) return 0.0;

      if (hostWithoutTld.contains(legitMain)) {
        if (!host.endsWith(legitDomain.split('.').last)) {
          return 0.9;
        }
        return 0.0;
      }

      if (hostMain == legitMain && !host.endsWith(legitDomain.split('.').last)) {
        return 0.9;
      }

      final distance = _levenshtein(hostMain, legitMain);
      if (distance <= 2 && distance > 0 && hostMain.length > 3) {
        return 0.8;
      }

      if (hostMain.contains(legitMain) || legitMain.contains(hostMain)) {
        if (hostMain.length >= legitMain.length - 2 && hostMain.length <= legitMain.length + 2) {
          return 0.5;
        }
      }
    }
    return 0.0;
  }

  double _checkSuspiciousPath(String path, String host) {
    double score = 0;
    int checks = 0;

    if (RegExp(r'/@?\w+\.\d{3,}').hasMatch(path)) {
      score += 0.8;
      checks++;
    }

    if (RegExp(r'/@?\w+\d{6,}').hasMatch(path)) {
      score += 0.5;
      checks++;
    }

    if (RegExp(r'(giveaway|free|claim|airdrop|bonus)', caseSensitive: false).hasMatch(path)) {
      score += 0.6;
      checks++;
    }

    if (RegExp(r'/login|/signin|/verify|/auth|/secure|/wallet|/recovery', caseSensitive: false).hasMatch(path)) {
      score += 0.4;
      checks++;
    }

    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    final subdomainCount = host.split('.').length;
    if (parts.length >= 3 && subdomainCount >= 3) {
      score += 0.3;
      checks++;
    }

    return checks > 0 ? (score / checks).clamp(0.0, 1.0) : 0.0;
  }

  double _checkTrackingParams(String query) {
    if (query.isEmpty) return 0.0;

    if (query.length > 100) {
      return 0.8;
    }

    if (query.length > 50) {
      return 0.4;
    }

    final params = query.split('&');
    for (final p in params) {
      final parts = p.split('=');
      if (parts.length == 2 && parts[1].length > 40) {
        return 0.6;
      }
    }

    if (RegExp(r'(ref|ref_id|aff|aff_id|utm_source|utm_medium|utm_campaign)=', caseSensitive: false).allMatches(query).length >= 3) {
      return 0.2;
    }

    return 0.0;
  }

  double _checkHomograph(String host) {
    final mixedScript = RegExp(r'[a-zA-Z][\u0400-\u04FF\u0370-\u03FF\u4E00-\u9FFF\u3040-\u309F\u30A0-\u30FF]|[\u0400-\u04FF\u0370-\u03FF\u4E00-\u9FFF\u3040-\u309F\u30A0-\u30FF][a-zA-Z]');
    if (mixedScript.hasMatch(host)) return 0.9;

    final cyrillic = RegExp(r'[\u0400-\u04FF]');
    final latinSimilar = RegExp(r'[a-zA-Z]');
    if (cyrillic.hasMatch(host) && latinSimilar.hasMatch(host)) return 0.7;

    return 0.0;
  }

  double _checkSensationalKeywords(String pathAndQuery) {
    if (pathAndQuery.isEmpty) return 0.0;
    final lower = pathAndQuery.toLowerCase();
    int count = 0;
    for (final kw in _sensationalUrlKeywords) {
      if (lower.contains(kw.toLowerCase())) count++;
    }
    return (count / 3).clamp(0.0, 1.0);
  }

  /// Returns a label if host is a trusted domain, null otherwise.
  /// Only matches exact domain or its subdomain (e.g. sub.gov.tw matches gov.tw).
  String? _checkTrustedDomain(String host) {
    if (host.endsWith('.gov.tw') || host == 'gov.tw') return '\u53F0\u7063\u653F\u5E9C\u6A5F\u95DC';
    if (host.endsWith('.edu.tw') || host == 'edu.tw') return '\u53F0\u7063\u6559\u80B2\u6A5F\u69CB';

    for (final entry in _trustedDomainMap.entries) {
      final d = entry.key;
      if (host == d || host.endsWith('.$d')) {
        return entry.value;
      }
    }
    return null;
  }
}
