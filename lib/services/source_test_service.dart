import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;

import '../models/book_source.dart';
import '../models/source_test_result.dart';

/// 书源测试服务
class SourceTestService {
  static final SourceTestService _instance = SourceTestService._internal();
  factory SourceTestService() => _instance;
  SourceTestService._internal();

  /// 默认测试关键词
  static const String defaultTestKeyword = '斗罗';

  /// 最大并发测试数
  static const int maxConcurrentTests = 5;

  /// 测试超时时间（秒）
  static const int testTimeoutSeconds = 8;

  /// 是否正在测试
  bool _isTesting = false;

  /// 是否已取消
  bool _isCancelled = false;

  /// 测试用的 Dio
  final Dio _testDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: testTimeoutSeconds),
    receiveTimeout: const Duration(seconds: testTimeoutSeconds),
  ));

  /// 是否正在测试
  bool get isTesting => _isTesting;

  /// 取消测试
  void cancelTest() {
    _isCancelled = true;
  }

  /// 测试单个书源
  Future<SourceTestResult> testSource(
    BookSource source, {
    String? keyword,
  }) async {
    final testKeyword = keyword ?? defaultTestKeyword;

    // 检查 searchUrl 是否存在
    if (source.searchUrl == null || source.searchUrl!.isEmpty) {
      return SourceTestResult(
        source: source,
        status: SourceTestStatus.failed,
        errorMessage: '书源无搜索URL',
      );
    }

    // 检查规则是否存在
    if (source.ruleSearch == null) {
      return SourceTestResult(
        source: source,
        status: SourceTestStatus.failed,
        errorMessage: '书源无搜索规则',
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      // 构建搜索URL
      String url = source.searchUrl!;
      if (url.contains('{{key}}')) {
        url = url.replaceAll('{{key}}', Uri.encodeComponent(testKeyword));
      } else if (url.contains('{{page}}')) {
        url = url.replaceAll('{{page}}', '1');
        if (url.contains('{{key}}')) {
          url = url.replaceAll('{{key}}', Uri.encodeComponent(testKeyword));
        } else {
          url = '$url${Uri.encodeComponent(testKeyword)}';
        }
      } else {
        url = '$url${Uri.encodeComponent(testKeyword)}';
      }

      // 清理 baseUrl
      final baseUrl = _cleanBaseUrl(source.bookSourceUrl);

      // 如果是相对路径，与 baseUrl 拼接
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = _resolveUrl(url, baseUrl);
      }

      // 发送请求
      final response = await _testDio.get<String>(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            if (source.header != null) ..._parseHeader(source.header!),
          },
        ),
      );

      stopwatch.stop();

      // 检测是否为 JSON 规则
      final isJsonRule = source.ruleSearch!.bookList?.startsWith('\$') ?? false;

      int resultCount = 0;
      if (isJsonRule) {
        resultCount = _countJsonResults(response.data, source);
      } else {
        resultCount = _countHtmlResults(response.data, source);
      }

      if (resultCount > 0) {
        return SourceTestResult(
          source: source,
          status: SourceTestStatus.success,
          responseTime: stopwatch.elapsed,
          resultCount: resultCount,
        );
      } else {
        return SourceTestResult(
          source: source,
          status: SourceTestStatus.failed,
          responseTime: stopwatch.elapsed,
          errorMessage: '无搜索结果',
        );
      }
    } on DioException catch (e) {
      stopwatch.stop();
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return SourceTestResult(
          source: source,
          status: SourceTestStatus.timeout,
          responseTime: stopwatch.elapsed,
          errorMessage: '连接超时',
        );
      }
      return SourceTestResult(
        source: source,
        status: SourceTestStatus.failed,
        responseTime: stopwatch.elapsed,
        errorMessage: _getErrorMessage(e),
      );
    } catch (e) {
      stopwatch.stop();
      return SourceTestResult(
        source: source,
        status: SourceTestStatus.failed,
        responseTime: stopwatch.elapsed,
        errorMessage: e.toString(),
      );
    }
  }

  /// 批量测试（流式返回进度）
  Stream<SourceTestProgress> testSourcesStream(
    List<BookSource> sources, {
    String? keyword,
  }) {
    final controller = StreamController<SourceTestProgress>.broadcast();

    _isTesting = true;
    _isCancelled = false;

    final total = sources.length;
    var completed = 0;
    final activeCount = <int>[0];

    // 分批并发测试
    Future<void> processSource(BookSource source) async {
      if (_isCancelled) {
        completed++;
        return;
      }

      // 发送进度更新（测试中）
      controller.add(SourceTestProgress(
        completed: completed,
        total: total,
        currentSourceName: source.bookSourceName,
      ));

      final result = await testSource(source, keyword: keyword);

      completed++;
      activeCount[0]--;

      // 发送完成进度
      controller.add(SourceTestProgress(
        completed: completed,
        total: total,
        lastResult: result,
      ));
    }

    // 限制并发的调度器
    int index = 0;
    void scheduleNext() {
      while (index < sources.length &&
          activeCount[0] < maxConcurrentTests &&
          !_isCancelled) {
        activeCount[0]++;
        final source = sources[index++];
        processSource(source).then((_) {
          scheduleNext();
        });
      }

      // 所有任务完成或已取消
      if ((completed >= total || _isCancelled) && !controller.isClosed) {
        _isTesting = false;
        controller.close();
      }
    }

    // 开始调度
    scheduleNext();

    return controller.stream;
  }

  /// 计算 JSON 结果数量
  int _countJsonResults(String? data, BookSource source) {
    if (data == null) return 0;

    try {
      final json = jsonDecode(data);
      final bookListPath =
          source.ruleSearch!.bookList?.substring(1) ?? ''; // 移除开头的 $
      final bookList = _getJsonValue(json, bookListPath) as List? ?? [];
      return bookList.length;
    } catch (e) {
      print('JSON解析失败: $e');
      return 0;
    }
  }

  /// 计算 HTML 结果数量
  int _countHtmlResults(String? data, BookSource source) {
    if (data == null) return 0;

    try {
      final document = parse(data);
      final bookListRule = source.ruleSearch!.bookList ?? '.item';

      // 使用与 SearchService 相同的元素获取逻辑
      final elements = _getElements(document.documentElement!, bookListRule);
      return elements.length;
    } catch (e) {
      print('HTML解析失败: $e');
      return 0;
    }
  }

  /// 获取元素列表（支持 Legado 规则格式）
  /// 复制自 SearchService 的逻辑
  List<dynamic> _getElements(dynamic root, String rule) {
    if (rule.isEmpty) return [root];

    final elements = <dynamic>[];
    String remainingRule = rule.trim();

    // 处理 @CSS: 前缀
    if (remainingRule.toLowerCase().startsWith('@css:')) {
      remainingRule = remainingRule.substring(5).trim();
      // 使用 querySelectorAll
      if (root != null) {
        elements.addAll(root.querySelectorAll(remainingRule));
      }
      return elements;
    }

    // 按 @ 分割规则
    final parts = remainingRule.split('@');
    List<dynamic> currentElements = [root];

    for (final part in parts) {
      final trimmedPart = part.trim();
      if (trimmedPart.isEmpty) continue;

      final nextElements = <dynamic>[];
      for (final element in currentElements) {
        nextElements.addAll(_getElementsBySingleRule(element, trimmedPart));
      }
      currentElements = nextElements;

      if (currentElements.isEmpty) break;
    }

    return currentElements;
  }

  /// 单个规则获取元素
  List<dynamic> _getElementsBySingleRule(dynamic element, String rule) {
    if (rule.isEmpty) return [element];

    try {
      // 处理 tag.xxx 格式
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

      // 处理带索引的选择器
      final indexPattern = RegExp(r'^(.+?)([.!])(-?\d+)$');
      final indexMatch = indexPattern.firstMatch(rule);
      if (indexMatch != null) {
        final selector = indexMatch.group(1)!;
        final splitChar = indexMatch.group(2)!;
        final indexStr = indexMatch.group(3)!;
        final index = int.parse(indexStr);

        final elements = _getElementsBySingleRule(element, selector);

        if (splitChar == '.') {
          // 选择模式
          if (index >= 0 && index < elements.length) {
            return [elements[index]];
          } else if (index < 0 && elements.length + index >= 0) {
            return [elements[elements.length + index]];
          }
        } else {
          // 排除模式 (!)
          if (index >= 0 && index < elements.length) {
            elements.removeAt(index);
          } else if (index < 0 && elements.length + index >= 0) {
            elements.removeAt(elements.length + index);
          }
          return elements;
        }
        return [];
      }

      // 处理 [index] 或 [start:end] 格式
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
      return [];
    }
  }

  /// 根据索引表达式选择元素
  List<dynamic> _selectElementsByIndex(List<dynamic> elements, String indexExpr) {
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

      start = start != null ? (start >= 0 ? start : elements.length + start) : 0;
      end = end != null ? (end >= 0 ? end : elements.length + end) : elements.length - 1;

      start = start.clamp(0, elements.length - 1);
      end = end.clamp(0, elements.length - 1);

      final result = <dynamic>[];
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

  /// 从 JSON 对象中获取值
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

  /// 清理 baseUrl
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

  /// 解析 header
  Map<String, String> _parseHeader(String header) {
    final map = <String, String>{};
    final trimmed = header.trim();

    // 尝试解析为 JSON 格式
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final content = trimmed.substring(1, trimmed.length - 1).replaceAllMapped(
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

  /// 获取错误消息
  String _getErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
        return '连接失败';
      case DioExceptionType.badResponse:
        return 'HTTP ${e.response?.statusCode ?? '错误'}';
      case DioExceptionType.cancel:
        return '已取消';
      case DioExceptionType.sendTimeout:
        return '发送超时';
      default:
        return e.message ?? '未知错误';
    }
  }
}
