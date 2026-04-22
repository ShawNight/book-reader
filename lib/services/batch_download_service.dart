import 'dart:async';

import '../models/book_source.dart';
import 'chapter_cache_service.dart';
import 'search_service.dart';

/// 下载状态枚举
enum DownloadStatus {
  notDownloaded, // 未下载
  downloading, // 下载中
  downloaded, // 已下载
  failed, // 下载失败
}

/// 章节下载状态
class ChapterDownloadStatus {
  final int index;
  final DownloadStatus status;
  final String? error;

  const ChapterDownloadStatus({
    required this.index,
    required this.status,
    this.error,
  });
}

/// 批量下载进度
class BatchDownloadProgress {
  final int total;
  final int completed;
  final int failed;
  final int current;
  final bool isDownloading;

  const BatchDownloadProgress({
    required this.total,
    required this.completed,
    required this.failed,
    required this.current,
    required this.isDownloading,
  });

  double get progress => total > 0 ? completed / total : 0;

  String get progressText => '$completed / $total';
}

/// 批量下载服务 - 单例模式
/// 用于管理章节的批量下载，支持后台下载和进度追踪
class BatchDownloadService {
  static final BatchDownloadService _instance =
      BatchDownloadService._internal();
  factory BatchDownloadService() => _instance;
  BatchDownloadService._internal();

  final SearchService _searchService = SearchService();
  final ChapterCacheService _cacheService = ChapterCacheService();

  // 下载状态
  final Map<String, DownloadStatus> _downloadStatus = {};
  final Map<String, String> _downloadErrors = {};

  // 当前下载任务
  bool _isDownloading = false;
  int _totalChapters = 0;
  int _completedChapters = 0;
  int _failedChapters = 0;
  int _currentIndex = -1;

  // 进度流控制器
  final _progressController =
      StreamController<BatchDownloadProgress>.broadcast();

  /// 进度流
  Stream<BatchDownloadProgress> get progressStream =>
      _progressController.stream;

  /// 是否正在下载
  bool get isDownloading => _isDownloading;

  /// 释放资源（当服务不再需要时调用）
  void dispose() {
    _progressController.close();
  }

  /// 发送进度更新
  void _emitProgress() {
    if (!_progressController.isClosed) {
      _progressController.add(BatchDownloadProgress(
        total: _totalChapters,
        completed: _completedChapters,
        failed: _failedChapters,
        current: _currentIndex,
        isDownloading: _isDownloading,
      ));
    }
  }

  /// 获取章节的下载状态
  DownloadStatus getStatus(String chapterUrl) {
    return _downloadStatus[chapterUrl] ?? DownloadStatus.notDownloaded;
  }

  /// 获取章节的下载错误信息
  String? getError(String chapterUrl) {
    return _downloadErrors[chapterUrl];
  }

  /// 检查章节是否已缓存
  Future<bool> isChapterCached(String chapterUrl) async {
    return _cacheService.hasCache(chapterUrl);
  }

  /// 批量检查章节缓存状态
  Future<Map<int, DownloadStatus>> checkChaptersCacheStatus(
    List<Chapter> chapters,
  ) async {
    final Map<int, DownloadStatus> statusMap = {};

    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final isCached = await _cacheService.hasCache(chapter.url);
      statusMap[i] =
          isCached ? DownloadStatus.downloaded : DownloadStatus.notDownloaded;
      _downloadStatus[chapter.url] =
          statusMap[i]!; // 同步更新内部状态映射，确保后续查询能命中缓存结果
    }

    return statusMap;
  }

  /// 开始批量下载
  /// [chapters] 要下载的章节列表
  /// [source] 书源
  /// [bookUrl] 书籍URL（用于标识下载任务）
  /// [concurrent] 并发数（默认3）
  Future<void> startBatchDownload(
    List<Chapter> chapters,
    BookSource source,
    String bookUrl, {
    int concurrent = 3,
  }) async {
    if (_isDownloading) {
      throw Exception('已有下载任务进行中');
    }

    _isDownloading = true;
    _totalChapters = chapters.length;
    _completedChapters = 0;
    _failedChapters = 0;
    _currentIndex = -1;

    // 发送初始进度
    _emitProgress();

    try {
      // 分批并发下载
      final batches = _splitIntoBatches(chapters, concurrent);

      for (final batch in batches) {
        if (!_isDownloading) break; // 已取消

        await Future.wait(
          batch.map((chapter) => _downloadChapter(chapter, source)),
        );
      }
    } finally {
      _isDownloading = false;
      _emitProgress();
    }
  }

  /// 下载单个章节
  Future<void> _downloadChapter(Chapter chapter, BookSource source) async {
    final chapterUrl = chapter.url;

    // 更新状态为下载中
    _downloadStatus[chapterUrl] = DownloadStatus.downloading;
    _currentIndex = _totalChapters > 0
        ? _completedChapters + _failedChapters
        : -1;
    _emitProgress();

    try {
      // 检查是否已缓存
      if (await _cacheService.hasCache(chapterUrl)) {
        _downloadStatus[chapterUrl] = DownloadStatus.downloaded;
        _completedChapters++;
        _emitProgress();
        return;
      }

      // 获取章节内容
      final content = await _searchService.getChapterContent(
        chapterUrl,
        source,
      );

      // 保存到缓存
      await _cacheService.saveCache(
        chapterUrl,
        content.content,
        bookName: chapter.name,
      );

      _downloadStatus[chapterUrl] = DownloadStatus.downloaded;
      _downloadErrors.remove(chapterUrl);
      _completedChapters++;
    } catch (e) {
      _downloadStatus[chapterUrl] = DownloadStatus.failed;
      _downloadErrors[chapterUrl] = e.toString();
      _failedChapters++;
      print('下载章节失败 [${chapter.name}]: $e');
    }

    _emitProgress();
  }

  /// 取消当前下载任务
  void cancelDownload() {
    _isDownloading = false;
    _emitProgress();
  }

  /// 将章节列表分割成批次
  List<List<Chapter>> _splitIntoBatches(List<Chapter> chapters, int size) {
    final batches = <List<Chapter>>[];
    for (var i = 0; i < chapters.length; i += size) {
      final end = (i + size < chapters.length) ? i + size : chapters.length;
      batches.add(chapters.sublist(i, end));
    }
    return batches;
  }

  /// 清除所有状态并重新检查缓存
  void clearAllStatusAndCheckCache() {
    _downloadStatus.clear();
    _downloadErrors.clear();
  }
}
