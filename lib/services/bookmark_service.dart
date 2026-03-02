import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/bookmark.dart';

/// 书签服务 - 管理阅读书签
class BookmarkService {
  static final BookmarkService _instance = BookmarkService._internal();
  factory BookmarkService() => _instance;
  BookmarkService._internal();

  /// 获取应用文档目录
  Future<String> get _appDocDir async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// 获取书签存储路径
  Future<String> get _bookmarksPath async {
    final dir = await _appDocDir;
    return '$dir/bookmarks.json';
  }

  /// 加载所有书签
  Future<List<Bookmark>> loadBookmarks() async {
    try {
      final path = await _bookmarksPath;
      final file = File(path);

      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> data = json.decode(content);

      return data.map((item) => Bookmark.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('加载书签失败: $e');
      return [];
    }
  }

  /// 保存所有书签
  Future<void> saveBookmarks(List<Bookmark> bookmarks) async {
    try {
      final path = await _bookmarksPath;
      final file = File(path);

      final jsonContent = json.encode(bookmarks.map((b) => b.toJson()).toList());
      await file.writeAsString(jsonContent);
    } catch (e) {
      print('保存书签失败: $e');
      rethrow;
    }
  }

  /// 添加书签
  Future<void> addBookmark(Bookmark bookmark) async {
    final bookmarks = await loadBookmarks();

    // 检查是否已存在相同位置的书签
    final existingIndex = bookmarks.indexWhere((b) => b.uniqueKey == bookmark.uniqueKey);

    if (existingIndex >= 0) {
      // 已存在，更新书签（主要是更新备注和时间）
      bookmarks[existingIndex] = bookmark;
    } else {
      // 不存在，添加到列表开头
      bookmarks.insert(0, bookmark);
    }

    await saveBookmarks(bookmarks);
  }

  /// 删除书签
  Future<void> removeBookmark(Bookmark bookmark) async {
    final bookmarks = await loadBookmarks();
    bookmarks.removeWhere((b) => b.uniqueKey == bookmark.uniqueKey);
    await saveBookmarks(bookmarks);
  }

  /// 删除指定书籍的所有书签
  Future<void> removeBookmarksForBook(String bookUrl) async {
    final bookmarks = await loadBookmarks();
    bookmarks.removeWhere((b) => b.bookUrl == bookUrl);
    await saveBookmarks(bookmarks);
  }

  /// 获取指定书籍的书签列表
  Future<List<Bookmark>> getBookmarksForBook(String bookUrl) async {
    final bookmarks = await loadBookmarks();
    return bookmarks.where((b) => b.bookUrl == bookUrl).toList();
  }

  /// 检查指定位置是否有书签
  Future<bool> hasBookmarkAtPosition(String bookUrl, int chapterIndex, double scrollPosition) async {
    final bookmarks = await loadBookmarks();
    final key = '$bookUrl-$chapterIndex-${scrollPosition.toStringAsFixed(3)}';
    return bookmarks.any((b) => b.uniqueKey == key);
  }

  /// 获取指定位置的书签
  Future<Bookmark?> getBookmarkAtPosition(String bookUrl, int chapterIndex, double scrollPosition) async {
    final bookmarks = await loadBookmarks();
    final key = '$bookUrl-$chapterIndex-${scrollPosition.toStringAsFixed(3)}';
    try {
      return bookmarks.firstWhere((b) => b.uniqueKey == key);
    } catch (e) {
      return null;
    }
  }

  /// 检查章节是否有书签（任意位置）
  Future<bool> hasBookmarkInChapter(String bookUrl, int chapterIndex) async {
    final bookmarks = await loadBookmarks();
    return bookmarks.any((b) => b.bookUrl == bookUrl && b.chapterIndex == chapterIndex);
  }

  /// 获取章节内的所有书签
  Future<List<Bookmark>> getBookmarksInChapter(String bookUrl, int chapterIndex) async {
    final bookmarks = await loadBookmarks();
    return bookmarks.where((b) => b.bookUrl == bookUrl && b.chapterIndex == chapterIndex).toList();
  }

  /// 切换书签状态（存在则删除，不存在则添加）
  Future<bool> toggleBookmark(Bookmark bookmark) async {
    final hasBookmark = await hasBookmarkAtPosition(
      bookmark.bookUrl,
      bookmark.chapterIndex,
      bookmark.scrollPosition,
    );

    if (hasBookmark) {
      await removeBookmark(bookmark);
      return false; // 已删除
    } else {
      await addBookmark(bookmark);
      return true; // 已添加
    }
  }
}
