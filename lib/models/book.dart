import 'package:json_annotation/json_annotation.dart';

part 'book.g.dart';

/// 书籍模型 - 用于书架收藏
@JsonSerializable(explicitToJson: true)
class Book {
  final String name;
  final String author;
  final String bookUrl;
  final String? coverUrl;
  final String? intro;
  final String? latestChapter;
  final String sourceName;
  final String sourceUrl;
  final DateTime addedTime;
  final int? lastReadChapter;
  final String? lastReadChapterName;
  final double? scrollProgress; // 章节内滚动进度 (0.0 - 1.0)
  final DateTime? lastReadTime; // 最近阅读时间
  final bool isRead; // 是否已读标记

  Book({
    required this.name,
    required this.author,
    required this.bookUrl,
    this.coverUrl,
    this.intro,
    this.latestChapter,
    required this.sourceName,
    required this.sourceUrl,
    required this.addedTime,
    this.lastReadChapter,
    this.lastReadChapterName,
    this.scrollProgress,
    this.lastReadTime,
    this.isRead = false, // 默认未读
  });

  factory Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);
  Map<String, dynamic> toJson() => _$BookToJson(this);

  /// 更新阅读进度
  Book copyWith({
    int? lastReadChapter,
    String? lastReadChapterName,
    String? latestChapter,
    double? scrollProgress,
    DateTime? lastReadTime,
    bool? isRead,
  }) {
    return Book(
      name: name,
      author: author,
      bookUrl: bookUrl,
      coverUrl: coverUrl,
      intro: intro,
      latestChapter: latestChapter ?? this.latestChapter,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      addedTime: addedTime,
      lastReadChapter: lastReadChapter ?? this.lastReadChapter,
      lastReadChapterName: lastReadChapterName ?? this.lastReadChapterName,
      scrollProgress: scrollProgress ?? this.scrollProgress,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      isRead: isRead ?? this.isRead,
    );
  }
}
