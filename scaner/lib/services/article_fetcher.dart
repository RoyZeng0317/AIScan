import 'dart:convert';
import 'package:http/http.dart' as http;

class ArticleFetcherResult {
  final String? title;
  final String content;
  final String? error;

  ArticleFetcherResult({this.title, required this.content, this.error});
}

class ArticleFetcher {
  Future<ArticleFetcherResult> fetch(String urlString) async {
    String url = urlString.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return ArticleFetcherResult(
        content: '',
        error: '無效的 URL 格式',
      );
    }

    try {
      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
        },
      );

      if (response.statusCode != 200) {
        return ArticleFetcherResult(
          content: '',
          error: 'HTTP ${response.statusCode}: 無法取得網頁內容',
        );
      }

      final html = response.body;

      final metaContent = _extractMetaContent(html);
      final jsonContent = _extractJsonContent(html);
      final htmlContent = _extractHtmlContent(html);

      final candidates = <String>[];
      if (metaContent.isNotEmpty) candidates.add(metaContent);
      if (jsonContent.isNotEmpty) candidates.add(jsonContent);
      if (htmlContent.isNotEmpty) candidates.add(htmlContent);

      String best = '';
      for (final c in candidates) {
        if (c.length > best.length) best = c;
      }

      final cleaned = _cleanText(best);

      if (cleaned.length < 15) {
        final raw = _stripTags(html);
        final cleanedRaw = _cleanText(raw);
        if (cleanedRaw.length > cleaned.length) {
          return ArticleFetcherResult(
            title: _extractTitle(html),
            content: cleanedRaw,
            error: cleanedRaw.length < 15
                ? '無法從該網頁擷取出足夠的文章內容（僅 ${cleanedRaw.length} 字元）'
                : null,
          );
        }
        return ArticleFetcherResult(
          title: _extractTitle(html),
          content: cleaned,
          error: '無法從該網頁擷取出足夠的文章內容（僅 ${cleaned.length} 字元）',
        );
      }

      return ArticleFetcherResult(
        title: _extractTitle(html),
        content: cleaned,
      );
    } catch (e) {
      return ArticleFetcherResult(
        content: '',
        error: '連線失敗: ${e.toString()}',
      );
    }
  }

  String _extractTitle(String html) {
    final titleMatch = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (titleMatch != null) {
      return _decodeEntities(_stripTags(titleMatch.group(1) ?? '')).trim();
    }
    final ogTitle = _metaContent(html, 'og:title');
    if (ogTitle != null) return ogTitle;
    return '';
  }

  String _extractMetaContent(String html) {
    final buffer = StringBuffer();

    for (final prop in ['og:description', 'twitter:description', 'description']) {
      final content = _metaContent(html, prop);
      if (content != null && content.length > buffer.length) {
        buffer.clear();
        buffer.write(content);
      }
    }

    return buffer.toString();
  }

  String? _metaContent(String html, String property) {
    final escapedProp = RegExp.escape(property);
    final patterns = [
      RegExp(
        '<meta\\s[^>]*property=["\']$escapedProp["\']\\s[^>]*content=["\']([^"\']*)["\'][^>]*/?>',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        '<meta\\s[^>]*name=["\']$escapedProp["\']\\s[^>]*content=["\']([^"\']*)["\'][^>]*/?>',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        '<meta\\s[^>]*content=["\']([^"\']*)["\'][^>]*property=["\']$escapedProp["\'][^>]*/?>',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        '<meta\\s[^>]*content=["\']([^"\']*)["\'][^>]*name=["\']$escapedProp["\'][^>]*/?>',
        caseSensitive: false,
        dotAll: true,
      ),
    ];

    for (final p in patterns) {
      final m = p.firstMatch(html);
      if (m != null) {
        return _decodeEntities(m.group(1) ?? '');
      }
    }
    return null;
  }

  String _extractJsonContent(String html) {
    final buffer = StringBuffer();

    final jsonLdMatches = RegExp(
      '<script\\s[^>]*type=["\']application/ld+json["\'][^>]*>(.*?)</script>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    for (final m in jsonLdMatches) {
      final jsonStr = m.group(1) ?? '';
      try {
        final data = jsonDecode(jsonStr);
        final text = _extractFromJsonLd(data);
        if (text.isNotEmpty) {
          buffer.write(text);
          buffer.write('\n');
        }
      } catch (_) {}
    }

    final dataMatches = RegExp(
      r'<script[^>]*>(window\.__INITIAL_STATE__|window\.__DATA__|window\.__NEXT_DATA__|window\.__NUXT__|window\.__PRELOADED_STATE__)\s*=\s*(\{.*?\});</script>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);

    for (final m in dataMatches) {
      final jsonStr = m.group(2) ?? '';
      try {
        final data = jsonDecode(jsonStr);
        final text = _recurseExtractText(data);
        if (text.isNotEmpty) {
          buffer.write(text);
          buffer.write('\n');
        }
      } catch (_) {}
    }

    return buffer.toString();
  }

  String _extractFromJsonLd(dynamic data) {
    if (data is List) {
      return data.map((e) => _extractFromJsonLd(e)).join('\n');
    }
    if (data is Map<String, dynamic>) {
      final buffer = StringBuffer();
      for (final key in ['articleBody', 'description', 'headline', 'caption', 'text', 'content']) {
        if (data[key] is String && (data[key] as String).length > 10) {
          buffer.write(data[key]);
          buffer.write('\n');
        }
      }
      return buffer.toString();
    }
    return '';
  }

  String _recurseExtractText(dynamic data, {int depth = 0}) {
    if (depth > 8) return '';
    if (data is String) {
      return data;
    }
    if (data is List) {
      return data.map((e) => _recurseExtractText(e, depth: depth + 1)).join(' ');
    }
    if (data is Map<String, dynamic>) {
      final textFields = <String>[];
      for (final key in data.keys) {
        if (data[key] is String) {
          final val = data[key] as String;
          if (val.length > 15 && val.length < 5000 && !val.contains('<')) {
            textFields.add(val);
          }
        }
      }
      if (textFields.isNotEmpty) {
        return textFields.join(' | ');
      }
      for (final key in data.keys) {
        final val = _recurseExtractText(data[key], depth: depth + 1);
        if (val.isNotEmpty) return val;
      }
    }
    return '';
  }

  String _extractHtmlContent(String html) {
    final buffer = StringBuffer();

    for (final tag in ['article', 'main']) {
      final match = RegExp(
        '<$tag[^>]*>(.*?)</$tag>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      if (match != null) {
        buffer.write(_stripTags(match.group(1)!));
        buffer.write('\n');
      }
    }

    for (final m in RegExp(
      r'<p[^>]*>(.*?)</p>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html)) {
      final text = _stripTags(m.group(1) ?? '');
      if (text.trim().length > 10) {
        buffer.write(text.trim());
        buffer.write('\n');
      }
    }

    for (final m in RegExp(
      r'<h[1-6][^>]*>(.*?)</h[1-6]>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html)) {
      final text = _stripTags(m.group(1) ?? '');
      if (text.trim().length > 5) {
        buffer.write(text.trim());
        buffer.write('\n');
      }
    }

    for (final m in RegExp(
      r'''<div[^>]*class=["'](?:[^"']*\s)?(?:post|entry|content|article|story|text|body|caption|message|tweet|thread|comment)[^"']*["'][^>]*>(.*?)</div>''',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html)) {
      buffer.write(_stripTags(m.group(1)!));
      buffer.write('\n');
    }

    for (final m in RegExp(
      r'''<span[^>]*class=["'](?:[^"']*\s)?(?:text|content|caption|body|message|post)[^"']*["'][^>]*>(.*?)</span>''',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html)) {
      final text = _stripTags(m.group(1) ?? '');
      if (text.trim().length > 10) {
        buffer.write(text.trim());
        buffer.write('\n');
      }
    }

    String result = buffer.toString();
    if (result.trim().length < 50) {
      final bodyMatch = RegExp(
        r'<body[^>]*>(.*?)</body>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      if (bodyMatch != null) {
        result = _stripTags(bodyMatch.group(1)!);
      }
    }

    return result;
  }

  String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true, caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true, caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<noscript[^>]*>.*?</noscript>', dotAll: true, caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<svg[^>]*>.*?</svg>', dotAll: true, caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#\d+;'), ' ')
        .replaceAll(RegExp(r'&#x[0-9a-fA-F]+;'), ' ');
  }

  String _decodeEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }

  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n'), '\n')
        .trim();
  }
}
