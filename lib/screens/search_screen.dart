import 'dart:async';

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
  int _completedSources = 0;
  int _totalSources = 0;
  StreamSubscription? _searchSubscription;
  String _currentKeyword = '';
  List<SearchResult> _allResults = []; // 存储所有未排序的结果

  @override
  void dispose() {
    _controller.dispose();
    _searchSubscription?.cancel();
    super.dispose();
  }

  /// 计算搜索结果的相关性分数（参考阅读3.0等成熟APP）
  /// 分数范围: 0-100，分数越高越相关
  int _calculateRelevanceScore(SearchResult result, String keyword) {
    final lowerKeyword = keyword.toLowerCase();
    final lowerName = result.name.toLowerCase();
    final lowerAuthor = result.author.toLowerCase();

    // 1. 书名完全匹配 (最高优先级)
    if (lowerName == lowerKeyword) return 100;

    // 2. 书名以关键词开头
    if (lowerName.startsWith(lowerKeyword)) return 90;

    // 3. 书名包含完整关键词
    if (lowerName.contains(lowerKeyword)) return 80;

    // 4. 书名包含关键词的字符（宽松匹配，适用于中文）
    int charMatchCount = 0;
    for (int i = 0; i < lowerKeyword.length; i++) {
      if (lowerName.contains(lowerKeyword[i])) {
        charMatchCount++;
      }
    }
    if (charMatchCount == lowerKeyword.length) {
      // 所有字符都匹配，给一个较高的分数
      return 70;
    }

    // 5. 作者完全匹配
    if (lowerAuthor == lowerKeyword) return 60;

    // 6. 作者以关键词开头
    if (lowerAuthor.startsWith(lowerKeyword)) return 55;

    // 7. 作者包含关键词
    if (lowerAuthor.contains(lowerKeyword)) return 50;

    // 8. 部分字符匹配
    if (charMatchCount > lowerKeyword.length / 2) {
      return 30 + (charMatchCount * 10 ~/ lowerKeyword.length);
    }

    // 9. 不太相关，但仍然显示
    return 10;
  }

  /// 对搜索结果进行排序（相关度高的排前面）
  List<SearchResult> _sortResults(List<SearchResult> results, String keyword) {
    // 计算每个结果的分数
    final scoredResults = results.map((result) {
      return MapEntry(result, _calculateRelevanceScore(result, keyword));
    }).toList();

    // 按分数降序排序
    scoredResults.sort((a, b) => b.value.compareTo(a.value));

    return scoredResults.map((e) => e.key).toList();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    // 取消之前的搜索
    _searchSubscription?.cancel();

    setState(() {
      _isSearching = true;
      _error = null;
      _results = [];
      _allResults = [];
      _completedSources = 0;
      _totalSources = 0;
      _currentKeyword = keyword;
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

      // 统计有效书源数量
      final validSources = sources
          .where((s) => s.enabled == true && s.searchUrl != null && s.searchUrl!.isNotEmpty)
          .toList();
      _totalSources = validSources.length;

      // 开始流式搜索
      _searchSubscription = _searchService.searchStream(keyword, sources).listen(
        (data) {
          if (!mounted) return;

          if (data is SearchResult) {
            _allResults.add(data);
            // 实时更新排序后的结果
            setState(() {
              _results = _sortResults(_allResults, _currentKeyword);
            });
          } else if (data is SearchProgress) {
            setState(() {
              _completedSources = data.completed;
            });
          }
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _isSearching = false;
            _results = _sortResults(_allResults, _currentKeyword);
            if (_results.isEmpty) {
              _error = '未找到相关小说';
            }
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _isSearching = false;
            _error = '搜索失败：$e';
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _error = '搜索失败：$e';
      });
    }
  }

  /// 取消搜索
  void _cancelSearch() {
    _searchSubscription?.cancel();
    setState(() {
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索书名或作者...',
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          if (_isSearching)
            TextButton(
              onPressed: _cancelSearch,
              child: const Text('取消'),
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _search,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 显示搜索进度状态栏
    final showProgress = _isSearching || _results.isNotEmpty;

    return Column(
      children: [
        // 搜索状态栏
        if (showProgress) _buildStatusBar(),

        // 结果列表或占位
        Expanded(
          child: _error != null && !_isSearching
              ? _buildError()
              : _results.isEmpty && !_isSearching
                  ? _buildEmpty()
                  : _buildResultList(),
        ),
      ],
    );
  }

  /// 构建状态栏
  Widget _buildStatusBar() {
    String statusText;
    if (_isSearching) {
      if (_totalSources > 0) {
        statusText = '正在搜索 $_completedSources/$_totalSources 个书源...';
      } else {
        statusText = '正在搜索...';
      }
    } else {
      statusText = '搜索完成，找到 ${_results.length} 个结果';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Expanded(
            child: Text(
              statusText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建错误视图
  Widget _buildError() {
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

  /// 构建空视图
  Widget _buildEmpty() {
    return const Center(
      child: Text('输入关键词搜索小说'),
    );
  }

  /// 构建结果列表
  Widget _buildResultList() {
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
