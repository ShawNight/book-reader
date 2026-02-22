import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/book.dart';

/// 书架服务 - 管理收藏的书籍
class BookshelfService {
  static final BookshelfService _instance = BookshelfService._internal();
  factory BookshelfService() => _instance;
  BookshelfService._internal();

  /// 获取应用文档目录
  Future<String> get _appDocDir async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// 获取书架存储路径
  Future<String> get _bookshelfPath async {
    final dir = await _appDocDir;
    return '$dir/bookshelf.json';
  }

  /// 加载书架
  Future<List<Book>> loadBooks() async {
    try {
      final path = await _bookshelfPath;
      final file = File(path);
      
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> data = json.decode(content);
      
      return data.map((item) => Book.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('加载书架失败: $e');
      return [];
    }
  }

  /// 保存书架
  Future<void> saveBooks(List<Book> books) async {
    try {
      final path = await _bookshelfPath;
      final file = File(path);
      
      final jsonContent = json.encode(books.map((b) => b.toJson()).toList());
      await file.writeAsString(jsonContent);
    } catch (e) {
      print('保存书架失败: $e');
      rethrow;
    }
  }

  /// 添加书籍到书架
  Future<void> addBook(Book book) async {
    final books = await loadBooks();
    
    // 检查是否已存在
    final index = books.indexWhere((b) => b.bookUrl == book.bookUrl);
    
    if (index >= 0) {
      // 已存在，更新信息
      books[index] = book;
    } else {
      // 不存在，添加到列表开头
      books.insert(0, book);
    }
    
    await saveBooks(books);
  }

  /// 从书架移除书籍
  Future<void> removeBook(String bookUrl) async {
    final books = await loadBooks();
    books.removeWhere((b) => b.bookUrl == bookUrl);
    await saveBooks(books);
  }

  /// 更新阅读进度
  Future<void> updateReadProgress(
    String bookUrl, {
    required int chapterIndex,
    required String chapterName,
  }) async {
    final books = await loadBooks();
    final index = books.indexWhere((b) => b.bookUrl == bookUrl);
    
    if (index >= 0) {
      books[index] = books[index].copyWith(
        lastReadChapter: chapterIndex,
        lastReadChapterName: chapterName,
      );
      await saveBooks(books);
    }
  }

  /// 检查书籍是否在书架中
  Future<bool> isBookInShelf(String bookUrl) async {
    final books = await loadBooks();
    return books.any((b) => b.bookUrl == bookUrl);
  }

  /// 获取指定书籍
  Future<Book?> getBook(String bookUrl) async {
    final books = await loadBooks();
    try {
      return books.firstWhere((b) => b.bookUrl == bookUrl);
    } catch (e) {
      return null;
    }
  }
}
