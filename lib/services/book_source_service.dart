import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/book_source.dart';

/// 书源服务 - 负责导入、解析、存储书源
class BookSourceService {
  static final BookSourceService _instance = BookSourceService._internal();
  factory BookSourceService() => _instance;
  BookSourceService._internal();

  /// 从 JSON 文件导入书源
  Future<List<BookSource>> importFromJsonFile(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    return parseBookSources(content);
  }

  /// 解析 JSON 字符串为书源列表
  List<BookSource> parseBookSources(String jsonContent) {
    final dynamic data = json.decode(jsonContent);

    if (data is List) {
      return data
          .map((item) => BookSource.fromJson(item as Map<String, dynamic>))
          .toList();
    } else if (data is Map) {
      // 单个书源的情况
      return [BookSource.fromJson(data as Map<String, dynamic>)];
    }

    throw FormatException('无法解析书源 JSON 格式');
  }

  /// 获取应用文档目录
  Future<String> get appDocDir async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// 获取书源存储路径
  Future<String> get bookSourcePath async {
    final dir = await appDocDir;
    final bookSourceDir = '$dir/book_sources';
    await Directory(bookSourceDir).create(recursive: true);
    return bookSourceDir;
  }

  /// 保存书源到本地
  Future<void> saveBookSources(List<BookSource> sources) async {
    final path = await bookSourcePath;
    final file = File('$path/sources.json');
    final jsonContent = json.encode(sources.map((s) => s.toJson()).toList());
    await file.writeAsString(jsonContent);
  }

  /// 加载本地书源
  Future<List<BookSource>> loadBookSources() async {
    try {
      final path = await bookSourcePath;
      final file = File('$path/sources.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return parseBookSources(content);
      }
    } catch (e) {
      // 忽略错误，返回空列表
    }
    return [];
  }
}
