import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// 章节缓存服务 - 单例模式
/// 用于持久化缓存章节内容，支持离线阅读
class ChapterCacheService {
  static final ChapterCacheService _instance = ChapterCacheService._internal();
  factory ChapterCacheService() => _instance;
  ChapterCacheService._internal();

  static const String _cacheDirName = 'chapter_cache';
  static const Duration _cacheExpiry = Duration(days: 30); // 缓存30天过期

  String? _cachePath;

  /// 初始化缓存服务
  Future<void> init() async {
    final directory = await getApplicationDocumentsDirectory();
    _cachePath = '${directory.path}/$_cacheDirName';

    // 创建缓存目录
    final cacheDir = Directory(_cachePath!);
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    // 清理过期缓存
    await _cleanExpiredCache();
  }

  /// 生成缓存文件名（使用 URL 的 MD5 哈希）
  String _getCacheFileName(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 获取缓存文件路径
  String _getCacheFilePath(String url) {
    return '$_cachePath/${_getCacheFileName(url)}.json';
  }

  /// 保存章节内容到缓存
  Future<void> saveCache(String url, String content, {String? bookName}) async {
    if (_cachePath == null) await init();

    final filePath = _getCacheFilePath(url);
    final file = File(filePath);

    final cacheData = {
      'url': url,
      'content': content,
      'bookName': bookName,
      'cachedAt': DateTime.now().toIso8601String(),
    };

    await file.writeAsString(jsonEncode(cacheData));
  }

  /// 从缓存读取章节内容
  /// 如果缓存不存在或已过期，返回 null
  Future<String?> getCache(String url) async {
    if (_cachePath == null) await init();

    final filePath = _getCacheFilePath(url);
    final file = File(filePath);

    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      final cacheData = jsonDecode(content) as Map<String, dynamic>;

      // 检查缓存是否过期
      final cachedAt = DateTime.parse(cacheData['cachedAt'] as String);
      final now = DateTime.now();

      if (now.difference(cachedAt) > _cacheExpiry) {
        // 缓存已过期，删除文件
        await file.delete();
        return null;
      }

      return cacheData['content'] as String;
    } catch (e) {
      print('读取缓存失败: $e');
      return null;
    }
  }

  /// 检查缓存是否存在
  Future<bool> hasCache(String url) async {
    if (_cachePath == null) await init();

    final filePath = _getCacheFilePath(url);
    final file = File(filePath);
    return file.exists();
  }

  /// 删除指定章节的缓存
  Future<void> deleteCache(String url) async {
    if (_cachePath == null) await init();

    final filePath = _getCacheFilePath(url);
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 清理所有缓存
  Future<void> clearAllCache() async {
    if (_cachePath == null) await init();

    final cacheDir = Directory(_cachePath!);
    if (await cacheDir.exists()) {
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
  }

  /// 清理过期缓存
  Future<void> _cleanExpiredCache() async {
    if (_cachePath == null) return;

    final cacheDir = Directory(_cachePath!);
    if (!await cacheDir.exists()) return;

    final now = DateTime.now();

    await for (final entity in cacheDir.list()) {
      if (entity is File) {
        try {
          final content = await entity.readAsString();
          final cacheData = jsonDecode(content) as Map<String, dynamic>;
          final cachedAt = DateTime.parse(cacheData['cachedAt'] as String);

          if (now.difference(cachedAt) > _cacheExpiry) {
            await entity.delete();
            print('清理过期缓存: ${entity.path}');
          }
        } catch (e) {
          // 无法解析的文件，直接删除
          await entity.delete();
        }
      }
    }
  }

  /// 获取缓存统计信息
  Future<CacheStats> getCacheStats() async {
    if (_cachePath == null) await init();

    final cacheDir = Directory(_cachePath!);
    if (!await cacheDir.exists()) {
      return const CacheStats(fileCount: 0, totalSize: 0);
    }

    int fileCount = 0;
    int totalSize = 0;

    await for (final entity in cacheDir.list()) {
      if (entity is File) {
        fileCount++;
        totalSize += await entity.length();
      }
    }

    return CacheStats(fileCount: fileCount, totalSize: totalSize);
  }

  /// 格式化文件大小
  static String formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

/// 缓存统计信息
class CacheStats {
  final int fileCount;
  final int totalSize;

  const CacheStats({
    required this.fileCount,
    required this.totalSize,
  });

  String get formattedSize => ChapterCacheService.formatSize(totalSize);
}
