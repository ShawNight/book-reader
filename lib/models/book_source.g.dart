// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookSource _$BookSourceFromJson(Map<String, dynamic> json) => BookSource(
      bookSourceName: json['bookSourceName'] as String,
      bookSourceUrl: json['bookSourceUrl'] as String,
      bookSourceGroup: json['bookSourceGroup'] as String?,
      bookSourceComment: json['bookSourceComment'] as String?,
      customOrder: (json['customOrder'] as num?)?.toInt(),
      enabled: json['enabled'] as bool?,
      enabledExplore: json['enabledExplore'] as bool?,
      searchUrl: json['searchUrl'] as String?,
      ruleSearch: json['ruleSearch'] == null
          ? null
          : RuleSearch.fromJson(json['ruleSearch'] as Map<String, dynamic>),
      ruleBookInfo: json['ruleBookInfo'] == null
          ? null
          : RuleBookInfo.fromJson(json['ruleBookInfo'] as Map<String, dynamic>),
      ruleToc: json['ruleToc'] == null
          ? null
          : RuleToc.fromJson(json['ruleToc'] as Map<String, dynamic>),
      ruleContent: json['ruleContent'] == null
          ? null
          : RuleContent.fromJson(json['ruleContent'] as Map<String, dynamic>),
      exploreUrl: json['exploreUrl'] as String?,
      header: json['header'] as String?,
      concurrentRate: json['concurrentRate'] as String?,
    );

Map<String, dynamic> _$BookSourceToJson(BookSource instance) =>
    <String, dynamic>{
      'bookSourceName': instance.bookSourceName,
      'bookSourceUrl': instance.bookSourceUrl,
      'bookSourceGroup': instance.bookSourceGroup,
      'bookSourceComment': instance.bookSourceComment,
      'customOrder': instance.customOrder,
      'enabled': instance.enabled,
      'enabledExplore': instance.enabledExplore,
      'searchUrl': instance.searchUrl,
      'ruleSearch': instance.ruleSearch?.toJson(),
      'ruleBookInfo': instance.ruleBookInfo?.toJson(),
      'ruleToc': instance.ruleToc?.toJson(),
      'ruleContent': instance.ruleContent?.toJson(),
      'exploreUrl': instance.exploreUrl,
      'header': instance.header,
      'concurrentRate': instance.concurrentRate,
    };

RuleSearch _$RuleSearchFromJson(Map<String, dynamic> json) => RuleSearch(
      checkKeyWord: json['checkKeyWord'] as String?,
      bookList: json['bookList'] as String?,
      name: json['name'] as String?,
      author: json['author'] as String?,
      intro: json['intro'] as String?,
      kind: json['kind'] as String?,
      lastChapter: json['lastChapter'] as String?,
      updateTime: json['updateTime'] as String?,
      bookUrl: json['bookUrl'] as String?,
      coverUrl: json['coverUrl'] as String?,
      wordCount: json['wordCount'] as String?,
      tocUrl: json['tocUrl'] as String?,
    );

Map<String, dynamic> _$RuleSearchToJson(RuleSearch instance) =>
    <String, dynamic>{
      'checkKeyWord': instance.checkKeyWord,
      'bookList': instance.bookList,
      'name': instance.name,
      'author': instance.author,
      'intro': instance.intro,
      'kind': instance.kind,
      'lastChapter': instance.lastChapter,
      'updateTime': instance.updateTime,
      'bookUrl': instance.bookUrl,
      'coverUrl': instance.coverUrl,
      'wordCount': instance.wordCount,
      'tocUrl': instance.tocUrl,
    };

RuleBookInfo _$RuleBookInfoFromJson(Map<String, dynamic> json) => RuleBookInfo(
      init: json['init'] as String?,
      name: json['name'] as String?,
      author: json['author'] as String?,
      intro: json['intro'] as String?,
      kind: json['kind'] as String?,
      lastChapter: json['lastChapter'] as String?,
      updateTime: json['updateTime'] as String?,
      coverUrl: json['coverUrl'] as String?,
      tocUrl: json['tocUrl'] as String?,
      wordCount: json['wordCount'] as String?,
      canReName: json['canReName'] as String?,
    );

Map<String, dynamic> _$RuleBookInfoToJson(RuleBookInfo instance) =>
    <String, dynamic>{
      'init': instance.init,
      'name': instance.name,
      'author': instance.author,
      'intro': instance.intro,
      'kind': instance.kind,
      'lastChapter': instance.lastChapter,
      'updateTime': instance.updateTime,
      'coverUrl': instance.coverUrl,
      'tocUrl': instance.tocUrl,
      'wordCount': instance.wordCount,
      'canReName': instance.canReName,
    };

RuleToc _$RuleTocFromJson(Map<String, dynamic> json) => RuleToc(
      chapterList: json['chapterList'] as String?,
      chapterName: json['chapterName'] as String?,
      chapterUrl: json['chapterUrl'] as String?,
      isVip: json['isVip'] as String?,
      isPay: json['isPay'] as String?,
      updateTime: json['updateTime'] as String?,
      nextTocUrl: json['nextTocUrl'] as String?,
    );

Map<String, dynamic> _$RuleTocToJson(RuleToc instance) => <String, dynamic>{
      'chapterList': instance.chapterList,
      'chapterName': instance.chapterName,
      'chapterUrl': instance.chapterUrl,
      'isVip': instance.isVip,
      'isPay': instance.isPay,
      'updateTime': instance.updateTime,
      'nextTocUrl': instance.nextTocUrl,
    };

RuleContent _$RuleContentFromJson(Map<String, dynamic> json) => RuleContent(
      content: json['content'] as String?,
      nextContentUrl: json['nextContentUrl'] as String?,
      webJs: json['webJs'] as String?,
      sourceRegex: json['sourceRegex'] as String?,
      replaceRegex: json['replaceRegex'] as String?,
      imageStyle: json['imageStyle'] as String?,
      payAction: json['payAction'] as String?,
    );

Map<String, dynamic> _$RuleContentToJson(RuleContent instance) =>
    <String, dynamic>{
      'content': instance.content,
      'nextContentUrl': instance.nextContentUrl,
      'webJs': instance.webJs,
      'sourceRegex': instance.sourceRegex,
      'replaceRegex': instance.replaceRegex,
      'imageStyle': instance.imageStyle,
      'payAction': instance.payAction,
    };
