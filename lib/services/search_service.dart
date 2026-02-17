import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;

import '../models/book_source.dart';

/// 搜索结果模型
class SearchResult {
  final String name;
  final String author;
  final String bookUrl;
  final String? coverUrl;
  final String? intro;
  final String? latestChapter;
  final BookSource source;

  SearchResult({
    required this.name,
    required this.author,
    required this.bookUrl,
    this.coverUrl,
    this.intro,
    this.latestChapter,
    required this.source,
  });
}

/// 章节模型
class Chapter {
  final String name;
  final String url;

  Chapter({required this.name, required this.url});
}

/// 章节内容
class ChapterContent {
  final String content;
  final String? nextUrl;

  ChapterContent({required this.content, this.nextUrl});
}

/// 搜索服务
class SearchService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// 搜索小说
  Future<List<SearchResult>> search(
    String keyword,
    List<BookSource> sources,
  ) async {
    final results = <SearchResult>[];

    for (final source in sources) {
      if (source.enabled != true) continue;
      if (source.searchUrl == null || source.searchUrl!.isEmpty) continue;

      try {
        final results_ = await _searchInSource(keyword, source);
        results.addAll(results_);
      } catch (e) {
        print('搜索书源 ${source.bookSourceName} 失败: $e');
      }
    }

    return results;
  }

  Future<List<SearchResult>> _searchInSource(
    String keyword,
    BookSource source,
  ) async {
    // 构建搜索URL
    String url = source.searchUrl!;
    if (url.contains('{{key}}')) {
      url = url.replaceAll('{{key}}', Uri.encodeComponent(keyword));
    } else if (url.contains('{{page}}')) {
      url = url.replaceAll('{{page}}', '1');
      if (url.contains('{{key}}')) {
        url = url.replaceAll('{{key}}', Uri.encodeComponent(keyword));
      } else {
        url = '$url${Uri.encodeComponent(keyword)}';
      }
    } else {
      url = '$url${Uri.encodeComponent(keyword)}';
    }

    // 发送请求
    final response = await _dio.get<String>(
      url,
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          if (source.header != null) ..._parseHeader(source.header!),
        },
      ),
    );

    // 解析HTML
    final document = parse(response.data);
    final rule = source.ruleSearch;
    if (rule == null) return [];

    final results = <SearchResult>[];
    final bookList = document.querySelectorAll(rule.bookList ?? '.item');

    for (final item in bookList) {
      try {
        final name = _extractText(item, rule.name);
        final author = _extractText(item, rule.author) ?? '未知';
        final bookUrl = _extractUrl(item, rule.bookUrl, source.bookSourceUrl);

        if (name == null || bookUrl == null) continue;

        results.add(SearchResult(
          name: name,
          author: author,
          bookUrl: bookUrl,
          coverUrl: _extractUrl(item, rule.coverUrl, source.bookSourceUrl),
          intro: _extractText(item, rule.intro),
          latestChapter: _extractText(item, rule.lastChapter),
          source: source,
        ));
      } catch (e) {
        print('解析书籍失败: $e');
      }
    }

    return results;
  }

  /// 获取章节目录
  Future<List<Chapter>> getChapters(String bookUrl, BookSource source) async {
    final response = await _dio.get<String>(
      bookUrl,
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          if (source.header != null) ..._parseHeader(source.header!),
        },
      ),
    );

    final document = parse(response.data);
    final rule = source.ruleToc;
    if (rule == null) return [];

    final chapters = <Chapter>[];
    final chapterList = document.querySelectorAll(rule.chapterList ?? 'a');

    for (final item in chapterList) {
      final name = _extractText(item, rule.chapterName);
      final url = _extractUrl(item, rule.chapterUrl, source.bookSourceUrl);

      if (name != null && url != null) {
        chapters.add(Chapter(name: name, url: url));
      }
    }

    return chapters;
  }

  /// 获取章节内容
  Future<ChapterContent> getChapterContent(
    String chapterUrl,
    BookSource source,
  ) async {
    final response = await _dio.get<String>(
      chapterUrl,
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          if (source.header != null) ..._parseHeader(source.header!),
        },
      ),
    );

    final document = parse(response.data);
    final rule = source.ruleContent;
    if (rule == null) {
      return ChapterContent(content: '暂无内容');
    }

    // 提取内容
    String content = '';
    if (rule.content != null) {
      final elements = document.querySelectorAll(rule.content!);
      content = elements.map((e) => e.text.trim()).join('\n\n');
    }

    // 清理内容
    if (rule.replaceRegex != null && rule.replaceRegex!.isNotEmpty) {
      try {
        final regex = RegExp(rule.replaceRegex!);
        content = content.replaceAll(regex, '');
      } catch (e) {
        print('替换正则错误: $e');
      }
    }

    return ChapterContent(
      content: content.trim().isEmpty ? '暂无内容' : content.trim(),
      nextUrl: _extractUrl(document.documentElement, rule.nextContentUrl, null),
    );
  }

  /// 从元素提取文本
  String? _extractText(dom.Element? element, String? rule) {
    if (element == null || rule == null || rule.isEmpty) return null;

    try {
      // 简单的CSS选择器解析
      // 格式: selector@attribute 或 selector.0@text
      final parts = rule.split('@');
      dom.Element? current = element;

      for (var i = 0; i < parts.length; i++) {
        final part = parts[i].trim();
        if (part.isEmpty) continue;

        if (part == 'text' || part == 'textNodes') {
          return current?.text.trim();
        }

        if (part.startsWith('.')) {
          // 索引选择 .0 .1
          final index = int.tryParse(part.substring(1));
          if (index != null && current != null) {
            final children = current.children;
            current = index < children.length ? children[index] : null;
          }
        } else if (part.startsWith('##')) {
          // 正则提取 ##pattern##replacement###
          final regexPart = part.substring(2);
          final splitIndex = regexPart.indexOf('##');
          if (splitIndex > 0) {
            final pattern = regexPart.substring(0, splitIndex);
            final replacement = regexPart.substring(splitIndex + 2);
            if (replacement.endsWith('###')) {
              final regex = RegExp(pattern);
              final match = regex.firstMatch(current?.text ?? '');
              return match?.group(replacement.replaceAll('###', '').isEmpty
                      ? 0
                      : int.tryParse(replacement.replaceAll('###', '')) ??
                          0) ??
                  current?.text.trim();
            }
          }
        } else if (part == 'content') {
          return current?.attributes['content']?.trim();
        } else {
          // CSS选择器
          final selected = current?.querySelector(part);
          current = selected;
        }
      }

      return current?.text.trim();
    } catch (e) {
      return null;
    }
  }

  /// 提取URL
  String? _extractUrl(dom.Element? element, String? rule, String? baseUrl) {
    if (element == null || rule == null || rule.isEmpty) return null;

    try {
      final parts = rule.split('@');
      dom.Element? current = element;

      for (var i = 0; i < parts.length; i++) {
        final part = parts[i].trim();
        if (part.isEmpty) continue;

        if (part == 'href') {
          final href = current?.attributes['href'];
          if (href != null && baseUrl != null) {
            return _resolveUrl(href, baseUrl);
          }
          return href;
        }

        if (part == 'src' || part == 'data-original') {
          final src = current?.attributes[part];
          if (src != null && baseUrl != null) {
            return _resolveUrl(src, baseUrl);
          }
          return src;
        }

        if (part == 'content') {
          final content = current?.attributes['content'];
          if (content != null && baseUrl != null) {
            return _resolveUrl(content, baseUrl);
          }
          return content;
        }

        if (part.startsWith('.')) {
          final index = int.tryParse(part.substring(1));
          if (index != null && current != null) {
            final children = current.children;
            current = index < children.length ? children[index] : null;
          }
        } else if (part == 'text') {
          final text = current?.text.trim();
          if (text != null && baseUrl != null) {
            return _resolveUrl(text, baseUrl);
          }
          return text;
        } else {
          current = current?.querySelector(part);
        }
      }

      return current?.text.trim();
    } catch (e) {
      return null;
    }
  }

  /// 解析相对URL
  String _resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    final base = Uri.parse(baseUrl);
    if (url.startsWith('//')) {
      return '${base.scheme}:$url';
    } else if (url.startsWith('/')) {
      return '${base.scheme}://${base.host}$url';
    } else {
      final path = base.path.endsWith('/')
          ? base.path
          : base.path.substring(0, base.path.lastIndexOf('/') + 1);
      return '${base.scheme}://${base.host}$path$url';
    }
  }

  /// 解析header
  Map<String, String> _parseHeader(String header) {
    final map = <String, String>{};
    for (final line in header.split('\n')) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        map[parts[0].trim()] = parts.sublist(1).join(':').trim();
      }
    }
    return map;
  }
}
