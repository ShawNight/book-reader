import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 搜索历史服务 - 管理搜索关键词历史
class SearchHistoryService {
  static final SearchHistoryService _instance = SearchHistoryService._internal();
  factory SearchHistoryService() => _instance;
  SearchHistoryService._internal();

  static const int _maxHistorySize = 20; // 最多保存 20 条历史

  /// 获取应用文档目录
  Future<String> get _appDocDir async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// 获取搜索历史存储路径
  Future<String> get _historyPath async {
    final dir = await _appDocDir;
    return '$dir/search_history.json';
  }

  /// 加载搜索历史
  Future<List<String>> loadHistory() async {
    try {
      final path = await _historyPath;
      final file = File(path);

      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final List<dynamic> data = json.decode(content);

      return data.map((item) => item as String).toList();
    } catch (e) {
      print('加载搜索历史失败: $e');
      return [];
    }
  }

  /// 保存搜索历史
  Future<void> saveHistory(List<String> history) async {
    try {
      final path = await _historyPath;
      final file = File(path);

      final jsonContent = json.encode(history);
      await file.writeAsString(jsonContent);
    } catch (e) {
      print('保存搜索历史失败: $e');
      rethrow;
    }
  }

  /// 添加搜索关键词到历史
  Future<void> addKeyword(String keyword) async {
    if (keyword.trim().isEmpty) return;

    final history = await loadHistory();

    // 移除已存在的相同关键词（避免重复）
    history.remove(keyword);

    // 添加到列表开头
    history.insert(0, keyword);

    // 限制历史数量
    if (history.length > _maxHistorySize) {
      history.removeRange(_maxHistorySize, history.length);
    }

    await saveHistory(history);
  }

  /// 删除单个搜索历史
  Future<void> removeKeyword(String keyword) async {
    final history = await loadHistory();
    history.remove(keyword);
    await saveHistory(history);
  }

  /// 清空所有搜索历史
  Future<void> clearHistory() async {
    await saveHistory([]);
  }
}
