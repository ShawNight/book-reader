import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/book_source.dart';
import '../models/bookmark.dart';
import '../models/reader_settings.dart';
import '../services/search_service.dart';
import '../services/bookshelf_service.dart';
import '../services/reader_settings_service.dart';
import '../services/chapter_cache_service.dart';
import '../services/bookmark_service.dart';
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController.addListener(_onPageChanged);
    _initServices();

    // 预加载当前章节
    _loadChapter(_currentIndex);
    // 预加载下一章节
    if (_currentIndex + 1 < widget.chapters.length) {
      _loadChapter(_currentIndex + 1);
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
    return Scaffold(
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // 内容区域 - 根据翻页模式选择不同的实现
            _buildContentView(),

            // 顶部控制栏
            if (_showControls) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppBar(
                  backgroundColor: Colors.black54,
                  title: Text(
                    widget.bookName,
                    style: const TextStyle(fontSize: 16),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _hasBookmarkAtCurrentPosition
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                      ),
                      tooltip: _hasBookmarkAtCurrentPosition ? '移除书签' : '添加书签',
                      onPressed: () => _toggleBookmark(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.list_alt),
                      tooltip: '书签列表',
                      onPressed: () => _showBookmarkList(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () => _showSettingsPanel(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.list),
                      onPressed: () => _showChapterList(),
                    ),
                  ],
                ),
              ),

              // 底部控制栏
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 章节进度条
                        Row(
                          children: [
                            Text(
                              '${(_chapterProgress * 100).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: _chapterProgress,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_currentIndex + 1}/${widget.chapters.length}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _currentIndex > 0
                                    ? () => _goToChapter(_currentIndex - 1)
                                    : null,
                                child: const Text('上一章'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _currentIndex + 1 <
                                        widget.chapters.length
                                    ? () => _goToChapter(_currentIndex + 1)
                                    : null,
                                child: const Text('下一章'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '章节列表',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.chapters.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _currentIndex;
                    return ListTile(
                      title: Text(
                        widget.chapters[index].name,
                        style: TextStyle(
                          color: isSelected ? Theme.of(context).primaryColor : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).primaryColor,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        _goToChapter(index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 显示阅读设置面板
  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '阅读设置',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),

                  // 字体大小调节
                  Row(
                    children: [
                      const Text('字体大小'),
                      const SizedBox(width: 16),
                      const Text('A', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Slider(
                          value: _settings.fontSize,
                          min: 12,
                          max: 32,
                          divisions: 20,
                          label: _settings.fontSize.round().toString(),
                          onChanged: (value) {
                            setModalState(() {
                              _settings = _settings.copyWith(fontSize: value);
                            });
                            setState(() {});
                            _settingsService.saveSettings(_settings);
                          },
                        ),
                      ),
                      const Text('A', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          _settings.fontSize.round().toString(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 行间距调节
                  Row(
                    children: [
                      const Text('行间距'),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Slider(
                          value: _settings.lineHeight,
                          min: 1.2,
                          max: 3.0,
                          divisions: 18,
                          label: _settings.lineHeight.toStringAsFixed(1),
                          onChanged: (value) {
                            setModalState(() {
                              _settings = _settings.copyWith(lineHeight: value);
                            });
                            setState(() {});
                            _settingsService.saveSettings(_settings);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          _settings.lineHeight.toStringAsFixed(1),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 段间距调节
                  Row(
                    children: [
                      const Text('段间距'),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Slider(
                          value: _settings.paragraphSpacing,
                          min: 0,
                          max: 24,
                          divisions: 24,
                          label: _settings.paragraphSpacing.round().toString(),
                          onChanged: (value) {
                            setModalState(() {
                              _settings = _settings.copyWith(paragraphSpacing: value);
                            });
                            setState(() {});
                            _settingsService.saveSettings(_settings);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          _settings.paragraphSpacing.round().toString(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 首行缩进调节
                  Row(
                    children: [
                      const Text('首行缩进'),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Slider(
                          value: _settings.indentSize,
                          min: 0,
                          max: 4,
                          divisions: 4,
                          label: _settings.indentSize.round().toString(),
                          onChanged: (value) {
                            setModalState(() {
                              _settings = _settings.copyWith(indentSize: value);
                            });
                            setState(() {});
                            _settingsService.saveSettings(_settings);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          _settings.indentSize.round().toString(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 章节标题显示开关
                  Row(
                    children: [
                      const Text('显示章节标题'),
                      const Spacer(),
                      Switch(
                        value: _settings.showChapterTitle,
                        onChanged: (value) {
                          setModalState(() {
                            _settings = _settings.copyWith(showChapterTitle: value);
                          });
                          setState(() {});
                          _settingsService.saveSettings(_settings);
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 翻页模式选择
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('翻页模式'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PageTurnMode.values.map((mode) {
                      final isSelected = mode == _settings.pageTurnMode;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            _settings = _settings.copyWith(
                              pageTurnModeIndex: mode.index,
                            );
                          });
                          setState(() {});
                          _settingsService.saveSettings(_settings);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            mode.displayName,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // 主题选择
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('阅读主题'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: ReaderSettings.themes.length,
                      itemBuilder: (context, index) {
                        final theme = ReaderSettings.themes[index];
                        final isSelected = index == _settings.themeIndex;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              _settings = _settings.copyWith(themeIndex: index);
                            });
                            setState(() {});
                            _settingsService.saveSettings(_settings);
                          },
                          child: Container(
                            width: 60,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: theme.backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey.shade300,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '文',
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  theme.name,
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
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

  /// 显示书签列表
  void _showBookmarkList() {
    if (_bookmarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无书签')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '书签列表 (${_bookmarks.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
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
                          if (mounted) {
                            setState(() {
                              _bookmarks.removeAt(index);
                            });
                            // 更新当前位置书签状态
                            _checkBookmarkAtCurrentPosition();
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('书签已删除')),
                            );
                          }
                        },
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _goToBookmark(bookmark);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
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
}
