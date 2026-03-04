import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/book_source.dart';
import '../models/bookmark.dart';
import '../models/reader_settings.dart';
import '../services/search_service.dart';
import '../services/bookshelf_service.dart';
import '../services/reader_settings_service.dart';
import '../services/chapter_cache_service.dart';
import '../services/bookmark_service.dart';
import '../services/batch_download_service.dart';
import '../widgets/simulation_page_turn.dart';
import '../widgets/content_with_images.dart';

/// 阅读页面
class ReaderScreen extends StatefulWidget {
  final List<Chapter> chapters;
  final int initialIndex;
  final BookSource source;
  final String bookName;
  final String? bookUrl;
  final double? initialScrollProgress; // 初始滚动进度

  const ReaderScreen({
    super.key,
    required this.chapters,
    required this.initialIndex,
    required this.source,
    required this.bookName,
    this.bookUrl,
    this.initialScrollProgress,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final SearchService _searchService = SearchService();
  final BookshelfService _bookshelfService = BookshelfService();
  final ReaderSettingsService _settingsService = ReaderSettingsService();
  final ChapterCacheService _cacheService = ChapterCacheService();
  final BookmarkService _bookmarkService = BookmarkService();
  final BatchDownloadService _downloadService = BatchDownloadService();
  final PageController _pageController = PageController();
  final SimulationPageTurnController _simulationController = SimulationPageTurnController();

  late int _currentIndex;
  final Map<int, String> _contentCache = {};
  final Map<int, bool> _loadingStates = {};
  final Map<int, ScrollController> _scrollControllers = {};

  bool _showControls = true;
  ReaderSettings _settings = const ReaderSettings();

  // 书签相关
  List<Bookmark> _bookmarks = [];
  bool _hasBookmarkAtCurrentPosition = false;

  // 章节内阅读进度
  double _chapterProgress = 0.0; // 0.0 - 1.0

  // 延迟保存 Timer
  Timer? _saveProgressTimer;

  // 是否已恢复初始滚动位置
  bool _hasRestoredInitialProgress = false;

  // 下载相关
  final Map<int, DownloadStatus> _chapterDownloadStatus = {};
  final Set<int> _selectedChapters = {};
  bool _isSelectionMode = false;
  bool _isDownloading = false;
  BatchDownloadProgress? _downloadProgress;
  int _downloadedCount = 0;

  // 抽屉Tab索引：0=章节，1=书签
  int _drawerTabIndex = 0;

  // 底部设置栏显示状态
  bool _showSettingsBar = false;

  @override
  void initState() {
    super.initState();
    // 进入阅读器时全屏，隐藏系统状态栏和导航栏
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
    // 设置透明状态栏，让内容延伸到状态栏区域
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );

    _currentIndex = widget.initialIndex;
    _pageController.addListener(_onPageChanged);
    _initServices();
    _listenToDownloadProgress();

    // 预加载当前章节
    _loadChapter(_currentIndex);
    // 预加载下一章节
    if (_currentIndex + 1 < widget.chapters.length) {
      _loadChapter(_currentIndex + 1);
    }
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
    for (int i = 0; i < widget.chapters.length; i++) {
      final chapter = widget.chapters[i];
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

  Future<void> _initServices() async {
    await Future.wait([
      _settingsService.init(),
      _cacheService.init(),
    ]);
    if (mounted) {
      setState(() {
        _settings = _settingsService.settings;
      });
      // 加载书签
      await _loadBookmarks();
    }
  }

  /// 加载书签
  Future<void> _loadBookmarks() async {
    if (widget.bookUrl == null) return;

    final bookmarks = await _bookmarkService.getBookmarksForBook(widget.bookUrl!);
    if (mounted) {
      setState(() {
        _bookmarks = bookmarks;
      });
      _checkBookmarkAtCurrentPosition();
    }
  }

  /// 检查当前位置是否有书签
  Future<void> _checkBookmarkAtCurrentPosition() async {
    if (widget.bookUrl == null) return;

    final hasBookmark = await _bookmarkService.hasBookmarkAtPosition(
      widget.bookUrl!,
      _currentIndex,
      _chapterProgress,
    );
    if (mounted) {
      setState(() {
        _hasBookmarkAtCurrentPosition = hasBookmark;
      });
    }
  }

  @override
  void dispose() {
    _saveProgressTimer?.cancel();

    // 退出阅读器时恢复系统状态栏
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    // 退出时保存当前进度（章节 + 滚动位置）
    if (widget.bookUrl != null) {
      _bookshelfService.updateReadProgress(
        widget.bookUrl!,
        chapterIndex: _currentIndex,
        chapterName: widget.chapters[_currentIndex].name,
        scrollProgress: _chapterProgress,
      );
    }

    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    // 释放所有 ScrollController
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onPageChanged() {
    final newIndex = _pageController.page?.round() ?? _currentIndex;
    if (newIndex != _currentIndex) {
      setState(() {
        _currentIndex = newIndex;
        _chapterProgress = 0.0; // 切换章节时重置进度
      });

      // 预加载下一章节
      if (newIndex + 1 < widget.chapters.length &&
          !_contentCache.containsKey(newIndex + 1)) {
        _loadChapter(newIndex + 1);
      }

      // 更新阅读进度
      if (widget.bookUrl != null) {
        _bookshelfService.updateReadProgress(
          widget.bookUrl!,
          chapterIndex: newIndex,
          chapterName: widget.chapters[newIndex].name,
        );
      }

      // 检查新页面是否有书签
      _checkBookmarkAtCurrentPosition();
    }
  }

  /// 获取或创建章节的 ScrollController
  ScrollController _getScrollController(int index) {
    if (!_scrollControllers.containsKey(index)) {
      final controller = ScrollController();
      controller.addListener(() => _onScrollChanged(index, controller));
      _scrollControllers[index] = controller;
    }
    return _scrollControllers[index]!;
  }

  /// 滚动位置变化时更新进度
  void _onScrollChanged(int index, ScrollController controller) {
    if (index != _currentIndex) return;

    if (controller.hasClients) {
      final maxScroll = controller.position.maxScrollExtent;
      final currentScroll = controller.offset;

      if (maxScroll > 0) {
        final progress = (currentScroll / maxScroll).clamp(0.0, 1.0);
        if ((progress - _chapterProgress).abs() > 0.01) {
          setState(() => _chapterProgress = progress);
          _scheduleProgressSave();
          // 检查当前位置是否有书签
          _checkBookmarkAtCurrentPosition();
        }
      }
    }
  }

  /// 延迟保存进度（滚动停止 2 秒后保存）
  void _scheduleProgressSave() {
    _saveProgressTimer?.cancel();
    _saveProgressTimer = Timer(const Duration(seconds: 2), () {
      if (widget.bookUrl != null && mounted) {
        _bookshelfService.updateReadProgress(
          widget.bookUrl!,
          chapterIndex: _currentIndex,
          chapterName: widget.chapters[_currentIndex].name,
          scrollProgress: _chapterProgress,
        );
        print('已保存阅读进度: 章节 $_currentIndex, 进度 ${(_chapterProgress * 100).toInt()}%');
      }
    });
  }

  /// 恢复滚动位置
  void _restoreScrollPosition(int index, double progress) {
    final controller = _scrollControllers[index];
    if (controller != null && controller.hasClients) {
      final maxScroll = controller.position.maxScrollExtent;
      final targetScroll = (maxScroll * progress).clamp(0.0, maxScroll);
      controller.jumpTo(targetScroll);
      setState(() => _chapterProgress = progress);
      print('已恢复滚动位置: ${(progress * 100).toInt()}%');
    }
  }

  Future<void> _loadChapter(int index) async {
    if (_loadingStates[index] == true) return;
    if (_contentCache.containsKey(index)) return;

    setState(() => _loadingStates[index] = true);

    final chapterUrl = widget.chapters[index].url;

    try {
      // 先尝试从缓存读取
      String? content = await _cacheService.getCache(chapterUrl);

      if (content != null) {
        print('从缓存加载章节: ${widget.chapters[index].name}');
      } else {
        // 缓存不存在，从网络加载
        print('从网络加载章节: ${widget.chapters[index].name}');
        final result = await _searchService.getChapterContent(
          chapterUrl,
          widget.source,
        );
        content = result.content;

        // 保存到缓存
        await _cacheService.saveCache(
          chapterUrl,
          content,
          bookName: widget.bookName,
        );
      }

      if (mounted) {
        setState(() {
          _contentCache[index] = content!;
          _loadingStates[index] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _contentCache[index] = '加载失败：$e';
          _loadingStates[index] = false;
        });
      }
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _goToChapter(int index) {
    if (index < 0 || index >= widget.chapters.length) return;

    // 根据翻页模式选择不同的跳转方式
    switch (_settings.pageTurnMode) {
      case PageTurnMode.simulation:
        _simulationController.animateToPage(index);
        break;
      case PageTurnMode.scroll:
        // 滚动模式使用 ListView，不支持直接跳转
        break;
      default:
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
    }
  }

  /// 构建内容视图 - 根据翻页模式选择不同的实现
  Widget _buildContentView() {
    switch (_settings.pageTurnMode) {
      case PageTurnMode.simulation:
        return _buildSimulationView();
      case PageTurnMode.cover:
        return _buildCoverView();
      case PageTurnMode.scroll:
        return _buildScrollView();
      case PageTurnMode.slide:
      default:
        return _buildSlideView();
    }
  }

  /// 滑动翻页视图（默认 PageView）
  Widget _buildSlideView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.chapters.length,
      itemBuilder: (context, index) {
        return _buildChapterPage(index);
      },
    );
  }

  /// 覆盖翻页视图
  Widget _buildCoverView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.chapters.length,
      pageSnapping: true,
      physics: const PageScrollPhysics(),
      itemBuilder: (context, index) {
        return _buildChapterPage(index);
      },
    );
  }

  /// 滚动翻页视图
  Widget _buildScrollView() {
    return ListView.builder(
      itemCount: widget.chapters.length,
      itemBuilder: (context, index) {
        // 滚动模式下，章节直接垂直排列
        final content = _contentCache[index];
        if (content == null) {
          // 触发加载
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadChapter(index);
          });
        }
        return _buildScrollableChapterPage(index);
      },
    );
  }

  /// 仿真翻页视图
  Widget _buildSimulationView() {
    return SimulationPageTurn(
      controller: _simulationController,
      itemCount: widget.chapters.length,
      backgroundColor: _settings.theme.backgroundColor,
      onPageChanged: (index) {
        if (index != _currentIndex) {
          setState(() {
            _currentIndex = index;
            _chapterProgress = 0.0;
          });

          // 预加载下一章节
          if (index + 1 < widget.chapters.length &&
              !_contentCache.containsKey(index + 1)) {
            _loadChapter(index + 1);
          }

          // 更新阅读进度
          if (widget.bookUrl != null) {
            _bookshelfService.updateReadProgress(
              widget.bookUrl!,
              chapterIndex: index,
              chapterName: widget.chapters[index].name,
            );
          }
        }
      },
      itemBuilder: (context, index) {
        return _buildChapterPage(index);
      },
    );
  }

  /// 构建可滚动章节页面（用于滚动翻页模式）
  Widget _buildScrollableChapterPage(int index) {
    final isLoading = _loadingStates[index] == true;
    final content = _contentCache[index];
    final theme = _settings.theme;

    if (isLoading && content == null) {
      return Container(
        height: MediaQuery.of(context).size.height,
        color: theme.backgroundColor,
        child: Center(
          child: CircularProgressIndicator(color: theme.textColor),
        ),
      );
    }

    if (content == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadChapter(index);
      });
      return Container(
        height: MediaQuery.of(context).size.height,
        color: theme.backgroundColor,
        child: Center(
          child: CircularProgressIndicator(color: theme.textColor),
        ),
      );
    }

    final chapterName = widget.chapters[index].name;
    final filteredContent = _filterChapterName(content, chapterName);

    return Container(
      color: theme.backgroundColor,
      padding: EdgeInsets.symmetric(
        vertical: _settings.verticalPadding,
        horizontal: _settings.horizontalPadding,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_settings.showChapterTitle) ...[
              Center(
                child: Text(
                  chapterName,
                  style: TextStyle(
                    fontSize: _settings.fontSize + 4,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: _settings.lineHeight * 8),
              Divider(color: theme.textColor.withOpacity(0.2), height: 1),
              SizedBox(height: _settings.lineHeight * 12),
            ],
            _buildContentText(filteredContent, theme),
            const SizedBox(height: 48),
            // 章节分隔
            Container(
              height: 40,
              alignment: Alignment.center,
              child: Divider(
                color: theme.textColor.withOpacity(0.3),
                thickness: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: _settings.theme.backgroundColor,
        body: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            children: [
              // 内容区域 - 根据翻页模式选择不同的实现
              _buildContentView(),

              // 顶部控制栏（透明，只显示更多按钮）
              if (_showControls)
                Positioned(
                  top: 0,
                  right: 0,
                  child: SafeArea(
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                      color: Colors.black87,
                      onSelected: (value) {
                        if (value == 'add_bookmark') {
                          _toggleBookmark();
                        } else if (value == 'directory') {
                          _showChapterList();
                        } else if (value == 'back') {
                          Navigator.pop(context);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'directory',
                          child: ListTile(
                            leading: const Icon(Icons.list),
                            title: const Text('目录'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'add_bookmark',
                          child: ListTile(
                            leading: Icon(
                              _hasBookmarkAtCurrentPosition
                                  ? Icons.bookmark
                                  : Icons.bookmark_add,
                            ),
                            title: Text(
                              _hasBookmarkAtCurrentPosition ? '移除书签' : '添加书签',
                            ),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'back',
                          child: ListTile(
                            leading: Icon(Icons.arrow_back),
                            title: Text('返回'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 底部控制栏（透明，点击设置图标展开详细设置）
              if (_showControls)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.black45,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // 目录按钮
                          IconButton(
                            icon: const Icon(Icons.list, color: Colors.white70),
                            onPressed: () => _showChapterList(),
                          ),
                          // 字体大小调节
                          _buildBottomSettingItem(
                            icon: Icons.text_fields,
                            value: _settings.fontSize.round().toString(),
                            onTap: () => _showFontSizeDialog(),
                          ),
                          // 翻页模式
                          _buildBottomSettingItem(
                            icon: Icons.menu_book,
                            value: _settings.pageTurnMode.displayName,
                            onTap: () => _showPageTurnModeDialog(),
                          ),
                          // 设置按钮（展开详细设置）
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.white70),
                            onPressed: () => _showDetailedSettings(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 详细设置面板（向上滑出）
              if (_showSettingsBar)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      color: Colors.black87,
                      child: _buildSettingsBarContent(),
                    ),
                  ),
                ),

              // 阅读进度百分比（右下角，仅当控制栏和设置栏都不显示时）
              if (!_showControls && !_showSettingsBar)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${(_chapterProgress * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建底部设置项
  Widget _buildBottomSettingItem({
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// 显示字号调节对话框
  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          title: const Text('字体大小', style: TextStyle(color: Colors.white)),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Row(
                children: [
                  const Text('A', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  Expanded(
                    child: Slider(
                      value: _settings.fontSize,
                      min: 12,
                      max: 32,
                      divisions: 20,
                      label: _settings.fontSize.round().toString(),
                      onChanged: (v) => _updateSettings(fontSize: v),
                    ),
                  ),
                  const Text('A', style: TextStyle(color: Colors.white70, fontSize: 22)),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  /// 显示翻页模式选择对话框
  void _showPageTurnModeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          title: const Text('翻页模式', style: TextStyle(color: Colors.white)),
          content: Wrap(
            spacing: 8,
            children: PageTurnMode.values.map((mode) {
              final isSelected = mode == _settings.pageTurnMode;
              return GestureDetector(
                onTap: () {
                  _updateSettings(pageTurnModeIndex: mode.index);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white24 : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    mode.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  /// 显示详细设置面板
  void _showDetailedSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '详细设置',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 16),
                  // 行间距
                  Row(
                    children: [
                      const Expanded(
                        child: Text('行间距', style: TextStyle(color: Colors.white70)),
                      ),
                      Expanded(
                        child: Slider(
                          value: _settings.lineHeight,
                          min: 1.2,
                          max: 3.0,
                          divisions: 18,
                          label: _settings.lineHeight.toStringAsFixed(1),
                          onChanged: (v) => _updateSettings(lineHeight: v),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          _settings.lineHeight.toStringAsFixed(1),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 段间距
                  Row(
                    children: [
                      const Expanded(
                        child: Text('段间距', style: TextStyle(color: Colors.white70)),
                      ),
                      Expanded(
                        child: Slider(
                          value: _settings.paragraphSpacing,
                          min: 0,
                          max: 24,
                          divisions: 24,
                          label: _settings.paragraphSpacing.round().toString(),
                          onChanged: (v) => _updateSettings(paragraphSpacing: v),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          _settings.paragraphSpacing.round().toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 首行缩进
                  Row(
                    children: [
                      const Expanded(
                        child: Text('首行缩进', style: TextStyle(color: Colors.white70)),
                      ),
                      Expanded(
                        child: Slider(
                          value: _settings.indentSize,
                          min: 0,
                          max: 4,
                          divisions: 4,
                          label: _settings.indentSize.round().toString(),
                          onChanged: (v) => _updateSettings(indentSize: v),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          _settings.indentSize.round().toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 主题选择
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('阅读主题', style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: ReaderSettings.themes.length,
                      itemBuilder: (context, index) {
                        final theme = ReaderSettings.themes[index];
                        final isSelected = index == _settings.themeIndex;
                        return GestureDetector(
                          onTap: () => _updateSettings(themeIndex: index),
                          child: Container(
                            width: 50,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: theme.backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.white24,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '文',
                                style: TextStyle(color: theme.textColor),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChapterPage(int index) {
    final isLoading = _loadingStates[index] == true;
    final content = _contentCache[index];
    final theme = _settings.theme;

    if (isLoading && content == null) {
      return Container(
        color: theme.backgroundColor,
        child: Center(
          child: CircularProgressIndicator(
            color: theme.textColor,
          ),
        ),
      );
    }

    if (content == null) {
      // 触发加载
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadChapter(index);
      });
      return Container(
        color: theme.backgroundColor,
        child: Center(
          child: CircularProgressIndicator(
            color: theme.textColor,
          ),
        ),
      );
    }

    // 恢复初始滚动位置（仅首次加载当前章节时）
    if (index == widget.initialIndex &&
        !_hasRestoredInitialProgress &&
        widget.initialScrollProgress != null &&
        widget.initialScrollProgress! > 0) {
      _hasRestoredInitialProgress = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreScrollPosition(index, widget.initialScrollProgress!);
      });
    }

    // 过滤内容中可能包含的章节名称
    final chapterName = widget.chapters[index].name;
    final filteredContent = _filterChapterName(content, chapterName);

    return Container(
      color: theme.backgroundColor,
      padding: EdgeInsets.symmetric(
        vertical: _settings.verticalPadding,
        horizontal: _settings.horizontalPadding,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          controller: _getScrollController(index),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 章节标题
              if (_settings.showChapterTitle) ...[
                Center(
                  child: Text(
                    chapterName,
                    style: TextStyle(
                      fontSize: _settings.fontSize + 4,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: _settings.lineHeight * 8),
                // 分隔线
                Divider(
                  color: theme.textColor.withOpacity(0.2),
                  height: 1,
                ),
                SizedBox(height: _settings.lineHeight * 12),
              ],
              // 章节内容（按段落渲染）
              _buildContentText(filteredContent, theme),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  /// 过滤内容开头的章节名称
  String _filterChapterName(String content, String chapterName) {
    // 移除开头可能的章节名称
    if (content.startsWith(chapterName)) {
      content = content.substring(chapterName.length).trim();
    }
    // 移除开头可能的换行符
    while (content.startsWith('\n')) {
      content = content.substring(1);
    }
    return content;
  }

  /// 构建正文内容（支持文本和图片）
  Widget _buildContentText(String content, ReaderTheme theme) {
    return ContentWithImages(
      content: content,
      textStyle: TextStyle(
        fontSize: _settings.fontSize,
        height: _settings.lineHeight,
        color: theme.textColor,
      ),
      paragraphSpacing: _settings.paragraphSpacing,
      indentSize: _settings.indentSize,
      referer: widget.source.bookSourceUrl, // 添加防盗链 Referer
      onImageTap: (imageUrl) => _showImagePreview(imageUrl),
    );
  }

  /// 显示图片预览
  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 图片查看器
            GestureDetector(
              onTap: () => Navigator.pop(context),
              onVerticalDragEnd: (details) {
                // 下滑关闭
                if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
                  Navigator.pop(context);
                }
              },
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    httpHeaders: {
                      'Referer': widget.source.bookSourceUrl,
                    },
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '图片加载失败',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 关闭按钮
            Positioned(
              top: 40,
              right: 16,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 添加首行缩进
  String _addIndent(String paragraph) {
    // 如果已经有缩进（全角空格开头），不再添加
    if (_settings.indentSize <= 0) {
      return paragraph;
    }
    // 检查是否已经有缩进
    if (paragraph.startsWith('　') || paragraph.startsWith(' ')) {
      return paragraph;
    }
    // 添加全角空格作为缩进
    final indent = '　' * _settings.indentSize.toInt();
    return indent + paragraph;
  }

  void _showChapterList() {
    // 刷新下载状态
    _refreshDownloadStatus();

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Material(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    // 左侧抽屉
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () {}, // 阻止点击穿透
                        child: Container(
                          width: 320,
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(2, 0),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // 标题栏 - 铺满顶部
                              Container(
                                padding: EdgeInsets.only(
                                  top: MediaQuery.of(context).padding.top + 12,
                                  left: 16,
                                  right: 16,
                                  bottom: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.bookName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              ),
                              // Tab切换栏
                              Container(
                                color: Theme.of(context).primaryColor,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => setDialogState(() => _drawerTabIndex = 0),
                                        child: Text(
                                          '章节',
                                          style: TextStyle(
                                            color: _drawerTabIndex == 0
                                                ? Colors.white
                                                : Colors.white70,
                                            fontWeight: _drawerTabIndex == 0
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => setDialogState(() => _drawerTabIndex = 1),
                                        child: Text(
                                          '书签',
                                          style: TextStyle(
                                            color: _drawerTabIndex == 1
                                                ? Colors.white
                                                : Colors.white70,
                                            fontWeight: _drawerTabIndex == 1
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 顶部操作区（仅章节Tab显示）
                              if (_drawerTabIndex == 0)
                                _buildDrawerTopActions(setDialogState),
                              // 内容区域（章节或书签）
                              Expanded(
                                child: _drawerTabIndex == 0
                                    ? (_isSelectionMode
                                        ? _buildSelectionChapterList(setDialogState)
                                        : _buildNormalChapterList())
                                    : _buildBookmarkListInDrawer(setDialogState),
                              ),
                              // 底部操作栏（仅章节Tab的多选模式）
                              if (_drawerTabIndex == 0 && _isSelectionMode)
                                _buildDrawerBottomActions(setDialogState),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 抽屉顶部操作区
  Widget _buildDrawerTopActions(StateSetter setDialogState) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          if (_isSelectionMode) ...[
            // 多选模式标题
            Expanded(
              child: Text(
                _isDownloading
                    ? '下载中 ${_downloadProgress?.progressText ?? ""}'
                    : '已选 ${_selectedChapters.length} 章',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: _isDownloading
                  ? null
                  : () {
                      setDialogState(() {
                        if (_selectedChapters.length == widget.chapters.length) {
                          _selectedChapters.clear();
                        } else {
                          _selectedChapters.clear();
                          _selectedChapters.addAll(
                            List.generate(widget.chapters.length, (i) => i),
                          );
                        }
                      });
                    },
              child: Text(
                _selectedChapters.length == widget.chapters.length ? '取消全选' : '全选',
              ),
            ),
            TextButton(
              onPressed: () {
                setDialogState(() {
                  _isSelectionMode = false;
                  _selectedChapters.clear();
                });
              },
              child: const Text('取消'),
            ),
          ] else ...[
            // 普通模式
            Expanded(
              child: ElevatedButton.icon(
                icon: _isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download, size: 18),
                label: Text(_isDownloading ? '下载中...' : '批量下载'),
                onPressed: _isDownloading
                    ? null
                    : () {
                        setDialogState(() {
                          _isSelectionMode = true;
                          _selectedChapters.clear();
                        });
                      },
              ),
            ),
            if (_downloadedCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.offline_pin, size: 14, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text(
                      '$_downloadedCount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// 普通模式章节列表
  Widget _buildNormalChapterList() {
    return ListView.builder(
      itemCount: widget.chapters.length,
      itemBuilder: (context, index) {
        final isSelected = index == _currentIndex;
        final downloadStatus = _chapterDownloadStatus[index] ??
            DownloadStatus.notDownloaded;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  widget.chapters[index].name,
                  style: TextStyle(
                    color: isSelected ? Theme.of(context).primaryColor : null,
                    fontWeight: isSelected ? FontWeight.bold : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildDownloadStatusIcon(downloadStatus),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.play_circle_fill,
                  size: 18,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ],
          ),
          onTap: () {
            Navigator.pop(context);
            _goToChapter(index);
          },
        );
      },
    );
  }

  /// 多选模式章节列表
  Widget _buildSelectionChapterList(StateSetter setDialogState) {
    return ListView.builder(
      itemCount: widget.chapters.length,
      itemBuilder: (context, index) {
        final isSelected = _selectedChapters.contains(index);
        final downloadStatus = _chapterDownloadStatus[index] ??
            DownloadStatus.notDownloaded;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Checkbox(
            value: isSelected,
            onChanged: _isDownloading
                ? null
                : (value) {
                    setDialogState(() {
                      if (value == true) {
                        _selectedChapters.add(index);
                      } else {
                        _selectedChapters.remove(index);
                      }
                    });
                  },
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  widget.chapters[index].name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildDownloadStatusIcon(downloadStatus),
            ],
          ),
          onTap: _isDownloading
              ? null
              : () {
                  setDialogState(() {
                    if (_selectedChapters.contains(index)) {
                      _selectedChapters.remove(index);
                    } else {
                      _selectedChapters.add(index);
                    }
                  });
                },
        );
      },
    );
  }

  /// 抽屉底部操作栏
  Widget _buildDrawerBottomActions(StateSetter setDialogState) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: _isDownloading
          ? _buildDownloadProgressBar()
          : Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download, size: 18),
                    label: Text('下载选中 (${_selectedChapters.length})'),
                    onPressed: _selectedChapters.isEmpty
                        ? null
                        : () => _startDownload(setDialogState),
                  ),
                ),
              ],
            ),
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
            const SizedBox(width: 12),
            Text(
              progress?.progressText ?? '0 / 0',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            _downloadService.cancelDownload();
            setState(() {
              _isDownloading = false;
            });
          },
          child: const Text('取消下载'),
        ),
      ],
    );
  }

  /// 开始下载
  Future<void> _startDownload(StateSetter setDialogState) async {
    if (_selectedChapters.isEmpty) return;

    final selectedChapters =
        _selectedChapters.map((i) => widget.chapters[i]).toList();

    // 开始后台下载
    setDialogState(() {
      _isDownloading = true;
    });

    try {
      await _downloadService.startBatchDownload(
        selectedChapters,
        widget.source,
        widget.bookUrl ?? '',
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
        setDialogState(() {
          _isSelectionMode = false;
          _selectedChapters.clear();
          _isDownloading = false;
        });
        _refreshDownloadStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：$e')),
        );
        setDialogState(() {
          _isDownloading = false;
        });
      }
    }
  }

  /// 构建下载状态图标
  Widget _buildDownloadStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.downloaded:
        return const Icon(
          Icons.offline_pin,
          size: 16,
          color: Colors.green,
        );
      case DownloadStatus.downloading:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case DownloadStatus.failed:
        return const Icon(
          Icons.error_outline,
          size: 16,
          color: Colors.red,
        );
      case DownloadStatus.notDownloaded:
        return Icon(
          Icons.cloud_off_outlined,
          size: 16,
          color: Colors.grey[400],
        );
    }
  }

  /// 切换书签
  Future<void> _toggleBookmark() async {
    if (widget.bookUrl == null) return;

    final bookmark = Bookmark(
      bookUrl: widget.bookUrl!,
      bookName: widget.bookName,
      chapterIndex: _currentIndex,
      chapterName: widget.chapters[_currentIndex].name,
      scrollPosition: _chapterProgress,
      createdAt: DateTime.now(),
    );

    if (_hasBookmarkAtCurrentPosition) {
      // 删除书签
      await _bookmarkService.removeBookmark(bookmark);
      if (mounted) {
        setState(() {
          _hasBookmarkAtCurrentPosition = false;
          _bookmarks.removeWhere((b) => b.uniqueKey == bookmark.uniqueKey);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('书签已移除')),
        );
      }
    } else {
      // 添加书签（可选输入备注）
      final note = await _showAddBookmarkDialog();
      if (note == null) return; // 用户取消

      final newBookmark = bookmark.copyWith(note: note.isEmpty ? null : note);
      await _bookmarkService.addBookmark(newBookmark);
      if (mounted) {
        setState(() {
          _hasBookmarkAtCurrentPosition = true;
          _bookmarks.insert(0, newBookmark);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('书签已添加')),
        );
      }
    }
  }

  /// 显示添加书签对话框（输入备注）
  Future<String?> _showAddBookmarkDialog() async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加书签'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '添加备注（可选）',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  /// 跳转到书签位置
  void _goToBookmark(Bookmark bookmark) {
    // 跳转到对应章节
    _goToChapter(bookmark.chapterIndex);

    // 延迟恢复滚动位置
    Future.delayed(const Duration(milliseconds: 300), () {
      _restoreScrollPosition(bookmark.chapterIndex, bookmark.scrollPosition);
    });
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return '刚刚';
        }
        return '${difference.inMinutes}分钟前';
      }
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  /// 切换底部设置栏显示
  void _toggleSettingsBar() {
    setState(() {
      _showSettingsBar = !_showSettingsBar;
    });
  }

  /// 构建底部设置栏内容
  Widget _buildSettingsBarContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 关闭按钮行
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => _toggleSettingsBar(),
              ),
            ],
          ),
          // 字体大小
          _buildSettingRow(
            label: '字体',
            value: _settings.fontSize.round().toString(),
            slider: Slider(
              value: _settings.fontSize,
              min: 12,
              max: 32,
              divisions: 20,
              label: _settings.fontSize.round().toString(),
              onChanged: (v) => _updateSettings(fontSize: v),
            ),
          ),
          // 行间距
          _buildSettingRow(
            label: '行距',
            value: _settings.lineHeight.toStringAsFixed(1),
            slider: Slider(
              value: _settings.lineHeight,
              min: 1.2,
              max: 3.0,
              divisions: 18,
              label: _settings.lineHeight.toStringAsFixed(1),
              onChanged: (v) => _updateSettings(lineHeight: v),
            ),
          ),
          // 段间距
          _buildSettingRow(
            label: '段距',
            value: _settings.paragraphSpacing.round().toString(),
            slider: Slider(
              value: _settings.paragraphSpacing,
              min: 0,
              max: 24,
              divisions: 24,
              label: _settings.paragraphSpacing.round().toString(),
              onChanged: (v) => _updateSettings(paragraphSpacing: v),
            ),
          ),
          // 首行缩进
          _buildSettingRow(
            label: '缩进',
            value: _settings.indentSize.round().toString(),
            slider: Slider(
              value: _settings.indentSize,
              min: 0,
              max: 4,
              divisions: 4,
              label: _settings.indentSize.round().toString(),
              onChanged: (v) => _updateSettings(indentSize: v),
            ),
          ),
          // 翻页模式
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('翻页模式', style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: PageTurnMode.values.map((mode) {
              final isSelected = mode == _settings.pageTurnMode;
              return GestureDetector(
                onTap: () => _updateSettings(pageTurnModeIndex: mode.index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    mode.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          // 主题选择
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('阅读主题', style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ReaderSettings.themes.length,
              itemBuilder: (context, index) {
                final theme = ReaderSettings.themes[index];
                final isSelected = index == _settings.themeIndex;
                return GestureDetector(
                  onTap: () => _updateSettings(themeIndex: index),
                  child: Container(
                    width: 50,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.white24,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '文',
                        style: TextStyle(color: theme.textColor),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 构建设置行
  Widget _buildSettingRow({
    required String label,
    required String value,
    required Widget slider,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        Expanded(child: slider),
        SizedBox(
          width: 40,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  /// 更新设置
  void _updateSettings({
    double? fontSize,
    double? lineHeight,
    double? paragraphSpacing,
    double? indentSize,
    int? pageTurnModeIndex,
    int? themeIndex,
  }) {
    setState(() {
      _settings = _settings.copyWith(
        fontSize: fontSize,
        lineHeight: lineHeight,
        paragraphSpacing: paragraphSpacing,
        indentSize: indentSize,
        pageTurnModeIndex: pageTurnModeIndex,
        themeIndex: themeIndex,
      );
    });
    _settingsService.saveSettings(_settings);
  }

  /// 构建抽屉中的书签列表
  Widget _buildBookmarkListInDrawer(StateSetter setDialogState) {
    if (_bookmarks.isEmpty) {
      return const Center(
        child: Text(
          '暂无书签',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = _bookmarks[index];
        final isCurrentPosition = bookmark.chapterIndex == _currentIndex &&
            (bookmark.scrollPosition - _chapterProgress).abs() < 0.01;

        return ListTile(
          leading: Icon(
            Icons.bookmark,
            color: isCurrentPosition ? Theme.of(context).primaryColor : null,
          ),
          title: Text(
            bookmark.chapterName,
            style: TextStyle(
              fontWeight: isCurrentPosition ? FontWeight.bold : null,
              color: isCurrentPosition ? Theme.of(context).primaryColor : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('进度: ${(bookmark.scrollPosition * 100).toInt()}%'),
              if (bookmark.note != null && bookmark.note!.isNotEmpty)
                Text(
                  '备注: ${bookmark.note}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              Text(
                _formatDateTime(bookmark.createdAt),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await _bookmarkService.removeBookmark(bookmark);
              setDialogState(() {
                _bookmarks.removeAt(index);
              });
              _checkBookmarkAtCurrentPosition();
            },
          ),
          onTap: () {
            Navigator.pop(context);
            _goToBookmark(bookmark);
          },
        );
      },
    );
  }


  /// 构建底部设置项
  
}
