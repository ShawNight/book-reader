import 'package:flutter/material.dart';

import '../models/book_source.dart';
import '../models/book.dart';
import '../services/search_service.dart';
import '../services/bookshelf_service.dart';
import 'reader_screen.dart';

/// 章节列表页面
class ChapterListScreen extends StatefulWidget {
  final String bookUrl;
  final String bookName;
  final BookSource source;
  final String? coverUrl;
  final String? intro;
  final String? latestChapter;

  const ChapterListScreen({
    super.key,
    required this.bookUrl,
    required this.bookName,
    required this.source,
    this.coverUrl,
    this.intro,
    this.latestChapter,
  });

  @override
  State<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends State<ChapterListScreen> {
  final SearchService _searchService = SearchService();
  final BookshelfService _bookshelfService = BookshelfService();

  List<Chapter> _chapters = [];
  bool _isLoading = true;
  String? _error;
  bool _isInBookshelf = false;

  @override
  void initState() {
    super.initState();
    _checkBookshelf();
    _loadChapters();
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
      appBar: AppBar(
        title: Text(widget.bookName),
        actions: [
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
      ),
      body: _buildBody(),
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
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
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
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

    return ListView.builder(
      itemCount: _chapters.length,
      itemBuilder: (context, index) {
        final chapter = _chapters[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text('${index + 1}'),
          ),
          title: Text(chapter.name),
          onTap: () {
            Navigator.push(
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
          },
        );
      },
    );
  }
}
