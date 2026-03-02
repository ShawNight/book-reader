import 'book_source.dart';

/// 测试状态枚举
enum SourceTestStatus {
  pending, // 待测试
  testing, // 测试中
  success, // 有效
  failed, // 失败
  timeout, // 超时
}

/// 单个书源测试结果
class SourceTestResult {
  final BookSource source;
  final SourceTestStatus status;
  final String? errorMessage;
  final Duration? responseTime;
  final int? resultCount; // 搜索结果数量

  SourceTestResult({
    required this.source,
    required this.status,
    this.errorMessage,
    this.responseTime,
    this.resultCount,
  });

  bool get isValid => status == SourceTestStatus.success;

  SourceTestResult copyWith({
    BookSource? source,
    SourceTestStatus? status,
    String? errorMessage,
    Duration? responseTime,
    int? resultCount,
  }) {
    return SourceTestResult(
      source: source ?? this.source,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      responseTime: responseTime ?? this.responseTime,
      resultCount: resultCount ?? this.resultCount,
    );
  }
}

/// 批量测试进度
class SourceTestProgress {
  final int completed;
  final int total;
  final String? currentSourceName;
  final SourceTestResult? lastResult;

  SourceTestProgress({
    required this.completed,
    required this.total,
    this.currentSourceName,
    this.lastResult,
  });

  double get progress => total > 0 ? completed / total : 0;

  SourceTestProgress copyWith({
    int? completed,
    int? total,
    String? currentSourceName,
    SourceTestResult? lastResult,
  }) {
    return SourceTestProgress(
      completed: completed ?? this.completed,
      total: total ?? this.total,
      currentSourceName: currentSourceName ?? this.currentSourceName,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}
