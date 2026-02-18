import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;

import '../models/book_source.dart';

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

/// 搜索服务
class SearchService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
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

  /// 流式搜索 - 每完成一个书源就返回结果
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

    // 并发搜索所有书源
    Future.wait(
      validSources.map((source) async {
        // 发送进度更新
        controller.add(SearchProgress(
          completed: completed,
          total: total,
          currentSourceName: source.bookSourceName,
        ));

        try {
          final results = await _searchInSource(keyword, source);
          for (final result in results) {
            controller.add(result);
          }
        } catch (e) {
          print('搜索书源 ${source.bookSourceName} 失败: $e');
        } finally {
          completed++;
          // 发送完成进度
          controller.add(SearchProgress(
            completed: completed,
            total: total,
          ));
        }
      }),
    ).then((_) {
      controller.close();
    });

    return controller.stream;
  }

  Future<List<SearchResult>> _searchInSource(
    String keyword,
    BookSource source,
  ) async {
    // 清理 baseUrl，移除 ## 或 # 后面的标记
    final baseUrl = _cleanBaseUrl(source.bookSourceUrl);

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

    // 如果是相对路径，与 baseUrl 拼接
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = _resolveUrl(url, baseUrl);
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
      final bookList = _getJsonValue(json, bookListPath) as List? ?? [];

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
    final bookList = _getElements(document.documentElement!, bookListRule);

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

  /// 从 JSON 对象中获取值（支持 $.a.b.c 格式）
  dynamic _getJsonValue(dynamic json, String path) {
    if (path.isEmpty) return json;

    final parts = path.split('.');
    dynamic current = json;

    for (final part in parts) {
      if (part.isEmpty) continue;
      if (current is Map) {
        current = current[part];
      } else if (current is List && int.tryParse(part) != null) {
        final index = int.parse(part);
        current = index < current.length ? current[index] : null;
      } else {
        return null;
      }
    }

    return current;
  }

  /// 从 JSON 对象提取文本
  String? _extractJsonText(dynamic json, String? rule) {
    if (rule == null || rule.isEmpty) return null;

    try {
      // 处理 {{$.xxx}} 模板
      if (rule.contains('{{')) {
        return rule.replaceAllMapped(
          RegExp(r'\{\{\$\.([^}]+)\}\}'),
          (match) => _getJsonValue(json, match.group(1) ?? '')?.toString() ?? '',
        );
      }

      // 处理 $.xxx 格式
      if (rule.startsWith('\$.')) {
        final value = _getJsonValue(json, rule.substring(2));
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
          (match) => _getJsonValue(json, match.group(1) ?? '')?.toString() ?? '',
        );
      } else if (rule.startsWith('\$.')) {
        url = _getJsonValue(json, rule.substring(2))?.toString();
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
      return _resolveUrl(url, baseUrl);
    } catch (e) {
      return null;
    }
  }

  /// 获取章节目录
  Future<List<Chapter>> getChapters(String bookUrl, BookSource source) async {
    // 清理 baseUrl
    String baseUrl = _cleanBaseUrl(source.bookSourceUrl);

    print('📖 获取章节目录: $bookUrl');
    print('📖 书源: ${source.bookSourceName}');

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

    final rule = source.ruleToc;
    if (rule == null) {
      print('⚠️ 书源 ${source.bookSourceName} 没有目录规则');
      return [];
    }

    print('📖 目录规则: chapterList=${rule.chapterList}, chapterName=${rule.chapterName}, chapterUrl=${rule.chapterUrl}');

    // 检测是否为 JSON 规则
    final isJsonRule = rule.chapterList?.startsWith('\$') ?? false;

    List<Chapter> chapters;
    if (isJsonRule) {
      chapters = _parseJsonChapters(response.data, rule, baseUrl);
    } else {
      chapters = _parseHtmlChapters(response.data, rule, baseUrl);
    }

    print('📖 解析到 ${chapters.length} 个章节');
    if (chapters.isNotEmpty) {
      print('📖 前3章: ${chapters.take(3).map((c) => c.name).join(", ")}');
    }

    return chapters;
  }

  /// 解析 JSON 章节列表
  List<Chapter> _parseJsonChapters(String? data, RuleToc rule, String baseUrl) {
    if (data == null) return [];

    try {
      final json = jsonDecode(data);
      final chapters = <Chapter>[];

      final chapterListPath = rule.chapterList?.substring(1) ?? '';
      final chapterList = _getJsonValue(json, chapterListPath) as List? ?? [];

      for (final item in chapterList) {
        final name = _extractJsonText(item, rule.chapterName);
        final url = _extractJsonUrl(item, rule.chapterUrl, baseUrl);

        if (name != null && url != null) {
          chapters.add(Chapter(name: name, url: url));
        }
      }

      return chapters;
    } catch (e) {
      print('JSON章节解析失败: $e');
      return [];
    }
  }

  /// 解析 HTML 章节列表
  List<Chapter> _parseHtmlChapters(String? data, RuleToc rule, String baseUrl) {
    if (data == null) return [];

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
      chapterElements = _getElements(document.documentElement!, chapterListRule);
    }

    print('📄 找到${chapterElements.length}个章节元素');

    for (final item in chapterElements) {
      final name = _extractTextNew(item, rule.chapterName);
      final url = _extractUrlNew(item, rule.chapterUrl, baseUrl);

      if (name != null && url != null && name.trim().isNotEmpty) {
        chapters.add(Chapter(name: name.trim(), url: url));
      }
    }

    return chapters;
  }

  /// 获取元素列表（支持 Legado 规则格式）
  List<dom.Element> _getElements(dom.Element root, String rule) {
    if (rule.isEmpty) return [root];

    final elements = <dom.Element>[];
    String remainingRule = rule.trim();

    // 处理 @CSS: 前缀
    if (remainingRule.toLowerCase().startsWith('@css:')) {
      remainingRule = remainingRule.substring(5).trim();
      elements.addAll(root.querySelectorAll(remainingRule));
      return elements;
    }

    // 按 @ 分割规则
    final parts = remainingRule.split('@');
    List<dom.Element> currentElements = [root];

    for (final part in parts) {
      final trimmedPart = part.trim();
      if (trimmedPart.isEmpty) continue;

      final nextElements = <dom.Element>[];
      for (final element in currentElements) {
        nextElements.addAll(_getElementsBySingleRule(element, trimmedPart));
      }
      currentElements = nextElements;

      if (currentElements.isEmpty) break;
    }

    return currentElements;
  }

  /// 单个规则获取元素
  List<dom.Element> _getElementsBySingleRule(dom.Element element, String rule) {
    if (rule.isEmpty) return [element];

    try {
      // 处理 tag.xxx 格式 (如 tag.a, tag.div)
      if (rule.startsWith('tag.')) {
        final tagName = rule.substring(4);
        return element.getElementsByTagName(tagName).toList();
      }

      // 处理 class.xxx 格式
      if (rule.startsWith('class.')) {
        final className = rule.substring(6);
        return element.getElementsByClassName(className).toList();
      }

      // 处理 id.xxx 格式
      if (rule.startsWith('id.')) {
        final id = rule.substring(3);
        final found = element.querySelector('#$id');
        return found != null ? [found] : [];
      }

      // 处理 children 格式
      if (rule == 'children') {
        return element.children.toList();
      }

      // 处理带索引的选择器 (如 .class.0 或 .class!0)
      // 支持格式: .className.0, .className!0, selector.0, selector!0
      final indexPattern = RegExp(r'^(.+?)([.!])(-?\d+)$');
      final indexMatch = indexPattern.firstMatch(rule);
      if (indexMatch != null) {
        final selector = indexMatch.group(1)!;
        final splitChar = indexMatch.group(2)!;
        final indexStr = indexMatch.group(3)!;
        final index = int.parse(indexStr);

        final elements = _getElementsBySingleRule(element, selector);

        if (splitChar == '.') {
          // 选择模式: 获取第 index 个元素
          if (index >= 0 && index < elements.length) {
            return [elements[index]];
          } else if (index < 0 && elements.length + index >= 0) {
            return [elements[elements.length + index]];
          }
        } else {
          // 排除模式 (!): 排除第 index 个元素
          if (index >= 0 && index < elements.length) {
            elements.removeAt(index);
          } else if (index < 0 && elements.length + index >= 0) {
            elements.removeAt(elements.length + index);
          }
          return elements;
        }
        return [];
      }

      // 处理 [index] 或 [start:end] 或 [start:end:step] 格式
      final bracketMatch = RegExp(r'^(.+?)\[([^\]]+)\]$').firstMatch(rule);
      if (bracketMatch != null) {
        final selector = bracketMatch.group(1)!;
        final indexExpr = bracketMatch.group(2)!;
        final elements = _getElementsBySingleRule(element, selector);

        return _selectElementsByIndex(elements, indexExpr);
      }

      // 默认使用 CSS 选择器
      return element.querySelectorAll(rule).toList();
    } catch (e) {
      // CSS 选择器或其他错误
      return [];
    }
  }

  /// 根据索引表达式选择元素
  List<dom.Element> _selectElementsByIndex(List<dom.Element> elements, String indexExpr) {
    if (elements.isEmpty) return [];

    // 单个索引
    final singleIndex = int.tryParse(indexExpr);
    if (singleIndex != null) {
      final idx = singleIndex >= 0 ? singleIndex : elements.length + singleIndex;
      if (idx >= 0 && idx < elements.length) {
        return [elements[idx]];
      }
      return [];
    }

    // 区间 [start:end] 或 [start:end:step]
    final rangeMatch = RegExp(r'^(-?\d*):(-?\d*)(?::(-?\d*))?$').firstMatch(indexExpr);
    if (rangeMatch != null) {
      int? start = rangeMatch.group(1)!.isNotEmpty ? int.parse(rangeMatch.group(1)!) : null;
      int? end = rangeMatch.group(2)!.isNotEmpty ? int.parse(rangeMatch.group(2)!) : null;
      int step = rangeMatch.group(3) != null && rangeMatch.group(3)!.isNotEmpty
          ? int.parse(rangeMatch.group(3)!)
          : 1;

      // 转换负索引
      start = start != null ? (start >= 0 ? start : elements.length + start) : 0;
      end = end != null ? (end >= 0 ? end : elements.length + end) : elements.length - 1;

      // 边界检查
      start = start.clamp(0, elements.length - 1);
      end = end.clamp(0, elements.length - 1);

      final result = <dom.Element>[];
      if (step > 0 && start <= end) {
        for (int i = start; i <= end; i += step) {
          if (i < elements.length) result.add(elements[i]);
        }
      } else if (step < 0 && start >= end) {
        for (int i = start; i >= end; i += step) {
          if (i >= 0 && i < elements.length) result.add(elements[i]);
        }
      }
      return result;
    }

    return elements;
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
        final foundElements = _getElementsBySingleRule(current, trimmedPart);
        if (foundElements.isNotEmpty) {
          current = foundElements.first;
          result = current.text.trim();
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
        return _resolveUrl(href, baseUrl);
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
        final foundElements = _getElementsBySingleRule(current, trimmedPart);
        if (foundElements.isNotEmpty) {
          current = foundElements.first;
          // 尝试获取 href
          final href = current.attributes['href'];
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
        return _resolveUrl(result, baseUrl);
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
    String baseUrl = _cleanBaseUrl(source.bookSourceUrl);

    print('📖 获取章节内容: $chapterUrl');
    print('📖 书源: ${source.bookSourceName}');

    // 检查章节 URL 是否需要拼接
    String fullUrl = chapterUrl;
    if (!chapterUrl.startsWith('http://') && !chapterUrl.startsWith('https://')) {
      fullUrl = _resolveUrl(chapterUrl, baseUrl);
      print('📖 拼接URL: $chapterUrl -> $fullUrl');
    }

    final response = await _dio.get<String>(
      fullUrl,
      options: Options(
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          if (source.header != null) ..._parseHeader(source.header!),
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

      // 处理正则替换
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
        final elements = _getElements(document.documentElement!, contentRule);
        print('📄 找到 ${elements.length} 个内容元素');
        content = elements.map((e) => e.text.trim()).join('\n\n');
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

    // 清理内容
    if (rule.replaceRegex != null && rule.replaceRegex!.isNotEmpty) {
      print('📄 应用替换正则: ${rule.replaceRegex}');
      try {
        final regex = RegExp(rule.replaceRegex!);
        content = content.replaceAll(regex, '');
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

  /// 清理 baseUrl，移除 ## 或 # 后面的标记
  String _cleanBaseUrl(String url) {
    if (url.contains('##')) {
      return url.split('##')[0];
    } else if (url.contains('#')) {
      return url.split('#')[0];
    }
    return url;
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
    final trimmed = header.trim();

    // 尝试解析为 JSON 格式 {"key": "value"}
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        // 简单的 JSON 解析，不依赖 dart:convert
        final content = trimmed
            .substring(1, trimmed.length - 1)
            .replaceAllMapped(
              RegExp(r'"([^"]+)"\s*:\s*"([^"]*)"'),
              (match) => '${match.group(1)}:${match.group(2)}',
            );
        for (final pair in content.split(',')) {
          final kv = pair.split(':');
          if (kv.length >= 2) {
            final key = kv[0].trim().replaceAll('"', '');
            final value = kv.sublist(1).join(':').trim().replaceAll('"', '');
            if (key.isNotEmpty) {
              map[key] = value;
            }
          }
        }
        return map;
      } catch (e) {
        // JSON 解析失败，尝试行格式
      }
    }

    // 行格式: Key: Value
    for (final line in header.split('\n')) {
      final parts = line.split(':');
      if (parts.length >= 2) {
        map[parts[0].trim()] = parts.sublist(1).join(':').trim();
      }
    }
    return map;
  }
}
