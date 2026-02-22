import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../services/book_source_service.dart';
import '../services/bookshelf_service.dart';
import '../models/book_source.dart';
import '../models/book.dart';
import 'search_screen.dart';
import 'chapter_list_screen.dart';

/// 首页 - 书架页面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _BookshelfPage(),
          _BookSourcePage(),
          _SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.book),
            label: '书架',
          ),
          NavigationDestination(
            icon: Icon(Icons.source),
            label: '书源',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

/// 书架页面
class _BookshelfPage extends StatefulWidget {
  const _BookshelfPage();

  @override
  State<_BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<_BookshelfPage> {
  final BookshelfService _bookshelfService = BookshelfService();
  List<Book> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final books = await _bookshelfService.loadBooks();
    if (mounted) {
      setState(() {
        _books = books;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的书架'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SearchScreen(),
                ),
              );
              // 返回后刷新书架
              _loadBooks();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_books.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('书架为空，点击右上角搜索按钮'),
            SizedBox(height: 8),
            Text('搜索前请先导入书源', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _books.length,
      itemBuilder: (context, index) {
        final book = _books[index];
        return Dismissible(
          key: Key(book.bookUrl),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _removeBook(book),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: ListTile(
            leading: book.coverUrl != null
                ? Image.network(
                    book.coverUrl!,
                    width: 50,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.book),
                  )
                : const Icon(Icons.book),
            title: Text(book.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('作者：${book.author}'),
                if (book.lastReadChapterName != null)
                  Text(
                    '读到：${book.lastReadChapterName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                if (book.latestChapter != null)
                  Text(
                    '最新：${book.latestChapter}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  '来源：${book.sourceName}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            isThreeLine: true,
            onTap: () async {
              // 从书源服务加载书源
              final sourceService = BookSourceService();
              final sources = await sourceService.loadBookSources();
              final source = sources.firstWhere(
                (s) => s.bookSourceUrl == book.sourceUrl,
                orElse: () => throw Exception('书源不存在'),
              );

              if (!mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChapterListScreen(
                    bookUrl: book.bookUrl,
                    bookName: book.name,
                    source: source,
                    coverUrl: book.coverUrl,
                    intro: book.intro,
                    latestChapter: book.latestChapter,
                  ),
                ),
              );
              // 返回后刷新书架
              _loadBooks();
            },
          ),
        );
      },
    );
  }

  Future<void> _removeBook(Book book) async {
    await _bookshelfService.removeBook(book.bookUrl);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('《${book.name}》已从书架移除')),
      );
      _loadBooks();
    }
  }
}

/// 书源管理页面
class _BookSourcePage extends StatefulWidget {
  const _BookSourcePage();

  @override
  State<_BookSourcePage> createState() => _BookSourcePageState();
}

class _BookSourcePageState extends State<_BookSourcePage> {
  final BookSourceService _service = BookSourceService();
  List<BookSource> _sources = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  Future<void> _loadSources() async {
    final sources = await _service.loadBookSources();
    if (mounted) {
      setState(() {
        _sources = sources;
        _isLoading = false;
      });
    }
  }

  Future<void> _importBookSource() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'JSON文件',
        extensions: ['json'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在导入书源...')),
      );

      final sources = await _service.importFromJsonFile(file.path);
      await _service.saveBookSources(sources);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功导入 ${sources.length} 个书源！')),
      );

      await _loadSources();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书源管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _importBookSource,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sources.isEmpty) {
      return const Center(
        child: Text('暂无书源，点击右上角导入'),
      );
    }

    return ListView.builder(
      itemCount: _sources.length,
      itemBuilder: (context, index) {
        final source = _sources[index];
        return ListTile(
          leading: const Icon(Icons.source),
          title: Text(source.bookSourceName),
          subtitle: Text(source.bookSourceUrl),
          trailing: source.enabled == true
              ? const Icon(Icons.check_circle, color: Colors.green)
              : const Icon(Icons.cancel, color: Colors.grey),
        );
      },
    );
  }
}

/// 设置页面
class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('主题模式'),
            subtitle: const Text('跟随系统'),
            onTap: () {
              // TODO: 实现主题切换
            },
          ),
          ListTile(
            leading: const Icon(Icons.font_download),
            title: const Text('字体大小'),
            subtitle: const Text('中'),
            onTap: () {
              // TODO: 实现字体大小设置
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('关于'),
            subtitle: const Text('YueDu Flutter v1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: '悦读',
                applicationVersion: '1.0.0',
                applicationLegalese: '开源阅读器',
              );
            },
          ),
        ],
      ),
    );
  }
}
