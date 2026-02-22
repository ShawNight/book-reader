import 'package:flutter/material.dart';

import '../models/book_source.dart';
import '../services/search_service.dart';
import '../services/bookshelf_service.dart';

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
  final PageController _pageController = PageController();

  late int _currentIndex;
  final Map<int, String> _contentCache = {};
  final Map<int, bool> _loadingStates = {};

  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController.addListener(_onPageChanged);

    // 预加载当前章节
    _loadChapter(_currentIndex);
    // 预加载下一章节
    if (_currentIndex + 1 < widget.chapters.length) {
      _loadChapter(_currentIndex + 1);
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final newIndex = _pageController.page?.round() ?? _currentIndex;
    if (newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);

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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_currentIndex + 1} / ${widget.chapters.length}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            Text(
                              widget.chapters[_currentIndex].name,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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

    if (isLoading && content == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (content == null) {
      // 触发加载
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadChapter(index);
      });
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Container(
      color: const Color(0xFFF5F5DC), // 米黄色背景
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 章节标题
              Text(
                widget.chapters[index].name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // 章节内容
              Text(
                content,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.8,
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
}
