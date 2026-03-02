import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../services/book_source_service.dart';
import '../services/bookshelf_service.dart';
import '../services/search_service.dart';
import '../services/reader_settings_service.dart';
import '../models/book_source.dart';
import '../models/book.dart';
import '../models/reader_settings.dart';
import 'search_screen.dart';
import 'chapter_list_screen.dart';
import 'reader_screen.dart';
import 'source_purify_screen.dart';

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
  final ReaderSettingsService _settingsService = ReaderSettingsService();
  List<Book> _books = [];
  bool _isLoading = true;
  BookshelfSortMode _sortMode = BookshelfSortMode.addedTime;
  bool _sortAscending = false;

  // 多选模式状态
  bool _isSelectionMode = false;
  final Set<String> _selectedBookUrls = {};

  @override
  void initState() {
    super.initState();
    _sortMode = _settingsService.settings.bookshelfSortMode;
    _sortAscending = _settingsService.settings.bookshelfSortAscending;
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final books = await _bookshelfService.loadBooks();
    final sortedBooks = _bookshelfService.sortBooks(books, _sortMode, _sortAscending);
    if (mounted) {
      setState(() {
        _books = sortedBooks;
        _isLoading = false;
      });
    }
  }

  void _changeSortMode(BookshelfSortMode newMode) {
    if (_sortMode == newMode) {
      // 同一排序模式，切换升序/降序
      setState(() {
        _sortAscending = !_sortAscending;
      });
    } else {
      // 不同排序模式，切换模式并重置为降序
      setState(() {
        _sortMode = newMode;
        _sortAscending = false;
      });
    }
    // 保存设置
    _saveSortSettings();
    // 重新排序
    _books = _bookshelfService.sortBooks(_books, _sortMode, _sortAscending);
  }

  Future<void> _saveSortSettings() async {
    final newSettings = _settingsService.settings.copyWith(
      bookshelfSortModeIndex: _sortMode.index,
      bookshelfSortAscending: _sortAscending,
    );
    await _settingsService.saveSettings(newSettings);
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
      title: const Text('我的书架'),
      actions: [
        // 排序按钮
        PopupMenuButton<BookshelfSortMode>(
          icon: const Icon(Icons.sort),
          tooltip: '排序方式',
          initialValue: _sortMode,
          onSelected: _changeSortMode,
          itemBuilder: (context) {
            return BookshelfSortMode.values.map((mode) {
              final isSelected = _sortMode == mode;
              return PopupMenuItem<BookshelfSortMode>(
                value: mode,
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? (_sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward)
                          : null,
                      size: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      mode.displayName,
                      style: TextStyle(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : null,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
        ),
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
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: '多选',
          onPressed: _books.isEmpty ? null : _enterSelectionMode,
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
      title: Text('已选 ${_selectedBookUrls.length} 本'),
      actions: [
        TextButton(
          onPressed: _selectedBookUrls.isEmpty
              ? _selectAll
              : _selectedBookUrls.length == _books.length
                  ? _deselectAll
                  : _selectAll,
          child: Text(
            _selectedBookUrls.length == _books.length ? '取消全选' : '全选',
          ),
        ),
      ],
    );
  }

  /// 底部操作栏
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.delete,
            label: '删除',
            onPressed: _selectedBookUrls.isEmpty ? null : _batchDelete,
            color: Colors.red,
          ),
          _buildActionButton(
            icon: Icons.check_circle,
            label: '标记已读',
            onPressed: _selectedBookUrls.isEmpty ? null : _batchMarkAsRead,
            color: Colors.green,
          ),
          _buildActionButton(
            icon: Icons.radio_button_unchecked,
            label: '标记未读',
            onPressed: _selectedBookUrls.isEmpty ? null : _batchMarkAsUnread,
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    final isEnabled = onPressed != null;
    return TextButton(
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isEnabled ? color : Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isEnabled ? color : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
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
        return _buildBookItem(book);
      },
    );
  }

  /// 构建书籍列表项
  Widget _buildBookItem(Book book) {
    final isSelected = _selectedBookUrls.contains(book.bookUrl);

    if (_isSelectionMode) {
      // 多选模式
      return ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (value) => _toggleSelection(book.bookUrl),
            ),
            book.coverUrl != null
                ? Image.network(
                    book.coverUrl!,
                    width: 50,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.book),
                  )
                : const Icon(Icons.book),
          ],
        ),
        title: Row(
          children: [
            Expanded(child: Text(book.name)),
            if (book.isRead)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '已读',
                  style: TextStyle(fontSize: 10, color: Colors.green),
                ),
              ),
          ],
        ),
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
        onTap: () => _toggleSelection(book.bookUrl),
      );
    } else {
      // 普通模式
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
          title: Row(
            children: [
              Expanded(child: Text(book.name)),
              if (book.isRead)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '已读',
                    style: TextStyle(fontSize: 10, color: Colors.green),
                  ),
                ),
            ],
          ),
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

            // 检查是否有阅读记录
            if (book.lastReadChapter != null) {
              // 有阅读记录，直接进入阅读器
              await _openReaderDirectly(book, source);
            } else {
              // 首次阅读，进入章节列表
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
                    lastReadChapter: book.lastReadChapter,
                    scrollProgress: book.scrollProgress,
                  ),
                ),
              );
            }
            // 返回后刷新书架
            _loadBooks();
          },
          onLongPress: () {
            // 长按进入多选模式并选中该项
            _enterSelectionMode(bookUrl: book.bookUrl);
          },
        ),
      );
    }
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

  // ============== 多选模式相关方法 ==============

  /// 进入多选模式
  void _enterSelectionMode({String? bookUrl}) {
    setState(() {
      _isSelectionMode = true;
      if (bookUrl != null) {
        _selectedBookUrls.add(bookUrl);
      }
    });
  }

  /// 退出多选模式
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedBookUrls.clear();
    });
  }

  /// 切换选中状态
  void _toggleSelection(String bookUrl) {
    setState(() {
      if (_selectedBookUrls.contains(bookUrl)) {
        _selectedBookUrls.remove(bookUrl);
      } else {
        _selectedBookUrls.add(bookUrl);
      }
    });
  }

  /// 全选
  void _selectAll() {
    setState(() {
      _selectedBookUrls.clear();
      _selectedBookUrls.addAll(_books.map((b) => b.bookUrl));
    });
  }

  /// 取消全选
  void _deselectAll() {
    setState(() {
      _selectedBookUrls.clear();
    });
  }

  /// 批量删除
  Future<void> _batchDelete() async {
    final count = _selectedBookUrls.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 $count 本书吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _bookshelfService.removeBooks(_selectedBookUrls.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 $count 本书')),
        );
        _exitSelectionMode();
        _loadBooks();
      }
    }
  }

  /// 批量标记已读
  Future<void> _batchMarkAsRead() async {
    final count = _selectedBookUrls.length;
    await _bookshelfService.markBooksAsRead(_selectedBookUrls.toList());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将 $count 本书标记为已读')),
      );
      _exitSelectionMode();
      _loadBooks();
    }
  }

  /// 批量标记未读
  Future<void> _batchMarkAsUnread() async {
    final count = _selectedBookUrls.length;
    await _bookshelfService.markBooksAsUnread(_selectedBookUrls.toList());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将 $count 本书标记为未读')),
      );
      _exitSelectionMode();
      _loadBooks();
    }
  }

  /// 直接打开阅读器到上次阅读位置
  Future<void> _openReaderDirectly(Book book, BookSource source) async {
    // 显示加载指示器
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // 加载章节列表
      final searchService = SearchService();
      final chapters = await searchService.getChapters(book.bookUrl, source);

      if (!mounted) return;

      // 关闭加载指示器
      Navigator.pop(context);

      if (chapters.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到章节')),
        );
        return;
      }

      // 计算有效的章节索引
      final initialIndex = (book.lastReadChapter ?? 0).clamp(0, chapters.length - 1);

      // 跳转到阅读器
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderScreen(
            chapters: chapters,
            initialIndex: initialIndex,
            source: source,
            bookName: book.name,
            bookUrl: book.bookUrl,
            initialScrollProgress: book.scrollProgress,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // 关闭加载指示器
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败：$e')),
      );
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
          if (_sources.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cleaning_services),
              tooltip: '书源净化',
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SourcePurifyScreen(sources: _sources),
                  ),
                );
                if (result == true) _loadSources();
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
