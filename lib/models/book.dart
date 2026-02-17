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
  });

  factory Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);
  Map<String, dynamic> toJson() => _$BookToJson(this);

  /// 更新阅读进度
  Book copyWith({
    int? lastReadChapter,
    String? lastReadChapterName,
    String? latestChapter,
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
    );
  }
}
