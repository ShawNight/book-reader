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
      lastReadChapter: (json['lastReadChapter'] as num?)?.toInt(),
      lastReadChapterName: json['lastReadChapterName'] as String?,
      scrollProgress: (json['scrollProgress'] as num?)?.toDouble(),
      lastReadTime: json['lastReadTime'] == null
          ? null
          : DateTime.parse(json['lastReadTime'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );

Map<String, dynamic> _$BookToJson(Book instance) => <String, dynamic>{
      'name': instance.name,
      'author': instance.author,
      'bookUrl': instance.bookUrl,
      'coverUrl': instance.coverUrl,
      'intro': instance.intro,
      'latestChapter': instance.latestChapter,
      'sourceName': instance.sourceName,
      'sourceUrl': instance.sourceUrl,
      'addedTime': instance.addedTime.toIso8601String(),
      'lastReadChapter': instance.lastReadChapter,
      'lastReadChapterName': instance.lastReadChapterName,
      'scrollProgress': instance.scrollProgress,
      'lastReadTime': instance.lastReadTime?.toIso8601String(),
      'isRead': instance.isRead,
    };
