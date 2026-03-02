import 'package:json_annotation/json_annotation.dart';

part 'bookmark.g.dart';

/// 书签模型 - 用于保存阅读书签
@JsonSerializable(explicitToJson: true)
class Bookmark {
  final String bookUrl;      // 书籍URL（用于标识书籍）
  final String bookName;     // 书名
  final int chapterIndex;    // 章节索引
  final String chapterName;  // 章节名称
  final double scrollPosition; // 章节内滚动位置 (0.0 - 1.0)
  final DateTime createdAt;  // 创建时间
  final String? note;        // 备注（可选）

  Bookmark({
    required this.bookUrl,
    required this.bookName,
    required this.chapterIndex,
    required this.chapterName,
    required this.scrollPosition,
    required this.createdAt,
    this.note,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) => _$BookmarkFromJson(json);
  Map<String, dynamic> toJson() => _$BookmarkToJson(this);

  /// 生成唯一标识（用于判断同一位置的书签）
  String get uniqueKey => '$bookUrl-$chapterIndex-${scrollPosition.toStringAsFixed(3)}';

  /// 复制并修改
  Bookmark copyWith({
    String? bookUrl,
    String? bookName,
    int? chapterIndex,
    String? chapterName,
    double? scrollPosition,
    DateTime? createdAt,
    String? note,
  }) {
    return Bookmark(
      bookUrl: bookUrl ?? this.bookUrl,
      bookName: bookName ?? this.bookName,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterName: chapterName ?? this.chapterName,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
    );
  }

  @override
  String toString() {
    return 'Bookmark(bookName: $bookName, chapter: $chapterName, position: ${(scrollPosition * 100).toInt()}%)';
  }
}
