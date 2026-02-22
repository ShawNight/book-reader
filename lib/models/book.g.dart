// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Book _$BookFromJson(Map<String, dynamic> json) => Book(
      name: json['name'] as String,
      author: json['author'] as String,
      bookUrl: json['bookUrl'] as String,
      coverUrl: json['coverUrl'] as String?,
      intro: json['intro'] as String?,
      latestChapter: json['latestChapter'] as String?,
      sourceName: json['sourceName'] as String,
      sourceUrl: json['sourceUrl'] as String,
      addedTime: DateTime.parse(json['addedTime'] as String),
      lastReadChapter: json['lastReadChapter'] as int?,
      lastReadChapterName: json['lastReadChapterName'] as String?,
    );

Map<String, dynamic> _$BookToJson(Book instance) {
  final val = <String, dynamic>{
    'name': instance.name,
    'author': instance.author,
    'bookUrl': instance.bookUrl,
    'sourceName': instance.sourceName,
    'sourceUrl': instance.sourceUrl,
    'addedTime': instance.addedTime.toIso8601String(),
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('coverUrl', instance.coverUrl);
  writeNotNull('intro', instance.intro);
  writeNotNull('latestChapter', instance.latestChapter);
  writeNotNull('lastReadChapter', instance.lastReadChapter);
  writeNotNull('lastReadChapterName', instance.lastReadChapterName);

  return val;
}
