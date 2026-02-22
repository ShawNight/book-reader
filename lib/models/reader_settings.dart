import 'package:flutter/material.dart';

/// 阅读设置模型
class ReaderSettings {
  /// 字体大小 (12-32)
  final double fontSize;

  /// 行高 (1.2-3.0)
  final double lineHeight;

  /// 背景主题索引
  final int themeIndex;

  /// 上下边距
  final double verticalPadding;

  /// 左右边距
  final double horizontalPadding;

  const ReaderSettings({
    this.fontSize = 18.0,
    this.lineHeight = 1.8,
    this.themeIndex = 0,
    this.verticalPadding = 16.0,
    this.horizontalPadding = 16.0,
  });

  /// 预设主题列表
  static const List<ReaderTheme> themes = [
    ReaderTheme(
      name: '米黄色',
      backgroundColor: Color(0xFFF5F5DC),
      textColor: Color(0xFF333333),
    ),
    ReaderTheme(
      name: '护眼绿',
      backgroundColor: Color(0xFFCCE8CF),
      textColor: Color(0xFF333333),
    ),
    ReaderTheme(
      name: '夜间模式',
      backgroundColor: Color(0xFF1A1A1A),
      textColor: Color(0xFFAAAAAA),
    ),
    ReaderTheme(
      name: '纯白',
      backgroundColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF333333),
    ),
    ReaderTheme(
      name: '羊皮纸',
      backgroundColor: Color(0xFFF0E6D2),
      textColor: Color(0xFF5B4636),
    ),
    ReaderTheme(
      name: '蓝色护眼',
      backgroundColor: Color(0xFFD6E5F3),
      textColor: Color(0xFF333333),
    ),
  ];

  /// 获取当前主题
  ReaderTheme get theme => themes[themeIndex.clamp(0, themes.length - 1)];

  /// 复制并修改
  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    int? themeIndex,
    double? verticalPadding,
    double? horizontalPadding,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      themeIndex: themeIndex ?? this.themeIndex,
      verticalPadding: verticalPadding ?? this.verticalPadding,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'themeIndex': themeIndex,
      'verticalPadding': verticalPadding,
      'horizontalPadding': horizontalPadding,
    };
  }

  /// 从 JSON 创建
  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    return ReaderSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
      lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.8,
      themeIndex: json['themeIndex'] as int? ?? 0,
      verticalPadding: (json['verticalPadding'] as num?)?.toDouble() ?? 16.0,
      horizontalPadding: (json['horizontalPadding'] as num?)?.toDouble() ?? 16.0,
    );
  }
}

/// 阅读主题
class ReaderTheme {
  final String name;
  final Color backgroundColor;
  final Color textColor;

  const ReaderTheme({
    required this.name,
    required this.backgroundColor,
    required this.textColor,
  });
}
