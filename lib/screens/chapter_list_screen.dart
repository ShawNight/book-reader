import 'package:flutter/material.dart';

import '../models/book_source.dart';
import '../models/book.dart';
import '../services/search_service.dart';
import '../services/bookshelf_service.dart';
import '../services/bookmark_service.dart';
import '../services/batch_download_service.dart';
import '../services/chapter_cache_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'reader_screen.dart';

/// 章节列表页面
class ChapterListScreen extends StatefulWidget {
  final String bookUrl;
  final String bookName;
  final BookSource source;
  final String? coverUrl;
  final String? intro;
  final String? latestChapter;
  final int? lastReadChapter;
  final double? scrollProgress;

  const ChapterListScreen({
    super.key,
    required this.bookUrl,
    required this.bookName,
    required this.source,
    this.coverUrl,
    this.intro,
    this.latestChapter,
    this.lastReadChapter,
    this.scrollProgress,
  });

  @override
  State<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends State<ChapterListScreen> {
  final SearchService _searchService = SearchService();
  final BookshelfService _bookshelfService = BookshelfService();
  final BookmarkService _bookmarkService = BookmarkService();
  final BatchDownloadService _downloadService = BatchDownloadService();
  final ChapterCacheService _cacheService = ChapterCacheService();

  List<Chapter> _chapters = [];
  bool _isLoading = true;
  String? _error;
  bool _isInBookshelf = false;

  // 书签相关
  Set<int> _bookmarkedChapters = {}; // 有书签的章节索引集合

  // 下载相关
  final Map<int, DownloadStatus> _chapterDownloadStatus = {};
  bool _isSelectionMode = false;
  final Set<int> _selectedChapters = {};
  BatchDownloadProgress? _downloadProgress;
  bool _isDownloading = false;
  int _downloadedCount = 0; // 已缓存章节数量

  @override
  void initState() {
    super.initState();
    _checkBookshelf();
    _loadChapters();
    _loadBookmarkedChapters();
    _listenToDownloadProgress();
  }

  /// 监听下载进度
  void _listenToDownloadProgress() {
    _downloadService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _downloadProgress = progress;
          _isDownloading = progress.isDownloading;
        });

        // 下载完成后刷新状态
        if (!progress.isDownloading && progress.total > 0) {
          _refreshDownloadStatus();
        }
      }
    });
  }

  /// 刷新下载状态
  Future<void> _refreshDownloadStatus() async {
    int count = 0;
    for (int i = 0; i < _chapters.length; i++) {
      final chapter = _chapters[i];
      final isCached = await _cacheService.hasCache(chapter.url);
      if (isCached) {
        _chapterDownloadStatus[i] = DownloadStatus.downloaded;
        count++;
      } else {
        _chapterDownloadStatus[i] = DownloadStatus.notDownloaded;
      }
    }
    if (mounted) {
      setState(() {
        _downloadedCount = count;
      });
    }
  }

  /// 加载有书签的章节
  Future<void> _loadBookmarkedChapters() async {
    final bookmarks =
        await _bookmarkService.getBookmarksForBook(widget.bookUrl);
    if (mounted) {
      setState(() {
        _bookmarkedChapters = bookmarks.map((b) => b.chapterIndex).toSet();
      });
    }
  }

  Future<void> _checkBookshelf() async {
    final isIn = await _bookshelfService.isBookInShelf(widget.bookUrl);
    if (mounted) {
      setState(() => _isInBookshelf = isIn);
    }
  }

  Future<void> _loadChapters() async {
    try {
      final chapters = await _searchService.getChapters(
        widget.bookUrl,
        widget.source,
      );

      if (!mounted) return;

      setState(() {
        _chapters = chapters;
        _isLoading = false;

        if (chapters.isEmpty) {
          _error = '未找到章节';
        }
      });

      // 加载章节缓存状态
      _refreshDownloadStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '加载失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _isSelectionMode ? _buildBottomActionBar() : null,
    );
  }

  /// 普通模式 AppBar
  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: Text(widget.bookName),
      actions: [
        // 下载按钮
        if (_chapters.isNotEmpty)
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: AppSpacing.iconSizeMd,
                    height: AppSpacing.iconSizeMd,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            tooltip: _isDownloading ? '下载中...' : '批量下载',
            onPressed: _isDownloading ? null : _enterSelectionMode,
          ),
        if (widget.lastReadChapter != null)
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: '继续阅读',
            onPressed: _isLoading ? null : _continueReading,
          ),
        IconButton(
          icon: Icon(
            _isInBookshelf ? Icons.bookmark : Icons.bookmark_border,
          ),
          tooltip: _isInBookshelf ? '已在书架' : '加入书架',
          onPressed: _toggleBookshelf,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _isLoading ? null : _loadChapters,
        ),
      ],
    );
  }

  /// 多选模式 AppBar
  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      title: _isDownloading
          ? Text('下载中 ${_downloadProgress?.progressText ?? ""}')
          : Text('已选 ${_selectedChapters.length} 章'),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: _selectedChapters.isEmpty
                ? _selectAll
                : _selectedChapters.length == _chapters.length
                    ? _deselectAll
                    : _selectAll,
            child: Text(
              _selectedChapters.length == _chapters.length ? '取消全选' : '全选',
            ),
          ),
      ],
    );
  }

  /// 底部操作栏
  Widget _buildBottomActionBar() {
    return Container(
      padding: AppSpacing.horizontalLg
          .copyWith(top: AppSpacing.sm, bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _isDownloading
          ? _buildDownloadProgressBar()
          : _buildSelectionActions(),
    );
  }

  /// 下载进度条
  Widget _buildDownloadProgressBar() {
    final progress = _downloadProgress;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: progress?.progress ?? 0,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Text(
              progress?.progressText ?? '0 / 0',
              style: const TextStyle(fontSize: AppSpacing.sm + 1),
            ),
            const SizedBox(width: AppSpacing.sm),
            if ((progress?.failed ?? 0) > 0)
              Text(
                '失败: ${progress?.failed ?? 0}',
                style: const TextStyle(
                    fontSize: AppSpacing.sm + 1, color: AppColors.error),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _cancelDownload,
          child: const Text('取消下载'),
        ),
      ],
    );
  }

  /// 选择操作按钮
  Widget _buildSelectionActions() {
    final selectedCount = _selectedChapters.length;
    final cachedCount = _selectedChapters.where((i) {
      final status = _chapterDownloadStatus[i];
      return status == DownloadStatus.downloaded;
    }).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.download,
          label: '下载选中',
          onPressed: selectedCount == 0 ? null : _startDownload,
          color: AppColors.primary,
          subtitle: cachedCount > 0 ? '($cachedCount 已缓存)' : null,
        ),
        _buildActionButton(
          icon: Icons.download_done,
          label: '下载未缓存',
          onPressed: null,
          color: AppColors.success,
        ),
      ],
    );
  }

  /// 操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
    String? subtitle,
  }) {
    final isEnabled = onPressed != null;
    return TextButton(
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isEnabled ? color : AppColors.grey,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              color: isEnabled ? color : AppColors.grey,
              fontSize: AppSpacing.sm + 1,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: TextStyle(
                color: isEnabled ? color : AppColors.grey,
                fontSize: AppSpacing.xs + 2,
              ),
            ),
        ],
      ),
    );
  }

  /// 加入/移出书架
  Future<void> _toggleBookshelf() async {
    try {
      if (_isInBookshelf) {
        // 从书架移除
        await _bookshelfService.removeBook(widget.bookUrl);
        if (!mounted) return;
        setState(() => _isInBookshelf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已从书架移除')),
        );
      } else {
        // 加入书架
        final book = Book(
          name: widget.bookName,
          author: '未知', // 可以从搜索结果传递
          bookUrl: widget.bookUrl,
          coverUrl: widget.coverUrl,
          intro: widget.intro,
          latestChapter: widget.latestChapter,
          sourceName: widget.source.bookSourceName,
          sourceUrl: widget.source.bookSourceUrl,
          addedTime: DateTime.now(),
        );

        await _bookshelfService.addBook(book);
        if (!mounted) return;
        setState(() => _isInBookshelf = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('《${widget.bookName}》已加入书架')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败：$e')),
      );
    }
  }

  /// 继续阅读
  void _continueReading() async {
    if (_chapters.isEmpty) return;

    // 计算有效的章节索引
    final initialIndex =
        (widget.lastReadChapter ?? 0).clamp(0, _chapters.length - 1);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          chapters: _chapters,
          initialIndex: initialIndex,
          source: widget.source,
          bookName: widget.bookName,
          bookUrl: widget.bookUrl,
          initialScrollProgress: widget.scrollProgress,
        ),
      ),
    );
    // 返回时刷新书签状态
    _loadBookmarkedChapters();
  }

  // ============== 多选模式相关方法 ==============

  /// 进入多选模式
  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedChapters.clear();
    });
  }

  /// 退出多选模式
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedChapters.clear();
    });
  }

  /// 切换选中状态
  void _toggleSelection(int index) {
    setState(() {
      if (_selectedChapters.contains(index)) {
        _selectedChapters.remove(index);
      } else {
        _selectedChapters.add(index);
      }
    });
  }

  /// 全选
  void _selectAll() {
    setState(() {
      _selectedChapters.clear();
      _selectedChapters.addAll(List.generate(_chapters.length, (i) => i));
    });
  }

  /// 取消全选
  void _deselectAll() {
    setState(() {
      _selectedChapters.clear();
    });
  }

  /// 开始下载选中章节
  Future<void> _startDownload() async {
    if (_selectedChapters.isEmpty) return;

    final selectedChapters =
        _selectedChapters.map((i) => _chapters[i]).toList();

    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认下载'),
        content: Text('确定要下载选中的 ${selectedChapters.length} 个章节吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('下载'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 开始后台下载
    setState(() {
      _isDownloading = true;
    });

    try {
      await _downloadService.startBatchDownload(
        selectedChapters,
        widget.source,
        widget.bookUrl,
        concurrent: 3,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '下载完成：${_downloadProgress?.completed ?? 0} 章'
              '${(_downloadProgress?.failed ?? 0) > 0 ? '，失败 ${_downloadProgress?.failed} 章' : ''}',
            ),
          ),
        );
        _exitSelectionMode();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：$e')),
        );
      }
    }
  }

  /// 取消下载
  void _cancelDownload() {
    _downloadService.cancelDownload();
    setState(() {
      _isDownloading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已取消下载')),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.lg),
            Text('正在加载章节列表...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: AppSpacing.iconSizeLg, color: AppColors.grey),
            const SizedBox(height: AppSpacing.lg),
            Text(_error!),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loadChapters,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_chapters.isEmpty) {
      return const Center(
        child: Text('暂无章节'),
      );
    }

    return Column(
      children: [
        // 顶部操作区域
        _buildTopActions(),
        // 章节列表
        Expanded(
          child: ListView.builder(
            itemCount: _chapters.length,
            itemBuilder: (context, index) {
              final chapter = _chapters[index];
              final hasBookmark = _bookmarkedChapters.contains(index);
              final downloadStatus =
                  _chapterDownloadStatus[index] ?? DownloadStatus.notDownloaded;
              final isSelected = _selectedChapters.contains(index);

              if (_isSelectionMode) {
                // 多选模式 - 目录样式
                return ListTile(
                  contentPadding: AppSpacing.listItemPadding,
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: _isDownloading
                        ? null
                        : (value) => _toggleSelection(index),
                  ),
                  title: Row(
                    children: [
                      Text(
                        '第${index + 1}章',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.greyDark,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(chapter.name),
                      ),
                      _buildDownloadStatusIcon(downloadStatus),
                      if (hasBookmark) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(
                          Icons.bookmark,
                          size: AppSpacing.iconSizeSm,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                  onTap: _isDownloading ? null : () => _toggleSelection(index),
                );
              } else {
              // 普通模式 - 目录样式
              return ListTile(
                contentPadding: AppSpacing.listItemPadding,
                title: Row(
                  children: [
                    Text(
                      '第${index + 1}章',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.greyDark,
                      ),
                    ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(chapter.name),
                      ),
                      _buildDownloadStatusIcon(downloadStatus),
                      if (hasBookmark) ...[
                        const SizedBox(width: AppSpacing.sm),
                        const Icon(
                          Icons.bookmark,
                          size: AppSpacing.iconSizeSm,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReaderScreen(
                          chapters: _chapters,
                          initialIndex: index,
                          source: widget.source,
                          bookName: widget.bookName,
                          bookUrl: widget.bookUrl,
                        ),
                      ),
                    );
                    // 返回时刷新书签状态和下载状态
                    _loadBookmarkedChapters();
                    _refreshDownloadStatus();
                  },
                );
              }
            },
          ),
        ),
      ],
    );
  }

  /// 顶部操作区域
  Widget _buildTopActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: _isDownloading
                  ? const SizedBox(
                      width: AppSpacing.iconSizeSm,
                      height: AppSpacing.iconSizeSm,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download),
              label: Text(_isDownloading ? '下载中...' : '批量下载'),
              onPressed: _isDownloading ? null : _enterSelectionMode,
            ),
          ),
          if (_downloadedCount > 0) ...[
            const SizedBox(width: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: AppSpacing.chipBorderRadius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.offline_pin,
                    size: AppSpacing.iconSizeSm,
                    color: AppColors.successDark,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '已缓存 $_downloadedCount 章',
                    style: const TextStyle(
                      fontSize: AppSpacing.sm + 1,
                      color: AppColors.successDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建下载状态图标
  Widget _buildDownloadStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloaded:
        return const Icon(
          Icons.offline_pin,
          size: AppSpacing.iconSizeSm,
          color: AppColors.success,
        );
      case DownloadStatus.downloading:
        return const SizedBox(
          width: AppSpacing.iconSizeSm,
          height: AppSpacing.iconSizeSm,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case DownloadStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: AppSpacing.iconSizeSm,
          color: AppColors.error,
        );
      case DownloadStatus.notDownloaded:
        return Icon(
          Icons.cloud_off_outlined,
          size: AppSpacing.iconSizeSm,
          color: AppColors.grey.withOpacity(0.5),
        );
    }
  }
}
