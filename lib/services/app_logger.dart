import 'package:flutter/foundation.dart';

/// App 日志工具 - 支持分级日志， release 模式下只输出 warning 和 error
class AppLogger {
  AppLogger._();

  static void debug(String message, [String? tag]) {
    if (kDebugMode) {
      _log('DEBUG', message, tag);
    }
  }

  static void info(String message, [String? tag]) {
    if (kDebugMode) {
      _log('INFO', message, tag);
    }
  }

  static void warning(String message, [String? tag]) {
    _log('WARN', message, tag);
  }

  static void error(String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    _log('ERROR', message, tag);
    if (error != null) print('  Error: $error');
    if (stackTrace != null) print('  StackTrace: $stackTrace');
  }

  static void _log(String level, String message, String? tag) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final prefix = tag != null ? '[$tag] ' : '';
    print('$timestamp $level $prefix$message');
  }
}
