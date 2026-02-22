import 'package:flutter/material.dart';

import '../models/book_source.dart';
import '../models/reader_settings.dart';
import '../services/search_service.dart';
import '../services/bookshelf_service.dart';
import '../services/reader_settings_service.dart';

/// 阅读页面
class ReaderScreen extends StatefulWidget {
  final List<Chapter> chapters;
  final int initialIndex;
  final BookSource source;
  final String bookName;
  final String? bookUrl;

  const ReaderScreen({
    super.key,
    required this.chapters,
    required this.initialIndex,
    required this.source,
    required this.bookName,
    this.bookUrl,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final SearchService _searchService = SearchService();
  final BookshelfService _bookshelfService = BookshelfService();
  final ReaderSettingsService _settingsService = ReaderSettingsService();
  final PageController _pageController = PageController();

  late int _currentIndex;
  final Map<int, String> _contentCache = {};
  final Map<int, bool> _loadingStates = {};
  final Map<int, ScrollController> _scrollControllers = {};

  bool _showControls = true;
  ReaderSettings _settings = const ReaderSettings();

  // 章节内阅读进度
  double _chapterProgress = 0.0; // 0.0 - 1.0

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController.addListener(_onPageChanged);
    _loadSettings();

    // 预加载当前章节
    _loadChapter(_currentIndex);
    // 预加载下一章节
    if (_currentIndex + 1 < widget.chapters.length) {
      _loadChapter(_currentIndex + 1);
    }
  }

  Future<void> _loadSettings() async {
    await _settingsService.init();
    if (mounted) {
      setState(() {
        _settings = _settingsService.settings;
      });
    }
  }

  @override
  void dispose() {
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
        }
      }
    }
  }

  Future<void> _loadChapter(int index) async {
    if (_loadingStates[index] == true) return;
    if (_contentCache.containsKey(index)) return;

    setState(() => _loadingStates[index] = true);

    try {
      final content = await _searchService.getChapterContent(
        widget.chapters[index].url,
        widget.source,
      );

      if (mounted) {
        setState(() {
          _contentCache[index] = content.content;
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

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // 内容区域
            PageView.builder(
              controller: _pageController,
              itemCount: widget.chapters.length,
              itemBuilder: (context, index) {
                return _buildChapterPage(index);
              },
            ),

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
              Text(
                widget.chapters[index].name,
                style: TextStyle(
                  fontSize: _settings.fontSize + 2,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              SizedBox(height: _settings.lineHeight * 10),
              // 章节内容
              Text(
                content,
                style: TextStyle(
                  fontSize: _settings.fontSize,
                  height: _settings.lineHeight,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
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
}
