import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;

import '../models/book_source.dart';
import '../utils/url_builder.dart';
import 'rule_parser.dart';

/// 流式搜索进度信息
class SearchProgress {
  final int completed;
  final int total;
  final String? currentSourceName;

  SearchProgress({
    required this.completed,
    required this.total,
    this.currentSourceName,
  });

  double get progress => total > 0 ? completed / total : 0;
}

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

/// 目录解析结果（内部使用）
class _TocParseResult {
  final List<Chapter> chapters;
  final String? nextUrl;

  _TocParseResult({required this.chapters, this.nextUrl});
}

/// 搜索服务
class SearchService {
  /// 搜索用的 Dio（短超时，快速失败）
  final Dio _searchDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// 获取内容用的 Dio（长超时，保证内容获取）
  final Dio _contentDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  /// 最大并发搜索数
  static const int _maxConcurrentSearches = 5;

  /// 释放资源（当服务不再需要时调用）
  void dispose() {
    _searchDio.close();
    _contentDio.close();
  }

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

  /// 流式搜索 - 限制并发数，每完成一个书源就返回结果
  Stream<dynamic> searchStream(
    String keyword,
    List<BookSource> sources,
  ) {
    final controller = StreamController<dynamic>.broadcast();

    // 过滤有效的书源
    final validSources =
        sources.where((s) => s.enabled == true && s.searchUrl != null && s.searchUrl!.isNotEmpty).toList();

    final total = validSources.length;
    var completed = 0;
    var cancelled = false; // 追踪取消状态
    final activeCount = <int>[0]; // 使用列表来允许可变引用

    // 确保 controller 正确关闭的辅助方法
    void closeControllerIfNeeded() {
      if (!cancelled && completed >= total && !controller.isClosed) {
        controller.close();
      } else if (cancelled && !controller.isClosed) {
        controller.close();
      }
    }

    // 分批并发搜索（使用 Future.doWhile 实现）
    Future<void> processSource(BookSource source) async {
      if (cancelled) return; // 如果已取消，直接返回

      try {
        // 发送进度更新
        if (!controller.isClosed) {
          controller.add(SearchProgress(
            completed: completed,
            total: total,
            currentSourceName: source.bookSourceName,
          ));
        }

        try {
          final results = await _searchInSource(keyword, source);
          for (final result in results) {
            if (cancelled || controller.isClosed) break;
            controller.add(result);
          }
        } catch (e) {
          print('搜索书源 ${source.bookSourceName} 失败: $e');
        }
      } finally {
        completed++;
        activeCount[0]--;
        // 发送完成进度
        if (!controller.isClosed) {
          controller.add(SearchProgress(
            completed: completed,
            total: total,
          ));
        }
        closeControllerIfNeeded();
      }
    }

    // 使用 Future.doWhile 实现并发调度
    int index = 0;
    Future<void> runScheduler() async {
      while (index < validSources.length && !cancelled) {
        // 等待直到有可用槽位
        while (activeCount[0] >= _maxConcurrentSearches && !cancelled) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
        if (cancelled) break;

        // 启动新的搜索任务
        if (index < validSources.length) {
          activeCount[0]++;
          final source = validSources[index++];
          processSource(source); // 不等待，让它并行运行
        }
      }
      // 等待所有任务完成
      while (activeCount[0] > 0 && !cancelled) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      closeControllerIfNeeded();
    }

    // 监听取消事件，确保资源释放
    controller.onCancel = () {
      cancelled = true;
      closeControllerIfNeeded();
    };

    // 当 Stream 被监听时开始调度
    controller.onListen = () {
      runScheduler();
    };

    // 如果没有监听者，也开始调度（兼容直接获取 stream 的情况）
    Future.delayed(Duration.zero, () {
      if (!controller.hasListener && !cancelled) {
        runScheduler();
      }
    });

    return controller.stream;
  }

  Future<List<SearchResult>> _searchInSource(
    String keyword,
    BookSource source,
  ) async {
    // 清理 baseUrl，移除 ## 或 # 后面的标记
    final baseUrl = RuleParser.cleanBaseUrl(source.bookSourceUrl);

    // 构建搜索URL（使用 UrlBuilder 统一处理）
    String url = UrlBuilder.buildSearchUrl(
      source.searchUrl!,
      keyword: keyword,
      page: 1,
    );

    // 如果是相对路径，与 baseUrl 拼接
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = RuleParser.resolveUrl(url, baseUrl);
    }

    // 发送请求（使用搜索专用短超时）
    final response = await _searchDio.get<String>(
      url,
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          if (source.header != null) ...RuleParser.parseHeader(source.header!),
        },
      ),
    );

    final rule = source.ruleSearch;
    if (rule == null) return [];

    // 检测是否为 JSON 规则（以 $ 开头）
    final isJsonRule = rule.bookList?.startsWith('\$') ?? false;

    if (isJsonRule) {
      return _parseJsonSearchResult(response.data, rule, source, baseUrl);
    } else {
      return _parseHtmlSearchResult(response.data, rule, source, baseUrl);
    }
  }

  /// 解析 JSON 搜索结果
  List<SearchResult> _parseJsonSearchResult(
    String? data,
    RuleSearch rule,
    BookSource source,
    String baseUrl,
  ) {
    if (data == null) return [];

    try {
      final json = jsonDecode(data);
      final results = <SearchResult>[];

      // 获取书籍列表
      final bookListPath = rule.bookList?.substring(1) ?? ''; // 移除开头的 $
      final bookList = RuleParser.getJsonValue(json, bookListPath) as List? ?? [];

      for (final item in bookList) {
        try {
          final name = _extractJsonText(item, rule.name);
          final author = _extractJsonText(item, rule.author) ?? '未知';
          final bookUrl = _extractJsonUrl(item, rule.bookUrl, baseUrl);

          if (name == null || bookUrl == null) continue;

          results.add(SearchResult(
            name: name,
            author: author,
            bookUrl: bookUrl,
            coverUrl: _extractJsonUrl(item, rule.coverUrl, baseUrl),
            intro: _extractJsonText(item, rule.intro),
            latestChapter: _extractJsonText(item, rule.lastChapter),
            source: source,
          ));
        } catch (e) {
          print('解析JSON书籍失败: $e');
        }
      }

      return results;
    } catch (e) {
      print('JSON解析失败: $e');
      return [];
    }
  }

  /// 解析 HTML 搜索结果
  List<SearchResult> _parseHtmlSearchResult(
    String? data,
    RuleSearch rule,
    BookSource source,
    String baseUrl,
  ) {
    if (data == null) return [];

    final document = parse(data);
    final results = <SearchResult>[];

    final bookListRule = rule.bookList ?? '.item';
    final bookList = RuleParser.getElements(document.documentElement!, bookListRule).cast<dom.Element>();

    print('📄 搜索解析: 规则="$bookListRule", 找到${bookList.length}个元素');

    for (final item in bookList) {
      try {
        final name = _extractTextNew(item, rule.name);
        final author = _extractTextNew(item, rule.author) ?? '未知';
        final bookUrl = _extractUrlNew(item, rule.bookUrl, baseUrl);

        if (name == null || bookUrl == null) continue;

        results.add(SearchResult(
          name: name,
          author: author,
          bookUrl: bookUrl,
          coverUrl: _extractUrlNew(item, rule.coverUrl, baseUrl),
          intro: _extractTextNew(item, rule.intro),
          latestChapter: _extractTextNew(item, rule.lastChapter),
          source: source,
        ));
      } catch (e) {
        print('解析书籍失败: $e');
      }
    }

    return results;
  }

  /// 从 JSON 对象提取文本
  String? _extractJsonText(dynamic json, String? rule) {
    if (rule == null || rule.isEmpty) return null;

    try {
      // 处理 {{$.xxx}} 模板
      if (rule.contains('{{')) {
        return rule.replaceAllMapped(
          RegExp(r'\{\{\$\.([^}]+)\}\}'),
          (match) => RuleParser.getJsonValue(json, match.group(1) ?? '')?.toString() ?? '',
        );
      }

      // 处理 $.xxx 格式
      if (rule.startsWith('\$.')) {
        final value = RuleParser.getJsonValue(json, rule.substring(2));
        return value?.toString();
      }

      // 处理带 ## 的正则替换
      if (rule.contains('##')) {
        final parts = rule.split('##');
        String value = _extractJsonText(json, parts[0]) ?? '';

        if (parts.length >= 2) {
          final pattern = parts[1];
          if (parts.length >= 3) {
            // ##pattern##replacement 格式
            final replacement = parts[2];
            value = value.replaceAll(RegExp(pattern), replacement);
          } else {
            // ##pattern 格式，移除匹配项
            value = value.replaceAll(RegExp(pattern), '');
          }
        }
        return value.trim();
      }

      return rule;
    } catch (e) {
      return null;
    }
  }

  /// 从 JSON 对象提取 URL
  String? _extractJsonUrl(dynamic json, String? rule, String baseUrl) {
    if (rule == null || rule.isEmpty) return null;

    try {
      String? url;

      // 处理 {{$.xxx}} 模板
      if (rule.contains('{{')) {
        url = rule.replaceAllMapped(
          RegExp(r'\{\{\$\.([^}]+)\}\}'),
          (match) => RuleParser.getJsonValue(json, match.group(1) ?? '')?.toString() ?? '',
        );
      } else if (rule.startsWith('\$.')) {
        url = RuleParser.getJsonValue(json, rule.substring(2))?.toString();
      } else if (rule.startsWith('http')) {
        url = rule;
      } else {
        return null;
      }

      if (url == null || url.isEmpty) return null;

      // 如果已经是完整URL，直接返回
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
      }

      // 否则与 baseUrl 拼接
      return RuleParser.resolveUrl(url, baseUrl);
    } catch (e) {
      return null;
    }
  }

  /// 获取章节目录（支持分页）
  Future<List<Chapter>> getChapters(String bookUrl, BookSource source) async {
    // 清理 baseUrl
    String baseUrl = RuleParser.cleanBaseUrl(source.bookSourceUrl);

    print('📖 获取章节目录: $bookUrl');
    print('📖 书源: ${source.bookSourceName}');

    final rule = source.ruleToc;
    if (rule == null) {
      print('⚠️ 书源 ${source.bookSourceName} 没有目录规则');
      return [];
    }

    print('📖 目录规则: chapterList=${rule.chapterList}, chapterName=${rule.chapterName}, chapterUrl=${rule.chapterUrl}, nextTocUrl=${rule.nextTocUrl}');

    final allChapters = <Chapter>[];
    String? currentUrl = bookUrl;
    int pageCount = 0;
    const maxPages = 20; // 防止无限循环，最多20页

    while (currentUrl != null && pageCount < maxPages) {
      pageCount++;
      print('📖 正在获取第 $pageCount 页: $currentUrl');

      try {
        // 使用内容专用长超时
        final response = await _contentDio.get<String>(
          currentUrl,
          options: Options(
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              if (source.header != null) ...RuleParser.parseHeader(source.header!),
            },
          ),
        );

        // 检测是否为 JSON 规则
        final isJsonRule = rule.chapterList?.startsWith('\$') ?? false;

        _TocParseResult result;
        if (isJsonRule) {
          result = _parseJsonChaptersWithNextUrl(response.data, rule, baseUrl);
        } else {
          result = _parseHtmlChaptersWithNextUrl(response.data, rule, baseUrl);
        }

        allChapters.addAll(result.chapters);
        print('📖 第 $pageCount 页解析到 ${result.chapters.length} 个章节，累计 ${allChapters.length} 个');

        // 获取下一页URL
        currentUrl = result.nextUrl;
        if (currentUrl != null) {
          print('📖 发现下一页: $currentUrl');
        }
      } catch (e) {
        print('⚠️ 获取第 $pageCount 页失败: $e');
        break;
      }
    }

    if (pageCount >= maxPages) {
      print('⚠️ 达到最大页数限制 ($maxPages 页)');
    }

    print('📖 总共解析到 ${allChapters.length} 个章节，共 $pageCount 页');
    if (allChapters.isNotEmpty) {
      print('📖 前3章: ${allChapters.take(3).map((c) => c.name).join(", ")}');
    }

    return allChapters;
  }

  /// 解析 HTML 章节列表（包含下一页URL）
  _TocParseResult _parseHtmlChaptersWithNextUrl(String? data, RuleToc rule, String baseUrl) {
    if (data == null) return _TocParseResult(chapters: [], nextUrl: null);

    final document = parse(data);
    final chapters = <Chapter>[];

    final chapterListRule = rule.chapterList ?? '';
    print('📄 HTML解析: 规则="$chapterListRule"');

    // 获取章节元素列表
    List<dom.Element> chapterElements;
    if (chapterListRule.isEmpty) {
      // 默认获取所有链接
      chapterElements = document.querySelectorAll('a').toList();
    } else {
      chapterElements = RuleParser.getElements(document.documentElement!, chapterListRule).cast<dom.Element>();
    }

    print('📄 找到${chapterElements.length}个章节元素');

    for (final item in chapterElements) {
      final name = _extractTextNew(item, rule.chapterName);
      final url = _extractUrlNew(item, rule.chapterUrl, baseUrl);

      if (name != null && url != null && name.trim().isNotEmpty) {
        chapters.add(Chapter(name: name.trim(), url: url));
      }
    }

    // 提取下一页URL
    String? nextUrl;
    if (rule.nextTocUrl != null && rule.nextTocUrl!.isNotEmpty) {
      nextUrl = _extractUrlNew(document.documentElement, rule.nextTocUrl, baseUrl);
    }

    return _TocParseResult(chapters: chapters, nextUrl: nextUrl);
  }

  /// 解析 JSON 章节列表（包含下一页URL）
  _TocParseResult _parseJsonChaptersWithNextUrl(String? data, RuleToc rule, String baseUrl) {
    if (data == null) return _TocParseResult(chapters: [], nextUrl: null);

    try {
      final json = jsonDecode(data);
      final chapters = <Chapter>[];

      final chapterListPath = rule.chapterList?.substring(1) ?? '';
      final chapterList = RuleParser.getJsonValue(json, chapterListPath) as List? ?? [];

      for (final item in chapterList) {
        final name = _extractJsonText(item, rule.chapterName);
        final url = _extractJsonUrl(item, rule.chapterUrl, baseUrl);

        if (name != null && url != null) {
          chapters.add(Chapter(name: name, url: url));
        }
      }

      // 提取下一页URL（JSON格式通常在特定字段中）
      String? nextUrl;
      if (rule.nextTocUrl != null && rule.nextTocUrl!.isNotEmpty) {
        // 对于JSON，nextTocUrl可能是类似 $.nextUrl 的路径
        if (rule.nextTocUrl!.startsWith('\$')) {
          final nextPath = rule.nextTocUrl!.substring(1);
          final nextValue = RuleParser.getJsonValue(json, nextPath);
          if (nextValue is String && nextValue.isNotEmpty) {
            nextUrl = RuleParser.resolveUrl(nextValue, baseUrl);
          }
        }
      }

      return _TocParseResult(chapters: chapters, nextUrl: nextUrl);
    } catch (e) {
      print('JSON章节解析失败: $e');
      return _TocParseResult(chapters: [], nextUrl: null);
    }
  }

  /// 新版文本提取（支持更多规则格式）
  String? _extractTextNew(dom.Element? element, String? rule) {
    if (element == null) return null;

    // 如果没有规则，直接返回文本
    if (rule == null || rule.isEmpty) {
      return element.text.trim();
    }

    try {
      String? result;
      String remainingRule = rule.trim();

      // 处理正则替换 ##pattern##replacement
      String? replacePattern;
      String? replaceReplacement;
      if (remainingRule.contains('##')) {
        final parts = remainingRule.split('##');
        remainingRule = parts[0];
        if (parts.length >= 2) replacePattern = parts[1];
        if (parts.length >= 3) replaceReplacement = parts[2];
      }

      // 按 @ 分割规则
      final parts = remainingRule.split('@');
      dom.Element? current = element;

      for (final part in parts) {
        final trimmedPart = part.trim();
        if (trimmedPart.isEmpty) continue;

        if (current == null) {
          result = null;
          break;
        }

        // 特殊属性
        if (trimmedPart == 'text' || trimmedPart == 'textNodes') {
          result = current.text.trim();
          break;
        }
        if (trimmedPart == 'ownText') {
          result = current.nodes
              .where((n) => n.nodeType == dom.Node.TEXT_NODE)
              .map((n) => n.text?.trim() ?? '')
              .where((s) => s.isNotEmpty)
              .join(' ');
          break;
        }
        if (trimmedPart == 'html') {
          result = current.innerHtml;
          break;
        }

        // 属性获取
        if (trimmedPart.startsWith('attr.') || (trimmedPart.startsWith('@') && !trimmedPart.contains('CSS'))) {
          final attrName = trimmedPart.replaceFirst('attr.', '').replaceFirst('@', '');
          result = current.attributes[attrName]?.trim();
          break;
        }

        // 使用元素获取规则
        final foundElements = RuleParser.getElementsBySingleRule(current, trimmedPart);
        if (foundElements.isNotEmpty) {
          current = foundElements.first as dom.Element?;
          if (current != null) {
            result = current.text.trim();
          }
        } else {
          // 可能是属性名
          final attrValue = current.attributes[trimmedPart];
          if (attrValue != null) {
            result = attrValue.trim();
            break;
          }
          result = null;
          break;
        }
      }

      if (result == null && current != null) {
        result = current.text.trim();
      }

      // 应用正则替换
      if (result != null && replacePattern != null) {
        try {
          final regex = RegExp(replacePattern);
          result = result.replaceAll(regex, replaceReplacement ?? '');
        } catch (e) {
          // 正则替换失败，忽略
        }
      }

      return result?.trim();
    } catch (e) {
      return null;
    }
  }

  /// 新版 URL 提取（支持更多规则格式）
  String? _extractUrlNew(dom.Element? element, String? rule, String baseUrl) {
    if (element == null) return null;

    // 如果没有规则，尝试获取 href
    if (rule == null || rule.isEmpty) {
      final href = element.attributes['href'];
      if (href != null) {
        return RuleParser.resolveUrl(href, baseUrl);
      }
      return null;
    }

    try {
      String? result;
      String remainingRule = rule.trim();

      // 处理正则替换
      String? replacePattern;
      String? replaceReplacement;
      if (remainingRule.contains('##')) {
        final parts = remainingRule.split('##');
        remainingRule = parts[0];
        if (parts.length >= 2) replacePattern = parts[1];
        if (parts.length >= 3) replaceReplacement = parts[2];
      }

      // 按 @ 分割规则
      final parts = remainingRule.split('@');
      dom.Element? current = element;

      for (final part in parts) {
        final trimmedPart = part.trim();
        if (trimmedPart.isEmpty) continue;

        if (current == null) {
          result = null;
          break;
        }

        // href 属性
        if (trimmedPart == 'href') {
          result = current.attributes['href'];
          break;
        }
        // src 属性
        if (trimmedPart == 'src') {
          result = current.attributes['src'];
          break;
        }
        // text 转URL
        if (trimmedPart == 'text') {
          result = current.text.trim();
          break;
        }

        // 属性获取
        if (trimmedPart.startsWith('attr.') || (trimmedPart.startsWith('@') && !trimmedPart.contains('CSS'))) {
          final attrName = trimmedPart.replaceFirst('attr.', '').replaceFirst('@', '');
          result = current.attributes[attrName]?.trim();
          break;
        }

        // 使用元素获取规则
        final foundElements = RuleParser.getElementsBySingleRule(current, trimmedPart);
        if (foundElements.isNotEmpty) {
          current = foundElements.first as dom.Element?;
          // 尝试获取 href
          final href = current?.attributes['href'];
          if (href != null) {
            result = href;
            break;
          }
        } else {
          // 可能是属性名
          final attrValue = current.attributes[trimmedPart];
          if (attrValue != null) {
            result = attrValue.trim();
            break;
          }
          result = null;
          break;
        }
      }

      // 如果没有结果但 current 有值，尝试获取 href
      if (result == null && current != null) {
        result = current.attributes['href'];
      }

      // 应用正则替换
      if (result != null && replacePattern != null) {
        try {
          final regex = RegExp(replacePattern);
          result = result.replaceAll(regex, replaceReplacement ?? '');
        } catch (e) {
          // 正则替换失败，忽略
        }
      }

      // 解析为完整URL
      if (result != null && result.isNotEmpty) {
        return RuleParser.resolveUrl(result, baseUrl);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 获取章节内容
  Future<ChapterContent> getChapterContent(
    String chapterUrl,
    BookSource source,
  ) async {
    // 清理 baseUrl
    String baseUrl = RuleParser.cleanBaseUrl(source.bookSourceUrl);

    print('📖 获取章节内容: $chapterUrl');
    print('📖 书源: ${source.bookSourceName}');

    // 检查章节 URL 是否需要拼接
    String fullUrl = chapterUrl;
    if (!chapterUrl.startsWith('http://') && !chapterUrl.startsWith('https://')) {
      fullUrl = RuleParser.resolveUrl(chapterUrl, baseUrl);
      print('📖 拼接URL: $chapterUrl -> $fullUrl');
    }

    // 使用内容专用长超时
    final response = await _contentDio.get<String>(
      fullUrl,
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          if (source.header != null) ...RuleParser.parseHeader(source.header!),
        },
      ),
    );

    final rule = source.ruleContent;
    if (rule == null) {
      print('⚠️ 书源 ${source.bookSourceName} 没有内容规则');
      return ChapterContent(content: '暂无内容（书源缺少内容规则）');
    }

    print('📖 内容规则: content=${rule.content}');

    // 检测是否为 JSON 规则
    final isJsonRule = rule.content?.startsWith('\$') ?? false;

    ChapterContent result;
    if (isJsonRule) {
      result = _parseJsonContent(response.data, rule);
    } else {
      result = _parseHtmlContent(response.data, rule, baseUrl);
    }

    print('📖 内容长度: ${result.content.length} 字符');
    if (result.content.length < 50) {
      print('📖 内容预览: ${result.content}');
    }

    return result;
  }

  /// 解析 JSON 内容
  ChapterContent _parseJsonContent(String? data, RuleContent rule) {
    if (data == null) return ChapterContent(content: '暂无内容');

    try {
      final json = jsonDecode(data);

      String content = _extractJsonText(json, rule.content)?.trim() ?? '';

      // 处理正则替换（添加保护）
      if (rule.replaceRegex != null && rule.replaceRegex!.isNotEmpty) {
        try {
          final regex = RegExp(rule.replaceRegex!);
          final newContent = content.replaceAll(regex, '');
          if (newContent.length > 100) {
            content = newContent;
          }
        } catch (e) {
          print('替换正则错误: $e');
        }
      }

      return ChapterContent(
        content: content.trim().isEmpty ? '暂无内容' : content.trim(),
        nextUrl: null, // JSON 响应通常不支持下一页
      );
    } catch (e) {
      print('JSON内容解析失败: $e');
      return ChapterContent(content: '暂无内容');
    }
  }

  /// 解析 HTML 内容
  ChapterContent _parseHtmlContent(String? data, RuleContent rule, String baseUrl) {
    if (data == null) {
      print('⚠️ HTML内容为空');
      return ChapterContent(content: '暂无内容');
    }

    final document = parse(data);

    // 提取内容
    String content = '';
    String? contentRule = rule.content;

    print('📄 开始解析内容, 规则: "$contentRule"');

    // 检查是否为 JS 规则（不支持）
    bool isJsRule = contentRule != null &&
        (contentRule.startsWith('<js>') ||
         contentRule.startsWith('js:') ||
         contentRule.contains('@js:') ||
         contentRule == '<js>');

    if (isJsRule) {
      print('⚠️ 检测到JS规则，尝试通用选择器');
      // JS 规则不支持，尝试通用选择器
      content = _tryCommonContentSelectors(document);
      print('📄 通用选择器返回: ${content.length} 字符');
    } else if (contentRule != null && contentRule.isNotEmpty) {
      print('📄 内容规则: "$contentRule"');
      try {
        final elements = RuleParser.getElements(document.documentElement!, contentRule).cast<dom.Element>();
        print('📄 找到 ${elements.length} 个内容元素');
        // 提取HTML内容以保留图片标签
        content = _extractContentWithImages(elements, baseUrl);
      } catch (e) {
        print('⚠️ 内容解析错误: $e');
        // 规则解析失败，尝试通用选择器
        content = _tryCommonContentSelectors(document);
      }
    } else {
      print('⚠️ 内容规则为空，尝试通用选择器');
      content = _tryCommonContentSelectors(document);
    }

    print('📄 第一次提取后内容长度: ${content.length}');

    // 如果内容仍然为空，尝试更多选择器
    if (content.trim().isEmpty) {
      content = _tryCommonContentSelectors(document);
    }

    print('📄 最终内容长度: ${content.length}');

    // 清理内容（添加保护：如果替换后内容太短则不应用）
    if (rule.replaceRegex != null && rule.replaceRegex!.isNotEmpty) {
      print('📄 应用替换正则: ${rule.replaceRegex}');
      try {
        final regex = RegExp(rule.replaceRegex!);
        final newContent = content.replaceAll(regex, '');
        // 只有当替换后内容仍然足够长时才应用
        // 避免贪婪正则把正文全部删除
        if (newContent.length > 100) {
          content = newContent;
        } else {
          print('📄 替换后内容太短(${newContent.length}字符)，跳过替换');
        }
      } catch (e) {
        print('替换正则错误: $e');
      }
    }

    final finalContent = content.trim().isEmpty ? '暂无内容' : content.trim();
    print('📄 返回内容长度: ${finalContent.length}');

    return ChapterContent(
      content: finalContent,
      nextUrl: _extractUrlNew(document.documentElement, rule.nextContentUrl, baseUrl),
    );
  }

  /// 从元素中提取内容（保留图片标签）
  String _extractContentWithImages(List<dom.Element> elements, String baseUrl) {
    final buffer = StringBuffer();

    for (final element in elements) {
      // 递归处理元素节点
      _processNode(element, buffer, baseUrl);
    }

    return buffer.toString().trim();
  }

  /// 递归处理节点，保留图片标签
  void _processNode(dom.Node node, StringBuffer buffer, String baseUrl) {
    if (node is dom.Text) {
      // 文本节点直接添加
      final text = node.text.trim();
      if (text.isNotEmpty) {
        buffer.write(text);
      }
    } else if (node is dom.Element) {
      if (node.localName == 'img') {
        // 处理图片标签
        final src = node.attributes['src'] ?? node.attributes['data-src'];
        if (src != null && src.isNotEmpty) {
          final fullUrl = RuleParser.resolveUrl(src, baseUrl);
          buffer.write('\n<img src="$fullUrl"/>\n');
        }
      } else if (node.localName == 'br') {
        buffer.write('\n');
      } else if (node.localName == 'p' || node.localName == 'div') {
        // 段落或div，递归处理子节点
        final childBuffer = StringBuffer();
        for (final child in node.nodes) {
          _processNode(child, childBuffer, baseUrl);
        }
        final childText = childBuffer.toString().trim();
        if (childText.isNotEmpty) {
          buffer.write('\n$childText\n');
        }
      } else {
        // 其他标签，递归处理子节点
        for (final child in node.nodes) {
          _processNode(child, buffer, baseUrl);
        }
      }
    }
  }

  /// 尝试常见的内容选择器
  String _tryCommonContentSelectors(dom.Document document) {
    // 常见的小说内容选择器
    final selectors = [
      '#content',
      '.content',
      '#chapter-content',
      '.chapter-content',
      '#chaptercontent',
      '.chaptercontent',
      '#Content',
      '.Content',
      '#text-content',
      '.text-content',
      '.novel-content',
      '#novelcontent',
      '.novelcontent',
      '.read-content',
      '#read-content',
      '.article-content',
      '#article-content',
      '.book-content',
      '#BookText',
      '.BookText',
      'div.content',
      'div.chapter',
      'div.text',
      // 笔趣阁常见选择器
      '#contenttxt',
      '.contenttxt',
      '.txt-cont',
      '#txt-cont',
      '.m-read',
      '#chapterText',
      '.chapter-text',
    ];

    for (final selector in selectors) {
      try {
        final elements = document.querySelectorAll(selector);
        if (elements.isNotEmpty) {
          final text = elements.map((e) => e.text.trim()).join('\n\n');
          if (text.length > 100) {
            print('✅ 通用选择器命中: $selector (${text.length} 字符)');
            return text;
          }
        }
      } catch (e) {
        // 选择器无效，继续尝试下一个
      }
    }

    // 如果所有选择器都失败，尝试查找最大的文本块
    print('📄 尝试查找最大文本块...');
    final allDivs = document.querySelectorAll('div, p, article');
    String? largestContent;
    int maxLength = 0;

    for (final div in allDivs) {
      final text = div.text.trim();
      // 内容块通常有这些特征
      if (text.length > maxLength &&
          text.length > 200 &&
          !text.contains('<') &&
          text.split('\n').length > 3) {
        maxLength = text.length;
        largestContent = text;
      }
    }

    if (largestContent != null && maxLength > 200) {
      print('✅ 找到最大文本块: $maxLength 字符');
      return largestContent;
    }

    return '';
  }
}
