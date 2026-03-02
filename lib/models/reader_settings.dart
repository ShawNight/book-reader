import 'package:flutter/material.dart';

/// 书架排序方式枚举
enum BookshelfSortMode {
  /// 按添加时间（默认）
  addedTime,
  /// 按书名
  name,
  /// 按作者
  author,
  /// 按最近阅读时间
  lastReadTime,
  /// 按阅读进度
  readProgress,
}

/// 书架排序方式扩展方法
extension BookshelfSortModeExtension on BookshelfSortMode {
  String get displayName {
    switch (this) {
      case BookshelfSortMode.addedTime:
        return '添加时间';
      case BookshelfSortMode.name:
        return '书名';
      case BookshelfSortMode.author:
        return '作者';
      case BookshelfSortMode.lastReadTime:
        return '最近阅读';
      case BookshelfSortMode.readProgress:
        return '阅读进度';
    }
  }

  static BookshelfSortMode fromIndex(int index) {
    return BookshelfSortMode.values[index.clamp(0, BookshelfSortMode.values.length - 1)];
  }
}

/// 翻页模式枚举
enum PageTurnMode {
  /// 滑动翻页
  slide,
  /// 覆盖翻页
  cover,
  /// 仿真翻页
  simulation,
  /// 滚动翻页
  scroll,
}

/// 翻页模式扩展方法
extension PageTurnModeExtension on PageTurnMode {
  String get displayName {
    switch (this) {
      case PageTurnMode.slide:
        return '滑动';
      case PageTurnMode.cover:
        return '覆盖';
      case PageTurnMode.simulation:
        return '仿真';
      case PageTurnMode.scroll:
        return '滚动';
    }
  }

  static PageTurnMode fromIndex(int index) {
    return PageTurnMode.values[index.clamp(0, PageTurnMode.values.length - 1)];
  }
}

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

  /// 段间距 (0-24)
  final double paragraphSpacing;

  /// 首行缩进字符数 (0-4)
  final double indentSize;

  /// 是否显示章节标题
  final bool showChapterTitle;

  /// 翻页模式
  final int pageTurnModeIndex;

  /// 书架排序方式索引
  final int bookshelfSortModeIndex;

  /// 书架排序是否升序
  final bool bookshelfSortAscending;

  const ReaderSettings({
    this.fontSize = 18.0,
    this.lineHeight = 1.8,
    this.themeIndex = 0,
    this.verticalPadding = 16.0,
    this.horizontalPadding = 16.0,
    this.paragraphSpacing = 8.0,
    this.indentSize = 2.0,
    this.showChapterTitle = true,
    this.pageTurnModeIndex = 0,
    this.bookshelfSortModeIndex = 0,
    this.bookshelfSortAscending = false,
  });

  /// 获取当前翻页模式
  PageTurnMode get pageTurnMode => PageTurnModeExtension.fromIndex(pageTurnModeIndex);

  /// 获取当前书架排序模式
  BookshelfSortMode get bookshelfSortMode => BookshelfSortModeExtension.fromIndex(bookshelfSortModeIndex);

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
    double? paragraphSpacing,
    double? indentSize,
    bool? showChapterTitle,
    int? pageTurnModeIndex,
    int? bookshelfSortModeIndex,
    bool? bookshelfSortAscending,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      themeIndex: themeIndex ?? this.themeIndex,
      verticalPadding: verticalPadding ?? this.verticalPadding,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      indentSize: indentSize ?? this.indentSize,
      showChapterTitle: showChapterTitle ?? this.showChapterTitle,
      pageTurnModeIndex: pageTurnModeIndex ?? this.pageTurnModeIndex,
      bookshelfSortModeIndex: bookshelfSortModeIndex ?? this.bookshelfSortModeIndex,
      bookshelfSortAscending: bookshelfSortAscending ?? this.bookshelfSortAscending,
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
      'paragraphSpacing': paragraphSpacing,
      'indentSize': indentSize,
      'showChapterTitle': showChapterTitle,
      'pageTurnModeIndex': pageTurnModeIndex,
      'bookshelfSortModeIndex': bookshelfSortModeIndex,
      'bookshelfSortAscending': bookshelfSortAscending,
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
      paragraphSpacing: (json['paragraphSpacing'] as num?)?.toDouble() ?? 8.0,
      indentSize: (json['indentSize'] as num?)?.toDouble() ?? 2.0,
      showChapterTitle: json['showChapterTitle'] as bool? ?? true,
      pageTurnModeIndex: json['pageTurnModeIndex'] as int? ?? 0,
      bookshelfSortModeIndex: json['bookshelfSortModeIndex'] as int? ?? 0,
      bookshelfSortAscending: json['bookshelfSortAscending'] as bool? ?? false,
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
