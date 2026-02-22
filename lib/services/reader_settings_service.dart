import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/reader_settings.dart';

/// 阅读设置服务 - 单例模式
class ReaderSettingsService {
  static final ReaderSettingsService _instance =
      ReaderSettingsService._internal();
  factory ReaderSettingsService() => _instance;
  ReaderSettingsService._internal();

  static const String _settingsFileName = 'reader_settings.json';

  ReaderSettings _settings = const ReaderSettings();
  ReaderSettings get settings => _settings;

  /// 初始化服务，加载保存的设置
  Future<void> init() async {
    try {
      final file = await _getSettingsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _settings = ReaderSettings.fromJson(json);
      }
    } catch (e) {
      print('加载阅读设置失败: $e');
    }
  }

  /// 保存设置
  Future<void> saveSettings(ReaderSettings settings) async {
    _settings = settings;
    try {
      final file = await _getSettingsFile();
      await file.writeAsString(jsonEncode(settings.toJson()));
    } catch (e) {
      print('保存阅读设置失败: $e');
    }
  }

  /// 获取设置文件
  Future<File> _getSettingsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_settingsFileName');
  }
}
