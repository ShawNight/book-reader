import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;

import '../models/book_source.dart';
import '../models/source_test_result.dart';
import '../utils/url_builder.dart';
import 'rule_parser.dart';

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

  /// 释放资源（当服务不再需要时调用）
  void dispose() {
    _testDio.close();
  }

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
      // 构建搜索URL（使用 UrlBuilder 统一处理）
      String url = UrlBuilder.buildSearchUrl(
        source.searchUrl!,
        keyword: testKeyword,
        page: 1,
      );

      // 清理 baseUrl
      final baseUrl = RuleParser.cleanBaseUrl(source.bookSourceUrl);

      // 如果是相对路径，与 baseUrl 拼接
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = RuleParser.resolveUrl(url, baseUrl);
      }

      // 发送请求
      final response = await _testDio.get<String>(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            if (source.header != null) ...RuleParser.parseHeader(source.header!),
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

    // 确保 controller 正确关闭的辅助方法
    void closeControllerIfNeeded() {
      if ((completed >= total || _isCancelled) && !controller.isClosed) {
        _isTesting = false;
        controller.close();
      }
    }

    // 分批并发测试
    Future<void> processSource(BookSource source) async {
      if (_isCancelled) {
        completed++;
        return;
      }

      // 发送进度更新（测试中）
      if (!controller.isClosed) {
        controller.add(SourceTestProgress(
          completed: completed,
          total: total,
          currentSourceName: source.bookSourceName,
        ));
      }

      try {
        final result = await testSource(source, keyword: keyword);
        completed++;
        activeCount[0]--;

        // 发送完成进度
        if (!controller.isClosed) {
          controller.add(SourceTestProgress(
            completed: completed,
            total: total,
            lastResult: result,
          ));
        }
      } catch (e) {
        completed++;
        activeCount[0]--;
        if (!controller.isClosed) {
          controller.add(SourceTestProgress(
            completed: completed,
            total: total,
          ));
        }
      }

      closeControllerIfNeeded();
    }

    // 使用 Future 实现并发调度
    int index = 0;
    Future<void> runScheduler() async {
      while (index < sources.length && !_isCancelled) {
        // 等待直到有可用槽位
        while (activeCount[0] >= maxConcurrentTests && !_isCancelled) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
        if (_isCancelled) break;

        // 启动新的测试任务
        if (index < sources.length) {
          activeCount[0]++;
          final source = sources[index++];
          processSource(source); // 不等待，让它并行运行
        }
      }
      // 等待所有任务完成
      while (activeCount[0] > 0 && !_isCancelled) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      closeControllerIfNeeded();
    }

    // 监听取消事件，确保资源释放
    controller.onCancel = () {
      _isCancelled = true;
      closeControllerIfNeeded();
    };

    // 当 Stream 被监听时开始调度
    controller.onListen = () {
      runScheduler();
    };

    // 如果没有监听者，也开始调度（兼容直接获取 stream 的情况）
    Future.delayed(Duration.zero, () {
      if (!controller.hasListener && !_isCancelled) {
        runScheduler();
      }
    });

    return controller.stream;
  }

  /// 计算 JSON 结果数量
  int _countJsonResults(String? data, BookSource source) {
    if (data == null) return 0;

    try {
      final json = jsonDecode(data);
      final bookListPath =
          source.ruleSearch!.bookList?.substring(1) ?? ''; // 移除开头的 $
      final bookList = RuleParser.getJsonValue(json, bookListPath) as List? ?? [];
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
      final elements = RuleParser.getElements(document.documentElement!, bookListRule);
      return elements.length;
    } catch (e) {
      print('HTML解析失败: $e');
      return 0;
    }
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
