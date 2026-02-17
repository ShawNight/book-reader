import 'package:flutter/material.dart';

import '../services/search_service.dart';
import '../services/bookshelf_service.dart';
import '../services/book_source_service.dart';
import '../models/book.dart';
import 'chapter_list_screen.dart';

/// 搜索页面
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final SearchService _searchService = SearchService();
  final BookSourceService _bookSourceService = BookSourceService();

  List<SearchResult> _results = [];
  bool _isSearching = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isSearching = true;
      _error = null;
      _results = [];
    });

    try {
      // 加载书源
      final sources = await _bookSourceService.loadBookSources();
      if (sources.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先导入书源')),
        );
        setState(() => _isSearching = false);
        return;
      }

      // 搜索
      final results = await _searchService.search(keyword, sources);

      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;

        if (results.isEmpty) {
          _error = '未找到相关小说';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _error = '搜索失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索小说...',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _isSearching ? null : _search,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在搜索...'),
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
              onPressed: _search,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text('输入关键词搜索小说'),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return ListTile(
          leading: result.coverUrl != null
              ? Image.network(
                  result.coverUrl!,
                  width: 50,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.book),
                )
              : const Icon(Icons.book),
          title: Text(result.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('作者：${result.author}'),
              if (result.latestChapter != null)
                Text(
                  '最新：${result.latestChapter}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                '来源：${result.source.bookSourceName}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          isThreeLine: true,
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '加入书架',
            onPressed: () => _addToBookshelf(result),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChapterListScreen(
                  bookUrl: result.bookUrl,
                  bookName: result.name,
                  source: result.source,
                  coverUrl: result.coverUrl,
                  intro: result.intro,
                  latestChapter: result.latestChapter,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 加入书架
  Future<void> _addToBookshelf(SearchResult result) async {
    try {
      final book = Book(
        name: result.name,
        author: result.author,
        bookUrl: result.bookUrl,
        coverUrl: result.coverUrl,
        intro: result.intro,
        latestChapter: result.latestChapter,
        sourceName: result.source.bookSourceName,
        sourceUrl: result.source.bookSourceUrl,
        addedTime: DateTime.now(),
      );

      await BookshelfService().addBook(book);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('《${result.name}》已加入书架')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入书架失败：$e')),
      );
    }
  }
}
